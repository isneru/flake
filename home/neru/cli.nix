{ colors, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
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
      font = "CaskaydiaCove NFM 11";
      selection-notification = true;
      guioptions = "none";
    };
  };
}
