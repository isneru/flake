{ colors, fonts, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      # keep-sorted start
      pdf = "zathura";
      v = "nvim";
      # keep-sorted end
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        # keep-sorted start
        "docker"
        "git"
        "sudo"
        # keep-sorted end
      ];
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      recolor-darkcolor = colors.fg;
      recolor-lightcolor = colors.bg;
      default-bg = colors.bg;
      default-fg = colors.fg;
      statusbar-bg = colors.bgAlt;
      statusbar-fg = colors.fg;
      highlight-color = colors.red;
      highlight-active-color = colors.cyan;
      font = "${fonts.mono} 11";
      selection-notification = true;
      guioptions = "none";
    };
  };
}
