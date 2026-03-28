{
  inputs,
  pkgs,
  utils,
  ...
}:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
  };

  xdg.configFile."noctalia" = {
    source = utils.create_symlink "${utils.dotfiles}/noctalia/";
    recursive = true;
  };
}
