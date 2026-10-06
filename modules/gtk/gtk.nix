{ ... }:
{
  flake.modules.homeManager.gtk =
    {
      pkgs,
      config,
      style,
      ...
    }:
    {
      gtk = {
        enable = true;
        theme = {
          name = "adw-gtk3";
          package = pkgs.adw-gtk3;
        };
        gtk4 = {
          theme = config.gtk.theme;
          extraCss = ''
            @import url("file://${config.home.homeDirectory}/.local/share/theme-engine/gtk4-colors.css");
          '';
        };
        font = {
          name = style.fonts.mono;
          size = style.fonts.sizeUi;
        };
      };

      home.packages = [
        (pkgs.writeShellApplication {
          name = "gtk-theme-flip";
          runtimeInputs = [ pkgs.dconf ];
          runtimeEnv = {
            NAME = "adw-gtk3-accent";
            ADW = pkgs.linkFarm "adw-gtk3-schemes" {
              dark = "${config.gtk.theme.package}/share/themes/adw-gtk3-dark";
              light = "${config.gtk.theme.package}/share/themes/adw-gtk3";
            };
            SCHEME = "${config.xdg.dataHome}/theme-engine/gtk-scheme";
            COLORS = "${config.xdg.dataHome}/theme-engine/gtk3-colors.css";
            THEMES = "${config.xdg.dataHome}/themes";
          };
          text = builtins.readFile ./theme-flip.sh;
        })
      ];

      xdg.configFile."gtk-3.0/gtk.css" = {
        text = "";
        force = true;
      };

      theme-engine.apps.gtk3 = {
        template = builtins.readFile ./gtk3.css.tmpl;
        target = "~/.local/share/theme-engine/gtk3-colors.css";
        reload = [ "gtk-theme-flip" ];
      };
      theme-engine.apps.gtk-scheme = {
        template = "{{scheme}}";
        target = "~/.local/share/theme-engine/gtk-scheme";
      };
      theme-engine.apps.gtk4 = {
        template = builtins.readFile ./gtk4.css.tmpl;
        target = "~/.local/share/theme-engine/gtk4-colors.css";
      };
    };
}
