{ utils, ... }:
{
  programs.vesktop.enable = true;

  xdg.configFile."vesktop" = {
    source = utils.create_symlink "${utils.dotfiles}/vesktop/";
    recursive = true;
  };
}
