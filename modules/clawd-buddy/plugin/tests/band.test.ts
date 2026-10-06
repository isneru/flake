import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

const band = (bodyColumns: number) =>
  ({
    plugin: 'clawd-buddy',
    surface: 'terminal',
    component: 'AbovePrompt',
    requestId: 'band',
    props: {
      hasSurvey: false,
      isWorking: true,
      maxRows: 12,
      bodyColumns,
      scroll: { offset: 0, bodyRows: 12 },
      view: {},
    },
  }) as const

const SESSION = { cwd: '/repo', surface: 'terminal', isInteractive: true } as const
const engine = (
  on: On,
  writes: { path: string; text: string }[] = [],
  files: Record<string, string> = {},
  blits: string[] = [],
) => {
  mock.env(on, { XDG_RUNTIME_DIR: '/run/user/1000' })
  on('fs.read', (_$, e) => {
    const text = files[e.path]
    if (text === undefined) throw new Error(`ENOENT ${e.path}`)
    return { value: text }
  })
  on('session.id', () => ({ value: 's1' }))
  on('fs.write', (_$, e) => {
    writes.push(e)
    return { value: undefined }
  })
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('turn.complete', (_$, e) => ({ text: e.answer }))
  on('session.end', (_$, e) => ({ sessionId: e.sessionId }))
  on('ui.blit', (_$, e) => {
    if ('cells' in e) blits.push(e.cells)
    return { value: {} }
  })
}

const foregrounds = (cells: string) => {
  const bytes = Uint8Array.from(atob(cells), c => c.charCodeAt(0))
  return Array.from(new Uint32Array(bytes.buffer).filter((_, i) => i % 3 === 1))
}

const USAGE = { input_tokens: 10, output_tokens: 1200, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }

describe('clawd-buddy band', () => {
  test('acts out the turn and keeps a liveness pulse', async ($, on) => {
    const writes: { path: string; text: string }[] = []
    engine(on, writes)
    const clock = mock.clock(on, { now: 1_000_000 })
    const published = () => {
      const last = writes.at(-1)
      expect(last?.path).toBe('/run/user/1000/clawd-buddy/s1.json')
      return JSON.parse(last?.text ?? '{}')
    }
    let finishRead = () => {}
    on('tool.call', () => new Promise(resolve => (finishRead = () => resolve({ result: 'ok', text: 'ok' } as never))))
    on('turn.step', async function* (_$, e) {
      yield { kind: 'thinking', index: 0, text: 'hmm, let me see' }
      yield { kind: 'stop', stopReason: 'end_turn', usage: { ...USAGE, model: 'claude' } }
      return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
    })

    await $.session.start(SESSION)
    const ui = await $.ui.mount(band(120))
    const shows = async (text: RegExp) => expect(await ui.find({ type: 'Text', text })).toBeDefined()

    expect(await ui.find({ type: 'Raster', key: 'clawd' })).toBeDefined()
    await shows(/tea|cursor|tune|desk|Ready/)

    await $.turn.start({ text: 'fix it', turnId: 't1' })
    const read = $.tool.call({ tool: 'Read', file_path: '/repo/src/app.ts' })
    await clock.advance(1000)
    await shows(/Reading a file/)
    await shows(/^app\.ts$/)
    await shows(/no model tokens are spent/)
    expect(published()).toMatchObject({ width: 20, height: 8 })
    expect(published().pixels).toHaveLength(20 * 8)
    finishRead()
    await read

    const stream = $.turn.step({ turnId: 't1', index: 1, model: 'claude', messageCount: 3 })
    await stream.next()
    await clock.advance(1000)
    await shows(/^Thinking$/)
    await shows(/15 characters of thought/)
    await shows(/Live: output is streaming/)

    await clock.advance(40_000)
    await shows(/Quiet for 0:4\d: a long silent think/)

    for await (const _ of stream) {
    }
    await $.turn.complete({ answer: 'done', durationMs: 65_000, isAborted: false, turnId: 't1', reason: 'answer' })
    await clock.advance(1000)
    await shows(/^Done!$/)

    await clock.advance(5000)
    await shows(/Last turn: 1:05 · 1 model call · 1 tool · 1\.2k tokens out/)
  })

  test('tells the bar the session ended, and only on a real exit', async ($, on) => {
    const writes: { path: string; text: string }[] = []
    engine(on, writes)
    const clock = mock.clock(on, { now: 1_000_000 })
    await $.session.start(SESSION)
    await clock.advance(300)

    await $.session.end({ reason: 'clear', sessionId: 's1', resume: { id: 's1' } })
    await clock.advance(1500)
    expect(JSON.parse(writes.at(-1)!.text).isEnded).toBeUndefined()

    await $.session.end({ reason: 'prompt_input_exit', sessionId: 's1', resume: { id: 's1' } })
    const count = writes.length
    expect(JSON.parse(writes.at(-1)!.text)).toMatchObject({ isEnded: true })
    await clock.advance(3000)
    expect(writes).toHaveLength(count)
  })

  test('wears the colour the bar gave its session, in the bar and in the band', async ($, on) => {
    const writes: { path: string; text: string }[] = []
    const blits: string[] = []
    const tints = JSON.stringify({ s1: { body: '#7fa8f5', shade: '#58749f' } })
    engine(on, writes, { '/run/user/1000/clawd-buddy/.tints': tints }, blits)
    const clock = mock.clock(on, { now: 1_000_000 })
    await $.session.start(SESSION)
    await $.ui.mount(band(120))
    await clock.advance(1200)

    const pixels: number[] = JSON.parse(writes.at(-1)!.text).pixels
    expect(pixels).toContain(0x7fa8f5)
    expect(pixels).not.toContain(0xd97757)
    const band_ = foregrounds(blits.at(-1)!)
    expect(band_).toContain(0x7fa8f5)
    expect(band_).not.toContain(0xd97757)
  })

  test('falls back to one line when the band is narrow', async ($, on) => {
    engine(on)
    mock.clock(on)
    await $.session.start(SESSION)
    const ui = await $.ui.mount(band(50))
    expect(await ui.find({ type: 'Raster' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /tea|cursor|tune|desk|Ready/ })).toBeDefined()
  })
})
