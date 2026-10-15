import type { EngineInterface, Register, TurnStepChunk } from 'claude-code'

import { drawMiniScene, recolor, type Scene, type Tint } from './scene'

type Family = 'read' | 'edit' | 'bash' | 'web' | 'agent' | 'ask' | 'other'
type Kind = 'idle' | 'waiting' | 'thinking' | 'writing' | 'drafting' | 'tool' | 'compacting' | 'done' | 'error'
type Activity = { kind: Kind; family?: Family }

const TICK_MS = 150
const SETTLE_MS = 4000
const SLEEP_AFTER_MS = 10 * 60_000
const HEARTBEAT_MS = 1000

const IDLE: Activity = { kind: 'idle' }
const WAITING: Activity = { kind: 'waiting' }
const THINKING: Activity = { kind: 'thinking' }
const WRITING: Activity = { kind: 'writing' }
const COMPACTING: Activity = { kind: 'compacting' }
const DONE: Activity = { kind: 'done' }

const FAMILIES: Record<string, Family> = {
  Read: 'read',
  Grep: 'read',
  Glob: 'read',
  LS: 'read',
  LSP: 'read',
  ToolSearch: 'read',
  Edit: 'edit',
  MultiEdit: 'edit',
  Write: 'edit',
  NotebookEdit: 'edit',
  Bash: 'bash',
  BashOutput: 'bash',
  KillShell: 'bash',
  PowerShell: 'bash',
  Monitor: 'bash',
  TaskStop: 'bash',
  WebFetch: 'web',
  WebSearch: 'web',
  Agent: 'agent',
  Task: 'agent',
  SendMessage: 'agent',
  AskUserQuestion: 'ask',
  ExitPlanMode: 'ask',
}

let activity = IDLE
let activitySince = 0
let isActivityStamped = false
let isTurnActive = false
let frame = 0
let callCount = 0

const running = new Map<string, Activity>()
const bar = { path: undefined as string | undefined, key: '', writtenAt: 0, id: '', tintsPath: '', tintReadAt: 0 }
let kitty: { pid: number; window: number } | undefined
let tint: Tint | undefined

const familyOf = (tool: string): Family =>
  FAMILIES[tool] ?? (/browser|chrome|fetch/i.test(tool) ? 'web' : 'other')

function become(next: Activity): void {
  if (next.kind !== activity.kind || next.family !== activity.family) isActivityStamped = false
  activity = next
}

function stamp(now: number): void {
  if (!isActivityStamped) {
    activitySince = now
    isActivityStamped = true
  }
  const isSettling = activity.kind === 'done' || activity.kind === 'error'
  if (isSettling && now - activitySince > SETTLE_MS) {
    activity = IDLE
    activitySince = now
  }
}

function sceneAt(now: number): Scene {
  switch (activity.kind) {
    case 'idle':
      return now - activitySince > SLEEP_AFTER_MS ? 'sleep' : 'idle'
    case 'drafting':
    case 'tool':
      return activity.family ?? 'other'
    case 'done':
      return 'hop'
    case 'error':
      return 'sweat'
    default:
      return activity.kind
  }
}

function watch(chunk: TurnStepChunk): void {
  switch (chunk.kind) {
    case 'engine':
      if (activity.kind === 'waiting') become(THINKING)
      break
    case 'thinking':
      become(THINKING)
      break
    case 'text':
      become(WRITING)
      break
    case 'tool':
      become({ kind: 'drafting', family: familyOf(chunk.name) })
      break
  }
}

async function publish($: EngineInterface, path: string, now: number, scene: Scene): Promise<void> {
  const { width, height, pixels } = recolor(drawMiniScene(scene, frame), tint)
  const fields = { width, height, pixels: Array.from(pixels) }
  const key = JSON.stringify(fields)
  if (key === bar.key && now - bar.writtenAt < HEARTBEAT_MS) return
  bar.key = key
  bar.writtenAt = now
  await $.fs.write(path, JSON.stringify({ updatedAt: now, kitty, ...fields }))
}

async function readTint($: EngineInterface): Promise<Tint | undefined> {
  try {
    const entry = JSON.parse(await $.fs.read(bar.tintsPath))[bar.id]
    return entry && { body: parseInt(entry.body.slice(1), 16), shade: parseInt(entry.shade.slice(1), 16) }
  } catch {
    return tint
  }
}

async function tick($: EngineInterface, path: string): Promise<void> {
  const now = await $.clock.now()
  stamp(now)
  frame += 1
  if (now - bar.tintReadAt >= HEARTBEAT_MS) {
    bar.tintReadAt = now
    tint = await readTint($)
  }
  await publish($, path, now, sceneAt(now))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const runtimeDir = await $.env.get('XDG_RUNTIME_DIR')
    if (runtimeDir) {
      bar.id = await $.session.id()
      bar.path = `${runtimeDir}/claude-mascot/${bar.id}.json`
      bar.tintsPath = `${runtimeDir}/claude-mascot/.tints`
      const [pid, window] = [await $.env.get('KITTY_PID'), await $.env.get('KITTY_WINDOW_ID')]
      kitty = pid && window ? { pid: Number(pid), window: Number(window) } : undefined
      let isTicking = false
      $.clock.every(TICK_MS, () => {
        if (isTicking || bar.path === undefined) return
        isTicking = true
        void tick($, bar.path).finally(() => {
          isTicking = false
        })
      })
    }
    return next(e)
  })

  on('session.end', async ($, e, next) => {
    if (bar.path !== undefined && e.reason !== 'clear' && e.reason !== 'resume') {
      const path = bar.path
      bar.path = undefined
      await $.fs.write(path, JSON.stringify({ updatedAt: await $.clock.now(), isEnded: true }))
    }
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    isTurnActive = true
    running.clear()
    become(WAITING)
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    const isMain = e.agentId === undefined
    if (isMain) become(WAITING)
    for await (const chunk of next(e)) {
      if (isMain) watch(chunk)
      yield chunk
    }
  })

  on('tool.call', async ($, e, next) => {
    if (e.agentId !== undefined) return next(e)
    const call: Activity = { kind: 'tool', family: familyOf(e.tool) }
    const id = e.tool_use_id ?? `call-${++callCount}`
    running.set(id, call)
    become(call)
    try {
      return await next(e)
    } finally {
      running.delete(id)
      become([...running.values()].at(-1) ?? WAITING)
    }
  })

  on('session.compact', async ($, e, next) => {
    if (e.agentId !== undefined) return next(e)
    const before = activity
    become(COMPACTING)
    try {
      return await next(e)
    } finally {
      become(isTurnActive ? before : DONE)
    }
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      isTurnActive = false
      running.clear()
      become(e.reason === 'answer' ? DONE : { kind: 'error' })
    }
    return next(e)
  })
}
