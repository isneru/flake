{ style, ... }:
let
  c = style.colors;
  h = color: builtins.substring 1 6 color;
in
{
  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
        disable_loading_bar = true
        hide_cursor = true
        no_fade_in = true
        time_format = %H:%M
    }

    background {
        color = rgb(${h c.bg})
    }

    label {
        text = $TIME
        color = rgba(${h c.fg}ff)
        font_size = 64
        font_family = ${style.fonts.mono}
        position = 0, 80
        halign = center
        valign = center
    }

    label {
        text = cmd[update:60000] date +"%A, %-d %B"
        color = rgba(${h c.fgDim}ff)
        font_size = 18
        font_family = ${style.fonts.mono}
        position = 0, 20
        halign = center
        valign = center
    }

    input-field {
        size = 200, 50
        rounding = 0
        outline_thickness = 2
        outer_color = rgb(${h c.border})
        inner_color = rgba(00000000)
        font_color = rgb(${h c.fg})
        check_color = rgb(${h c.accent})
        fail_color = rgb(${h c.error})
        capslock_color = rgb(${h c.warning})
        placeholder_text = password
        dots_center = true
        hide_input = false
        position = 0, -80
        halign = center
        valign = center
    }
  '';
}
