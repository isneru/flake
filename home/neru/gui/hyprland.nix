{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    systemd.enable = true;

    settings = {
      "$terminal" = "ghostty";
      "$menu" = "vicinae toggle";
      "$file-manager" = "thunar";
      "$reload" = "hyprctl reload; pkill waybar; waybar &";
      "$audio-mixer" = "ghostty --class=audio-mixer -e pulsemixer";

      monitor = [
        ",preferred,auto,1"
      ];

      env = [
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "GTK_THEME,rose-pine-moon"
      ];

      exec-once = [
        "waybar"
        "swaybg -m fill -i /home/neru/Pictures/wallpapers/chainsaw-man-the-1920x1080-22996.jpg"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "vesktop"
      ];

      general = {
        gaps_in = 4;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(c4a7e7ff) rgba(ea9a97ff) 45deg";
        "col.inactive_border" = "rgba(2a273fcc)";
        layout = "dwindle";
      };

      input = {
        kb_layout = "pt";
        numlock_by_default = true;
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 4;
          passes = 2;
        };
      };

      animations = {
        enabled = "yes";
        bezier = [
          "myBezier, 0.05, 0.9, 0.1, 1.05"
        ];
        animation = [
          "windows, 1, 3, myBezier"
          "windowsOut, 1, 3, default, popin 80%"
          "border, 1, 5, default"
          "workspaces, 1, 3, default"
        ];
      };

      bind = [
        "SUPER, Return, exec, $terminal"
        "SUPER, D, exec, $menu"
        "SUPER, Q, killactive"
        "SUPER, E, exec, $file-manager"
        "SUPER, V, exec, $audio-mixer"
        "SUPER SHIFT, R, exec, $reload"
        "SUPER, SPACE, togglefloating"

        "SHIFT, Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        ",Print, exec, grim - | wl-copy"

        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"

        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
      ];

      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
