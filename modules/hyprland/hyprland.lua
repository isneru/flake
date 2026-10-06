require("theme-colors")

local MOD = "SUPER"

local function bare_mode()
	local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
	local f = io.open(state .. "/quickshell/mode", "r")
	if not f then
		return false
	end
	local v = f:read("l")
	f:close()
	return v == "bare"
end

local BARE = bare_mode()

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
		gaps_in = 4,
		gaps_out = 8,
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
			enabled = BARE,
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
		dim_special = 0,
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

	hl.bind(keybind, dispatcher, opts or {})
end

bind(MOD, "RETURN", hl.dsp.exec_cmd("kitty"))
bind(MOD, "E", hl.dsp.exec_cmd("env YAZI_BAR=1 kitty --class yazi yazi"))
bind(MOD, "PERIOD", hl.dsp.layout("consume_or_expel next"))
bind(MOD, "COMMA", hl.dsp.layout("consume_or_expel prev"))
bind(MOD, "ESCAPE", hl.dsp.exec_cmd("quickshell ipc call notch open power"))
bind(MOD, "A", hl.dsp.exec_cmd("quickshell ipc call notch open wall"))
bind(MOD, "O", hl.dsp.exec_cmd("quickshell ipc call notch open spaces"))
bind(MOD, "B", hl.dsp.exec_cmd("quickshell ipc call notch toggle"))
bind(MOD, "SPACE", hl.dsp.exec_cmd("quickshell ipc call notch open launcher"))
bind(MOD, "V", hl.dsp.exec_cmd("quickshell ipc call notch open clip"))
bind(MOD, "Q", hl.dsp.window.close())
bind(MOD, "T", hl.dsp.exec_cmd("quickshell ipc call notch toggleOpen tray"))
bind(MOD, "F", hl.dsp.window.float({ action = "toggle" }))
bind(MOD, "N", hl.dsp.exec_cmd("note"))
bind(MOD, "I", hl.dsp.exec_cmd("moodle-app"))
bind(MOD, "M", hl.dsp.exec_cmd("quickshell ipc call notch open media"))
bind(MOD, "plus", hl.dsp.layout("colresize +conf"))
bind(MOD, "minus", hl.dsp.layout("colresize -conf"))

bind({ MOD, "SHIFT" }, "V", hl.dsp.exec_cmd("quickshell ipc call notch open shelf"))
bind({ MOD, "SHIFT" }, "O", hl.dsp.exec_cmd("quickshell ipc call pick open repos"))
bind({ MOD, "SHIFT" }, "S", hl.dsp.exec_cmd("quickshell ipc call notch open send"))
bind({ MOD, "SHIFT" }, "T", hl.dsp.exec_cmd("quickshell ipc call notch open timer"))
bind({ MOD, "SHIFT" }, "N", hl.dsp.exec_cmd("quickshell ipc call notch toggleOpen notif"))
bind({ MOD, "SHIFT" }, "D", hl.dsp.exec_cmd("notch-pick deadlines"))
bind({ MOD, "SHIFT" }, "R", hl.dsp.exec_cmd("quickshell ipc call recording toggle"))
bind({ MOD, "SHIFT" }, "F", hl.dsp.window.fullscreen({}))
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
end)
bind({ MOD, "SHIFT" }, "apostrophe", hl.dsp.exec_cmd("quickshell ipc call notch toggleOpen keys"))
bind({ MOD, "CTRL" }, "L", hl.dsp.exec_cmd("quickshell ipc call lock lock"))

bind(nil, "PRINT", hl.dsp.exec_cmd("screenshot full"))
bind("SHIFT", "PRINT", hl.dsp.exec_cmd("screenshot region"))
bind(MOD, "PRINT", hl.dsp.exec_cmd("screenshot region --edit"))

local LOCKED = { locked = true }
local HELD = { locked = true, repeating = true }

bind(nil, "XF86AudioPlay", hl.dsp.exec_cmd("quickshell ipc call notch playPause"), LOCKED)
bind(nil, "XF86AudioNext", hl.dsp.exec_cmd("quickshell ipc call notch next"), LOCKED)
bind(nil, "XF86AudioPrev", hl.dsp.exec_cmd("quickshell ipc call notch previous"), LOCKED)
bind(nil, "XF86MonBrightnessUp", hl.dsp.exec_cmd("quickshell ipc call notch brightnessUp"), HELD)
bind(nil, "XF86MonBrightnessDown", hl.dsp.exec_cmd("quickshell ipc call notch brightnessDown"), HELD)
bind(nil, "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), HELD)
bind(nil, "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), HELD)
bind(nil, "XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), LOCKED)
bind(nil, "XF86AudioMicMute", hl.dsp.exec_cmd("quickshell ipc call notch micMute"), LOCKED)
bind(nil, "XF86Launch2", hl.dsp.exec_cmd("quickshell ipc call mode toggle"))
bind(MOD, "D", function()
	if #hl.get_windows({ class = "vesktop" }) == 0 then
		hl.exec_cmd("vesktop")
	end
	if #hl.get_windows({ class = "scratchmusic" }) == 0 then
		hl.exec_cmd("kitty --class scratchmusic -e rmpc")
	end
	hl.dispatch(hl.dsp.workspace.toggle_special("pad"))
	local sp = hl.get_active_special_workspace()
	local discord = hl.get_windows({ class = "vesktop", workspace = "special:pad" })[1]
	if sp and sp.name == "special:pad" and discord then
		hl.dispatch(hl.dsp.focus({ window = discord }))
	end
end)
bind(nil, "XF86Calculator", hl.dsp.exec_cmd("quickshell ipc call notch toggleOpen calc"))

bind(MOD, "mouse:272", hl.dsp.window.drag())
bind(MOD, "mouse:273", hl.dsp.window.resize())
bind({ MOD, "SHIFT" }, "mouse:273", hl.dsp.window.resize({ keep_aspect_ratio = true }))
bind(MOD, "mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(MOD, "mouse_up", hl.dsp.focus({ workspace = "e-1" }))
bind(MOD, "mouse_right", hl.dsp.layout("focus r"))
bind(MOD, "mouse_left", hl.dsp.layout("focus l"))
bind({ MOD, "SHIFT" }, "mouse_down", hl.dsp.layout("focus r"))
bind({ MOD, "SHIFT" }, "mouse_up", hl.dsp.layout("focus l"))

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

bind(MOD, "W", column_tabs)
bind(MOD, "Up", tab_or_focus("u", hl.dsp.group.prev()))
bind(MOD, "Down", tab_or_focus("d", hl.dsp.group.next()))
bind(MOD, "Left", hl.dsp.layout("focus l"))
bind(MOD, "Right", hl.dsp.layout("focus r"))
bind(MOD, "K", tab_or_focus("u", hl.dsp.group.prev()))
bind(MOD, "J", tab_or_focus("d", hl.dsp.group.next()))
bind(MOD, "H", hl.dsp.layout("focus l"))
bind(MOD, "L", hl.dsp.layout("focus r"))

bind({ MOD, "SHIFT" }, "Up", hl.dsp.window.swap({ direction = "u" }))
bind({ MOD, "SHIFT" }, "Down", hl.dsp.window.swap({ direction = "d" }))
bind({ MOD, "SHIFT" }, "Left", hl.dsp.layout("swapcol l"))
bind({ MOD, "SHIFT" }, "Right", hl.dsp.layout("swapcol r"))
bind({ MOD, "SHIFT" }, "K", hl.dsp.window.swap({ direction = "u" }))
bind({ MOD, "SHIFT" }, "J", hl.dsp.window.swap({ direction = "d" }))
bind({ MOD, "SHIFT" }, "H", hl.dsp.layout("swapcol l"))
bind({ MOD, "SHIFT" }, "L", hl.dsp.layout("swapcol r"))

for i = 0, 9 do
	bind(MOD, i, hl.dsp.focus({ workspace = i == 0 and 10 or i }))
	bind({ MOD, "SHIFT" }, i, hl.dsp.window.move({ workspace = i == 0 and 10 or i }))
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

hl.window_rule({
	match = { class = "vesktop" },
	workspace = "special:pad silent",
})

hl.window_rule({
	match = { class = "scratchmusic" },
	workspace = "special:pad silent",
})

hl.window_rule({
	match = { class = "^(mpv|org\\.qutebrowser\\.qutebrowser)$" },
	idle_inhibit = "fullscreen",
})

hl.layer_rule({
	match = { namespace = "^(quickshell-notch-scrim)$" },
	no_anim = true,
})

if BARE then
	hl.window_rule({
		match = { class = ".*" },
		rounding = 0,
	})

	hl.layer_rule({
		match = { namespace = ".*" },
		no_anim = true,
	})

	hl.window_rule({
		match = { class = "negative:^(kitty|scratchmusic)$" },
		no_blur = true,
	})

	hl.layer_rule({
		match = { namespace = "^(menu)$" },
		blur = true,
	})
end

local pads = { vesktop = true, scratchmusic = true }

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
