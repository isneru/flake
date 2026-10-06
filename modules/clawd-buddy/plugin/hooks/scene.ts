export const COLUMNS = 34
export const ROWS = 4

export type Scene =
  | 'idle'
  | 'sleep'
  | 'waiting'
  | 'thinking'
  | 'writing'
  | 'read'
  | 'edit'
  | 'bash'
  | 'web'
  | 'agent'
  | 'ask'
  | 'other'
  | 'compacting'
  | 'hop'
  | 'sweat'

type Canvas = { width: number; height: number; pixels: Int32Array }
type Palette = Record<string, number>

const MINI_WIDTH = 20
const MINI_HEIGHT = 8
const CLEAR = -1
const TERMINAL_DEFAULT = 0x01000000
const SPACE = 0x20
const UPPER_HALF = 0x2580
const LOWER_HALF = 0x2584

const ORANGE = 0xd97757
const ORANGE_DARK = 0x9e4a33

export type Tint = { body: number; shade: number }
const EYE = 0x1a1a1a
const PAPER = 0xede8dc
const INK = 0x8a8378
const BULB_ON = 0xffd24a
const BULB_OFF = 0x8a7f5a
const METAL = 0x9a9a9a
const METAL_DARK = 0x4a4a4a
const SCREEN = 0x111418
const CODE = 0x4ee07a
const CODE_DIM = 0x1f7a3c
const OCEAN = 0x3b82c4
const LAND_GREEN = 0x6bbf59
const WOOD = 0x8b5e3c
const GLASS = 0xcfe8f7
const ERASER = 0xf28ca6
const PENCIL_BODY = 0xf2c14e
const LEAD = 0x3a2e2a
const MUG = 0xe9e1d3
const TEA = 0x8b5a2b
const STEAM = 0xbfc5cc
const SNOOZE = 0x9cc9f5
const DROP = 0x7cc4f5
const DOT_ON = 0xe6e6e6
const DOT_OFF = 0x5a5a5a
const DUST = 0xa89f91

const BODY = [
  '...OOOOOOOOOOOO...',
  '...OOOOOOOOOOOO...',
  '.OOOOOOOOOOOOOOOO.',
  '...OOOOOOOOOOOO...',
  '....O.O....O.O....',
]
const CLAWD_X = 1

const MINI_BODY = ['.OOOOOO.', '.OOOOOO.', 'OOOOOOOO', '..O..O..']
const CROWN = ['Y.YY.Y', 'YYYYYY']
const MINI_Z = ['ZZZ', '..Z', '.Z.', 'ZZZ']
const CUP = ['MTTM..', 'MMMMMM', 'MMMM.M', 'MMMMMM']
const Z = ['ZZZ', '.Z.', 'ZZZ']
const BULB = ['.YYY.', 'YYYYY', 'YYYYY', '.YYY.', '.GGG.', '..G..']
const LENS = ['.GGG.', 'GlllG', 'GlllG', '.GGG.', '....H']
const PENCIL = ['...P', '..U.', '.U..', 'k...']
const QUESTION = ['.YY.', 'Y..Y', '...Y', '..Y.', '....', '..Y.']
const SPARKLE = ['.Y.', 'YYY', '.Y.']
const MONITOR = [
  'FFFFFFFFFFF',
  'FSSSSSSSSSF',
  'FSSSSSSSSSF',
  'FSSSSSSSSSF',
  'FSSSSSSSSSF',
  'FFFFFFFFFFF',
  '....FFF....',
  '..FFFFFFF..',
]
const GLOBE = ['..XXX..', '.XXXXX.', 'XXXXXXX', 'XXXXXXX', 'XXXXXXX', '.XXXXX.', '..XXX..']
const MINI_CUP = ['MTM.', 'MMMM', 'MMM.']
const MINI_BULB = ['YYY', 'YYY', '.G.']
const MINI_LENS = ['GGG.', 'GlG.', 'GGG.', '...H']
const MINI_PENCIL = ['..P', '.U.', 'k..']
const MINI_QUESTION = ['YY.', '..Y', '.Y.', '...', '.Y.']
const MINI_MONITOR = ['FFFFFFF', 'FSSSSSF', 'FSSSSSF', 'FSSSSSF', 'FFFFFFF', '..FFF..']
const MINI_GLOBE = ['.XXX.', 'XXXXX', 'XXXXX', 'XXXXX', '.XXX.']
const LAND = [
  '..NN......N...',
  '.NNNN....NNN..',
  'NNNNN...NNNNN.',
  '.NNN.....NNNN.',
  '..NN......NN..',
  '...N.......N..',
  '..............',
]

function put(c: Canvas, x: number, y: number, color: number): void {
  if (x >= 0 && x < c.width && y >= 0 && y < c.height) c.pixels[y * c.width + x] = color
}

function block(c: Canvas, x: number, y: number, w: number, h: number, color: number): void {
  for (let dy = 0; dy < h; dy++) for (let dx = 0; dx < w; dx++) put(c, x + dx, y + dy, color)
}

function sprite(c: Canvas, rows: readonly string[], x: number, y: number, palette: Palette): void {
  rows.forEach((row, dy) => {
    for (let dx = 0; dx < row.length; dx++) {
      const color = palette[row[dx]!]
      if (color !== undefined) put(c, x + dx, y + dy, color)
    }
  })
}

type Pose = {
  y?: number
  eyes?: 'open' | 'closed' | 'left' | 'right'
  wave?: 'left' | 'right' | 'both'
  step?: boolean
  isCrowned?: boolean
}

function clawd(c: Canvas, pose: Pose = {}): void {
  const x = CLAWD_X
  const y = pose.y ?? 3
  sprite(c, BODY, x, y, { O: ORANGE })
  const shift = pose.eyes === 'left' ? -1 : pose.eyes === 'right' ? 1 : 0
  const eye = pose.eyes === 'closed' ? ORANGE_DARK : EYE
  put(c, x + 5 + shift, y + 1, eye)
  put(c, x + 12 + shift, y + 1, eye)
  if (pose.wave === 'left' || pose.wave === 'both') {
    put(c, x + 1, y + 2, CLEAR)
    put(c, x + 1, y + 1, ORANGE)
  }
  if (pose.wave === 'right' || pose.wave === 'both') {
    put(c, x + 16, y + 2, CLEAR)
    put(c, x + 16, y + 1, ORANGE)
  }
  if (pose.step) {
    put(c, x + 4, y + 4, CLEAR)
    put(c, x + 11, y + 4, CLEAR)
  }
}

function miniClawd(c: Canvas, pose: Pose = {}, x = 0): void {
  const y = pose.y ?? 4
  sprite(c, MINI_BODY, x, y, { O: ORANGE })
  const shift = pose.eyes === 'left' ? -1 : pose.eyes === 'right' ? 1 : 0
  const eye = pose.eyes === 'closed' ? ORANGE_DARK : EYE
  put(c, x + 2 + shift, y + 1, eye)
  put(c, x + 5 + shift, y + 1, eye)
  if (pose.wave === 'left' || pose.wave === 'both') {
    put(c, x, y + 2, CLEAR)
    put(c, x, y + 1, ORANGE)
  }
  if (pose.wave === 'right' || pose.wave === 'both') {
    put(c, x + 7, y + 2, CLEAR)
    put(c, x + 7, y + 1, ORANGE)
  }
  if (pose.step) {
    put(c, x + 2, y + 3, CLEAR)
    put(c, x + 5, y + 3, CLEAR)
    put(c, x + 1, y + 3, ORANGE)
    put(c, x + 6, y + 3, ORANGE)
  }
  if (pose.isCrowned) sprite(c, CROWN, x + 1, y - 2, { Y: BULB_ON })
}

function paper(c: Canvas, lineLengths: readonly number[]): void {
  block(c, 22, 1, 10, 7, PAPER)
  lineLengths.forEach((length, i) => block(c, 23, 2 + i * 2, length, 1, INK))
}

function miniPaper(c: Canvas, lineLengths: readonly number[]): void {
  block(c, 10, 2, 5, 6, PAPER)
  lineLengths.forEach((length, i) => block(c, 11, 3 + i * 2, length, 1, INK))
}

const clamp = (n: number, low: number, high: number) => Math.min(high, Math.max(low, n))
const every = (f: number, ticks: number) => Math.floor(f / ticks)

const SCENES: Record<Scene, (c: Canvas, f: number) => void> = {
  idle(c, f) {
    const look = (['open', 'open', 'left', 'open', 'right', 'open'] as const)[every(f, 30) % 6]
    clawd(c, { eyes: f % 40 === 0 ? 'closed' : look })
    sprite(c, CUP, 24, 4, { M: MUG, T: TEA })
    for (let i = 0; i < 2; i++) {
      const rise = (every(f, 3) + i * 2) % 4
      put(c, 25 + i + (rise % 2), 3 - rise, STEAM)
    }
  },
  sleep(c, f) {
    clawd(c, { eyes: 'closed' })
    for (let i = 0; i < 2; i++) {
      const drift = (every(f, 3) + i * 5) % 10
      sprite(c, Z, 19 + drift, 4 - Math.floor(drift / 2), { Z: SNOOZE })
    }
  },
  waiting(c, f) {
    clawd(c, { eyes: 'right', step: every(f, 2) % 2 === 1 })
    const lit = every(f, 3) % 4
    for (let i = 0; i < 3; i++) block(c, 22 + i * 4, 4, 2, 2, i < lit ? DOT_ON : DOT_OFF)
  },
  thinking(c, f) {
    const beat = every(f, 2) % 12
    clawd(c, { eyes: beat < 6 ? 'right' : 'open' })
    if (beat >= 1) put(c, 20, 3, DOT_ON)
    if (beat >= 2) block(c, 22, 1, 2, 2, DOT_ON)
    if (beat >= 3) {
      const isLit = beat >= 5 && beat <= 9
      sprite(c, BULB, 26, 0, { Y: isLit ? BULB_ON : BULB_OFF, G: METAL })
      if (isLit && f % 2 === 0) {
        for (const [x, y] of [[24, 0], [32, 0], [24, 3], [32, 3]] as const) put(c, x, y, BULB_ON)
      }
    }
  },
  writing(c, f) {
    const progress = f % 30
    clawd(c, { eyes: 'right', wave: f % 2 === 0 ? 'right' : undefined })
    paper(c, [0, 1, 2].map(i => clamp(progress - i * 9, 0, 8)))
  },
  read(c, f) {
    clawd(c, { eyes: 'right' })
    paper(c, [8, 6, 8])
    const sweep = every(f, 2) % 8
    sprite(c, LENS, 21 + (sweep < 4 ? sweep : 7 - sweep) * 2, every(f, 16) % 2 === 0 ? 0 : 2, {
      G: METAL_DARK,
      l: GLASS,
      H: WOOD,
    })
  },
  edit(c, f) {
    const progress = f % 27
    const line = Math.floor(progress / 9)
    const length = progress % 9
    clawd(c, { eyes: 'right' })
    paper(c, [0, 1, 2].map(i => (i < line ? 8 : i === line ? length : 0)))
    sprite(c, PENCIL, 23 + length, line * 2 - 1, { P: ERASER, U: PENCIL_BODY, k: LEAD })
  },
  bash(c, f) {
    clawd(c, { eyes: 'right', wave: f % 2 === 0 ? 'right' : 'left' })
    sprite(c, MONITOR, 22, 0, { F: METAL_DARK, S: SCREEN })
    for (let i = 0; i < 9; i += 2) {
      const head = (f + i * 3) % 7
      if (head < 4) put(c, 23 + i, 1 + head, CODE)
      if (head >= 1 && head <= 4) put(c, 23 + i, head, CODE_DIM)
    }
  },
  web(c, f) {
    clawd(c, { eyes: 'right' })
    const spin = every(f, 2)
    GLOBE.forEach((row, y) => {
      for (let x = 0; x < row.length; x++) {
        if (row[x] === 'X') put(c, 24 + x, y, LAND[y]![(x + spin) % 14] === 'N' ? LAND_GREEN : OCEAN)
      }
    })
    block(c, 26, 7, 3, 1, WOOD)
  },
  agent(c, f) {
    clawd(c, { eyes: 'right', wave: every(f, 2) % 2 === 0 ? 'right' : undefined })
    const x = 19 + (f % 16)
    miniClawd(c, { step: f % 2 === 1 }, x)
    if (f % 2 === 1) put(c, x - 1, 7, DUST)
  },
  ask(c, f) {
    clawd(c, { eyes: 'right', wave: every(f, 3) % 2 === 0 ? 'right' : undefined })
    if (every(f, 4) % 4 !== 3) sprite(c, QUESTION, 24, 0, { Y: BULB_ON })
  },
  other(c, f) {
    const isDown = every(f, 2) % 2 === 1
    clawd(c, { eyes: 'right', wave: isDown ? undefined : 'right' })
    block(c, 26, 6, 6, 2, METAL_DARK)
    put(c, 28, 5, WOOD)
    if (isDown) {
      block(c, 27, 3, 3, 2, METAL)
      block(c, 28, 0, 1, 3, WOOD)
      for (const [x, y] of [[25, 4], [31, 4], [26, 2], [30, 2]] as const) put(c, x, y, BULB_ON)
    } else {
      block(c, 27, 0, 3, 2, METAL)
      block(c, 28, 2, 1, 2, WOOD)
    }
  },
  compacting(c, f) {
    const height = 6 - (every(f, 2) % 6)
    clawd(c, { eyes: 'right', wave: 'both' })
    for (let i = 0; i < height; i++) block(c, 23, 7 - i, 8, 1, i % 2 === 0 ? PAPER : INK)
    block(c, 22, 7 - height, 10, 1, METAL_DARK)
    block(c, 26, 0, 2, 7 - height, METAL)
  },
  hop(c, f) {
    const y = [3, 2, 1, 1, 2, 3][f % 6]!
    clawd(c, { y, wave: y < 3 ? 'both' : undefined })
    if (f % 2 === 0) {
      sprite(c, SPARKLE, 23, 1, { Y: BULB_ON })
      sprite(c, SPARKLE, 29, 4, { Y: BULB_ON })
    } else {
      sprite(c, SPARKLE, 26, 2, { Y: BULB_ON })
    }
  },
  sweat(c, f) {
    clawd(c, { eyes: f % 20 === 0 ? 'closed' : 'open' })
    const y = 1 + (every(f, 3) % 3)
    block(c, 16, y, 1, 2, DROP)
  },
}

const MINI_SCENES: Record<Scene, (c: Canvas, f: number) => void> = {
  idle(c, f) {
    const look = (['open', 'open', 'left', 'open', 'right', 'open'] as const)[every(f, 30) % 6]
    miniClawd(c, { eyes: f % 40 === 0 ? 'closed' : look })
    sprite(c, MINI_CUP, 11, 5, { M: MUG, T: TEA })
    const rise = every(f, 3) % 3
    put(c, 12 + (rise % 2), 4 - rise, STEAM)
  },
  sleep(c, f) {
    miniClawd(c, { eyes: 'closed' })
    const rise = every(f, 3) % 8
    if (rise < 6) {
      sprite(c, MINI_Z, 8 + Math.floor(rise / 2), 3 - Math.floor((rise + 1) / 2), { Z: SNOOZE })
    }
  },
  waiting(c, f) {
    miniClawd(c, { eyes: 'right', step: every(f, 2) % 2 === 1 })
    const lit = every(f, 3) % 4
    for (let i = 0; i < 3; i++) put(c, 10 + i * 2, 6, i < lit ? DOT_ON : DOT_OFF)
  },
  thinking(c, f) {
    const beat = every(f, 2) % 12
    miniClawd(c, { eyes: beat < 6 ? 'right' : 'open' })
    if (beat >= 1) put(c, 8, 3, DOT_ON)
    if (beat >= 2) put(c, 10, 1, DOT_ON)
    if (beat >= 3) {
      const isLit = beat >= 5 && beat <= 9
      sprite(c, MINI_BULB, 12, 0, { Y: isLit ? BULB_ON : BULB_OFF, G: METAL })
      if (isLit && f % 2 === 0) {
        for (const [x, y] of [[16, 0], [16, 2]] as const) put(c, x, y, BULB_ON)
      }
    }
  },
  writing(c, f) {
    const progress = f % 8
    miniClawd(c, { eyes: 'right', wave: f % 2 === 0 ? 'right' : undefined })
    miniPaper(c, [0, 1].map(i => clamp(progress - i * 4, 0, 3)))
  },
  read(c, f) {
    miniClawd(c, { eyes: 'right' })
    miniPaper(c, [3, 2])
    const sweep = every(f, 2) % 4
    sprite(c, MINI_LENS, 9 + (sweep < 2 ? sweep : 3 - sweep) * 2, every(f, 8) % 2 === 0 ? 2 : 4, {
      G: METAL_DARK,
      l: GLASS,
      H: WOOD,
    })
  },
  edit(c, f) {
    const progress = f % 8
    const line = Math.floor(progress / 4)
    const length = progress % 4
    miniClawd(c, { eyes: 'right' })
    miniPaper(c, [0, 1].map(i => (i < line ? 3 : i === line ? length : 0)))
    sprite(c, MINI_PENCIL, 11 + length, 1 + line * 2, { P: ERASER, U: PENCIL_BODY, k: LEAD })
  },
  bash(c, f) {
    miniClawd(c, { eyes: 'right', wave: f % 2 === 0 ? 'right' : 'left' })
    sprite(c, MINI_MONITOR, 10, 2, { F: METAL_DARK, S: SCREEN })
    for (let i = 0; i < 5; i += 2) {
      const head = (f + i * 2) % 5
      if (head < 3) put(c, 11 + i, 3 + head, CODE)
      if (head >= 1 && head <= 3) put(c, 11 + i, 2 + head, CODE_DIM)
    }
  },
  web(c, f) {
    miniClawd(c, { eyes: 'right' })
    const spin = every(f, 2)
    MINI_GLOBE.forEach((row, y) => {
      for (let x = 0; x < row.length; x++) {
        if (row[x] === 'X') put(c, 11 + x, 2 + y, LAND[y + 1]![(x + spin) % 14] === 'N' ? LAND_GREEN : OCEAN)
      }
    })
    block(c, 12, 7, 3, 1, WOOD)
  },
  agent(c, f) {
    miniClawd(c, { eyes: 'right', wave: every(f, 2) % 2 === 0 ? 'right' : undefined, isCrowned: true })
    const x = 9 + (f % 14)
    miniClawd(c, { step: f % 2 === 1 }, x)
    if (f % 2 === 1) put(c, x - 1, 7, DUST)
  },
  ask(c, f) {
    miniClawd(c, { eyes: 'right', wave: every(f, 3) % 2 === 0 ? 'right' : undefined })
    if (every(f, 4) % 4 !== 3) sprite(c, MINI_QUESTION, 11, 1, { Y: BULB_ON })
  },
  other(c, f) {
    const phase = (['up', 'up', 'mid', 'down', 'down', 'mid'] as const)[f % 6]
    miniClawd(c, { eyes: 'right', wave: phase === 'down' ? 'right' : undefined })
    block(c, 9, 7, 6, 1, WOOD)
    put(c, 11, 6, METAL)
    if (phase === 'up') {
      block(c, 15, 0, 3, 2, METAL_DARK)
      block(c, 16, 2, 1, 3, WOOD)
    } else if (phase === 'mid') {
      block(c, 12, 0, 2, 2, METAL_DARK)
      for (const [x, y] of [[14, 2], [15, 3], [16, 4]] as const) put(c, x, y, WOOD)
    } else {
      block(c, 11, 3, 2, 3, METAL_DARK)
      block(c, 13, 4, 4, 1, WOOD)
      if (f % 6 === 3) for (const [x, y] of [[10, 5], [13, 6]] as const) put(c, x, y, BULB_ON)
    }
  },
  compacting(c, f) {
    const height = 3 - (every(f, 2) % 3)
    miniClawd(c, { eyes: 'right', wave: 'both' })
    block(c, 10, 2, 6, 1, METAL_DARK)
    block(c, 10, 3, 1, 5, METAL_DARK)
    block(c, 15, 3, 1, 5, METAL_DARK)
    for (let i = 0; i < height; i++) block(c, 11, 7 - i, 4, 1, i % 2 === 0 ? PAPER : INK)
    block(c, 11, 7 - height, 4, 1, METAL)
    block(c, 12, 3, 2, 4 - height, METAL)
  },
  hop(c, f) {
    const y = [4, 3, 2, 2, 3, 4][f % 6]!
    miniClawd(c, { y, wave: y < 4 ? 'both' : undefined })
    if (f % 2 === 0) {
      sprite(c, SPARKLE, 10, 1, { Y: BULB_ON })
      sprite(c, SPARKLE, 15, 3, { Y: BULB_ON })
    } else {
      sprite(c, SPARKLE, 12, 2, { Y: BULB_ON })
    }
  },
  sweat(c, f) {
    miniClawd(c, { eyes: f % 20 === 0 ? 'closed' : 'open' })
    block(c, 8, 2 + (every(f, 3) % 3), 1, 2, DROP)
  },
}

const BASE64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function base64(bytes: Uint8Array): string {
  let out = ''
  for (let i = 0; i < bytes.length; i += 3) {
    const n = (bytes[i]! << 16) | (bytes[i + 1]! << 8) | bytes[i + 2]!
    out += BASE64[(n >> 18) & 63]! + BASE64[(n >> 12) & 63]! + BASE64[(n >> 6) & 63]! + BASE64[n & 63]!
  }
  return out
}

export function toCells(c: Canvas): string {
  const rows = c.height / 2
  const words = new Uint32Array(c.width * rows * 3)
  for (let row = 0; row < rows; row++) {
    for (let x = 0; x < c.width; x++) {
      const top = c.pixels[2 * row * c.width + x]!
      const bottom = c.pixels[(2 * row + 1) * c.width + x]!
      const i = (row * c.width + x) * 3
      if (top !== CLEAR) {
        words[i] = UPPER_HALF
        words[i + 1] = top
        words[i + 2] = bottom === CLEAR ? TERMINAL_DEFAULT : bottom
      } else if (bottom !== CLEAR) {
        words[i] = LOWER_HALF
        words[i + 1] = bottom
        words[i + 2] = TERMINAL_DEFAULT
      } else {
        words[i] = SPACE
        words[i + 1] = TERMINAL_DEFAULT
        words[i + 2] = TERMINAL_DEFAULT
      }
    }
  }
  return base64(new Uint8Array(words.buffer))
}

export function recolor(c: Canvas, tint: Tint | undefined): Canvas {
  if (tint !== undefined) {
    c.pixels.forEach((color, i) => {
      if (color === ORANGE) c.pixels[i] = tint.body
      else if (color === ORANGE_DARK) c.pixels[i] = tint.shade
    })
  }
  return c
}

function draw(scenes: typeof SCENES, width: number, height: number, scene: Scene, frame: number): Canvas {
  const canvas = { width, height, pixels: new Int32Array(width * height).fill(CLEAR) }
  scenes[scene](canvas, frame)
  return canvas
}

export const drawScene = (scene: Scene, frame: number) => draw(SCENES, COLUMNS, ROWS * 2, scene, frame)

export const drawMiniScene = (scene: Scene, frame: number) => draw(MINI_SCENES, MINI_WIDTH, MINI_HEIGHT, scene, frame)
