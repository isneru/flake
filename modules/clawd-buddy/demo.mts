import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { drawMiniScene, recolor, type Scene, type Tint } from './plugin/hooks/scene.ts'

const ALL = 'idle,sleep,waiting,thinking,writing,read,edit,bash,web,agent,ask,other,compacting,hop,sweat'
const scenes = (process.argv[2] ?? ALL).split(',') as Scene[]
const perScene = Number(process.argv[3] ?? 4000)
const loops = Number(process.argv[4] ?? 1)
const dir = `${process.env.XDG_RUNTIME_DIR}/clawd-buddy`
const path = `${dir}/demo.json`

const tintOf = (): Tint | undefined => {
  try {
    const entry = JSON.parse(readFileSync(`${dir}/.tints`, 'utf8')).demo
    return entry && { body: parseInt(entry.body.slice(1), 16), shade: parseInt(entry.shade.slice(1), 16) }
  } catch {
    return undefined
  }
}

mkdirSync(dir, { recursive: true })
let frame = 0
const start = Date.now()
const timer = setInterval(() => {
  const step = Math.floor((Date.now() - start) / perScene)
  if (step >= scenes.length * loops) {
    clearInterval(timer)
    writeFileSync(path, JSON.stringify({ updatedAt: Date.now(), isEnded: true }))
    return
  }
  frame += 1
  const { width, height, pixels } = recolor(drawMiniScene(scenes[step % scenes.length]!, frame), tintOf())
  writeFileSync(path, JSON.stringify({ updatedAt: Date.now(), width, height, pixels: Array.from(pixels) }))
}, 150)
