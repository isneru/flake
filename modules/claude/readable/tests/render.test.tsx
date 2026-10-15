import { expect, test } from 'claude-code/testing'

const TEXT = [
  '# Title',
  'Some **bold**, *italic*, `code`, $x^2$ and a [link](https://example.com).',
  '## Steps',
  '1. first',
  '2. second',
  '   - nested',
  '> quoted',
  '| a | b |',
  '|---|--:|',
  '| 1 | 2 |',
  '```ts',
  'const x = 1',
  '```',
  '---',
].join('\n')

const draw = ($: any) =>
  $.ui.mount({
    plugin: 'readable',
    surface: 'terminal',
    component: 'AssistantMessage',
    viewport: { columns: 100, rows: 40 },
    props: { text: TEXT, isFirstOfReply: true },
  })

const texts = (node: any): string[] =>
  typeof node === 'string' ? [node]
    : !node || typeof node !== 'object' ? []
      : [
        ...(typeof node.props?.source === 'string' ? [node.props.source] : []),
        ...(Array.isArray(node.children) ? node.children : [node.children]).flatMap(texts),
      ]

test('draws a reply glow-style on the terminal', async $ => {
  const ui = await draw($)
  const tree = await ui.drawn()
  const all = texts(tree).join('')
  expect(tree).toMatchObject({ type: 'Box' })
  expect(all).toContain(' Title ')
  expect(all).toContain('## Steps')
  expect(all).toContain('•')
  expect(all).toContain('┌')
  expect(all).toContain('const x = 1')
  expect(all).toContain('─ ts ─')
  expect(all).toContain('const x = 1─')
  expect(all).not.toContain('│ const')
  expect(all).not.toContain('╭')
})
