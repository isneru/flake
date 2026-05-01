{ style, ... }:
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

      font = style.fonts.mono;
      font-size = 18;

      background-color = style.colors.bgOverlay;
      text-color = style.colors.fg;

      selection-color = style.colors.red;
      selection-background = style.colors.bg;
      selection-background-padding = "5, 10";
      selection-background-corner-radius = style.radius;

      prompt-color = style.colors.accent;
    };
  };
}
