{ ... }:

let
  hexChars = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };
  parseHex = c: hexChars.${c};
in
{
  _module.args.style = {
    radius = 0;

    colors = {
      # Backgrounds (dark to light)
      bg = "#1a1b26";
      bgDim = "#16161e";
      bgAlt = "#292e42";
      bgOverlay = "#000A";
      border = "#3b4261";

      # Foregrounds (bright to dim)
      fg = "#c0caf5";
      fgDim = "#a9b1d6";
      fgMuted = "#565f89";

      # Semantic (UI states)
      accent = "#7aa2f7";
      error = "#f7768e";
      warning = "#e0af68";
      success = "#98c379";
      info = "#7dcfff";

      # Palette (syntax highlighting + multi-colored UI)
      red = "#f7768e";
      magenta = "#bb9af7";
      orange = "#ff9e64";
      cyan = "#7dcfff";
      blue = "#7aa2f7";
      purple = "#bb9af7";

      # Helpers
      hexToRgb =
        hex:
        let
          r = parseHex (builtins.substring 1 1 hex) * 16 + parseHex (builtins.substring 2 1 hex);
          g = parseHex (builtins.substring 3 1 hex) * 16 + parseHex (builtins.substring 4 1 hex);
          b = parseHex (builtins.substring 5 1 hex) * 16 + parseHex (builtins.substring 6 1 hex);
        in
        "rgb(${toString r}, ${toString g}, ${toString b})";
      hexToRgbValues =
        hex:
        let
          r = parseHex (builtins.substring 1 1 hex) * 16 + parseHex (builtins.substring 2 1 hex);
          g = parseHex (builtins.substring 3 1 hex) * 16 + parseHex (builtins.substring 4 1 hex);
          b = parseHex (builtins.substring 5 1 hex) * 16 + parseHex (builtins.substring 6 1 hex);
        in
        "${toString r}, ${toString g}, ${toString b}";
    };

    fonts = {
      mono = "IosevkaTerm Nerd Font";
      fallbacks = [
        "CaskaydiaCove NFM"
        "JetBrainsMono Nerd Font"
        "GeistMono Nerd Font"
      ];
    };
  };
}
