import { api } from "/.site/api.js"

const list = document.getElementById("list")
const empty = document.getElementById("empty")
const item = document.getElementById("item")

const show = async () => {
  let pending
  try {
    pending = await api("pending")
  } catch (e) {
    empty.textContent = e.message
    empty.hidden = false
    return
  }
  list.replaceChildren()
  empty.hidden = pending.length > 0
  for (const p of pending) {
    const node = item.content.cloneNode(true)
    const link = node.querySelector(".path")
    link.href = p.path.split("/").map(encodeURIComponent).join("/")
    link.textContent = p.path
    node.querySelector(".who").textContent = `${p.author} · ${new Date(p.time * 1000).toLocaleString()}`
    node.querySelector(".state").textContent = !p.clean
      ? "Conflicts with the current note: edit it by hand, then reject this."
      : p.stale
        ? "The note changed since; approving merges both."
        : ""
    node.querySelector(".diff").append(
      ...p.diff
        .replace(/\n$/, "")
        .split("\n")
        .slice(2)
        .map((line, i, all) => {
        const span = document.createElement("span")
        span.className = { "+": "add", "-": "del", "@": "hunk" }[line[0]] ?? ""
        span.textContent = i < all.length - 1 ? `${line}\n` : line
        return span
      }),
    )
    const status = node.querySelector(".status")
    node.querySelector("[data-act=approve]").disabled = !p.clean
    for (const act of node.querySelectorAll("[data-act]")) {
      act.addEventListener("click", async () => {
        try {
          await api(`pending/${p.id}/${act.dataset.act}`, { method: "POST" })
          show()
        } catch (e) {
          status.textContent = e.message
        }
      })
    }
    list.append(node)
  }
}

show()
