{ pkgs, utils, ... }:

{
  home.packages = with pkgs; [
    tmux
  ];

  xdg.configFile."tmux" = {
    source = utils.create_symlink "${utils.dotfiles}/tmux";
    recursive = true;
  };
}
