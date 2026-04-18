{ ... }:
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
          "tray"
        ];

        "niri/workspaces" = {
          format = "{value}";
        };

        "clock" = {
          format = "󰥔  {:%H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "pulseaudio" = {
          format = "{icon}  {volume}%";
          format-muted = "󰝟 ";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          on-click = "pavucontrol";
        };

        "network" = {
          format-wifi = "󰤨  {essid}";
          format-ethernet = "󱘖  {ifname}";
          format-disconnected = "󰤮 ";
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
          format = "{icon}  {capacity}%";
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
        font-family: "CaskaydiaCove NFM";
        font-size: 13px;
      }

      window#waybar {
        background: #232136;
        color: #e0def4;
        border-bottom: 1px solid #393552;
      }

      #workspaces button {
        padding: 0 10px;
        color: #6e6a86;
      }
      #workspaces button.focused {
        color: #ea9a97;
        border-bottom: 2px solid #ea9a97;
      }

      #clock {
        font-weight: bold;
        color: #e0def4;
      }

      #pulseaudio, #network, #cpu, #memory, #battery, #tray {
        padding: 0 12px;
        margin: 4px 0;
      }

      #pulseaudio { color: #ea9a97; }
      #network    { color: #9ccfd8; }
      #cpu        { color: #c4a7e7; }
      #memory     { color: #eb6f92; }
      #battery    { color: #f6c177; }

      #battery.critical {
        background-color: #eb6f92;
        color: #232136;
      }

      #tray {
        border-left: 1px solid #393552;
        margin-left: 8px;
      }
    '';
  };
}
