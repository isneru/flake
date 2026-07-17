-- Structural config only - never changes with theme. Colors/rounding come
-- from theme-colors.lua, written by theme-set (theme-engine) at runtime and
-- required from here so `hyprctl reload` alone (no rebuild) picks up either
-- half changing independently.
require("theme-colors")

hl.config({
	input = {
		kb_layout = "pt",
		numlock_by_default = true,
		repeat_rate = 25,
		repeat_delay = 200,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			disable_while_typing = true,
		},
	},
	general = {
		gaps_in = 8,
		gaps_out = 8,
		border_size = 1,
		-- Niri-style scrolling layout instead of dwindle/master: windows sit
		-- in horizontally-scrolling columns within a single workspace rather
		-- than a binary-tree tiling split.
		layout = "scrolling",
	},
	scrolling = {
		column_width = 0.8,
		wrap_focus = false,
		wrap_swapcol = false,
	},
	decoration = {
		shadow = { enabled = true },
		-- Global, not per-window: hl.window_rule has no opt-in "blur" field,
		-- only an opt-out "no_blur" - driftwm's kitty-only blur rule doesn't
		-- have a direct equivalent, so blur is enabled globally instead. kitty
		-- is the only meaningfully transparent window in this setup (see its
		-- background_opacity), so this reads the same in practice.
		blur = { enabled = true },
		dim_inactive = true,
		dim_strength = 0.2,
	},
	xwayland = {
		enabled = false,
	},
})

-- Animation curves + feel, ported from voidarc/hypr's animations.lua.
hl.curve("heavyOvershoot", { type = "bezier", points = { { 0.53, 0.51 }, { 0.4, 1.22 } } })
hl.curve("lightOvershoot", { type = "bezier", points = { { 0.33, 0.61 }, { 0.63, 1.19 } } })
hl.curve("smoothSnap", { type = "bezier", points = { { 0.32, 0.51 }, { 0.44, 1 } } })
hl.curve("smoothIn", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("smoothOutOvershoot", { type = "bezier", points = { { 0.46, -0.25 }, { 0.81, 0.51 } } })

hl.curve("hardSpring", { type = "spring", mass = 1, stiffness = 500, dampening = 36 })
hl.curve("mediumSpring", { type = "spring", mass = 1, stiffness = 480, dampening = 36 })
hl.curve("heavierSpring", { type = "spring", mass = 1.3, stiffness = 480, dampening = 37 })
hl.curve("looseSpring", { type = "spring", mass = 1, stiffness = 480, dampening = 31 })

hl.animation({ leaf = "windows", enabled = true, speed = 4, spring = "heavierSpring", style = "slide right" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "heavyOvershoot", style = "popin 30%" })
-- windowsMove drives every window's position animation, including the
-- column-pan from SUPER+H/L below - without this it inherits "windows"
-- above (a stiff spring), which reads as way too snappy for a scroll-pan.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "smoothSnap" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "heavyOvershoot", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, spring = "mediumSpring", style = "slidefadevert -80%" })

-- Autostart (driftwm's `autostart = ["vesktop"]`).
-- graphical-session.target activation is UWSM's job now (SDDM's default
-- session is the "Hyprland (uwsm-managed)" entry, hyprland-uwsm.desktop) -
-- no manual systemctl call needed here anymore. The previous manual
-- hyprland-session.target hack (started on hyprland.start, never stopped
-- on exit) left stale session state behind on logout that broke the next
-- login's systemd session allocation entirely (confirmed live: a real
-- hang requiring a hard shutdown) - UWSM ties start *and* stop to the
-- compositor's actual process lifetime, which a bare exec_cmd call here
-- never could.
hl.on("hyprland.start", function()
	-- --start-minimized was tried here and reverted: it doesn't reliably
	-- start hidden (a real, currently-unmerged upstream Vesktop bug - a fix
	-- PR for exactly this exists but was closed, not merged), and the
	-- alternative (a Hyprland window rule forcing it onto a hidden special
	-- workspace) risks a worse failure mode where clicking the tray icon
	-- silently does nothing instead of just occasionally not starting
	-- minimized. Plain launch; minimizeToTray/closeToTray are already "on"
	-- in vesktop's own settings.json for once it's manually minimized once.
	hl.exec_cmd("vesktop")
	hl.exec_cmd("noctalia")
end)

local mod = "SUPER"

-- Direct ports of driftwm's spawn keybinds.
hl.bind(mod .. " + D", hl.dsp.exec_cmd("tofi-drun --drun-launch=true"))
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("emacsclient -c"))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("powermenu"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"))
-- No direct Noctalia equivalent to driftshell's curated theme-menu overlay
-- (Noctalia's own settings picker is for its own scheme system, not our
-- themes/*.toml list) - dropped; theme-set next/prev below still cover
-- switching, `theme-set <name>` from a terminal covers picking directly.
hl.bind(mod .. " + SHIFT + PERIOD", hl.dsp.exec_cmd("theme-set next"))
hl.bind(mod .. " + SHIFT + COMMA", hl.dsp.exec_cmd("theme-set prev"))
hl.bind("Print", hl.dsp.exec_cmd("screenshot full"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("screenshot region"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("screenshot window"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("noctalia msg volume-mute"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("noctalia msg brightness-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"))
hl.bind(mod .. " + CTRL + SHIFT + Q", hl.dsp.exec_cmd("hyprctl dispatch exit"))

-- Window management.
hl.bind(mod .. " + Q", hl.dsp.window.close())
-- Confirmed live via hyprctl eval: an empty table defaults to toggle
-- behavior, same as { action = "toggle" }.
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({}))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))

-- Mouse-drag move/resize. Hyprland's mouse bind key syntax ("mouse:<code>")
-- doubles as the trigger for a click-drag gesture: hl.dsp.window.drag()/
-- resize() called with no args returns the drag dispatcher, not an
-- instant action.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize())

-- driftwm's center-nearest <dir> (canvas nav) has no equivalent - this binds
-- Hyprland's native focus-by-direction instead, the closest analogue for the
-- same physical keys.
hl.bind(mod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + Down", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + Right", hl.dsp.focus({ direction = "r" }))

-- Scrolling-layout column navigation - moves to and centers the next/prev
-- column (unlike plain movefocus, this also scrolls the viewport into view).
hl.bind(mod .. " + H", hl.dsp.layout("move -col"))
hl.bind(mod .. " + L", hl.dsp.layout("move +col"))
hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))

-- Workspace switching - driftwm had no workspace concept at all (canvas
-- only), so there was nothing to port here. mod+N switches, mod+shift+N
-- moves the focused window along.
for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Window rules (driftwm's [[window_rules]]). Blur is global (see decoration
-- above), not a per-window opt-in - kitty needed no rule of its own.
-- Approximate: driftwm's "minimal" decoration mode has no direct field, so
-- this only zeroes rounding.
hl.window_rule({
	match = { title = "Picture-in-Picture" },
	float = true,
	pin = true,
	border_size = 0,
})

-- Don't dim fullscreen or YouTube windows.
hl.window_rule({
	match = { fullscreen = true },
	no_dim = true,
	opaque = true,
})
hl.window_rule({
	match = { class = "helium", title = ".*YouTube.*" },
	no_dim = true,
	opaque = true,
})

-- Float file pickers instead of tiling them into a scrolling column.
hl.window_rule({
	match = { class = "xdg-desktop-portal-gtk" },
	float = true,
	animation = "popin 70%",
	size = { 800, 500 },
})

-- satty (screenshot annotator, see scripts/screenshot.sh) - same floating
-- popup treatment, no fixed size since it sizes itself to the screenshot.
hl.window_rule({
	match = { class = "com.gabm.satty" },
	float = true,
	animation = "popin 90%",
})

-- Blur on overlay layer surfaces - global decoration.blur only covers
-- windows, layer-shell surfaces (tofi) need their own opt-in via layer_rule.
hl.layer_rule({
	match = { namespace = "^(launcher)$" },
	blur = true,
})

-- Replaces the driftshell dashboard: Noctalia's own control-center panel.
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
