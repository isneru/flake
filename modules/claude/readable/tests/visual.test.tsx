import { expect, test } from 'claude-code/testing'

const TEXT = [
  '# Title',
  '',
  '$$',
  'x = 1',
  '$$',
  '',
  '```plantuml',
  '@startuml',
  'A -> B',
  '@enduml',
  '```',
].join('\n')

test('draws math and diagrams as images', async ($: any, on: any) => {
  on('env.get', () => ({ value: '/home/test' }))
  on('fs.exists', () => ({ value: true }))
  on('fs.read', () => ({ value: JSON.stringify({ w: 200, h: 60 }) }))
  const ui = await $.ui.mount({
    plugin: 'readable',
    surface: 'terminal',
    component: 'AssistantMessage',
    viewport: { columns: 100, rows: 40 },
    props: { text: TEXT, isFirstOfReply: true },
  })
  const tree = await ui.drawn()
  expect(JSON.stringify(tree)).toContain('"Image"')
})
