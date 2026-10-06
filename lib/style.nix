let
  seed = fromTOML (builtins.readFile ../modules/theme-engine/themes/mocha.toml);
in
{
  colors = seed.colors;

  fonts = seed.fonts;
}
