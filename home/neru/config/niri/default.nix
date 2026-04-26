{ config, colors, ... }:
{
  xdg.configFile."niri/config.kdl".text = ''
    workspace "main"
    workspace "other"

    hotkey-overlay {
        skip-at-startup
    }

    environment {
        XDG_CURRENT_DESKTOP "niri"
        XDG_SESSION_DESKTOP "niri"
        XDG_SESSION_TYPE "wayland"
    }

    input {
        keyboard {
            xkb {
                layout "pt"
            }
            numlock
        }
        touchpad {
            tap
            natural-scroll
        }
        focus-follows-mouse max-scroll-amount="90%"
        workspace-auto-back-and-forth
    }

    layout {
        background-color "transparent"
        gaps 8
        default-column-width { proportion 1.0; }
        preset-column-widths {
            proportion 0.5
            proportion 0.75
            proportion 1.0
        }
        focus-ring {
            width 1
            active-color "${colors.accent}"
        }
    }

    overview {
        workspace-shadow {
            off
        }
    }

    spawn-at-startup "vesktop" "--use-tray-icon" "--ozone-platform-hint=auto" "--enable-features=WaylandWindowDecorations"
    spawn-at-startup "waybar"
    spawn-at-startup "swaybg" "-i" "${config.home.homeDirectory}/Pictures/wallpapers/wallhaven_l3xk6q.jpg" "-m" "fill"

    prefer-no-csd

    screenshot-path "${config.home.homeDirectory}/Pictures/Screenshots/screenshot_%Y-%m-%d %H-%M-%S.png"

    window-rule {
        match app-id="vesktop"
        open-on-workspace "other"
    }

    window-rule {
        match title="audiomantui"
        open-floating true
        default-column-width { proportion 0.6; }
        default-window-height { proportion 0.6; }
    }

    window-rule {
        match title="power-menu-tui"
        open-floating true
        default-column-width { proportion 0.6; }
        default-window-height { proportion 0.6; }
    }

    window-rule {
        geometry-corner-radius 0
        clip-to-geometry true
        draw-border-with-background false
    }

    window-rule {
        match app-id="com.mitchellh.ghostty"
        background-effect {
            blur true
        }
    }

    layer-rule {
        match namespace="^wallpaper$"
        place-within-backdrop true
    }

    binds {
        Mod+D { spawn "tofi-drun" "--drun-launch=true"; }
        Mod+Return { spawn "ghostty"; }
        Mod+E { spawn "thunar"; }
        Mod+L { spawn "swaylock"; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "+10%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "-10%"; }

        Mod+O repeat=false { toggle-overview; }
        Mod+Q repeat=false { close-window; }

        Mod+Left { focus-column-left; }
        Mod+Down { focus-window-or-workspace-down; }
        Mod+Up { focus-window-or-workspace-up; }
        Mod+Right { focus-column-right; }

        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Down { move-window-down; }
        Mod+Shift+Up { move-window-up; }
        Mod+Shift+Right { move-column-right; }

        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

        Mod+Shift+WheelScrollDown { focus-column-right; }
        Mod+Shift+WheelScrollUp { focus-column-left; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }

        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }

        Mod+Comma { consume-or-expel-window-left; }
        Mod+Period { consume-or-expel-window-right; }
        Mod+W { toggle-column-tabbed-display; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { expand-column-to-available-width; }

        Mod+Shift+R { switch-preset-window-height; }
        Mod+Ctrl+R { reset-window-height; }

        Mod+C { center-column; }
        Mod+Ctrl+C { center-visible-columns; }

        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }

        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        Mod+V { toggle-window-floating; }

        Print { screenshot; }
        Alt+Print { screenshot-screen; }
        Ctrl+Print { screenshot-window; }

        Mod+Alt+Delete allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        Mod+Shift+P { power-off-monitors; }
    }
  '';
}
