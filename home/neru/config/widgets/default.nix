{
  pkgs,
  style,
  ...
}:
let
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      rich
      art
    ]
  );
  c = style.colors;

  widgets = [
    {
      name = "clock";
      module = "clock_widget";
      cols = 38;
      rows = 7;
    }
    {
      name = "stats";
      module = "stats_widget";
      cols = 38;
      rows = 12;
    }
    {
      name = "canvas";
      module = "canvas_widget";
      cols = 38;
      rows = 5;
    }
    {
      name = "calendar";
      module = "calendar_widget";
      cols = 24;
      rows = 12;
    }
    {
      name = "weather";
      module = "weather_widget";
      cols = 24;
      rows = 7;
    }
    {
      name = "notif";
      module = "notif_widget";
      cols = 24;
      rows = 5;
    }
  ];

  widgetPyEntries = builtins.concatStringsSep "\n    " (
    map (w: ''("${w.name}", "${w.module}", ${toString w.cols}, ${toString w.rows}),'') widgets
  );

  widgetNames = builtins.concatStringsSep " " (map (w: w.name) widgets);

  widgetLaunchCalls = builtins.concatStringsSep "\n" (
    map (w: "launch ${w.name} ${toString w.cols} ${toString w.rows}") widgets
  );
in
{
  home.file.".local/share/driftwm-widgets/colors.py".text = ''
    BG = "${c.bg}"
    BG_DIM = "${c.bgDim}"
    BG_ALT = "${c.bgAlt}"
    BORDER = "${c.border}"
    FG = "${c.fg}"
    FG_DIM = "${c.fgDim}"
    FG_MUTED = "${c.fgMuted}"
    ACCENT = "${c.accent}"
    ERROR = "${c.error}"
    WARNING = "${c.warning}"
    SUCCESS = "${c.success}"
    INFO = "${c.info}"
    RED = "${c.red}"
    ORANGE = "${c.orange}"
    CYAN = "${c.cyan}"
    BLUE = "${c.blue}"
  '';

  home.file.".local/share/driftwm-widgets/widgets.py".text = ''
    WIDGETS: list[tuple[str, str, int, int]] = [
        ${widgetPyEntries}
    ]
  '';

  home.packages = [
    (pkgs.writeShellApplication {
      name = "widget-launcher";
      runtimeInputs = [
        pythonEnv
        pkgs.socat
        pkgs.kitty
      ];
      text = ''
        export PYTHONPATH="$HOME/.local/share/driftwm-widgets''${PYTHONPATH:+:$PYTHONPATH}"

        DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/driftwm-widgets"
        RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

        exec 9>"''${RUNTIME}/drift-widgets.lock"
        flock -n 9 || exit 0

        launch() {
          local name="$1" cols="$2" lines="$3"
          (
            while true; do
              kitty --class "driftwm-widget-''${name}" \
                -o initial_window_width="''${cols}c" \
                -o initial_window_height="''${lines}c" \
                -o remember_window_size=no \
                -o window_padding_width=2 \
                -o hide_window_decorations=yes \
                -o confirm_os_window_close=0 \
                -- socat -,icanon=0,echo=0 "UNIX-CONNECT:''${RUNTIME}/drift-''${name}.sock"
              sleep 1
            done
          ) &
        }

        (
          while true; do
            python3 "$DIR/daemon.py"
            sleep 1
          done
        ) &

        for name in ${widgetNames}; do
          for _ in $(seq 1 50); do
            [ -S "''${RUNTIME}/drift-''${name}.sock" ] && break
            sleep 0.05
          done
        done

        ${widgetLaunchCalls}

        wait
      '';
    })
  ];

  xdg.configFile."driftwm-widgets".source = ./.;
}
