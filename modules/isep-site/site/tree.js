const side = document.getElementById("side")
if (matchMedia("(max-width: 50rem)").matches) side.open = false
const filter = document.getElementById("filter")
const tree = document.getElementById("tree")
const items = [...tree.querySelectorAll("li")].reverse()
const folders = [...tree.querySelectorAll("details")]
const initial = folders.map((d) => d.open)
addEventListener("keydown", (e) => {
  if (e.key !== "/" || e.target.matches("input, textarea")) return
  e.preventDefault()
  side.open = true
  filter.focus()
})
filter.addEventListener("input", () => {
  const q = filter.value.trim().toLowerCase()
  for (const li of items) li.hidden = false
  if (!q) {
    folders.forEach((d, i) => (d.open = initial[i]))
    return
  }
  for (const li of items) {
    const label = li.querySelector(":scope > a, :scope > details > summary")
    const own = label.textContent.toLowerCase().includes(q)
    const folder = li.querySelector(":scope > details")
    const inner = folder?.querySelector(":scope > ul > li:not([hidden])")
    if (folder) folder.open = Boolean(inner)
    li.hidden = !own && !inner
    if (own && folder) for (const child of li.querySelectorAll("li")) child.hidden = false
  }
})
