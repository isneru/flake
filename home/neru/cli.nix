{ style, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      # keep-sorted start
      pdf = "zathura";
      # keep-sorted end
    };
    initContent = ''
      VI_MODE_SET_CURSOR=true

      v() {
        if [[ $1 == *:* ]]; then
          nvim "+''${1##*:}" "''${1%%:*}"
        else
          nvim "$@"
        fi
      }
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        # keep-sorted start
        "docker"
        "git"
        "vi-mode"
        # keep-sorted end
      ];
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd" "cd" ];
  };

  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      recolor-darkcolor = style.colors.fg;
      recolor-lightcolor = style.colors.bg;
      default-bg = style.colors.bg;
      default-fg = style.colors.fg;
      statusbar-bg = style.colors.bgAlt;
      statusbar-fg = style.colors.fg;
      highlight-color = style.colors.red;
      highlight-active-color = style.colors.cyan;
      font = "${style.fonts.mono} 11";
      selection-notification = true;
      guioptions = "none";
    };
  };
}
