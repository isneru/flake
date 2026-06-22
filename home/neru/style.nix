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
  radius = 12;

  colors = {
    bg = "#1e1e2e";
    bgDim = "#181825";
    bgAlt = "#313244";
    bgOverlay = "#000A";
    border = "#45475a";

    fg = "#cdd6f4";
    fgDim = "#bac2de";
    fgMuted = "#6c7086";

    accent = "#cba6f7";
    error = "#f38ba8";
    warning = "#f9e2af";
    success = "#a6e3a1";
    info = "#89dcfe";

    red = "#f38ba8";
    magenta = "#cba6f7";
    orange = "#fab387";
    cyan = "#89dcfe";
    blue = "#89b4fa";
    purple = "#cba6f7";

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
    mono = "CaskaydiaCove NFM";
    size = 11;
    fallbacks = [
      "IosevkaTerm Nerd Font"
      "JetBrainsMono Nerd Font"
      "GeistMono Nerd Font"
    ];
  };
}
