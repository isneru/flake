{ utils, ... }:
{
  programs.ghostty.enable = true;

  xdg.configFile."ghostty" = {
    source = utils.create_symlink "${utils.dotfiles}/ghostty/";
    recursive = true;
  };
}
