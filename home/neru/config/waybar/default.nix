{ colors, fonts, ... }:
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
        font-family: ${
          builtins.concatStringsSep ", " (map (f: "\"${f}\"") ([ fonts.mono ] ++ fonts.fallbacks))
        };
        font-size: 13px;
      }

      window#waybar {
        background: ${colors.bg};
        color: ${colors.fg};
        border-bottom: 1px solid ${colors.border};
      }

      #workspaces {
        border-right: 1px solid ${colors.border};
        margin-right: 8px;
      }

      #workspaces button {
        padding: 0 10px;
        color: ${colors.fgMuted};
      }
      #workspaces button.focused {
        color: ${colors.red};
        border-bottom: 2px solid ${colors.red};
      }

      #clock {
        font-weight: bold;
        color: ${colors.fg};
      }

      #pulseaudio, #network, #cpu, #memory, #battery, #tray {
        padding: 0 10px;
      }

      #pulseaudio { color: ${colors.red}; }
      #network    { color: ${colors.cyan}; }
      #cpu        { color: ${colors.purple}; }
      #memory     { color: ${colors.magenta}; }
      #battery    { color: ${colors.orange}; }

      #battery.critical {
        background-color: ${colors.error};
        color: ${colors.bg};
      }

      #tray {
        border-left: 1px solid ${colors.border};
        margin-left: 8px;
      }

      #custom-power {
        color: ${colors.red};
        margin-left: 10px;
        margin-right: 5px;
        padding: 0 5px;
      }
    '';
  };
}
