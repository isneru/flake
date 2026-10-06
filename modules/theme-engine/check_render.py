#!/usr/bin/env python3

import ast
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import theme_engine as te


def _check_json(text: str) -> None:
    json.loads(text)


def _check_python(text: str) -> None:
    ast.parse(text)


def _check_lua(text: str) -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".lua") as handle:
        handle.write(text)
        handle.flush()
        result = subprocess.run(
            ["luac", "-p", handle.name], capture_output=True, text=True, check=False
        )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip())


PARSERS = {
    ".json": _check_json,
    ".py": _check_python,
    ".lua": _check_lua,
}


def main() -> None:
    themes = te.list_themes()
    if not themes:
        sys.exit(f"check_render: no themes found in {te.THEMES_DIR}")
    apps = te.load_apps()
    failures = []
    parsed = 0
    for theme in themes:
        tokens = te.load_theme(theme)
        for name, app in apps.items():
            label = f"{name}.tmpl"
            path = te.TEMPLATES_DIR / label
            if not path.is_file():
                failures.append(f"{theme}: {label}: file missing")
                continue
            rendered = te.render(path.read_text(), tokens)
            leftover = te.leftover_tokens(rendered)
            if leftover:
                failures.append(
                    f"{theme}: {label}: unreplaced tokens: {', '.join(leftover)}"
                )
            parser = PARSERS.get(Path(app["target"]).suffix)
            if parser is None:
                continue
            try:
                parser(rendered)
                parsed += 1
            except Exception as error:  # noqa: BLE001 - reported, not raised
                failures.append(f"{theme}: {label}: does not parse: {error}")
    if failures:
        sys.exit("\n".join(failures))
    print(
        f"OK: {len(themes)} themes x {len(apps)} templates rendered clean "
        f"({parsed} also parsed against their target format)"
    )


if __name__ == "__main__":
    main()
