{ style, ... }:

{
  services.mako = {
    enable = true;
    settings = {
      font = "${style.fonts.mono} 11";
      width = 340;
      height = 120;
      margin = "16";
      padding = "12,16";
      border-size = 1;
      border-radius = style.radius;
      icons = true;
      max-icon-size = 32;
      sort = "-time";
      layer = "overlay";
      anchor = "top-center";

      background-color = style.colors.bgAlt;
      text-color = style.colors.fg;
      border-color = style.colors.border;
      progress-color = "over ${style.colors.accent}";
    };
    extraConfig = ''
      [urgency=low]
      border-color=${style.colors.border}
      default-timeout=3000

      [urgency=normal]
      border-color=${style.colors.border}
      default-timeout=5000

      [urgency=high]
      border-color=${style.colors.error}
      text-color=${style.colors.error}
      default-timeout=0
    '';
  };
}
