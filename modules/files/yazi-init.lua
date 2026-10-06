local bar = os.getenv("YAZI_BAR") == "1"
local home = os.getenv("HOME")
local state = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/quickshell/mode"
local out = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/yazi-bar-" .. (os.getenv("KITTY_PID") or "0") .. ".json"
local last

local function read_bare()
	local f = io.open(state)
	if not f then
		return false
	end
	local mode = f:read("l")
	f:close()
	return mode == "bare"
end

local bare = bar and read_bare()

local function publish(payload)
	local text = ya.json_encode(payload)
	if text == last then
		return
	end
	last = text
	local f = io.open(out, "w")
	if f then
		f:write(text, "\n")
		f:close()
	end
end

if bar then
	ps.sub_remote("notch-mode", function(mode)
		bare = mode == "bare"
		if not bare then
			last = nil
			os.remove(out)
		end
		ya.render()
	end)
end

local layout = Root.layout
function Root:layout()
	layout(self)
	if bare then
		self._chunks[3] = ui.Rect({
			x = self._chunks[3].x,
			y = self._chunks[3].y,
			w = self._chunks[3].w,
			h = self._chunks[3].h + self._chunks[4].h,
		})
		self._chunks[4] = ui.Rect({ x = 0, y = 0, w = 0, h = 0 })
	end
end

local redraw = Status.redraw
function Status:redraw()
	if not bare then
		return redraw(self)
	end
	local current = self._current
	local h = current.hovered
	local summary = cx.tasks.summary
	publish({
		id = os.getenv("YAZI_ID"),
		mode = tostring(self._tab.mode),
		size = h and ya.readable_size(h.cha.len or 0) or "",
		name = h and ui.printable(h.name) or "",
		perm = h and h.cha:perm() or "",
		cursor = current.cursor,
		files = #current.files,
		tasks = summary.total - summary.success,
		failed = summary.failed,
		percent = summary.percent and math.floor(summary.percent) or nil,
	})
	return {}
end
