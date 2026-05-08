{ style, ... }:

{
  home.file."browser-ntp/colors.css".text = ''
    body.colors {
      background: ${style.colors.bg} !important;
      color: ${style.colors.fg} !important;
    }

    body.colors .terminal-header {
      color: ${style.colors.accent} !important;
      border-bottom: 1px solid ${style.colors.border} !important;
    }
  '';
}
