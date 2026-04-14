{
  utils,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.niri.homeModules.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  xdg.configFile."niri" = {
    source = utils.create_symlink "${utils.dotfiles}/niri/";
    recursive = true;
  };
}
