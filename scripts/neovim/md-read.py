import base64
import fcntl
import hashlib
import json
import os
import random
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import tty
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from markdown_it import MarkdownIt
from markdown_it.tree import SyntaxTreeNode
from mdit_py_plugins.amsmath import amsmath_plugin
from mdit_py_plugins.dollarmath import dollarmath_plugin
from mdit_py_plugins.front_matter import front_matter_plugin
from mdit_py_plugins.tasklists import tasklists_plugin
from pygments import lex
from pygments.lexers import get_lexer_by_name
from pygments.token import Comment, Keyword, Name, Number, Operator, String
from pygments.util import ClassNotFound
from pylatexenc.latex2text import LatexNodes2Text
from wcwidth import wcswidth

MAX_WIDTH = 100
PLACEHOLDER = "\U0010eeee"
DIACRITIC_RANGES = (
    "305 30D-30E 310 312 33D-33F 346 34A-34C 350-352 357 35B 363-36F 483-487 592-595 "
    "597-599 59C-5A1 5A8-5A9 5AB-5AC 5AF 5C4 610-617 657-65B 65D-65E 6D6-6DC 6DF-6E2 "
    "6E4 6E7-6E8 6EB-6EC 730 732-733 735-736 73A 73D 73F-741 743 745 747 749-74A "
    "7EB-7F1 7F3 816-819 81B-823 825-827 829-82D 951 953-954 F82-F83 F86-F87 "
    "135D-135F 17DD 193A 1A17 1A75-1A7C 1B6B 1B6D-1B73 1CD0-1CD2 1CDA-1CDB 1CE0 "
    "1DC0-1DC1 1DC3-1DC9 1DCB-1DCC 1DD1-1DE6 1DFE 20D0-20D1 20D4-20D7 20DB-20DC 20E1 "
    "20E7 20E9 20F0 2CEF-2CF1 2DE0-2DFF A66F A67C-A67D A6F0-A6F1 A8E0-A8F1 AAB0 "
    "AAB2-AAB3 AAB7-AAB8 AABE-AABF AAC1 FE20-FE26 10A0F 10A38 1D185-1D189 1D1AA-1D1AD "
    "1D242-1D244"
)
DIACRITICS = [
    chr(c)
    for span in DIACRITIC_RANGES.split()
    for lo, _, hi in [span.partition("-")]
    for c in range(int(lo, 16), int(hi or lo, 16) + 1)
]
VISUAL = {
    "mermaid": "mermaid",
    "plantuml": "plantuml",
    "puml": "plantuml",
    "uml": "plantuml",
    "math": "math",
}


def load_palette():
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    try:
        return json.loads((data / "theme-engine/bare-colors.json").read_text())
    except (OSError, ValueError):
        return {}


PALETTE = load_palette()


def rgb(name, layer=38):
    value = PALETTE.get(name, "")
    if len(value) != 7:
        return ""
    r, g, b = (int(value[i : i + 2], 16) for i in (1, 3, 5))
    return f"\x1b[{layer};2;{r};{g};{b}m"


def style(fg=None, bg=None, bold=False, italic=False, underline=False, strike=False):
    return "".join(
        [
            "\x1b[1m" if bold else "",
            "\x1b[3m" if italic else "",
            "\x1b[4m" if underline else "",
            "\x1b[9m" if strike else "",
            rgb(fg) if fg else "",
            rgb(bg, 48) if bg else "",
        ]
    )


RULE = style("border")
MUTED = style("fgMuted")

SYNTAX = [
    (Comment, style("fgMuted", italic=True)),
    (String, style("green")),
    (Number, style("yellow")),
    (Keyword, style("magenta")),
    (Name.Function, style("blue")),
    (Name.Builtin, style("cyan")),
    (Name.Class, style("yellow")),
    (Name.Decorator, style("cyan")),
    (Operator, style("fgDim")),
]


SCRIPTS = {
    "^": dict(zip("0123456789+-=()in", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁱⁿ")),
    "_": dict(
        zip("0123456789+-=()aehijklmnoprstuvx", "₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ")
    ),
}


def inline_math(src):
    def script(m):
        table, body = SCRIPTS[m[1]], m[2] or m[3]
        return (
            "".join(table[c] for c in body) if all(c in table for c in body) else m[0]
        )

    return (
        LatexNodes2Text()
        .latex_to_text(re.sub(r"([\^_])(?:\{([^{}]*)\}|(\w))", script, src))
        .strip()
    )


def width_of(text):
    return max(0, wcswidth(text))


class Renders:
    """Renders mermaid, PlantUML and display math to PNGs through neru render."""

    def __init__(self, wake):
        self.dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "md-read"
        self.dir.mkdir(parents=True, exist_ok=True)
        renderer = shutil.which("neru") or ""
        self.version = os.path.realpath(renderer) if renderer else ""
        self.pool = ThreadPoolExecutor(max_workers=2)
        self.pending = set()
        self.wake = wake

    def key(self, kind, src, color):
        return hashlib.sha1(
            f"{self.version}\0{kind}\0{color}\0{src}".encode()
        ).hexdigest()

    def get(self, kind, src, color):
        """Return ("ok", png, w, h), ("error", message) or ("pending",)."""
        key = self.key(kind, src, color)
        meta, err = self.dir / f"{key}.json", self.dir / f"{key}.err"
        if meta.exists():
            w, h = json.loads(meta.read_text())
            return ("ok", self.dir / f"{key}.png", w, h)
        if err.exists():
            return (
                "error",
                (err.read_text().strip() or "render failed").splitlines()[0],
            )
        if not self.version:
            return ("error", "neru is not on PATH")
        if key not in self.pending:
            self.pending.add(key)
            self.pool.submit(self.run, key, kind, src, color)
        return ("pending",)

    def run(self, key, kind, src, color):
        source = self.dir / f"{key}.src"
        source.write_text(src)
        try:
            done = subprocess.run(
                [
                    "neru",
                    "render",
                    kind,
                    str(source),
                    str(self.dir / f"{key}.png"),
                    color,
                ],
                capture_output=True,
                check=False,
                text=True,
                timeout=60,
            )
            if done.returncode == 0:
                w, h = map(int, done.stdout.split())
                (self.dir / f"{key}.json").write_text(json.dumps([w, h]))
            else:
                (self.dir / f"{key}.err").write_text(
                    done.stderr or f"render failed ({done.returncode})"
                )
        except (subprocess.TimeoutExpired, ValueError) as error:
            (self.dir / f"{key}.err").write_text(str(error))
        self.pending.discard(key)
        os.write(self.wake, b"x")


class Images:
    """Places PNGs through kitty's Unicode placeholders, so they scroll as text."""

    def __init__(self):
        self.placed = {}

    def rows(self, png, cols, rows):
        prev = self.placed.get(png)
        if prev and prev[1:] == (cols, rows):
            image_id = prev[0]
        else:
            image_id = prev[0] if prev else random.randint(1, 0xFFFFFF)
            payload = base64.b64encode(str(png).encode()).decode()
            sys.stdout.write(f"\x1b_Ga=d,d=I,i={image_id},q=2\x1b\\")
            sys.stdout.write(
                f"\x1b_Ga=T,U=1,f=100,t=f,i={image_id},c={cols},r={rows},q=2;{payload}\x1b\\"
            )
            self.placed[png] = (image_id, cols, rows)
        colour = (
            f"\x1b[38;2;{image_id >> 16 & 255};{image_id >> 8 & 255};{image_id & 255}m"
        )
        return [
            [(PLACEHOLDER + DIACRITICS[r] + PLACEHOLDER * (cols - 1), colour)]
            for r in range(rows)
        ]

    def clear(self):
        for image_id, _, _ in self.placed.values():
            sys.stdout.write(f"\x1b_Ga=d,d=I,i={image_id},q=2\x1b\\")
        self.placed.clear()


class Document:
    def __init__(self, renders, images, cell):
        self.renders = renders
        self.images = images
        self.cell = cell
        self.md = (
            MarkdownIt("commonmark", {"breaks": False})
            .enable(["table", "strikethrough"])
            .use(front_matter_plugin)
            .use(dollarmath_plugin, double_inline=True)
            .use(amsmath_plugin)
            .use(tasklists_plugin)
        )
        self.math_color = PALETTE.get("fg", "#e4e4e4")

    def render(self, source, width):
        self.source = source.split("\n")
        return self.blocks(SyntaxTreeNode(self.md.parse(source)).children, width)

    def blocks(self, nodes, width, gap=True):
        out = []
        for node in nodes:
            lines = self.block(node, width)
            if lines is None:
                continue
            if out and gap:
                out.append([])
            out.extend(lines)
        return out

    def block(self, node, width):
        kind = node.type
        if kind == "front_matter":
            return None
        if kind == "heading":
            level = int(node.tag[1])
            spans = self.inline(node.children[0], style("accent", bold=True))
            if level == 1:
                h1 = style("bg", "accent", bold=True)
                return [
                    [(" ", h1), *[(t, h1) for t, _ in line], (" ", h1)]
                    for line in wrap(spans, width - 2)
                ]
            return wrap(
                [("#" * level + " ", style("accent", bold=True)), *spans], width
            )
        if kind == "paragraph":
            return wrap(self.inline(node.children[0]), width)
        if kind in ("fence", "code_block"):
            lang = node.info.strip().split(" ")[0].lower() if kind == "fence" else ""
            if lang in VISUAL:
                return self.visual(VISUAL[lang], node.content.rstrip("\n"), width)
            return code_block(node.content.rstrip("\n"), lang, width)
        if kind in ("math_block", "math_block_label"):
            return self.visual("math", node.content.strip(), width)
        if kind == "amsmath":
            return self.visual("math", node.content.strip(), width)
        if kind == "blockquote":
            bar = ("│ ", style("border"))
            return [[bar, *line] for line in self.blocks(node.children, width - 2)]
        if kind in ("bullet_list", "ordered_list"):
            return self.list(node, width)
        if kind == "table":
            return self.table(node, width)
        if kind == "hr":
            return [[("─" * width, RULE)]]
        if kind == "html_block":
            return [[(line, MUTED)] for line in node.content.rstrip("\n").split("\n")]
        return None

    def list(self, node, width):
        ordered = node.type == "ordered_list"
        start = int(node.attrs.get("start", 1)) if ordered else 1
        marker_width = len(f"{start + len(node.children) - 1}.") + 1 if ordered else 2
        out = []
        for k, item in enumerate(node.children):
            marker = f"{start + k}." if ordered else "•"
            body = self.blocks(
                item.children,
                width - marker_width,
                gap=not node.meta.get("tight", True),
            ) or [[]]
            for n, line in enumerate(body):
                head = marker.ljust(marker_width) if n == 0 else " " * marker_width
                out.append([(head, style("accent")), *line])
        return out

    def table(self, node, width):
        rows = [row for section in node.children for row in section.children]
        cells = [
            [
                self.inline(
                    cell.children[0], style(bold=True) if cell.type == "th" else ""
                )
                if cell.children
                else []
                for cell in row.children
            ]
            for row in rows
        ]
        align = [
            (cell.attrs.get("style") or "").removeprefix("text-align:")
            for cell in rows[0].children
        ]
        widths = [
            max(3, *(sum(width_of(t) for t, _ in r[k]) for r in cells if k < len(r)))
            for k in range(len(align))
        ]
        room = width - 3 * len(widths) - 1
        if room < 3 * len(widths):
            return [[(line, "")] for line in self.raw(node)]
        floor = [
            max(
                3,
                *(
                    width_of(word)
                    for r in cells
                    if k < len(r)
                    for word in "".join(t for t, _ in r[k]).split()
                ),
            )
            for k in range(len(widths))
        ]
        while sum(widths) > room:
            k = max(range(len(widths)), key=lambda k: (widths[k] > floor[k], widths[k]))
            widths[k] -= 1
        edge = lambda left, mid, right: [
            (left + mid.join("─" * (w + 2) for w in widths) + right, RULE)
        ]
        out = [edge("┌", "┬", "┐")]
        for n, r in enumerate(cells):
            wrapped = [
                wrap(r[k] if k < len(r) else [], w) for k, w in enumerate(widths)
            ]
            for i in range(max(map(len, wrapped))):
                line = []
                for k, w in enumerate(widths):
                    spans = wrapped[k][i] if i < len(wrapped[k]) else []
                    gap = w - sum(width_of(t) for t, _ in spans)
                    left = (
                        gap
                        if align[k] == "right"
                        else gap // 2
                        if align[k] == "center"
                        else 0
                    )
                    line += [
                        ("│ " if k == 0 else " │ ", RULE),
                        (" " * left, ""),
                        *spans,
                        (" " * (gap - left), ""),
                    ]
                out.append([*line, (" │", RULE)])
            if n == 0:
                out.append(edge("├", "┼", "┤"))
        out.append(edge("└", "┴", "┘"))
        return out

    def raw(self, node):
        start, end = node.map or (0, 0)
        return self.source[start:end]

    def visual(self, kind, src, width):
        color = self.math_color if kind == "math" else ""
        state = self.renders.get(kind, src, color)
        if state[0] == "ok":
            _, png, w, h = state
            scale = 1 if kind == "plantuml" else 2
            cols, rows = w / scale / self.cell[0], h / scale / self.cell[1]
            fit = min(1, width / cols, 255 / rows)
            cols, rows = max(1, round(cols * fit)), max(1, round(rows * fit))
            pad = (" " * ((width - cols) // 2), "")
            return [[pad, *line] for line in self.images.rows(png, cols, rows)]
        note = f"⚠ {state[1]}" if state[0] == "error" else "rendering…"
        return [
            *code_block(src, "latex" if kind == "math" else kind, width),
            [(note, MUTED)],
        ]

    def inline(self, node, base=""):
        out = []
        marks = []

        def walk(n):
            current = base + "".join(marks)
            t = n.type
            if t == "text":
                out.append((n.content, current))
            elif t == "softbreak":
                out.append((" ", current))
            elif t == "hardbreak":
                out.append(("\n", current))
            elif t == "code_inline":
                out.append((n.content, current + style("red", "bgAlt")))
            elif t in ("math_inline", "math_inline_double"):
                out.append(
                    (inline_math(n.content), current + style("magenta", italic=True))
                )
            elif t == "html_inline":
                if "task-list-item-checkbox" in n.content:
                    out.append(
                        (
                            "☑ " if "checked" in n.content else "☐ ",
                            current + style("accent"),
                        )
                    )
                else:
                    out.append((n.content, current + MUTED))
            elif t == "image":
                out.append(
                    (
                        "▣ " + (n.content or n.attrs.get("src", "")),
                        current + style("accent"),
                    )
                )
            else:
                mark = {
                    "strong": style(bold=True),
                    "em": style(italic=True),
                    "s": style(strike=True),
                    "link": style("accent", underline=True),
                }.get(t, "")
                marks.append(mark)
                for child in n.children:
                    walk(child)
                marks.pop()
                if t == "link":
                    href = n.attrs.get("href", "")
                    label = "".join(c.content for c in n.walk() if c.type == "text")
                    if href and href != label and not href.startswith("#"):
                        out.append((f" {href}", base + MUTED))

        for child in node.children:
            walk(child)
        return out


def wrap(spans, width):
    width = max(1, width)
    lines, line, used, gap = [], [], 0, None
    for text, sgr in spans:
        for n, segment in enumerate(text.split("\n")):
            if n:
                lines.append(line)
                line, used, gap = [], 0, None
            for k, word in enumerate(segment.split(" ")):
                if k and line:
                    gap = sgr
                if not word:
                    continue
                w = width_of(word)
                if gap is not None and used + 1 + w > width:
                    lines.append(line)
                    line, used, gap = [], 0, None
                if gap is not None:
                    line.append((" ", gap))
                    used += 1
                    gap = None
                while used + w > width:
                    cut = 0
                    while cut < len(word) and width_of(word[: cut + 1]) <= width - used:
                        cut += 1
                    cut = cut or (0 if line else 1)
                    line.append((word[:cut], sgr))
                    lines.append(line)
                    line, used = [], 0
                    word = word[cut:]
                    w = width_of(word)
                if word:
                    line.append((word, sgr))
                    used += w
    lines.append(line)
    return lines


def code_block(src, lang, width):
    label = lang if lang and len(lang) + 6 <= width else ""
    top = (
        [
            ("─ ", RULE),
            (label, style("accent")),
            (" " + "─" * (width - len(label) - 3), RULE),
        ]
        if label
        else [("─" * width, RULE)]
    )
    try:
        tokens = list(lex(src, get_lexer_by_name(lang))) if lang else [(None, src)]
    except ClassNotFound:
        tokens = [(None, src)]
    lines, line, used = [], [], 0
    for token, value in tokens:
        sgr = next((s for t, s in SYNTAX if token is not None and token in t), "")
        for n, piece in enumerate(value.replace("\t", "    ").split("\n")):
            if n:
                lines.append(line)
                line, used = [], 0
            room = width - used
            if piece and room > 0:
                line.append((piece[:room], sgr))
                used += min(len(piece), room)
    if line:
        lines.append(line)
    while lines and not lines[-1]:
        lines.pop()
    return [top, *lines, [("─" * width, RULE)]]


def cell_size():
    try:
        rows, cols, xpx, ypx = struct.unpack(
            "HHHH", fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, b"\0" * 8)
        )
    except OSError:
        return 80, 24, 10, 21
    return cols, rows, (xpx / cols if xpx else 10), (ypx / rows if ypx else 21)


def to_ansi(line):
    return "".join(f"{sgr}{text}\x1b[0m" if sgr else text for text, sgr in line)


KEYS = {
    "j": 1,
    "\x1b[B": 1,
    "\x0e": 1,
    "\r": 1,
    "k": -1,
    "\x1b[A": -1,
    "\x10": -1,
    "d": "half",
    "\x04": "half",
    "u": "-half",
    "\x15": "-half",
    " ": "page",
    "f": "page",
    "\x1b[6~": "page",
    "\x06": "page",
    "b": "-page",
    "\x1b[5~": "-page",
    "\x02": "-page",
    "g": "top",
    "\x1b[H": "top",
    "G": "bottom",
    "\x1b[F": "bottom",
}


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: md-read <file.md>")
    path = Path(sys.argv[1])
    if not sys.stdout.isatty():
        sys.exit("md-read: stdout is not a terminal")

    wake_r, wake_w = os.pipe()
    renders = Renders(wake_w)
    images = Images()
    signal.signal(signal.SIGWINCH, lambda *_: os.write(wake_w, b"r"))

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    tty.setraw(fd)
    sys.stdout.write("\x1b[?1049h\x1b[?25l")
    top, lines, mtime = 0, [], None

    def layout():
        nonlocal lines
        cols, rows, cw, ch = cell_size()
        width = min(MAX_WIDTH, cols - 4)
        doc = Document(renders, images, (cw, ch))
        try:
            body = doc.render(path.read_text(), width)
        except OSError as error:
            body = [[(f"⚠ {error}", style("error"))]]
        margin = (" " * ((cols - width) // 2), "")
        lines = [[margin, *line] for line in [[], *body, []]]
        return rows

    def draw(rows):
        nonlocal top
        view = rows - 1
        top = max(0, min(top, len(lines) - view))
        out = ["\x1b[H"]
        for line in lines[top : top + view]:
            out.append(to_ansi(line) + "\x1b[K\r\n")
        out.append("\x1b[J")
        end = min(len(lines), top + view)
        pct = 100 if len(lines) <= view else round(100 * end / len(lines))
        status = f" {path.name}  {pct}%  q quit"
        out.append(f"\x1b[{rows};1H{MUTED}{status}\x1b[0m\x1b[K")
        sys.stdout.write("".join(out))
        sys.stdout.flush()

    try:
        rows = layout()
        mtime = path.stat().st_mtime if path.exists() else None
        draw(rows)
        while True:
            ready, _, _ = select.select([fd, wake_r], [], [], 0.5)
            relayout = False
            if wake_r in ready:
                os.read(wake_r, 1024)
                relayout = True
            if fd in ready:
                view = rows - 1
                for key in re.findall(
                    r"\x1b\[[0-9;]*[A-Za-z~]|.",
                    os.read(fd, 64).decode(errors="ignore"),
                    re.DOTALL,
                ):
                    if key in ("q", "\x1b", "\x03"):
                        return
                    action = KEYS.get(key)
                    if key == "r":
                        relayout = True
                    elif isinstance(action, int):
                        top += action
                    elif action in ("half", "-half"):
                        top += view // 2 * (-1 if action[0] == "-" else 1)
                    elif action in ("page", "-page"):
                        top += (view - 1) * (-1 if action[0] == "-" else 1)
                    elif action == "top":
                        top = 0
                    elif action == "bottom":
                        top = len(lines)
            current = path.stat().st_mtime if path.exists() else None
            if current != mtime:
                mtime, relayout = current, True
            if relayout:
                rows = layout()
            draw(rows)
    finally:
        images.clear()
        sys.stdout.write("\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)


if __name__ == "__main__":
    main()
    os._exit(0)
