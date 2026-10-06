{ ... }:
{
  flake.previews.kitty.build =
    {
      pkgs,
      lib,
      hm,
      render,
      argParser,
      fontsConf,
      mkApp,
      ...
    }:
    let
      template = pkgs.writeText "kitty-theme.tmpl" hm.theme-engine.apps.kitty.template;
      kittyConf = pkgs.writeText "kitty.conf" (
        lib.removeSuffix "include theme.conf\n" hm.xdg.configFile."kitty/kitty.conf".text
      );
    in
    mkApp {
      name = "kitty";
      text = ''
        ${argParser}
        themeConf=$(mktemp)
        trap 'rm -f "$themeConf"' EXIT
        ${render} "$theme" ${template} "$themeConf"
        export FONTCONFIG_FILE=${fontsConf [ pkgs.nerd-fonts.caskaydia-cove ]}
        exec ${pkgs.kitty}/bin/kitty --config ${kittyConf} --config "$themeConf" "''${args[@]}"
      '';
    };

  flake.modules.homeManager.kitty = {
    programs.kitty = {
      enable = true;
      settings = {
        confirm_os_window_close = 0;
        background_opacity = "1.0";
        hide_window_decorations = "yes";
        initial_window_width = "120c";
        initial_window_height = "30c";
        allow_remote_control = "socket-only";
        listen_on = "unix:/tmp/kitty-{kitty_pid}";
      };
      extraConfig = ''
        globinclude mode.conf
        include theme.conf'';
    };

    theme-engine.apps.kitty.target = "~/.config/kitty/theme.conf";
    theme-engine.apps.kitty.template = ''
      font_family {{mono}}
      font_size {{sizePt}}

      background {{bg}}
      foreground {{fg}}
      cursor {{accent}}
      cursor_text_color {{bg}}
      selection_background {{bgAlt}}
      selection_foreground {{fg}}
      url_color {{accent}}
      active_border_color {{accent}}
      inactive_border_color {{border}}

      color0  {{black}}
      color1  {{red}}
      color2  {{green}}
      color3  {{yellow}}
      color4  {{blue}}
      color5  {{magenta}}
      color6  {{cyan}}
      color7  {{white}}
      color8  {{brightBlack}}
      color9  {{brightRed}}
      color10 {{brightGreen}}
      color11 {{brightYellow}}
      color12 {{brightBlue}}
      color13 {{brightMagenta}}
      color14 {{brightCyan}}
      color15 {{brightWhite}}

      color234 {{bgDim}}
      color237 {{bgAlt}}
      color240 {{border}}
      color245 {{fgMuted}}
      color250 {{fgDim}}
      color253 {{fg}}
    '';
  };
}
