{ style, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = [ style.fonts.mono ] ++ style.fonts.fallbacks;
      font-size = 14;
      window-padding-balance = true;
      window-decoration = false;

      background = style.colors.bg;
      background-opacity = 0.95;
      foreground = style.colors.fg;
      cursor-color = style.colors.fg;
      selection-background = style.colors.bgAlt;
      selection-foreground = style.colors.fg;

      # 16-color terminal palette (Rose Pine Moon)
      palette = [
        "0=${style.colors.bgAlt}" # black
        "1=${style.colors.magenta}" # red
        "2=${style.colors.blue}" # green
        "3=${style.colors.orange}" # yellow
        "4=${style.colors.blue}" # blue
        "5=${style.colors.purple}" # magenta
        "6=${style.colors.cyan}" # cyan
        "7=${style.colors.fg}" # white
        "8=${style.colors.fgMuted}" # bright black
        "9=${style.colors.error}" # bright red
        "10=${style.colors.success}" # bright green
        "11=${style.colors.warning}" # bright yellow
        "12=${style.colors.info}" # bright blue
        "13=${style.colors.accent}" # bright magenta
        "14=${style.colors.success}" # bright cyan
        "15=${style.colors.fg}" # bright white
      ];
    };
  };
}
