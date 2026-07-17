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
        # adw-gtk3 needs this (not just the dconf color-scheme hint, which only
        # GTK4/libadwaita apps read) to pick its dark rendering path at all -
        # without it, GTK3 apps like Thunar render light structural chrome no
        # matter what the @define-color overrides say. Static for now: theme-set
        # flips the dconf color-scheme hint per theme (so GTK4 apps follow), but
        # this GTK3-native key lives in a Nix-managed settings.ini, so switching
        # to a light theme like latte still won't flip GTK3 without a rebuild.
        colorScheme = "dark";
        theme = {
          name = "adw-gtk3";
          package = pkgs.adw-gtk3;
        };
        # Without an installed icon theme GTK falls back to upscaled low-res
        # rasters (blurry folders in Thunar) - only hicolor's empty skeleton
        # exists otherwise. Adwaita is SVG-complete and color-neutral enough to
        # sit under any engine theme.
        iconTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
        gtk4 = {
          theme = config.gtk.theme;
          # Home Manager owns gtk-4.0/gtk.css itself (it needs the @import below
          # to make GTK4 apps pick up adw-gtk3 at all), so the theme engine's
          # live colors are kept in a separate file and pulled in via extraCss
          # instead of both fighting over the same path.
          extraCss = ''
            @import url("file://${config.home.homeDirectory}/.local/share/theme-engine/gtk4-colors.css");
          '';
        };
        font = {
          name = style.fonts.mono;
          size = style.fonts.sizeUi;
        };
      };

      # adw-gtk3 (despite the name) uses the same modern libadwaita color
      # vocabulary as GTK4 throughout its GTK3 stylesheet, not the legacy
      # Adwaita names (theme_bg_color, theme_selected_bg_color, etc.) - those
      # are barely referenced by it at all, so overriding them was a no-op.
      # GTK apps only pick these up on next launch - no live reload exists.
      theme-engine.apps.gtk3 = {
        template = builtins.readFile ./gtk/gtk3.css.tmpl;
        target = "~/.config/gtk-3.0/gtk.css";
      };
      theme-engine.apps.gtk4 = {
        template = builtins.readFile ./gtk/gtk4.css.tmpl;
        target = "~/.local/share/theme-engine/gtk4-colors.css";
      };
    };
}
