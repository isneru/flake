{ colors, fonts, ... }:
{
  programs.tofi = {
    enable = true;
    settings = {
      width = "100%";
      height = "100%";
      border-width = 0;
      outline-width = 0;

      padding-left = "35%";
      padding-top = "35%";
      result-spacing = 25;
      num-results = 5;

      font = fonts.mono;
      font-size = 18;

      background-color = colors.bgOverlay;
      text-color = colors.fg;

      selection-color = colors.red;
      selection-background = colors.bg;
      selection-background-padding = "5, 10";
      selection-background-corner-radius = 0;

      prompt-color = colors.accent;
    };
  };
}
