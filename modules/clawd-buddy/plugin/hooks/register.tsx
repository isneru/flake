import type { EngineInterface, Register, TurnStepChunk } from 'claude-code'

import { COLUMNS, ROWS, drawMiniScene, drawScene, recolor, toCells, type Scene, type Tint } from './scene'

type Family = 'read' | 'edit' | 'bash' | 'web' | 'agent' | 'ask' | 'other'
type Kind =
  | 'idle'
  | 'waiting'
  | 'thinking'
  | 'writing'
  | 'drafting'
  | 'tool'
  | 'compacting'
  | 'done'
  | 'aborted'
  | 'error'
type Activity = { kind: Kind; title: string; detail?: string; family?: Family }
type Level = 'live' | 'quiet' | 'stalled'
type Pulse = { text: string; level: Level }
type Info = { title: string; time?: string; detail?: string; pulse?: Pulse; stats?: string }
type TurnTally = { ms: number; steps: number; tools: number; tokensOut: number }

const TICK_MS = 150
const SETTLE_MS = 4000
const SLEEP_AFTER_MS = 10 * 60_000
const HEARTBEAT_MS = 1000

const ORANGE = '#D97757'
const GREEN = '#6BBF59'
const YELLOW = '#E5C07B'
const RED = '#E06C75'
const LEVEL_COLORS: Record<Level, string> = { live: GREEN, quiet: YELLOW, stalled: RED }

const IDLE: Activity = { kind: 'idle', title: '' }
const WAITING: Activity = { kind: 'waiting', title: 'Waiting for the model' }
const THINKING: Activity = { kind: 'thinking', title: 'Thinking' }
const WRITING: Activity = { kind: 'writing', title: 'Writing the answer' }
const COMPACTING: Activity = { kind: 'compacting', title: 'Compacting the conversation' }

const QUIPS = [
  'Clawd is sipping tea',
  'Clawd is watching the cursor blink',
  'Clawd is humming a little tune',
  'Clawd is tidying up the desk',
  'Ready when you are',
]

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

const TITLES: Record<string, string> = {
  Read: 'Reading a file',
  Grep: 'Searching the code',
  Glob: 'Looking for files',
  Edit: 'Editing a file',
  MultiEdit: 'Editing a file',
  Write: 'Writing a file',
  NotebookEdit: 'Editing a notebook',
  Bash: 'Running a command',
  WebFetch: 'Reading a web page',
  WebSearch: 'Searching the web',
  Agent: 'Sending out a subagent',
  Task: 'Sending out a subagent',
  AskUserQuestion: 'Waiting for your answer',
  ExitPlanMode: 'Waiting for plan approval',
  Skill: 'Opening a skill',
  TodoWrite: 'Updating the to-do list',
}

const FAMILY_TITLES: Record<Family, string> = {
  read: 'Looking around',
  edit: 'Editing',
  bash: 'Running a command',
  web: 'Browsing the web',
  agent: 'Talking to a subagent',
  ask: 'Waiting for you',
  other: 'Using a tool',
}

let activity = IDLE
let activitySince = 0
let isActivityStamped = false
let lastSignalAt = 0
let isSignalPending = false
let frame = 0
let subagentDetail: string | undefined
let lastTurn: TurnTally | null = null
let callCount = 0

const turn = { startedAt: 0, steps: 0, tools: 0, tokensOut: 0, isActive: false }
const step = { thought: 0, text: 0, input: 0 }
const running = new Map<string, Activity>()
const band = { requestId: undefined as string | undefined, hasRaster: false, cells: '', info: '' }
const bar = { path: undefined as string | undefined, key: '', writtenAt: 0, id: '', tintsPath: '', tintReadAt: 0 }
let tint: Tint | undefined

const familyOf = (tool: string): Family =>
  FAMILIES[tool] ?? (/browser|chrome|fetch/i.test(tool) ? 'web' : 'other')

const toolName = (tool: string) => (tool.startsWith('mcp__') ? tool.split('__').slice(1).join(' › ') : tool)

function detailOf(args: Record<string, unknown>): string | undefined {
  const text = (key: string) => {
    const value = args[key]
    return typeof value === 'string' && value !== '' ? value.replace(/\s+/g, ' ') : undefined
  }
  const file = text('file_path') ?? text('notebook_path')
  if (file) return file.split('/').pop()
  const pattern = text('pattern')
  if (pattern) return `"${pattern}"`
  const command = text('command')
  return text('description') ?? (command && `$ ${command}`) ?? text('query') ?? text('url') ?? text('skill')
}

function describeTool(tool: string, args: Record<string, unknown>): Activity {
  const family = familyOf(tool)
  return {
    kind: 'tool',
    family,
    title: TITLES[tool] ?? (tool.startsWith('mcp__') ? `Using ${toolName(tool)}` : FAMILY_TITLES[family]),
    detail: detailOf(args),
  }
}

function become(next: Activity): void {
  if (next.kind !== activity.kind || next.title !== activity.title) isActivityStamped = false
  activity = next
}

function signal(): void {
  isSignalPending = true
}

function stamp(now: number): void {
  if (!isActivityStamped) {
    activitySince = now
    isActivityStamped = true
  }
  if (isSignalPending) {
    lastSignalAt = now
    isSignalPending = false
  }
  const isSettling = activity.kind === 'done' || activity.kind === 'aborted' || activity.kind === 'error'
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
    case 'aborted':
    case 'error':
      return 'sweat'
    default:
      return activity.kind
  }
}

const clock = (ms: number) => {
  const seconds = Math.max(0, Math.floor(ms / 1000))
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

const count = (n: number) => (n < 1000 ? String(n) : `${(n / 1000).toFixed(1)}k`)

const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`

const tally = (t: TurnTally) =>
  `${clock(t.ms)} · ${plural(t.steps, 'model call')} · ${plural(t.tools, 'tool')} · ${count(t.tokensOut)} tokens out`

function detailNow(): string | undefined {
  switch (activity.kind) {
    case 'waiting':
      return 'Request sent, no tokens back yet'
    case 'thinking':
      return step.thought > 0
        ? `${count(step.thought)} characters of thought so far`
        : 'Thinking quietly (no thinking summary is streamed)'
    case 'writing':
      return `${count(step.text)} characters written`
    case 'drafting':
      return `${count(step.input)} characters of arguments so far`
    case 'tool':
      return activity.family === 'agent' && subagentDetail
        ? `${activity.detail ?? 'subagent'} → ${subagentDetail}`
        : activity.detail
    default:
      return activity.detail ?? (lastTurn ? `Took ${tally(lastTurn)}` : undefined)
  }
}

function pulseAt(now: number): Pulse | undefined {
  const isStreaming = ['waiting', 'thinking', 'writing', 'drafting'].includes(activity.kind)
  const isSubagent = activity.kind === 'tool' && activity.family === 'agent'
  if (activity.kind === 'tool' && !isSubagent) {
    return { text: '● Tool running; no model tokens are spent while it waits', level: 'live' }
  }
  if (!isStreaming && !isSubagent) return undefined
  const quiet = now - lastSignalAt
  if (quiet < 3000 && activity.kind !== 'waiting') {
    return { text: isSubagent ? '● Live: the subagent is streaming' : '● Live: output is streaming', level: 'live' }
  }
  if (quiet < 30_000) return { text: `● Quiet for ${Math.floor(quiet / 1000)}s, which is normal`, level: 'quiet' }
  return { text: `● Quiet for ${clock(quiet)}: a long silent think or a slow API (Esc stops it)`, level: 'stalled' }
}

function infoAt(now: number): Info {
  if (activity.kind === 'idle') {
    const isAsleep = now - activitySince > SLEEP_AFTER_MS
    return {
      title: isAsleep ? 'Clawd dozed off… zzz' : QUIPS[Math.floor(now / 45_000) % QUIPS.length]!,
      detail: lastTurn ? `Last turn: ${tally(lastTurn)}` : undefined,
    }
  }
  return {
    title: activity.title,
    time: clock(now - activitySince),
    detail: detailNow(),
    pulse: pulseAt(now),
    stats: turn.isActive
      ? `This turn: ${tally({ ...turn, ms: now - turn.startedAt })}`
      : undefined,
  }
}

function watch(chunk: TurnStepChunk): void {
  switch (chunk.kind) {
    case 'engine':
      if (activity.kind === 'waiting') become(THINKING)
      break
    case 'thinking':
      step.thought += chunk.text.length
      become(THINKING)
      break
    case 'text':
      step.text += chunk.text.length
      become(WRITING)
      break
    case 'tool':
      step.input = 0
      become({ kind: 'drafting', title: `Drafting a ${toolName(chunk.name)} call`, family: familyOf(chunk.name) })
      break
    case 'input':
      step.input += chunk.json.length
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
  await $.fs.write(path, JSON.stringify({ updatedAt: now, ...fields }))
}

async function readTint($: EngineInterface): Promise<Tint | undefined> {
  try {
    const entry = JSON.parse(await $.fs.read(bar.tintsPath))[bar.id]
    return entry && { body: parseInt(entry.body.slice(1), 16), shade: parseInt(entry.shade.slice(1), 16) }
  } catch {
    return tint
  }
}

async function tick($: EngineInterface): Promise<void> {
  const now = await $.clock.now()
  stamp(now)
  frame += 1
  if (bar.tintsPath !== '' && now - bar.tintReadAt >= HEARTBEAT_MS) {
    bar.tintReadAt = now
    tint = await readTint($)
  }
  const scene = sceneAt(now)
  if (band.hasRaster && band.requestId !== undefined) {
    const cells = toCells(recolor(drawScene(scene, frame), tint))
    if (cells !== band.cells) {
      band.cells = cells
      await $.ui.blit({ requestId: band.requestId, key: 'clawd', cells })
    }
  }
  const info = JSON.stringify(infoAt(now))
  if (info !== band.info) {
    band.info = info
    $.ui.invalidate('ui.render')
  }
  if (bar.path !== undefined) await publish($, bar.path, now, scene)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const runtimeDir = await $.env.get('XDG_RUNTIME_DIR')
    if (runtimeDir) {
      bar.id = await $.session.id()
      bar.path = `${runtimeDir}/clawd-buddy/${bar.id}.json`
      bar.tintsPath = `${runtimeDir}/clawd-buddy/.tints`
    }
    let isTicking = false
    $.clock.every(TICK_MS, () => {
      if (isTicking) return
      isTicking = true
      void tick($).finally(() => {
        isTicking = false
      })
    })
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
    Object.assign(turn, { startedAt: await $.clock.now(), steps: 0, tools: 0, tokensOut: 0, isActive: true })
    running.clear()
    subagentDetail = undefined
    become(WAITING)
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    const isMain = e.agentId === undefined
    turn.steps += 1
    signal()
    if (isMain) {
      Object.assign(step, { thought: 0, text: 0, input: 0 })
      become(WAITING)
    }
    for await (const chunk of next(e)) {
      signal()
      if (chunk.kind === 'stop') turn.tokensOut += chunk.usage?.output_tokens ?? 0
      else if (isMain) watch(chunk)
      yield chunk
    }
  })

  on('tool.call', async ($, e, next) => {
    turn.tools += 1
    signal()
    const call = describeTool(e.tool, e as unknown as Record<string, unknown>)
    if (e.agentId !== undefined) {
      subagentDetail = call.detail ? `${call.title}: ${call.detail}` : call.title
      return next(e)
    }
    const id = e.tool_use_id ?? `call-${++callCount}`
    running.set(id, call)
    become(call)
    try {
      return await next(e)
    } finally {
      running.delete(id)
      signal()
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
      become(turn.isActive ? before : { kind: 'done', title: 'Compacted!', detail: 'Context freed up' })
    }
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      turn.isActive = false
      lastTurn = { ms: e.durationMs, steps: turn.steps, tools: turn.tools, tokensOut: turn.tokensOut }
      running.clear()
      if (e.reason === 'answer') become({ kind: 'done', title: 'Done!' })
      else if (e.reason === 'aborted') become({ kind: 'aborted', title: 'Interrupted', detail: 'Stopped where it was' })
      else become({ kind: 'error', title: 'The turn ended early', detail: `Reason: ${e.reason}` })
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || e.surface !== 'terminal') {
      band.hasRaster = false
      return next(e)
    }
    const now = await $.clock.now()
    stamp(now)
    const info = infoAt(now)
    band.requestId = e.requestId
    band.info = JSON.stringify(info)
    const { Box, Raster, Text } = $.ui.resolve(e)
    const isCompact = e.props.maxRows < ROWS || e.props.bodyColumns < COLUMNS + 30
    const title = (
      <Text wrap="truncate">
        <Text color={ORANGE} bold>
          {info.title}
        </Text>
        {info.time ? <Text dimColor>{`  ${info.time}`}</Text> : null}
        {info.pulse && isCompact ? <Text color={LEVEL_COLORS[info.pulse.level]}>{`  ${info.pulse.text}`}</Text> : null}
      </Text>
    )

    if (isCompact) {
      band.hasRaster = false
      return title
    }

    band.hasRaster = true
    band.cells = toCells(recolor(drawScene(sceneAt(now), frame), tint))
    return (
      <Box flexDirection="row">
        <Raster key="clawd" columns={COLUMNS} rows={ROWS} cells={band.cells} />
        <Box flexDirection="column" marginLeft={2} flexGrow={1} flexShrink={1}>
          {title}
          <Text wrap="truncate">{info.detail ?? ' '}</Text>
          <Text wrap="truncate" color={info.pulse && LEVEL_COLORS[info.pulse.level]}>
            {info.pulse?.text ?? ' '}
          </Text>
          <Text wrap="truncate" dimColor>
            {info.stats ?? ' '}
          </Text>
        </Box>
      </Box>
    )
  })
}
