import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

const SESSION = { cwd: '/repo', surface: 'terminal', isInteractive: true } as const
const KITTY = { XDG_RUNTIME_DIR: '/run/user/1000', KITTY_PID: '4242', KITTY_WINDOW_ID: '7' }
const engine = (
  on: On,
  writes: { path: string; text: string }[] = [],
  files: Record<string, string> = {},
  env: Record<string, string> = KITTY,
) => {
  mock.env(on, env)
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
}

const USAGE = { input_tokens: 10, output_tokens: 1200, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }
const MUG = 0xe9e1d3
const GLASS = 0xcfe8f7
const PAPER = 0xede8dc
const SPARKLE = 0xffd24a

describe('claude-mascot bar', () => {
  test('acts out the turn in the bar file', async ($, on) => {
    const writes: { path: string; text: string }[] = []
    engine(on, writes)
    const clock = mock.clock(on, { now: 1_000_000 })
    const published = () => {
      const last = writes.at(-1)
      expect(last?.path).toBe('/run/user/1000/claude-mascot/s1.json')
      return JSON.parse(last?.text ?? '{}')
    }
    let finishRead = () => {}
    on('tool.call', () => new Promise(resolve => (finishRead = () => resolve({ result: 'ok', text: 'ok' } as never))))
    on('turn.step', async function* (_$, e) {
      yield { kind: 'text', index: 0, text: 'All fixed.' }
      yield { kind: 'stop', stopReason: 'end_turn', usage: { ...USAGE, model: 'claude' } }
      return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
    })

    await $.session.start(SESSION)
    await clock.advance(300)
    expect(published()).toMatchObject({ width: 20, height: 8, kitty: { pid: 4242, window: 7 } })
    expect(published().pixels).toHaveLength(20 * 8)
    expect(published().pixels).toContain(MUG)

    await $.turn.start({ text: 'fix it', turnId: 't1' })
    const read = $.tool.call({ tool: 'Read', file_path: '/repo/src/app.ts' })
    await clock.advance(300)
    expect(published().pixels).toContain(GLASS)
    finishRead()
    await read
    await clock.advance(300)
    expect(published().pixels).not.toContain(PAPER)

    const stream = $.turn.step({ turnId: 't1', index: 1, model: 'claude', messageCount: 3 })
    await stream.next()
    await clock.advance(300)
    expect(published().pixels).toContain(PAPER)
    for await (const _ of stream) {
    }

    await $.turn.complete({ answer: 'done', durationMs: 65_000, isAborted: false, turnId: 't1', reason: 'answer' })
    await clock.advance(300)
    expect(published().pixels).toContain(SPARKLE)

    await clock.advance(5000)
    expect(published().pixels).toContain(MUG)
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

  test('wears the colour the bar gave its session', async ($, on) => {
    const writes: { path: string; text: string }[] = []
    const tints = JSON.stringify({ s1: { body: '#7fa8f5', shade: '#58749f' } })
    engine(on, writes, { '/run/user/1000/claude-mascot/.tints': tints })
    const clock = mock.clock(on, { now: 1_000_000 })
    await $.session.start(SESSION)
    await clock.advance(1200)

    const pixels: number[] = JSON.parse(writes.at(-1)!.text).pixels
    expect(pixels).toContain(0x7fa8f5)
    expect(pixels).not.toContain(0xd97757)
  })

  test('names no kitty window outside kitty', async ($, on) => {
    const writes: { path: string; text: string }[] = []
    engine(on, writes, {}, { XDG_RUNTIME_DIR: '/run/user/1000' })
    const clock = mock.clock(on, { now: 1_000_000 })
    await $.session.start(SESSION)
    await clock.advance(300)

    expect(JSON.parse(writes.at(-1)!.text).kitty).toBeUndefined()
  })
})
