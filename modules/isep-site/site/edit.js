import { api } from "/.site/api.js"
import { continueList, format } from "/.site/format.js"

const me = await api("me").catch(() => null)
const review = document.getElementById("review")
if (me?.owner) {
  review.textContent = me.pending ? `Review (${me.pending})` : "Review"
  review.hidden = false
}

const button = document.getElementById("edit")
const editor = document.getElementById("editor")
if (button && me) {
  const article = document.querySelector("main > article")
  const area = editor.querySelector("textarea")
  const preview = document.getElementById("preview")
  const status = editor.querySelector(".status")
  const tabs = editor.querySelectorAll("[data-tab]")
  const tools = document.getElementById("tools")
  const route = `note?path=${encodeURIComponent(decodeURIComponent(location.pathname))}`
  let etag = ""
  let dirty = false

  editor.querySelector("[type=submit]").textContent = me.owner ? "Save" : "Propose change"
  button.hidden = false
  button.addEventListener("click", async () => {
    button.disabled = true
    try {
      const note = await api(route)
      area.value = note.text
      etag = note.etag
      status.textContent = note.pending
        ? "You have a change awaiting review. Saving replaces it."
        : me.owner
          ? ""
          : "Your change goes live once it is approved."
      article.hidden = true
      button.hidden = true
      editor.hidden = false
      area.focus()
    } catch (e) {
      alert(e.message)
      button.disabled = false
    }
  })

  for (const tab of tabs) {
    tab.addEventListener("click", async () => {
      const write = tab.dataset.tab === "write"
      for (const t of tabs) t.setAttribute("aria-pressed", t === tab)
      area.hidden = !write
      tools.hidden = !write
      if (!write) {
        const { md } = await import("/.site/md.js")
        preview.innerHTML = md.render(area.value.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, ""))
      }
      preview.hidden = write
    })
  }

  area.addEventListener("input", () => (dirty = true))
  const keys = { b: "bold", i: "italic", k: "link" }
  area.addEventListener("keydown", (e) => {
    if (e.key === "Enter") continueList(area, e)
    if (e.altKey && e.shiftKey && e.code === "KeyF") {
      e.preventDefault()
      format(area, "tidy")
      return
    }
    if (!(e.ctrlKey || e.metaKey) || e.altKey || e.shiftKey) return
    if (e.key === "s") {
      e.preventDefault()
      editor.requestSubmit()
    } else if (keys[e.key]) {
      e.preventDefault()
      format(area, keys[e.key])
    }
  })
  tools.addEventListener("click", (e) => {
    const tool = e.target.closest("button")
    if (!tool) return
    if (tool.dataset.tool) {
      format(area, tool.dataset.tool)
      return
    }
    const wrap = tool.getAttribute("aria-pressed") !== "true"
    tool.setAttribute("aria-pressed", wrap)
    area.wrap = wrap ? "soft" : "off"
  })
  addEventListener("beforeunload", (e) => dirty && e.preventDefault())

  editor.addEventListener("submit", async (e) => {
    e.preventDefault()
    status.textContent = "Saving…"
    try {
      const result = await api(route, { method: "PUT", body: JSON.stringify({ text: area.value, etag }) })
      dirty = false
      if (result.status === "saved") location.reload()
      else status.textContent = result.status === "pending" ? "Sent for review." : "No changes to send."
    } catch (err) {
      status.textContent = err.message
    }
  })

  editor.querySelector("[data-cancel]").addEventListener("click", () => {
    if (dirty && !confirm("Discard your changes?")) return
    dirty = false
    editor.hidden = true
    article.hidden = false
    button.hidden = false
    button.disabled = false
  })
}
