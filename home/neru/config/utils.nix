{ config, ... }:

{
  _module.args.utils = {
    dotfiles = "${config.home.homeDirectory}/Developer/flake/home/neru/config";

    create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  };
}
