const MARK = /^(\s*)(?:[-*+] \[[ xX]\] |[-*+] |\d+[.)] )?/
const LISTS = {
  ul: [/^\s*[-*+] (?!\[[ xX]\] )/, () => "- "],
  ol: [/^\s*\d+[.)] /, (n) => `${n}. `],
  task: [/^\s*[-*+] \[[ xX]\] /, () => "- [ ] "],
}

const insert = (area, start, end, text, from, to) => {
  area.focus()
  area.setSelectionRange(start, end)
  if (!document.execCommand("insertText", false, text)) {
    area.setRangeText(text, start, end)
    area.dispatchEvent(new Event("input"))
  }
  area.setSelectionRange(start + from, start + to)
}

const inline = (area, mark, placeholder) => {
  const { selectionStart: s, selectionEnd: e, value: v } = area
  const picked = v.slice(s, e)
  if (v.slice(s - mark.length, s) === mark && v.slice(e, e + mark.length) === mark) {
    insert(area, s - mark.length, e + mark.length, picked, 0, picked.length)
    return
  }
  const body = picked || placeholder
  insert(area, s, e, mark + body + mark, mark.length, mark.length + body.length)
}

const lines = (area, edit) => {
  const { selectionStart: s, selectionEnd: e, value: v } = area
  const start = v.lastIndexOf("\n", s - 1) + 1
  let end = v.indexOf("\n", e > s && v[e - 1] === "\n" ? e - 1 : e)
  if (end < 0) end = v.length
  const text = edit(v.slice(start, end).split("\n")).join("\n")
  insert(area, start, end, text, s === e ? text.length : 0, text.length)
}

const block = (area, text, from, to) => {
  const { selectionStart: s, selectionEnd: e, value: v } = area
  const lead = s > 0 && v[s - 1] !== "\n" ? "\n" : ""
  insert(area, s, e, lead + text, lead.length + from, lead.length + to)
}

const list = (area, kind) => {
  const [is, mark] = LISTS[kind]
  lines(area, (ls) => {
    const off = ls.every((l) => is.test(l))
    let n = 0
    return ls.map((l) => {
      const [head, indent] = l.match(MARK)
      if (off) return indent + l.slice(head.length)
      if (!l.trim() && ls.length > 1) return l
      return indent + mark(++n) + l.slice(head.length)
    })
  })
}

const ROW = /^\s*\|/
const RULE = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/
const FENCE = /^\s*(`{3,}|~{3,})/
const width = (text) => [...text].length

const cells = (line) => {
  let row = line.trim()
  if (row.startsWith("|")) row = row.slice(1)
  if (row.endsWith("|") && !row.endsWith("\\|")) row = row.slice(0, -1)
  return row.split(/(?<!\\)\|/).map((c) => c.trim())
}

const tidy = (rows) => {
  const table = rows.map(cells)
  const n = table[0].length
  if (table[1].length !== n || table.some((r) => r.length > n)) return rows
  const indent = rows[0].match(/^\s*/)[0]
  const align = table[1].map((c) => (c.endsWith(":") ? (c.startsWith(":") ? "c" : "r") : c.startsWith(":") ? "l" : ""))
  const widths = align.map((_, i) => Math.max(3, ...table.map((r, j) => (j === 1 ? 0 : width(r[i] ?? "")))))
  return table.map((r, j) => {
    const out = widths.map((w, i) => {
      const a = align[i]
      if (j === 1) return (a === "l" || a === "c" ? ":" : "-") + "-".repeat(w - 2) + (a === "r" || a === "c" ? ":" : "-")
      const c = r[i] ?? ""
      const pad = w - width(c)
      if (a === "r") return " ".repeat(pad) + c
      if (a === "c") return " ".repeat(pad >> 1) + c + " ".repeat(pad - (pad >> 1))
      return c + " ".repeat(pad)
    })
    return `${indent}| ${out.join(" | ")} |`
  })
}

const tidyTables = (text) => {
  const lines = text.split("\n")
  const out = []
  let fence = ""
  for (let i = 0; i < lines.length; ) {
    const open = lines[i].match(FENCE)
    if (open && (!fence || (open[1][0] === fence[0] && open[1].length >= fence.length))) {
      fence = fence ? "" : open[1]
    } else if (!fence && ROW.test(lines[i]) && ROW.test(lines[i + 1] ?? "") && RULE.test(lines[i + 1])) {
      let j = i + 2
      while (j < lines.length && ROW.test(lines[j])) j++
      out.push(...tidy(lines.slice(i, j)))
      i = j
      continue
    }
    out.push(lines[i])
    i++
  }
  return out.join("\n")
}

const TOOLS = {
  bold: (a) => inline(a, "**", "bold"),
  italic: (a) => inline(a, "_", "italic"),
  strike: (a) => inline(a, "~~", "text"),
  code: (a) => inline(a, "`", "code"),
  math: (a) => inline(a, "$", "x"),
  link: (a) => {
    const text = a.value.slice(a.selectionStart, a.selectionEnd) || "text"
    insert(a, a.selectionStart, a.selectionEnd, `[${text}](url)`, text.length + 3, text.length + 6)
  },
  heading: (a) =>
    lines(a, (ls) =>
      ls.map((l) => {
        const level = l.match(/^#{0,6}/)[0].length
        const rest = l.replace(/^#{1,6} ?/, "")
        return level >= 3 ? rest : `${"#".repeat(level + 1)} ${rest}`
      }),
    ),
  quote: (a) =>
    lines(a, (ls) => (ls.every((l) => l.startsWith(">")) ? ls.map((l) => l.replace(/^> ?/, "")) : ls.map((l) => `> ${l}`))),
  ul: (a) => list(a, "ul"),
  ol: (a) => list(a, "ol"),
  task: (a) => list(a, "task"),
  block: (a) => {
    const picked = a.value.slice(a.selectionStart, a.selectionEnd)
    block(a, `\`\`\`\n${picked}\n\`\`\`\n`, 4, 4 + picked.length)
  },
  table: (a) => block(a, "| Column | Column |\n| --- | --- |\n|  |  |\n", 2, 8),
  tidy: (a) => {
    const { value: v, selectionStart: s } = a
    const text = tidyTables(v)
    if (text === v) return
    const before = v.slice(0, s).split("\n")
    const row = text.split("\n").slice(0, before.length)
    const col = Math.min(before.at(-1).length, row.at(-1).length)
    const at = row.slice(0, -1).join("\n").length + (row.length > 1 ? 1 : 0) + col
    insert(a, 0, v.length, text, at, at)
  },
}

export const format = (area, name) => TOOLS[name](area)

export const continueList = (area, event) => {
  const { selectionStart: s, selectionEnd: e, value: v } = area
  if (event.shiftKey || event.isComposing || s !== e) return
  const start = v.lastIndexOf("\n", s - 1) + 1
  const line = v.slice(start, s)
  const m = line.match(/^(\s*)([-*+] \[[ xX]\] |[-*+] |(\d+)([.)]) |> )/)
  if (!m) return
  event.preventDefault()
  if (line === m[0]) {
    insert(area, start, s, "", 0, 0)
    return
  }
  const next = m[3] ? `${Number(m[3]) + 1}${m[4]} ` : m[2].replace(/\[[xX]\]/, "[ ]")
  const text = `\n${m[1]}${next}`
  insert(area, s, s, text, text.length, text.length)
}
