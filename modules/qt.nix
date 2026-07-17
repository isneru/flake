{ ... }:
{
  flake.modules.homeManager.qt =
    { config, ... }:
    let
      # QPalette color-role order qt5ct/qt6ct expect, as #AARRGGBB:
      # WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText,
      # Base, Window, Shadow, Highlight, HighlightedText, Link, LinkVisited,
      # AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText
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
      # Same roles with the text-ish entries muted.
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
          icon_theme = "Adwaita";
        };
        qt6ctSettings.Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/theme-engine/qt-colors.conf";
          icon_theme = "Adwaita";
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
