{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    systemd.enable = true;

    settings = {
      "$terminal" = "ghostty";
      "$file-manager" = "thunar";

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
        "ambxst"
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
        "SUPER, E, exec, $file-manager"
        "SUPER, Q, killactive"
        "SUPER, SPACE, togglefloating"

        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER, 6, workspace, 6"
        "SUPER, 7, workspace, 7"
        "SUPER, 8, workspace, 8"
        "SUPER, 9, workspace, 9"
        "SUPER, 0, workspace, 10"

        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
        "SUPER SHIFT, 6, movetoworkspace, 6"
        "SUPER SHIFT, 7, movetoworkspace, 7"
        "SUPER SHIFT, 8, movetoworkspace, 8"
        "SUPER SHIFT, 9, movetoworkspace, 9"
        "SUPER SHIFT, 0, movetoworkspace, 10"

        "SUPER, SUPER_L, exec, ambxst run launcher"
        "SUPER, D, exec, ambxst run dashboard"
        "SUPER, A, exec, ambxst run assistant"
        "SUPER, V, exec, ambxst run clipboard"
        "SUPER, PERIOD, exec, ambxst run emoji"
        "SUPER, N, exec, ambxst run notes"
        "SUPER, T, exec, ambxst run tmux"
        "SUPER, COMMA, exec, ambxst run wallpapers"
        "SUPER, TAB, exec, ambxst run overview"
        "SUPER, ESCAPE, exec, ambxst run powermenu"
        "SUPER SHIFT, C, exec, ambxst run config"
        "SUPER, L, exec, loginctl lock-session"
        "SUPER, S, exec, ambxst run tools"
        "SUPER SHIFT, S, exec, ambxst run screenshot"
        "SUPER SHIFT, R, exec, ambxst run screenrecord"
        "SUPER SHIFT, A, exec, ambxst run lens"
        "SUPER SHIFT, B, exec, ambxst reload"
      ];

      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
