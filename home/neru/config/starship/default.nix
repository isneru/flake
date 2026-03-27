{ utils, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."starship.toml" = {
    source = utils.create_symlink "${utils.dotfiles}/starship/starship.toml";
  };
}
