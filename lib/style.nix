let
  # Single source of truth for the build-time fallback palette: the theme
  # engine's default theme. Apps that structurally can't be runtime-themed
  # (spicetify, GTK/Qt font size, ...) read from here, and deriving it from
  # mocha.toml means the seed can't drift from what theme-set applies on a
  # fresh system.
  seed = builtins.fromTOML (builtins.readFile ../modules/theme-engine/themes/mocha.toml);
in
{
  radius = seed.misc.radius;

  colors = seed.colors // {
    # Alias kept for build-time-only consumers (spicetify).
    purple = seed.colors.accent;
  };

  fonts = seed.fonts // {
    # UI chrome size (GTK widgets, zathura) - deliberately smaller than the
    # theme's `size`, which is terminal-oriented; 15pt mono in Thunar's
    # menus and sidebar looks oversized.
    sizeUi = 11;
  };
}
