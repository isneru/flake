{ ... }:
{
  flake.modules.homeManager.qt =
    { config, ... }:
    let
      active = [
        "fg"
        "bgAlt"
        "border"
        "border"
        "bgDim"
        "border"
        "fg"
        "fg"
        "fg"
        "bg"
        "bg"
        "bgDim"
        "accent"
        "bg"
        "accent"
        "accent"
        "bgAlt"
        "fg"
        "bgDim"
        "fg"
        "fgMuted"
      ];
      disabled = [
        "fgMuted"
        "bgAlt"
        "border"
        "border"
        "bgDim"
        "border"
        "fgMuted"
        "fgMuted"
        "fgMuted"
        "bg"
        "bg"
        "bgDim"
        "accent"
        "fgMuted"
        "accent"
        "accent"
        "bgAlt"
        "fgMuted"
        "bgDim"
        "fgMuted"
        "fgMuted"
      ];
      palette = roles: builtins.concatStringsSep ", " (map (role: "#{{${role}Argb}}") roles);
    in
    {
      qt = {
        enable = true;
        platformTheme.name = "qtct";
        style.name = "Fusion";
        qt5ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/theme-engine/qt-colors.conf";
          icon_theme = config.gtk.iconTheme.name;
          standard_dialogs = "xdgdesktopportal";
        };
        qt6ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/theme-engine/qt-colors.conf";
          icon_theme = config.gtk.iconTheme.name;
          standard_dialogs = "xdgdesktopportal";
        };
      };

      theme-engine.apps.qt-colors = {
        target = "~/.config/theme-engine/qt-colors.conf";
        template = ''
          [ColorScheme]
          active_colors=${palette active}
          disabled_colors=${palette disabled}
          inactive_colors=${palette active}
        '';
      };
    };
}
