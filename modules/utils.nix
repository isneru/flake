{ ... }:
{
  flake.modules.homeManager.utils =
    { config, ... }:
    {
      _module.args.utils = {
        dotfiles = "${config.home.homeDirectory}/flake/modules";

        create_symlink = config.lib.file.mkOutOfStoreSymlink;
      };
    };
}
