{
  config,
  pkgs,
  inputs,
  ...
}:

let
  noctalia =
    cmd:
    [
      "noctalia-shell"
      "ipc"
      "call"
    ]
    ++ (pkgs.lib.splitString " " cmd);
in
{
  imports = [
    inputs.niri.homeModules.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri;
    settings = {
      workspaces = {
        "main" = { };
        "other" = { };
      };

      hotkey-overlay = {
        skip-at-startup = true;
      };

      environment = {
        GTK_THEME = "rose-pine-moon";
        XDG_CURRENT_DESKTOP = "Niri";
        XDG_SESSION_DESKTOP = "Niri";
        XDG_SESSION_TYPE = "wayland";
      };

      input = {
        keyboard = {
          xkb.layout = "pt";
          numlock = true;
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "90%";
        };
      };

      layout = {
        background-color = "transparent";
        gaps = 8;
        default-column-width = {
          proportion = 1. / 1.;
        };
        preset-column-widths = [
          { proportion = 1. / 2.; }
          { proportion = 3. / 4.; }
          { proportion = 1. / 1.; }
        ];
        focus-ring = {
          enable = true;
          width = 2;
          active.color = "#7fc8ff";
          inactive.color = "#505050";
        };
      };

      overview = {
        workspace-shadow = {
          enable = false;
        };
      };

      spawn-at-startup = [
        { argv = [ "noctalia-shell" ]; }
        { argv = [ "vesktop" ]; }
      ];

      prefer-no-csd = true;

      screenshot-path = "~/Pictures/Screenshots/screenshot_%Y-%m-%d %H-%M-%S.png";

      window-rules = [
        {
          matches = [
            { app-id = "vesktop"; }
          ];
          open-on-workspace = "other";
        }
        {
          geometry-corner-radius = {
            top-left = 8.0;
            top-right = 8.0;
            bottom-left = 8.0;
            bottom-right = 8.0;
          };
          clip-to-geometry = true;
          draw-border-with-background = false;
        }
      ];

      layer-rules = [
        {
          matches = [
            { namespace = "^noctalia-wallpaper-.*$"; }
          ];
          place-within-backdrop = true;
        }
      ];

      binds = with config.lib.niri.actions; {
        "Mod+Space".action.spawn = noctalia "launcher toggle";
        # "Mod+D".action.spawn = ["vicinae" "toggle"];
        "Mod+S".action.spawn = noctalia "controlCenter toggle";
        "Mod+Return".action.spawn = "ghostty";

        "Mod+Escape".action.spawn = noctalia "sessionMenu toggle";
        "Mod+L".action.spawn = noctalia "lockScreen lock";

        "XF86AudioRaiseVolume" = {
          action.spawn = noctalia "volume increase";
          allow-when-locked = true;
        };
        "XF86AudioLowerVolume" = {
          action.spawn = noctalia "volume decrease";
          allow-when-locked = true;
        };
        "XF86AudioMute" = {
          action.spawn = noctalia "volume muteOutput";
          allow-when-locked = true;
        };
        "XF86AudioMicMute" = {
          action.spawn = noctalia "volume muteInput";
          allow-when-locked = true;
        };
        "XF86MonBrightnessUp" = {
          action.spawn = noctalia "brightness increase";
          allow-when-locked = true;
        };
        "XF86MonBrightnessDown" = {
          action.spawn = noctalia "brightness decrease";
          allow-when-locked = true;
        };
        "XF86AudioPlay" = {
          action.spawn = noctalia "media playPause";
          allow-when-locked = true;
        };
        "XF86AudioStop" = {
          action.spawn = noctalia "media stop";
          allow-when-locked = true;
        };
        "XF86AudioPrev" = {
          action.spawn = noctalia "media previous";
          allow-when-locked = true;
        };
        "XF86AudioNext" = {
          action.spawn = noctalia "media next";
          allow-when-locked = true;
        };

        "Mod+O" = {
          action = toggle-overview;
          repeat = false;
        };
        "Mod+Q" = {
          action = close-window;
          repeat = false;
        };

        "Mod+Left".action = focus-column-left;
        "Mod+Down".action = focus-window-or-workspace-down;
        "Mod+Up".action = focus-window-or-workspace-up;
        "Mod+Right".action = focus-column-right;

        "Mod+Shift+Left".action = move-column-left;
        "Mod+Shift+Down".action = move-window-down;
        "Mod+Shift+Up".action = move-window-up;
        "Mod+Shift+Right".action = move-column-right;

        "Mod+WheelScrollDown" = {
          action = focus-workspace-down;
          cooldown-ms = 150;
        };
        "Mod+WheelScrollUp" = {
          action = focus-workspace-up;
          cooldown-ms = 150;
        };

        "Mod+Shift+WheelScrollDown".action = focus-column-right;
        "Mod+Shift+WheelScrollUp".action = focus-column-left;

        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;
        "Mod+Shift+1".action.move-column-to-workspace = 1;
        "Mod+Shift+2".action.move-column-to-workspace = 2;
        "Mod+Shift+3".action.move-column-to-workspace = 3;
        "Mod+Shift+4".action.move-column-to-workspace = 4;
        "Mod+Shift+5".action.move-column-to-workspace = 5;
        "Mod+Shift+6".action.move-column-to-workspace = 6;
        "Mod+Shift+7".action.move-column-to-workspace = 7;
        "Mod+Shift+8".action.move-column-to-workspace = 8;
        "Mod+Shift+9".action.move-column-to-workspace = 9;

        "Mod+Comma".action = consume-or-expel-window-left;
        "Mod+Period".action = consume-or-expel-window-right;
        "Mod+W".action = toggle-column-tabbed-display;

        "Mod+R".action = switch-preset-column-width;
        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = expand-column-to-available-width;

        "Mod+Shift+R".action = switch-preset-window-height;
        "Mod+Ctrl+R".action = reset-window-height;

        "Mod+C".action = center-column;
        "Mod+Ctrl+C".action = center-visible-columns;

        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Equal".action.set-column-width = "+10%";

        "Mod+Shift+Minus".action.set-window-height = "-10%";
        "Mod+Shift+Equal".action.set-window-height = "+10%";

        "Mod+V".action = toggle-window-floating;

        #"Print".action = screenshot;
        #"Ctrl+Print".action = screenshot-screen;
        #"Alt+Print".action = screenshot-window;

        "Mod+Alt+Delete" = {
          action = toggle-keyboard-shortcuts-inhibit;
          allow-inhibiting = false;
        };

        "Mod+Shift+P".action = power-off-monitors;
      };
    };
  };
}
