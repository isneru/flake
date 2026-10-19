local M = {}

local api = vim.api

local path
local active = false
local status = {}
local row = vim.NIL
local last

local function write(text)
	if text == last then
		return
	end
	last = text
	local f = io.open(path, "w")
	if f then
		f:write(text, "\n")
		f:close()
	end
end

local function publish()
	if active then
		write(vim.json.encode(vim.tbl_extend("force", status, { row = row })))
	end
end

local function refresh()
	if not active or api.nvim_win_get_config(0).relative ~= "" then
		return
	end
	local s = require("neru.statusline")
	status = {
		server = vim.v.servername,
		mode = require("lualine.utils.mode").get_mode(),
		branch = vim.b.gitsigns_head or vim.g.gitsigns_head or "",
		diagnostics = vim.trim(s.diagnostics()),
		search = vim.trim(s.search()),
		position = s.position(),
		lines = api.nvim_buf_line_count(0),
		indent = s.indent(),
		encoding = s.encoding(),
		eol = s.eol(),
		language = s.language(),
		formatter = s.formatter(),
	}
	publish()
end

local function resolve(group)
	if type(group) == "number" then
		return api.nvim_get_hl(0, { id = group, link = false })
	end
	local h = api.nvim_get_hl(0, { name = group, link = false, create = false })
	while vim.tbl_isempty(h) and group:find("%.") do
		group = group:gsub("%.[^.]*$", "")
		h = api.nvim_get_hl(0, { name = group, link = false, create = false })
	end
	return h
end

local flags = { "bold", "italic", "underline", "undercurl", "strikethrough", "reverse" }

local function combine(a, h)
	local out = { fg = h.fg or a.fg, bg = h.bg or a.bg }
	for _, k in ipairs(flags) do
		if h.nocombine then
			out[k] = h[k] or nil
		else
			out[k] = a[k] or h[k] or nil
		end
	end
	return out
end

local function render(win, cursor)
	local buf = api.nvim_win_get_buf(win)
	local text = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
	local base = combine({}, resolve("MsgArea"))
	local cells = {}
	local starts = vim.str_utf_pos(text)
	for i, s in ipairs(starts) do
		local e = (starts[i + 1] or #text + 1) - 1
		cells[i] = { s = s - 1, t = text:sub(s, e), a = base }
	end
	local function at(col)
		for i, c in ipairs(cells) do
			if c.s >= col then
				return i
			end
		end
		return #cells + 1
	end

	local marks = vim.tbl_filter(function(m)
		return m[2] == 0 and not m[4].invalid
	end, api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true }))
	table.sort(marks, function(x, y)
		local px, py = x[4].priority or 4096, y[4].priority or 4096
		return px == py and x[1] < y[1] or px < py
	end)
	for _, m in ipairs(marks) do
		local d = m[4]
		if d.hl_group then
			local h = resolve(d.hl_group)
			local stop = (d.end_row or 0) > 0 and math.huge or d.end_col or m[3]
			for _, c in ipairs(cells) do
				if c.s >= m[3] and c.s < stop then
					c.a = combine(c.a, h)
				end
			end
		end
	end
	for _, mt in ipairs(vim.fn.getmatches(win)) do
		local p = mt.pos1
		if p and p[1] == 1 then
			local h = resolve(mt.group)
			for _, c in ipairs(cells) do
				if c.s >= p[2] - 1 and c.s < p[2] - 1 + (p[3] or 1) then
					c.a = combine(c.a, h)
				end
			end
		end
	end
	for _, m in ipairs(marks) do
		local d = m[4]
		if d.virt_text and d.virt_text_pos == "overlay" then
			local i = at(m[3])
			for _, chunk in ipairs(d.virt_text) do
				local h = chunk[2] and resolve(chunk[2]) or {}
				for ch in chunk[1]:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
					cells[i] = { s = cells[i] and cells[i].s or math.huge, t = ch, a = combine(base, h) }
					i = i + 1
				end
			end
		end
	end

	local spans = {}
	for _, c in ipairs(cells) do
		local a, prev = c.a, spans[#spans]
		local span = {
			fg = a.fg and ("#%06x"):format(a.fg) or nil,
			bg = a.bg and ("#%06x"):format(a.bg) or nil,
		}
		for _, k in ipairs(flags) do
			span[k] = a[k]
		end
		local same = prev ~= nil and prev.fg == span.fg and prev.bg == span.bg
		for _, k in ipairs(flags) do
			same = same and prev[k] == span[k]
		end
		if same then
			prev.text = prev.text .. c.t
		else
			span.text = c.t
			spans[#spans + 1] = span
		end
	end
	return {
		spans = spans,
		cursor = cursor and at(api.nvim_win_get_cursor(win)[2]) - 1 or vim.NIL,
	}
end

local ui, cmdline, messages
local depth = 0
local broken = false
local wanted = 0
local guicursor

local function caret(hide)
	if (guicursor ~= nil) == hide then
		return
	end
	local value
	if hide then
		guicursor = vim.o.guicursor
		value = (guicursor == "" and "" or guicursor .. ",") .. "c-ci-cr:block-NeruBarCaret"
	else
		value, guicursor = guicursor, nil
	end
	vim._with({ noautocmd = true }, function()
		vim.o.guicursor = value
	end)
end

local function mirroring()
	return active and not broken and ui ~= nil and wanted == 0
end

local function sync()
	if depth > 0 or not ui then
		return
	end
	local win = ui.wins.cmd
	if not (mirroring() and api.nvim_win_is_valid(win)) then
		row = vim.NIL
		caret(false)
		return publish()
	end
	ui.cmdheight = 0
	local level = cmdline.level > 0
	local open = level or messages.cmd_on_key ~= nil
	local single = not open
		or (level and cmdline.srow == 0 and api.nvim_buf_line_count(ui.bufs.cmd) == 1)
		or (not level and api.nvim_win_text_height(win, {}).all <= 1)
	if single then
		if not api.nvim_win_get_config(win).hide then
			api.nvim_win_set_config(win, { hide = true })
		end
		if vim.o.cmdheight ~= 0 then
			vim._with({ noautocmd = true, o = { splitkeep = "screen" } }, function()
				vim.o.cmdheight = 0
			end)
			messages.set_pos()
		end
	end
	row = open and single and render(win, level) or vim.NIL
	caret(row ~= vim.NIL and level)
	publish()
end

local function release()
	broken = true
	row = vim.NIL
	pcall(caret, false)
	if ui and api.nvim_win_is_valid(ui.wins.cmd) and (cmdline.level > 0 or messages.cmd_on_key) then
		pcall(api.nvim_win_set_config, ui.wins.cmd, { hide = false })
	end
	publish()
end

local function guarded()
	local ok, err = pcall(sync)
	if not ok then
		release()
		vim.schedule(function()
			vim.notify("neru.bar: command line handed back to nvim: " .. tostring(err), vim.log.levels.WARN)
		end)
	end
end

local function shaped()
	return type(ui.wins) == "table"
		and type(ui.bufs) == "table"
		and type(ui.ns) == "number"
		and type(ui.check_targets) == "function"
		and type(cmdline.level) == "number"
		and type(cmdline.srow) == "number"
		and type(cmdline.cmdline_show) == "function"
		and type(messages.cmd) == "table"
		and type(messages.expand_msg) == "function"
		and type(messages.set_pos) == "function"
		and type(messages.msg_show) == "function"
end

local function dismiss()
	vim.on_key(nil, ui.ns)
	pcall(api.nvim_win_close, ui.wins.cmd, true)
	ui.check_targets()
	messages.cmd_on_key, messages.cmd.ids = nil, {}
end

local function attach()
	ui = package.loaded["vim._core.ui2"]
	cmdline = package.loaded["vim._core.ui2.cmdline"]
	messages = package.loaded["vim._core.ui2.messages"]
	if not (ui and cmdline and messages and shaped()) then
		ui = nil
		return
	end
	for _, mod in ipairs({ cmdline, messages }) do
		for name, fn in pairs(mod) do
			if type(fn) == "function" and (name:match("^cmdline_") or name:match("^msg_")) then
				mod[name] = function(...)
					depth = depth + 1
					local ok, err = pcall(fn, ...)
					depth = depth - 1
					if depth == 0 then
						guarded()
					end
					if not ok then
						error(err, 0)
					end
				end
			end
		end
	end
	local show = cmdline.cmdline_show
	cmdline.cmdline_show = function(...)
		if
			mirroring()
			and cmdline.level == 0
			and messages.cmd_on_key
			and api.nvim_win_is_valid(ui.wins.cmd)
			and api.nvim_win_text_height(ui.wins.cmd, {}).all <= 1
		then
			dismiss()
		end
		return show(...)
	end
	vim.on_key(function()
		if row ~= vim.NIL then
			vim.schedule(guarded)
		end
	end, api.nvim_create_namespace("neru.bar"))
end

function M.click()
	if not (mirroring() and row ~= vim.NIL and cmdline.level == 0 and messages.cmd_on_key) then
		return
	end
	vim.on_key(nil, ui.ns)
	messages.expand_msg("cmd", "pager")
	api.nvim_win_set_cursor(ui.wins.pager, { 1, 0 })
	pcall(api.nvim_win_close, ui.wins.cmd, true)
	ui.check_targets()
	messages.cmd_on_key, messages.cmd.ids = nil, {}
	guarded()
	api.nvim__redraw({ flush = true })
end

local rule = "%#WinSeparator#%{repeat('─', winwidth(0))}"

local function quiet(lualine)
	lualine.hide({ place = { "statusline" } })
	vim.go.statusline = rule
	vim.go.laststatus = 0
end

local function apply(on)
	if on == active then
		return
	end
	local ok, lualine = pcall(require, "lualine")
	active = on
	if on then
		if ok then
			quiet(lualine)
		end
		refresh()
		guarded()
	else
		if ui and row ~= vim.NIL and api.nvim_win_is_valid(ui.wins.cmd) then
			api.nvim_win_set_config(ui.wins.cmd, { hide = false })
		end
		row = vim.NIL
		caret(false)
		write("{}")
		if ok then
			if vim.go.statusline == rule then
				vim.go.statusline = ""
			end
			lualine.hide({ place = { "statusline" }, unhide = true })
		end
	end
end

local shell = 0

local function running(callback)
	local argv = { "systemctl", "--user", "show", "--property=ActiveState,MainPID", "quickshell.service" }
	local function parse(out)
		local state = (out or ""):match("ActiveState=(%S+)")
		shell = tonumber((out or ""):match("MainPID=(%d+)")) or 0
		return state == "active" and shell > 0
	end
	if not callback then
		return parse(vim.system(argv, { text = true }):wait().stdout)
	end
	vim.system(argv, { text = true }, function(r)
		vim.schedule(function()
			callback(parse(r.stdout))
		end)
	end)
end

function M.setup()
	local kitty = vim.env.KITTY_PID
	if not (kitty and vim.env.HYPRLAND_INSTANCE_SIGNATURE) or vim.env.NVIM or #api.nvim_list_uis() == 0 then
		return
	end
	path = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-bar-" .. kitty .. ".json"
	wanted = vim.o.cmdheight
	attach()

	local ok, lualine = pcall(require, "lualine")
	if ok then
		local setup = lualine.setup
		lualine.setup = function(...)
			setup(...)
			if active then
				quiet(lualine)
			end
		end
	end

	local wk, view = pcall(require, "which-key.view")
	if wk and type(view.show) == "function" then
		local show = view.show
		view.show = function(...)
			local win = require("which-key.config").win
			local row = win.row
			if active then
				win.row = math.huge
			end
			local ok, err = pcall(show, ...)
			win.row = row
			if not ok then
				error(err, 0)
			end
		end
	end

	local group = api.nvim_create_augroup("neru.bar", {})
	api.nvim_create_autocmd({
		"BufEnter",
		"CursorMoved",
		"CursorMovedI",
		"DiagnosticChanged",
		"BufWritePost",
		"FileType",
		"LspAttach",
		"LspDetach",
		"ModeChanged",
		"OptionSet",
		"TextChanged",
		"TextChangedI",
		"VimResume",
		"WinEnter",
	}, { group = group, callback = refresh })
	api.nvim_create_autocmd("User", { group = group, pattern = "GitSignsUpdate", callback = refresh })
	api.nvim_create_autocmd("CmdlineLeave", { group = group, callback = vim.schedule_wrap(refresh) })
	api.nvim_create_autocmd("OptionSet", {
		group = group,
		pattern = "cmdheight",
		callback = function()
			wanted = tonumber(vim.v.option_new) or 0
			if wanted > 0 and ui and api.nvim_win_is_valid(ui.wins.cmd) then
				api.nvim_win_set_config(ui.wins.cmd, { hide = false })
			end
			guarded()
		end,
	})
	api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			last = nil
			running(function(on)
				apply(on)
				refresh()
			end)
		end,
	})
	api.nvim_set_hl(0, "NeruBarCaret", { blend = 100, nocombine = true })
	api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			api.nvim_set_hl(0, "NeruBarCaret", { blend = 100, nocombine = true })
		end,
	})
	api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			apply(false)
		end,
	})
	api.nvim_create_autocmd("VimSuspend", {
		group = group,
		callback = function()
			last = nil
			write("{}")
		end,
	})

	local timer = vim.uv.new_timer()
	if timer then
		timer:start(
			2000,
			2000,
			vim.schedule_wrap(function()
				if active and (shell <= 0 or vim.uv.kill(shell, 0) ~= 0) then
					running(apply)
				end
			end)
		)
	end

	apply(running())
end

return M
