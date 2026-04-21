{ colors, fonts, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = [ fonts.mono ] ++ fonts.fallbacks;
      font-size = 14;
      window-padding-balance = true;
      window-decoration = false;

      background = colors.bg;
      foreground = colors.fg;
      cursor-color = colors.fg;
      selection-background = colors.bgAlt;
      selection-foreground = colors.fg;

      # 16-color terminal palette (Rose Pine Moon)
      palette = [
        "0=${colors.bgAlt}"      # black
        "1=${colors.magenta}"    # red
        "2=${colors.cyan}"       # green
        "3=${colors.orange}"     # yellow
        "4=${colors.blue}"       # blue
        "5=${colors.purple}"     # magenta
        "6=${colors.cyan}"       # cyan
        "7=${colors.fg}"         # white
        "8=${colors.fgMuted}"    # bright black
        "9=${colors.error}"      # bright red
        "10=${colors.success}"   # bright green
        "11=${colors.warning}"   # bright yellow
        "12=${colors.info}"      # bright blue
        "13=${colors.accent}"    # bright magenta
        "14=${colors.success}"   # bright cyan
        "15=${colors.fg}"        # bright white
      ];
    };
  };
}
