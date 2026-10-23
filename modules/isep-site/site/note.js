import { md } from "/.site/md.js"
const src = document.getElementById("src")
src.parentElement.innerHTML = md.render(src.textContent)
const toc = document.getElementById("toc")
const headings = [...document.querySelectorAll("article :is(h1, h2, h3, h4)")]
if (headings.length > 1) {
  const top = Math.min(...headings.map((h) => Number(h.tagName[1])))
  const links = headings.map((h) => {
    const base =
      h.textContent
        .trim()
        .toLowerCase()
        .replace(/[^\p{L}\p{N}]+/gu, "-")
        .replace(/^-|-$/g, "") || "section"
    let id = base
    for (let n = 2; document.getElementById(id); n++) id = `${base}-${n}`
    h.id = id
    const a = document.createElement("a")
    a.href = `#${encodeURIComponent(id)}`
    a.textContent = h.textContent
    a.style.setProperty("--depth", Number(h.tagName[1]) - top)
    return a
  })
  toc.append(...links)
  toc.hidden = false
  const spy = () => {
    const end = innerHeight + scrollY >= document.documentElement.scrollHeight - 2
    const i = end ? headings.length - 1 : headings.findLastIndex((h) => h.getBoundingClientRect().top <= 40)
    for (const [j, a] of links.entries()) {
      if (j === Math.max(i, 0)) a.setAttribute("aria-current", "location")
      else a.removeAttribute("aria-current")
    }
  }
  addEventListener("scroll", spy, { passive: true })
  spy()
  if (location.hash) document.getElementById(decodeURIComponent(location.hash.slice(1)))?.scrollIntoView()
}
const diagrams = document.querySelectorAll("code.language-mermaid")
if (diagrams.length) {
  for (const code of diagrams) {
    const pre = document.createElement("pre")
    pre.className = "mermaid"
    pre.textContent = code.textContent
    code.closest("pre").replaceWith(pre)
  }
  const { default: mermaid } = await import(
    "/.site/lib/mermaid/mermaid.esm.min.mjs"
  )
  const css = getComputedStyle(document.documentElement)
  const v = (name) => css.getPropertyValue(name).trim()
  mermaid.initialize({
    startOnLoad: false,
    theme: "base",
    themeVariables: {
      darkMode: v("color-scheme") === "dark",
      fontFamily: `${v("--mono")}, monospace`,
      background: v("--bg"),
      primaryColor: v("--raise"),
      primaryTextColor: v("--fg"),
      primaryBorderColor: v("--muted"),
      secondaryColor: v("--side"),
      tertiaryColor: v("--side"),
      lineColor: v("--muted"),
      textColor: v("--fg"),
    },
  })
  await document.fonts.ready
  await mermaid.run({ querySelector: "pre.mermaid", suppressErrors: true })
}

const zoom = document.getElementById("zoom")
const stage = document.getElementById("stage")
const touches = new Map()
let scale = 1
let x = 0
let y = 0
let moved = false
const draw = () => (stage.style.transform = `translate(${x}px, ${y}px) scale(${scale})`)
const zoomAt = (factor, px, py) => {
  const next = Math.min(Math.max(scale * factor, 0.5), 16)
  const cx = px - innerWidth / 2
  const cy = py - innerHeight / 2
  x = cx - ((cx - x) * next) / scale
  y = cy - ((cy - y) * next) / scale
  scale = next
  draw()
}
const reset = () => {
  scale = 1
  x = y = 0
  draw()
}
const show = (node) => {
  const copy = node.cloneNode(true)
  copy.removeAttribute("style")
  copy.removeAttribute("tabindex")
  stage.replaceChildren(copy)
  reset()
  zoom.showModal()
}
for (const node of document.querySelectorAll("article img, pre.mermaid svg")) {
  node.tabIndex = 0
  node.addEventListener("click", () => show(node))
  node.addEventListener("keydown", (e) => e.key === "Enter" && show(node))
}
zoom.addEventListener("wheel", (e) => {
  e.preventDefault()
  zoomAt(Math.exp(-e.deltaY * 0.002), e.clientX, e.clientY)
})
zoom.addEventListener("pointerdown", (e) => {
  if (e.target.closest("menu")) return
  zoom.setPointerCapture(e.pointerId)
  touches.set(e.pointerId, e)
  moved = e.target !== zoom
})
zoom.addEventListener("pointermove", (e) => {
  const last = touches.get(e.pointerId)
  if (!last) return
  if (touches.size === 2) {
    const [other] = [...touches.values()].filter((t) => t.pointerId !== e.pointerId)
    const before = Math.hypot(last.clientX - other.clientX, last.clientY - other.clientY)
    const after = Math.hypot(e.clientX - other.clientX, e.clientY - other.clientY)
    zoomAt(after / before, (e.clientX + other.clientX) / 2, (e.clientY + other.clientY) / 2)
  } else {
    x += e.clientX - last.clientX
    y += e.clientY - last.clientY
    draw()
  }
  moved = true
  touches.set(e.pointerId, e)
})
for (const type of ["pointerup", "pointercancel"]) {
  zoom.addEventListener(type, (e) => {
    const held = touches.delete(e.pointerId)
    if (held && !moved && type === "pointerup") zoom.close()
  })
}
zoom.addEventListener("dblclick", (e) => e.target.closest("menu") || reset())
zoom.addEventListener("keydown", (e) => {
  if (e.key === "+" || e.key === "=") zoomAt(1.25, innerWidth / 2, innerHeight / 2)
  if (e.key === "-") zoomAt(0.8, innerWidth / 2, innerHeight / 2)
  if (e.key === "0") reset()
})
zoom.querySelector("menu").addEventListener("click", (e) => {
  const action = e.target.dataset.zoom
  if (action === "close") zoom.close()
  else if (action === "0") reset()
  else if (action) zoomAt(Number(action), innerWidth / 2, innerHeight / 2)
})
