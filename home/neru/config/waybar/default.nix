{ style, ... }:
let
  c = style.colors;
  f = style.fonts;
in
{
  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 32;

        modules-left = [
          "niri/workspaces"
          "niri/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "mpris"
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "battery"
          "custom/power"
          "tray"
        ];

        "custom/power" = {
          format = "󰐥";
          on-click = "ghostty --title='power-menu-tui' -e power-tui";
          tooltip = false;
        };

        "niri/workspaces" = {
          format = "{value}";
        };

        "niri/window" = {
          format = "{app_id} >> {title}";
          rewrite = {
            "vesktop >> (.*)" = "discord";
            "helium >> (.*)" = "helium";
            "com.mitchellh.ghostty >> (.*)" = "terminal";
            "Spotify >> (.*)" = "spotify";
            "obsidian >> (.*)" = "obsidian";
            "z?.* >> (.*)" = "$1";
          };
        };

        "clock" = {
          format = "{:%H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "mpris" = {
          format = "{status_icon}  {title}";
          format-paused = "{status_icon}  {title}";
          format-stopped = "";
          status-icons = {
            playing = "󰏤";
            paused = "󰐊";
            stopped = "";
          };
          max-length = 32;
          tooltip = false;
          on-click = "playerctl play-pause";
          on-scroll-up = "playerctl next";
          on-scroll-down = "playerctl previous";
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 ";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          on-click = "ghostty --title=audiomantui -e pulsemixer";
        };

        "network" = {
          format-wifi = "󰤨 {essid}";
          format-ethernet = "󱘖 {ifname}";
          format-disconnected = "󰤮 ";
          on-click = "networkmanager_dmenu";
        };

        "cpu" = {
          format = "󰻠 {usage}%";
          interval = 5;
        };

        "memory" = {
          format = "󰍛 {percentage}%";
          interval = 5;
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-icons = [
            "󰂎"
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
        };

        "tray" = {
          icon-size = 16;
          spacing = 10;
        };
      }
    ];

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: ${builtins.concatStringsSep ", " (map (x: "\"${x}\"") ([ f.mono ] ++ f.fallbacks))};
        font-size: 13px;
      }

      window#waybar {
        background: ${c.bg};
        color: ${c.fg};
        border-bottom: 1px solid ${c.border};
      }

      #workspaces {
        border-right: 1px solid ${c.border};
        margin-right: 8px;
      }

      #workspaces button {
        padding: 0 10px;
        color: ${c.fgMuted};
      }
      #workspaces button.focused {
        color: ${c.red};
        border-bottom: 2px solid ${c.red};
      }

      #clock {
        font-weight: bold;
        color: ${c.fg};
      }

      #mpris {
        padding: 0 10px;
        color: ${c.purple};
      }
      #mpris.paused  { color: ${c.fgMuted}; }
      #mpris.stopped { padding: 0; }

      #pulseaudio, #network, #cpu, #memory, #battery, #tray {
        padding: 0 10px;
      }

      #pulseaudio { color: ${c.red}; }
      #network    { color: ${c.cyan}; }
      #cpu        { color: ${c.purple}; }
      #memory     { color: ${c.magenta}; }
      #battery    { color: ${c.orange}; }

      #battery.critical {
        background-color: ${c.error};
        color: ${c.bg};
      }

      #tray {
        border-left: 1px solid ${c.border};
        margin-left: 8px;
      }

      #custom-power {
        color: ${c.red};
        margin-left: 10px;
        margin-right: 5px;
        padding: 0 5px;
      }
    '';
  };
}
