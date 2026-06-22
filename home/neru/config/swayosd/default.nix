{ config, style, ... }:
{
  services.swayosd = {
    enable = true;
    topMargin = 0.95;
    stylePath = "${config.xdg.configHome}/swayosd/style.css";
  };

  xdg.configFile."swayosd/style.css".text = ''
    window#osd {
      background: ${style.colors.bg};
      border-radius: ${toString style.radius}px;
      border: 1px solid ${style.colors.border};
    }

    window#osd #container {
      margin: 16px;
    }

    window#osd image,
    window#osd label {
      color: ${style.colors.fg};
    }

    window#osd progressbar:disabled,
    window#osd image:disabled {
      opacity: 0.5;
    }

    window#osd progressbar,
    window#osd segmentedprogress {
      min-height: 6px;
      border-radius: 999px;
      background: transparent;
      border: none;
    }

    window#osd trough,
    window#osd segment {
      min-height: inherit;
      border-radius: inherit;
      border: none;
      background: ${style.colors.bgAlt};
    }

    window#osd progress,
    window#osd segment.active {
      min-height: inherit;
      border-radius: inherit;
      border: none;
      background: ${style.colors.accent};
    }

    window#osd segment {
      margin-left: 8px;
    }

    window#osd segment:first-child {
      margin-left: 0;
    }
  '';
}
