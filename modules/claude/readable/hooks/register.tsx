import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Renders } from '../types'
import { latexMath, unicodeMath } from './unicode-math'

const renders = atom({ plugin: 'readable', key: 'renders' } as const, 0)

const C = {
  h1Fg: '#ffff87',
  h1Bg: '#5f5fff',
  heading: '#00afff',
  code: '#ff5f5f',
  codeBg: '#303030',
  link: '#00af87',
  url: '#585858',
  math: '#d7afff',
  rule: '#585858',
  quote: '#808080',
  bullet: '#00afff',
}

type Kind = 'math' | 'plantuml' | 'mermaid'

type Block =
  | { type: 'heading'; level: number; text: string }
  | { type: 'para'; text: string }
  | { type: 'code'; lang: string; src: string }
  | { type: 'visual'; kind: Kind; src: string }
  | { type: 'quote'; blocks: Block[] }
  | { type: 'list'; ordered: boolean; start: number; items: Block[][] }
  | { type: 'table'; raw: string; align: string[]; header: string[]; rows: string[][] }
  | { type: 'hr' }

type Span = {
  text: string
  bold?: boolean
  italic?: boolean
  strike?: boolean
  code?: boolean
  math?: boolean
  link?: boolean
  url?: boolean
}

const FENCE = /^\s*(`{3,}|~{3,})\s*([\w+#.-]*)/
const HEADING = /^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/
const HR = /^\s{0,3}([-*_])(\s*\1){2,}\s*$/
const QUOTE = /^\s{0,3}>\s?/
const LIST = /^(\s*)([-*+]|\d{1,9}[.)])\s+(.*)$/
const TABLE_SEP = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/

const indentOf = (line: string) => line.length - line.trimStart().length

const visualKind = (lang: string): Kind | undefined =>
  lang === 'math' ? 'math'
    : lang === 'mermaid' ? 'mermaid'
      : ['plantuml', 'puml', 'uml'].includes(lang) ? 'plantuml'
        : undefined

const startsBlock = (line: string) => {
  const t = line.trim()
  return FENCE.test(line) || HEADING.test(line) || HR.test(line) || QUOTE.test(line)
    || LIST.test(line) || t.startsWith('$$') || t.startsWith('\\[') || t.startsWith('@startuml')
}

const splitRow = (line: string) =>
  line.trim().replace(/^\|/, '').replace(/\|$/, '').split(/(?<!\\)\|/).map(c => c.trim())

function untilClose(lines: string[], i: number, open: string, close: string) {
  const first = lines[i].trim().slice(open.length)
  if (first.trimEnd().endsWith(close) && first.trim().length >= close.length) {
    return { src: first.trimEnd().slice(0, -close.length), next: i + 1 }
  }
  const body = [first]
  for (let j = i + 1; j < lines.length; j++) {
    const t = lines[j].trimEnd()
    if (t.endsWith(close)) {
      body.push(t.slice(0, -close.length))
      return { src: body.join('\n'), next: j + 1 }
    }
    body.push(lines[j])
  }
  return undefined
}

function parseBlocks(lines: string[]): Block[] {
  const out: Block[] = []
  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    const t = line.trim()
    if (!t) { i++; continue }

    const fence = FENCE.exec(line)
    if (fence) {
      const body: string[] = []
      let j = i + 1
      while (j < lines.length && !lines[j].trim().startsWith(fence[1])) body.push(lines[j++])
      const isClosed = j < lines.length
      const lang = fence[2].toLowerCase()
      const kind = visualKind(lang)
      const src = body.join('\n')
      out.push(kind && isClosed ? { type: 'visual', kind, src } : { type: 'code', lang, src })
      i = j + 1
      continue
    }

    if (t.startsWith('@startuml')) {
      const j = lines.findIndex((l, k) => k > i && l.trim().startsWith('@enduml'))
      if (j !== -1) {
        out.push({ type: 'visual', kind: 'plantuml', src: lines.slice(i, j + 1).join('\n') })
        i = j + 1
        continue
      }
    }

    const delims = t.startsWith('$$') ? ['$$', '$$'] : t.startsWith('\\[') ? ['\\[', '\\]'] : undefined
    const math = delims && untilClose(lines, i, delims[0], delims[1])
    if (math && math.src.trim()) {
      out.push({ type: 'visual', kind: 'math', src: math.src.trim() })
      i = math.next
      continue
    }

    const heading = HEADING.exec(line)
    if (heading) {
      out.push({ type: 'heading', level: heading[1].length, text: heading[2] })
      i++
      continue
    }

    if (HR.test(line)) { out.push({ type: 'hr' }); i++; continue }

    if (QUOTE.test(line)) {
      const body: string[] = []
      while (i < lines.length && QUOTE.test(lines[i])) body.push(lines[i++].replace(QUOTE, ''))
      out.push({ type: 'quote', blocks: parseBlocks(body) })
      continue
    }

    if (line.includes('|') && i + 1 < lines.length && TABLE_SEP.test(lines[i + 1]) && lines[i + 1].includes('-')) {
      const start = i
      const header = splitRow(line)
      const align = splitRow(lines[i + 1]).map(c =>
        c.startsWith(':') && c.endsWith(':') ? 'center' : c.endsWith(':') ? 'right' : 'left')
      const rows: string[][] = []
      i += 2
      while (i < lines.length && lines[i].includes('|') && lines[i].trim()) rows.push(splitRow(lines[i++]))
      out.push({ type: 'table', raw: lines.slice(start, i).join('\n'), align, header, rows })
      continue
    }

    const item = LIST.exec(line)
    if (item) {
      const base = indentOf(line)
      const ordered = /\d/.test(item[2])
      const items: string[][] = []
      let cur: string[] = []
      let contentIndent = 0
      while (i < lines.length) {
        const l = lines[i]
        const m = LIST.exec(l)
        if (m && indentOf(l) === base) {
          cur = [m[3]]
          items.push(cur)
          contentIndent = m[1].length + m[2].length + 1
        } else if (!l.trim()) {
          const nextLine = lines[i + 1]
          if (nextLine === undefined || !nextLine.trim() || indentOf(nextLine) < base
            || (indentOf(nextLine) === base && !LIST.test(nextLine))) break
          cur.push('')
        } else if (indentOf(l) > base) {
          cur.push(l.slice(Math.min(contentIndent, indentOf(l))))
        } else if (lines[i - 1]?.trim() && !startsBlock(l)) {
          cur.push(l.trim())
        } else {
          break
        }
        i++
      }
      out.push({ type: 'list', ordered, start: ordered ? parseInt(item[2], 10) : 1, items: items.map(parseBlocks) })
      continue
    }

    const body = [t]
    i++
    while (i < lines.length && lines[i].trim() && !startsBlock(lines[i])) body.push(lines[i++].trim())
    out.push({ type: 'para', text: body.join(' ') })
  }
  return out
}

const INLINE = new RegExp([
  '(`+)([\\s\\S]*?[^`])\\1(?!`)',
  '\\$(?![\\s$])([^$\\n]*?[^\\s\\\\])\\$(?!\\d)',
  '\\\\\\(([\\s\\S]+?)\\\\\\)',
  '\\*\\*([\\s\\S]+?)\\*\\*|__([\\s\\S]+?)__',
  '~~([\\s\\S]+?)~~',
  '\\*(?!\\s)([\\s\\S]+?)\\*|\\b_(?!\\s)([\\s\\S]+?)_\\b',
  '\\[([^\\]]+)\\]\\(([^)\\s]+)[^)]*\\)',
  '<?(https?://[^\\s>]+[^\\s>.,;:!?)])>?',
].join('|'), 'g')

function parseInline(text: string, style: Omit<Span, 'text'> = {}): Span[] {
  const out: Span[] = []
  let last = 0
  for (const m of text.matchAll(INLINE)) {
    const at = m.index ?? 0
    if (at > last) out.push({ ...style, text: text.slice(last, at) })
    last = at + m[0].length
    if (m[2] !== undefined) out.push({ ...style, code: true, text: m[2].trim() })
    else if (m[3] !== undefined || m[4] !== undefined) out.push({ ...style, math: true, text: unicodeMath((m[3] ?? m[4]).trim()) })
    else if (m[5] !== undefined || m[6] !== undefined) out.push(...parseInline(m[5] ?? m[6], { ...style, bold: true }))
    else if (m[7] !== undefined) out.push(...parseInline(m[7], { ...style, strike: true }))
    else if (m[8] !== undefined || m[9] !== undefined) out.push(...parseInline(m[8] ?? m[9], { ...style, italic: true }))
    else if (m[10] !== undefined) {
      out.push(...parseInline(m[10], { ...style, link: true }))
      if (m[11] !== m[10]) out.push({ text: ` ${m[11]}`, url: true })
    } else out.push({ ...style, link: true, text: m[12] })
  }
  if (last < text.length) out.push({ ...style, text: text.slice(last) })
  return out.map(s => ({ ...s, text: s.code || s.math ? s.text : s.text.replace(/\\([\\`*_{}[\]()#+\-.!|$~])/g, '$1') }))
}

const plain = (text: string) => parseInline(text).map(s => s.text).join('')

const pending = new Set<string>()
const failed = new Map<string, string>()
let cache: { dir: string; version: string } | undefined

function hashKey(s: string) {
  let a = 0x811c9dc5
  let b = 0x01000193
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i)
    a = Math.imul(a ^ c, 0x01000193)
    b = Math.imul(b ^ c, 0x5bd1e995)
  }
  return (a >>> 0).toString(16).padStart(8, '0') + (b >>> 0).toString(16).padStart(8, '0')
}

async function renderCache($: EngineInterface) {
  if (!cache) {
    const runtime = await $.env.get('XDG_RUNTIME_DIR')
    const renderer = await $.process
      .run(['sh', '-c', 'readlink -f "$(command -v readable-render)"'], { timeoutMs: 5_000 })
      .catch(() => undefined)
    cache = { dir: `${runtime || '/tmp'}/claude-readable`, version: renderer?.stdout?.trim() ?? '' }
  }
  return cache
}

function schedule($: EngineInterface, key: string, kind: Kind, src: string, color: string) {
  if (pending.has(key)) return
  pending.add(key)
  $.clock.after(0, async () => {
    try {
      const { dir } = await renderCache($)
      await $.fs.write(`${dir}/${key}.src`, src)
      const run = await $.process.run(
        ['readable-render', kind, `${dir}/${key}.src`, `${dir}/${key}.png`, color],
        { timeoutMs: 60_000 },
      )
      if (run.exitCode === 0) {
        const [w, h] = run.stdout.trim().split(/\s+/).map(Number)
        await $.fs.write(`${dir}/${key}.json`, JSON.stringify({ w, h }))
      } else {
        failed.set(key, run.stderr.trim() || `render failed (${run.exitCode})`)
      }
    } catch (error) {
      failed.set(key, String(error))
    } finally {
      pending.delete(key)
      await update($, renders, (n: Renders) => n + 1)
    }
  })
}

export const register: Register = (on, options) => {
  const cellW = Number(options.cellWidthPx) || 10
  const cellH = Number(options.cellHeightPx) || 21
  const mathColor = String(options.mathColor || '#e4e4e4')

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)
    if (!e.surfaces.includes('terminal')) return composed
    const text = [
      '# Readable output',
      'Your replies are rendered as styled markdown in a kitty terminal. Make them easy to scan:',
      '- Lead with the answer. Keep paragraphs short. Use headings only for multi-part answers, bullet lists for parallel items and tables for comparisons.',
      '- Display math goes on its own lines between $$ and $$ (LaTeX with amsmath; use aligned for multi-line). It is drawn as a centered image. Keep inline $...$ math short and simple.',
      '- When a flow, sequence, state machine, architecture or relationship is clearer as a picture, draw it as a ```mermaid or ```plantuml fenced block; it is drawn as an image.',
      '- A simple chart of discrete data is a ```mermaid block too: xychart-beta for bars and lines, pie for shares. An xychart has no legend, so name each series in the title or the text.',
    ].join('\n')
    return { sections: [...composed.sections, { id: 'readable:format', text, scope: 'session' as const }] }
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || e.props.isSummary) return next(e)
    const { Box, Text, Code, Markdown, Image } = $.ui.resolve(e)
    await read($, renders)
    const width = Math.max(20, (e.viewport?.columns ?? 80) - 4)

    const spans = (list: Span[], base: { bold?: boolean; color?: string } = {}) =>
      list.map(s => (
        <Text
          color={s.code ? C.code : s.math ? C.math : s.link ? C.link : s.url ? C.url : base.color}
          backgroundColor={s.code ? C.codeBg : undefined}
          bold={s.bold || base.bold}
          italic={s.italic || s.math}
          strikethrough={s.strike}
          underline={s.link}
        >
          {s.text}
        </Text>
      ))

    const codeBlock = (src: string, lang: string, room: number) => {
      const lines = (src || ' ').replace(/\t/g, '    ').split('\n').flatMap(line => {
        const chunks: string[] = []
        for (let k = 0; k < line.length; k += room) chunks.push(line.slice(k, k + room))
        return chunks.length ? chunks : ['']
      })
      const label = lang && lang.length + 6 <= room ? lang : ''
      return (
        <Box flexDirection="column" width={room}>
          <Text color={C.rule}>
            {label ? '─ ' : ''}
            {label ? <Text color={C.heading}>{label}</Text> : ''}
            {(label ? ' ' : '') + '─'.repeat(room - (label ? label.length + 3 : 0))}
          </Text>
          <Code source={lines.join('\n')} language={lang || undefined} wrap="truncate-end" />
          <Text color={C.rule}>{'─'.repeat(room)}</Text>
        </Box>
      )
    }

    const visual = async (b: Extract<Block, { type: 'visual' }>, room: number) => {
      const color = b.kind === 'math' ? mathColor : ''
      const src = b.kind === 'math' ? latexMath(b.src) : b.src
      const { dir, version } = await renderCache($)
      const key = hashKey(`${version}\0${b.kind}\0${color}\0${src}`)
      if (await $.fs.exists(`${dir}/${key}.json`)) {
        const { w, h: height } = JSON.parse(await $.fs.read(`${dir}/${key}.json`))
        const scale = b.kind === 'plantuml' ? 1 : 2
        let columns = (w / scale) / cellW
        let rows = (height / scale) / cellH
        const fit = Math.min(1, room / columns, 255 / columns, 255 / rows)
        columns = Math.max(1, Math.round(columns * fit))
        rows = Math.max(1, Math.round(rows * fit))
        return (
          <Box width={room} justifyContent="center">
            <Image source={{ file: `${dir}/${key}.png`, format: 'png' }} columns={columns} rows={rows} alt={b.src} />
          </Box>
        )
      }
      const error = failed.get(key)?.split('\n')[0]
      const note = error ? `⚠ ${error}` : 'rendering…'
      if (!error) schedule($, key, b.kind, src, color)
      return (
        <Box flexDirection="column" width={room}>
          {codeBlock(b.src, b.kind === 'math' ? 'latex' : b.kind, room)}
          <Text dimColor>{note}</Text>
        </Box>
      )
    }

    const table = (b: Extract<Block, { type: 'table' }>, room: number) => {
      const cells = [b.header, ...b.rows].map(r => b.header.map((_, k) => parseInline(r[k] ?? '')))
      const widths = b.header.map((_, k) => Math.max(3, ...cells.map(r => r[k].map(s => s.text).join('').length)))
      if (widths.reduce((sum, w) => sum + w + 3, 1) > room) return <Markdown text={b.raw} />
      const line = (l: string, m: string, r: string) => (
        <Text color={C.rule}>{l + widths.map(w => '─'.repeat(w + 2)).join(m) + r}</Text>
      )
      const row = (r: Span[][], isHeader: boolean) => (
        <Text wrap="truncate">
          {r.flatMap((c, k) => {
            const gap = widths[k] - c.map(s => s.text).join('').length
            const left = b.align[k] === 'right' ? gap : b.align[k] === 'center' ? Math.floor(gap / 2) : 0
            return [
              <Text color={C.rule}>{k === 0 ? '│ ' : ' │ '}</Text>,
              ' '.repeat(left),
              ...spans(c, { bold: isHeader }),
              ' '.repeat(gap - left),
            ]
          })}
          <Text color={C.rule}> │</Text>
        </Text>
      )
      return (
        <Box flexDirection="column">
          {line('┌', '┬', '┐')}
          {row(cells[0], true)}
          {line('├', '┼', '┤')}
          {cells.slice(1).map(r => row(r, false))}
          {line('└', '┴', '┘')}
        </Box>
      )
    }

    const blocks = async (list: Block[], room: number, gap = 1): Promise<any> => (
      <Box flexDirection="column" gap={gap} width={room}>
        {await Promise.all(list.map(b => block(b, room)))}
      </Box>
    )

    const block = async (b: Block, room: number): Promise<any> => {
      switch (b.type) {
        case 'heading':
          return b.level === 1
            ? <Text bold color={C.h1Fg} backgroundColor={C.h1Bg}> {plain(b.text)} </Text>
            : <Text bold color={C.heading}>{'#'.repeat(b.level)} {spans(parseInline(b.text), { bold: true, color: C.heading })}</Text>
        case 'para':
          return <Text>{spans(parseInline(b.text))}</Text>
        case 'code':
          return codeBlock(b.src, b.lang, room)
        case 'visual':
          return visual(b, room)
        case 'quote':
          return (
            <Box flexDirection="row" width={room}>
              <Box width={2} flexShrink={0}><Text color={C.quote}>│</Text></Box>
              <Box flexDirection="column">{await blocks(b.blocks, room - 2)}</Box>
            </Box>
          )
        case 'list': {
          const markerWidth = b.ordered ? String(b.start + b.items.length - 1).length + 2 : 2
          return (
            <Box flexDirection="column" width={room}>
              {await Promise.all(b.items.map(async (item, k) => (
                <Box flexDirection="row">
                  <Box width={markerWidth} flexShrink={0}>
                    <Text color={C.bullet}>{b.ordered ? `${b.start + k}.` : '•'}</Text>
                  </Box>
                  {await blocks(item, room - markerWidth, 0)}
                </Box>
              )))}
            </Box>
          )
        }
        case 'table':
          return table(b, room)
        case 'hr':
          return <Text color={C.rule}>{'─'.repeat(Math.min(room, 40))}</Text>
      }
    }

    const body = await blocks(parseBlocks(e.props.text.split('\n')), width)
    return (
      <Box flexDirection="row" marginTop={1}>
        <Box width={2} flexShrink={0}><Text>{e.props.isFirstOfReply ? '●' : ' '}</Text></Box>
        {body}
      </Box>
    )
  })
}
