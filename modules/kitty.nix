{ ... }:
{
  flake.modules.homeManager.kitty =
    { style, ... }:
    {
      programs.kitty = {
        enable = true;
        font.name = style.fonts.mono;
        settings = {
          background_opacity = "0.95";
          hide_window_decorations = "yes";
          initial_window_width = "120c";
          initial_window_height = "30c";
          allow_remote_control = "socket-only";
          # A per-process socket, not a single shared address - every kitty
          # invocation is its own process, so a shared address would only ever
          # be claimed by the first one.
          listen_on = "unix:/tmp/kitty-{kitty_pid}";
        };
        extraConfig = "include theme.conf";
      };

      # Reload is handled specially by name inside theme-set (reload_kitty):
      # every kitty process has its own remote-control socket, so a single
      # reload command can't reach them all.
      theme-engine.apps.kitty.target = "~/.config/kitty/theme.conf";
      theme-engine.apps.kitty.template = ''
        font_family {{mono}}
        font_size {{size}}

        background {{bg}}
        foreground {{fg}}
        cursor {{accent}}
        selection_background {{bgAlt}}
        selection_foreground {{fg}}
        url_color {{accent}}
        active_border_color {{accent}}
        inactive_border_color {{border}}

        color0  {{bgDim}}
        color8  {{fgMuted}}
        color1  {{red}}
        color9  {{red}}
        color2  {{success}}
        color10 {{success}}
        color3  {{warning}}
        color11 {{warning}}
        color4  {{blue}}
        color12 {{blue}}
        color5  {{accent}}
        color13 {{accent}}
        color6  {{cyan}}
        color14 {{cyan}}
        color7  {{fg}}
        color15 {{fg}}
      '';
    };
}
