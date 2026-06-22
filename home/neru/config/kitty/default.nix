{ style, ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = style.fonts.mono;
      size = 14;
    };
    settings = {
      background_opacity = "0.95";
      hide_window_decorations = "yes";
      initial_window_width = "120c";
      initial_window_height = "30c";
    };
  };
}
