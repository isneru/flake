local theme = require("theme-colors")
pcall(require, "frame-plugin")

local MOD = "SUPER"

local function soft_look()
	local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
	local f = io.open(state .. "/quickshell/look", "r")
	if not f then
		return false
	end
	local v = f:read("l")
	f:close()
	return v == "soft"
end

local FLAT = not soft_look()

local function monitor_rules()
	local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
	local f = io.open(state .. "/quickshell/monitors", "r")
	if not f then
		return
	end
	for line in f:lines() do
		local c = {}
		for field in (line .. "\t"):gmatch("([^\t]*)\t") do
			c[#c + 1] = field
		end
		if c[1] and c[1] ~= "" then
			local rule = { output = c[1] }
			if c[2] ~= "" then
				rule.mode = c[2]
			end
			if c[3] ~= "" then
				rule.position = c[3]
			end
			if c[4] ~= "" then
				rule.scale = tonumber(c[4])
			end
			if c[5] ~= "" then
				rule.transform = tonumber(c[5])
			end
			if c[6] ~= "" then
				rule.vrr = tonumber(c[6])
			end
			if c[7] ~= "" then
				rule.mirror = c[7]
			end
			if c[8] == "1" then
				rule.disabled = true
			end
			hl.monitor(rule)
		end
	end
	f:close()
end

hl.on("hyprland.start", function()
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("vesktop")
end)

hl.config({
	input = {
		kb_layout = "pt",
		kb_options = "ctrl:nocaps,custom:shift_numlock_capslock",
		numlock_by_default = true,
		repeat_rate = 25,
		repeat_delay = 200,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			disable_while_typing = true,
		},
	},
	binds = {
		hide_special_on_workspace_change = true,
	},
	misc = {
		focus_on_activate = true,
	},
	general = {
		gaps_in = 6,
		gaps_out = 12,
		border_size = 0,
		layout = "scrolling",
	},
	group = {
		auto_group = false,
		groupbar = {
			render_titles = false,
		},
	},
	scrolling = {
		column_width = 1,
		focus_fit_method = 1,
		follow_min_visible = 0.9,
		direction = "right",
	},
	decoration = {
		shadow = { enabled = true },
		blur = {
			enabled = FLAT,
			size = 3,
			passes = 2,
			new_optimizations = true,
			noise = 0,
			contrast = 1,
			brightness = 1,
			vibrancy = 0,
		},
		dim_inactive = true,
		dim_strength = 0.1,
		dim_special = 0.5,
	},
	xwayland = {
		enabled = true,
	},
	animations = {
		enabled = true,
	},
	render = {
		direct_scanout = 2,
	},
	cursor = {
		no_hardware_cursors = 0,
		use_cpu_buffer = 0,
	},
})

monitor_rules()

for _, plugin in ipairs(hl.get_loaded_plugins()) do
	if plugin.name == "athanor" and type(theme) == "table" then
		hl.config({ plugin = { athanor = theme.frame } })
	end
end

local group = ""

local function section(name)
	group = name
end

local function bind(mods, key, dispatcher, opts)
	if not key or not dispatcher then
		return
	end

	local mod_string = ""

	if type(mods) == "table" then
		mod_string = table.concat(mods, " + ")
	elseif type(mods) == "string" and mods ~= "" then
		mod_string = mods
	end

	local keybind = tostring(key)

	if mod_string ~= "" then
		keybind = mod_string .. " + " .. keybind
	end

	local o = {}
	for k, v in pairs(opts or {}) do
		if k ~= "desc" and k ~= "keys" and k ~= "group" then
			o[k] = v
		end
	end
	if opts and opts.desc then
		o.description = table.concat({ opts.group or group, opts.desc, opts.keys or "" }, "\t")
	end

	hl.bind(keybind, dispatcher, o)
end

local function float_centered(w)
	local m = w.monitor
	hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
	hl.dispatch(hl.dsp.window.resize({
		x = math.floor(m.width / m.scale * 0.6),
		y = math.floor(m.height / m.scale * 0.7),
		window = w,
	}))
	hl.dispatch(hl.dsp.window.center({ window = w }))
end

local function column_tabs()
	local w = hl.get_active_window()
	if not w or w.floating then
		return
	end
	if w.group then
		hl.dispatch(hl.dsp.group.toggle())
		return
	end
	local mates = {}
	for _, o in ipairs(hl.get_windows({ workspace = w.workspace.id, floating = false })) do
		if o.address ~= w.address and o.at.x == w.at.x then
			mates[#mates + 1] = o
		end
	end
	hl.dispatch(hl.dsp.group.toggle())
	local g = hl.get_active_window().group
	if not g then
		return
	end
	for _, o in ipairs(mates) do
		g:add(o)
	end
	hl.dispatch(hl.dsp.focus({ window = w }))
end

local function tab_or_focus(dir, step)
	return function()
		local w = hl.get_active_window()
		if w and w.group and w.group.size > 1 then
			hl.dispatch(step)
		else
			hl.dispatch(hl.dsp.focus({ direction = dir }))
		end
	end
end

local function to_monitor(dir)
	return function()
		if hl.get_active_window() and hl.get_monitor(dir) then
			hl.dispatch(hl.dsp.window.move({ monitor = dir }))
		end
	end
end

section("SHELL")
bind(MOD, "B", hl.dsp.exec_cmd("bare-pick home"), { desc = "Every menu" })
bind(MOD, "SPACE", hl.dsp.exec_cmd("bare-pick run"), { desc = "Launcher, or search the web" })
bind(nil, "XF86Calculator", hl.dsp.exec_cmd("bare-pick calc"), { desc = "Calculator", keys = "CALC" })
bind(MOD, "V", hl.dsp.exec_cmd("bare-pick clip"), { desc = "Clipboard history" })
bind(MOD, "A", hl.dsp.exec_cmd("bare-pick wall"), { desc = "Wallpaper" })
bind(MOD, "TAB", hl.dsp.exec_cmd("bare-pick windows"), { desc = "Windows" })
bind(MOD, "O", hl.dsp.exec_cmd("quickshell ipc call bare overview"), { desc = "Overview of every workspace" })
bind(MOD, "ESCAPE", hl.dsp.exec_cmd("bare-pick power"), { desc = "Power menu" })
bind(MOD, "M", hl.dsp.exec_cmd("bare-pick media"), { desc = "Media controls" })
bind({ MOD, "SHIFT" }, "V", hl.dsp.exec_cmd("bare-pick shelf"), { desc = "Files shelf" })
bind({ MOD, "SHIFT" }, "S", hl.dsp.exec_cmd("bare-pick send"), { desc = "Send with LocalSend" })
bind({ MOD, "SHIFT" }, "T", hl.dsp.exec_cmd("bare-pick timer"), { desc = "Timer" })
bind({ MOD, "SHIFT" }, "O", hl.dsp.exec_cmd("bare-pick repos"), { desc = "Open a repository" })
bind(MOD, "N", hl.dsp.exec_cmd("note"), { desc = "Notes" })
bind(MOD, "T", hl.dsp.exec_cmd("bare-pick tray"), { desc = "Tray" })
bind(
	{ MOD, "SHIFT" },
	"apostrophe",
	hl.dsp.exec_cmd("quickshell ipc call bare keys"),
	{ desc = "This cheatsheet", keys = "SUPER+?" }
)
bind({ MOD, "CTRL" }, "L", hl.dsp.exec_cmd("quickshell ipc call lock lock"), { desc = "Lock the session" })
bind(
	nil,
	"XF86Launch2",
	hl.dsp.exec_cmd("quickshell ipc call look toggle"),
	{ desc = "Switch between the flat and the soft look", keys = "OMEN" }
)

section("APPS")
bind(MOD, "RETURN", hl.dsp.exec_cmd("kitty"), { desc = "Terminal" })
bind(MOD, "E", hl.dsp.exec_cmd("env YAZI_BAR=1 kitty --class yazi yazi"), { desc = "Files" })
bind(MOD, "D", function()
	if #hl.get_windows({ class = "vesktop" }) == 0 then
		hl.exec_cmd("vesktop")
	end
	if #hl.get_windows({ class = "rmpc" }) == 0 then
		hl.exec_cmd("kitty --class rmpc -e rmpc")
	end
	hl.dispatch(hl.dsp.workspace.toggle_special("pad"))
	local sp = hl.get_active_special_workspace()
	local discord = hl.get_windows({ class = "vesktop", workspace = "special:pad" })[1]
	if sp and sp.name == "special:pad" and discord then
		hl.dispatch(hl.dsp.focus({ window = discord }))
	end
end, { desc = "Discord and music pad" })

section("WINDOWS")
bind(MOD, "Q", hl.dsp.window.close(), { desc = "Close the window" })
bind(MOD, "F", function()
	local w = hl.get_active_window()
	if not w then
		return
	end
	if w.floating then
		hl.dispatch(hl.dsp.window.float({ action = "unset" }))
	else
		float_centered(w)
	end
end, { desc = "Float, centred / unfloat" })
bind({ MOD, "SHIFT" }, "F", hl.dsp.window.fullscreen({}), { desc = "Fullscreen" })
bind({ MOD, "SHIFT" }, "P", function()
	local w = hl.get_active_window()
	if not w then
		return
	end
	if w.pinned then
		hl.dispatch(hl.dsp.window.pin({ action = "unset" }))
		hl.dispatch(hl.dsp.window.float({ action = "unset" }))
	else
		hl.dispatch(hl.dsp.window.float({ action = "set" }))
		hl.dispatch(hl.dsp.window.pin({ action = "set" }))
	end
end, { desc = "Pin on top, everywhere / unpin" })

local focus = { desc = "Move focus" }
bind(MOD, "Up", tab_or_focus("u", hl.dsp.group.prev()), focus)
bind(MOD, "Down", tab_or_focus("d", hl.dsp.group.next()), focus)
bind(MOD, "Left", hl.dsp.layout("focus l"), focus)
bind(MOD, "Right", hl.dsp.layout("focus r"), focus)
bind(MOD, "K", tab_or_focus("u", hl.dsp.group.prev()), focus)
bind(MOD, "J", tab_or_focus("d", hl.dsp.group.next()), focus)
bind(MOD, "H", hl.dsp.layout("focus l"), focus)
bind(MOD, "L", hl.dsp.layout("focus r"), focus)

local swap = { desc = "Move the column / swap in it" }
bind({ MOD, "SHIFT" }, "Up", hl.dsp.window.swap({ direction = "u" }), swap)
bind({ MOD, "SHIFT" }, "Down", hl.dsp.window.swap({ direction = "d" }), swap)
bind({ MOD, "SHIFT" }, "Left", hl.dsp.layout("swapcol l"), swap)
bind({ MOD, "SHIFT" }, "Right", hl.dsp.layout("swapcol r"), swap)
bind({ MOD, "SHIFT" }, "K", hl.dsp.window.swap({ direction = "u" }), swap)
bind({ MOD, "SHIFT" }, "J", hl.dsp.window.swap({ direction = "d" }), swap)
bind({ MOD, "SHIFT" }, "H", hl.dsp.layout("swapcol l"), swap)
bind({ MOD, "SHIFT" }, "L", hl.dsp.layout("swapcol r"), swap)

local stack = { desc = "Stack into the next / previous column" }
bind(MOD, "PERIOD", hl.dsp.layout("consume_or_expel next"), stack)
bind(MOD, "COMMA", hl.dsp.layout("consume_or_expel prev"), stack)
local widen = { desc = "Widen / narrow the column" }
bind(MOD, "plus", hl.dsp.layout("colresize +conf"), widen)
bind(MOD, "minus", hl.dsp.layout("colresize -conf"), widen)
bind(MOD, "W", column_tabs, { desc = "Tab the column / untab it" })
local wheel = { desc = "Workspace up / down" }
bind(MOD, "mouse_down", hl.dsp.focus({ workspace = "e+1" }), wheel)
bind(MOD, "mouse_up", hl.dsp.focus({ workspace = "e-1" }), wheel)
local columns = { desc = "Previous / next column" }
bind({ MOD, "SHIFT" }, "mouse_down", hl.dsp.layout("focus r"), columns)
bind({ MOD, "SHIFT" }, "mouse_up", hl.dsp.layout("focus l"), columns)
bind(MOD, "mouse_right", hl.dsp.layout("focus r"))
bind(MOD, "mouse_left", hl.dsp.layout("focus l"))
bind(MOD, "mouse:272", hl.dsp.window.drag(), { desc = "Move a window" })
bind(MOD, "mouse:273", hl.dsp.window.resize(), { desc = "Resize a window" })
bind(
	{ MOD, "SHIFT" },
	"mouse:273",
	hl.dsp.window.resize({ keep_aspect_ratio = true }),
	{ desc = "Resize, keeping the aspect ratio" }
)
local monitor = { desc = "Window to the monitor left / right" }
bind({ MOD, "SHIFT" }, "COMMA", to_monitor("l"), monitor)
bind({ MOD, "SHIFT" }, "PERIOD", to_monitor("r"), monitor)

section("WORKSPACES")
for i = 0, 9 do
	bind(MOD, i, hl.dsp.focus({ workspace = i == 0 and 10 or i }), { desc = "Go to workspace" })
	bind(
		{ MOD, "SHIFT" },
		i,
		hl.dsp.window.move({ workspace = i == 0 and 10 or i }),
		{ desc = "Send the window there" }
	)
end

section("CAPTURE")
bind(nil, "PRINT", hl.dsp.exec_cmd("screenshot full"), { desc = "Screenshot everything" })
bind("SHIFT", "PRINT", hl.dsp.exec_cmd("screenshot region"), { desc = "Screenshot a region" })
bind(MOD, "PRINT", hl.dsp.exec_cmd("screenshot region --edit"), { desc = "A region, then edit it" })
bind(
	{ MOD, "SHIFT" },
	"R",
	hl.dsp.exec_cmd("quickshell ipc call recording toggle"),
	{ desc = "Record (asks for audio) / stop" }
)

section("SYSTEM")
local brightness = { locked = true, repeating = true, desc = "Screen brightness", keys = "Brightness keys" }
bind(nil, "XF86MonBrightnessUp", hl.dsp.exec_cmd("quickshell ipc call bare brightnessUp"), brightness)
bind(nil, "XF86MonBrightnessDown", hl.dsp.exec_cmd("quickshell ipc call bare brightnessDown"), brightness)
local volume = { locked = true, repeating = true, desc = "Volume up, down, mute", keys = "Volume keys" }
bind(nil, "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), volume)
bind(nil, "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), volume)
bind(
	nil,
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, desc = "Volume up, down, mute", keys = "Volume keys" }
)
bind(
	nil,
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("quickshell ipc call bare micMute"),
	{ locked = true, desc = "Mute - unmute the microphone", keys = "Mic mute" }
)
local media = { locked = true, desc = "Play-pause, next, previous", keys = "Media keys" }
bind(nil, "XF86AudioPlay", hl.dsp.exec_cmd("quickshell ipc call bare playPause"), media)
bind(nil, "XF86AudioNext", hl.dsp.exec_cmd("quickshell ipc call bare next"), media)
bind(nil, "XF86AudioPrev", hl.dsp.exec_cmd("quickshell ipc call bare previous"), media)
bind(
	nil,
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd("systemctl --user is-active --quiet caffeinate && quickshell ipc call lock lock"),
	{ locked = true }
)

local blur = { "kitty", "rmpc", "org\\.pwmt\\.zathura" }

local has_extra, extra = pcall(require, "extra")
if has_extra then
	extra(bind, MOD, blur)
end

hl.window_rule({
	match = { fullscreen = true },
	no_dim = true,
	opaque = true,
})

hl.window_rule({
	match = { class = "xdg-desktop-portal-gtk" },
	float = true,
	animation = "popin 70%",
	size = { 800, 500 },
})

hl.window_rule({
	match = { class = "^filepicker$" },
	float = true,
	center = true,
	animation = "popin 70%",
	size = { 1100, 650 },
})

hl.window_rule({
	match = { class = "com.gabm.satty" },
	float = true,
	animation = "popin 70%",
})

hl.window_rule({
	match = { class = "^(swayimg)$" },
	float = true,
	animation = "popin 70%",
})

hl.window_rule({
	match = { class = "^kitty$" },
	animation = "popin 70%",
})

hl.window_rule({
	match = { class = "^yazi$" },
	animation = "popin 70%",
})

hl.window_rule({
	match = { class = "^(gcr.*|org\\.gnome\\.keyring.*|.*ssh-askpass|polkit-.*)$" },
	float = true,
	pin = true,
	animation = "popin 70%",
})

hl.workspace_rule({ workspace = "special:pad", gaps_in = 24, gaps_out = 48 })

hl.window_rule({
	match = { class = "vesktop" },
	workspace = "special:pad silent",
})

hl.window_rule({
	match = { class = "rmpc" },
	workspace = "special:pad silent",
})

hl.window_rule({
	match = { class = "^(mpv|org\\.qutebrowser\\.qutebrowser)$" },
	idle_inhibit = "fullscreen",
})

hl.layer_rule({
	match = { namespace = "^(menu)$" },
	no_anim = true,
})

if FLAT then
	hl.layer_rule({
		match = { namespace = ".*" },
		no_anim = true,
	})

	hl.window_rule({
		match = { class = "negative:^(" .. table.concat(blur, "|") .. ")$" },
		no_blur = true,
	})

	hl.layer_rule({
		match = { namespace = "^(menu)$" },
		blur = true,
	})
end

local pads = { vesktop = true, rmpc = true }

hl.on("window.open", function(w)
	if not w.workspace.special or pads[w.class] or w.floating then
		return
	end

	local act = hl.get_active_window()
	if not act or act.address ~= w.address then
		return
	end

	local target = hl.get_active_workspace()
	if not target or target.special then
		return
	end

	hl.dispatch(hl.dsp.window.move({ workspace = target.id }))
end)

local FLOAT_WS = 5
local floated = {}

local function claim(w)
	if w.floating then
		return
	end
	float_centered(w)
	floated[w.stable_id] = true
end

hl.on("window.open", function(w)
	if w.workspace.id == FLOAT_WS then
		claim(w)
	end
end)

hl.on("window.move_to_workspace", function(w, ws)
	if ws.id == FLOAT_WS then
		hl.timer(function()
			claim(w)
		end, { timeout = 1, type = "oneshot" })
	elseif floated[w.stable_id] and not w.pinned then
		floated[w.stable_id] = nil
		hl.dispatch(hl.dsp.window.float({ action = "unset", window = w }))
	end
end)

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
