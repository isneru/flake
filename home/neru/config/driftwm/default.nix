{
  config,
  style,
  pkgs,
  ...
}:
let
  wGap = 6;

  # widget sizes
  ws = {
    clock = {
      w = 380;
      h = 165;
    };
    weather = {
      w = 255;
      h = 165;
    };
    stats = {
      w = 380;
      h = 285;
    };
    calendar = {
      w = 255;
      h = 285;
    };
    canvas = {
      w = 380;
      h = 125;
    };
    notif = {
      w = 255;
      h = 125;
    };
  };

  cx = 0;
  cy = 1500;

  totalW = ws.clock.w + wGap + ws.weather.w;
  totalH = ws.clock.h + wGap + ws.stats.h + wGap + ws.canvas.h;

  gridLeft = cx - totalW / 2;
  col1 = gridLeft + ws.clock.w / 2;
  col2 = gridLeft + ws.clock.w + wGap + ws.weather.w / 2;

  row1 = cy + totalH / 2 - ws.clock.h / 2;
  row2 = row1 - ws.clock.h / 2 - wGap - ws.stats.h / 2;
  row3 = row2 - ws.stats.h / 2 - wGap - ws.canvas.h / 2;

  i = toString;
in
{
  systemd.user.services.driftwm = {
    Unit = {
      Description = "driftwm compositor";
      BindsTo = "graphical-session.target";
      Before = "graphical-session.target";
      Wants = "graphical-session-pre.target";
      After = "graphical-session-pre.target";
    };
    Service = {
      Slice = "session.slice";
      Type = "notify";
      NotifyAccess = "main";
      UnsetEnvironment = "WAYLAND_DISPLAY DISPLAY WAYLAND_SOCKET";
      Environment = "XKB_DEFAULT_LAYOUT=pt";
      ExecStart = "${pkgs.driftwm}/bin/driftwm --backend udev";
    };
  };

  systemd.user.targets.driftwm-shutdown = {
    Unit = {
      Description = "driftwm shutdown";
      DefaultDependencies = "no";
      Conflicts = "graphical-session.target graphical-session-pre.target";
      After = "graphical-session.target graphical-session-pre.target";
    };
  };

  home.packages = [ pkgs.driftwm ];

  xdg.configFile."xdg-desktop-portal-wlr/config".text = ''
    [screencast]
    output_name=eDP-1
    max_fps=144
    chooser_type=none
  '';

  xdg.configFile."driftwm/plasma.glsl".source = ./plasma.glsl;
  xdg.configFile."driftwm/config.toml".text = ''
    mod_key = "super"
    focus_follows_mouse = true
    window_placement = "auto"
    autostart = ["vesktop", "battery-notify", "widget-launcher"]

    [input.keyboard]
    layout = "pt"
    num_lock = true
    repeat_rate = 25
    repeat_delay = 200

    [input.trackpad]
    tap_to_click = true
    natural_scroll = true
    disable_while_typing = true

    [navigation]
    animation_speed = 0.15
    anchors = []

    [zoom]
    step = 1.5

    [snap]
    enabled = true
    gap = ${toString style.radius}
    distance = 20
    same_edge = true
    edge_center = true

    [mouse]
    decoration_resize_snapped = true
    decoration_fit_snapped = true

    [decorations]
    corner_radius = ${toString style.radius}
    shadow = true
    default_mode = "minimal"
    border_width = 1
    border_color = "${style.colors.border}"
    border_color_focused = "${style.colors.accent}"

    [background]
    type = "shader"
    path = "${config.xdg.configHome}/driftwm/plasma.glsl"
    cache_shader = true

    [keybindings]
    "mod+d" = "exec tofi-drun --drun-launch=true"
    "mod+return" = "exec kitty"
    "mod+e" = "exec thunar"
    "mod+escape" = "exec power-menu"
    "mod+q" = "close-window"
    "mod+shift+f" = "toggle-fullscreen"
    "mod+m" = "fit-window-snapped"
    "mod+shift+m" = "fit-window"
    "mod+c" = "center-window"
    "mod+x" = "focus-center"
    "mod+t" = "toggle-pin-to-screen"
    "mod+up" = "center-nearest up"
    "mod+down" = "center-nearest down"
    "mod+left" = "center-nearest left"
    "mod+right" = "center-nearest right"
    "mod+shift+up" = "nudge-window up"
    "mod+shift+down" = "nudge-window down"
    "mod+shift+left" = "nudge-window left"
    "mod+shift+right" = "nudge-window right"
    "mod+ctrl+up" = "pan-viewport up"
    "mod+ctrl+down" = "pan-viewport down"
    "mod+ctrl+left" = "pan-viewport left"
    "mod+ctrl+right" = "pan-viewport right"
    "alt+tab" = "none"
    "alt+shift+tab" = "none"
    "mod+equal" = "zoom-in"
    "mod+minus" = "zoom-out"
    "mod+0" = "zoom-reset"
    "mod+w" = "zoom-to-fit"
    "mod+1" = "go-to 0 1500"
    "mod+2" = "go-to 0 1500"
    "mod+3" = "go-to 0 1500"
    "mod+4" = "go-to 0 1500"
    "mod+ctrl+shift+q" = "quit"
    "XF86AudioRaiseVolume" = "spawn swayosd-client --output-volume raise"
    "XF86AudioLowerVolume" = "spawn swayosd-client --output-volume lower"
    "XF86AudioMute" = "spawn swayosd-client --output-volume mute-toggle"
    "XF86MonBrightnessUp" = "spawn swayosd-client --brightness raise"
    "XF86MonBrightnessDown" = "spawn swayosd-client --brightness lower"
    "Print" = "spawn screenshot full"
    "shift+Print" = "spawn screenshot region"
    "mod+Print" = "spawn screenshot window"
    "mod+n" = "spawn swaync-client -t -sw"
    "mod+shift+a" = "spawn audio-applet"
    "mod+shift+n" = "spawn wifi-applet"
    "mod+shift+b" = "spawn bluetooth-applet"

    [gestures.on-window]
    "alt+3-finger-swipe" = "resize-window-snapped"
    "alt+shift+3-finger-swipe" = "resize-window"

    [[window_rules]]
    app_id = "kitty"
    blur = true

    [[window_rules]]
    title = "Picture-in-Picture"
    pinned_to_screen = true
    decoration = "none"

    [[window_rules]]
    app_id = "driftwm-widget-*"
    widget = true
    border_color = "${style.colors.accent}"

    [[window_rules]]
    app_id = "driftwm-widget-clock"
    position = [${i col1}, ${i row1}]
    size = [${i ws.clock.w}, ${i ws.clock.h}]

    [[window_rules]]
    app_id = "driftwm-widget-weather"
    position = [${i col2}, ${i row1}]
    size = [${i ws.weather.w}, ${i ws.weather.h}]

    [[window_rules]]
    app_id = "driftwm-widget-stats"
    position = [${i col1}, ${i row2}]
    size = [${i ws.stats.w}, ${i ws.stats.h}]

    [[window_rules]]
    app_id = "driftwm-widget-calendar"
    position = [${i col2}, ${i row2}]
    size = [${i ws.calendar.w}, ${i ws.calendar.h}]

    [[window_rules]]
    app_id = "driftwm-widget-canvas"
    position = [${i col1}, ${i row3}]
    size = [${i ws.canvas.w}, ${i ws.canvas.h}]

    [[window_rules]]
    app_id = "driftwm-widget-notif"
    position = [${i col2}, ${i row3}]
    size = [${i ws.notif.w}, ${i ws.notif.h}]

    [xwayland]
    enabled = false
  '';
}
