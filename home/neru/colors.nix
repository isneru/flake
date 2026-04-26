{ config, ... }:

let
  hexChars = {
    "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4;
    "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
    "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
    "A" = 10; "B" = 11; "C" = 12; "D" = 13; "E" = 14; "F" = 15;
  };
  parseHex = c: hexChars.${c};
in
{
  _module.args.colors = {
    # Backgrounds (dark to light)
    bg = "#232136";
    bgDim = "#191724";
    bgAlt = "#2a273f";
    bgOverlay = "#000A";
    border = "#393552";

    # Foregrounds (bright to dim)
    fg = "#e0def4";
    fgDim = "#908caa";
    fgMuted = "#6e6a86";

    # Semantic (UI states)
    accent = "#c4a7e7";
    error = "#eb6f92";
    warning = "#f6c177";
    success = "#9ccfd8";
    info = "#3e8fb0";

    # Palette (syntax highlighting + multi-colored UI)
    red = "#ea9a97";
    magenta = "#eb6f92";
    orange = "#f6c177";
    cyan = "#9ccfd8";
    blue = "#3e8fb0";
    purple = "#c4a7e7";

    # Helper
    hexToRgb = hex:
      let
        r = parseHex (builtins.substring 1 1 hex) * 16 + parseHex (builtins.substring 2 1 hex);
        g = parseHex (builtins.substring 3 1 hex) * 16 + parseHex (builtins.substring 4 1 hex);
        b = parseHex (builtins.substring 5 1 hex) * 16 + parseHex (builtins.substring 6 1 hex);
      in
        "rgb(${toString r}, ${toString g}, ${toString b})";
  };
}
