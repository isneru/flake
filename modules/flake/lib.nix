{
  config,
  inputs,
  lib,
  ...
}:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Helpers shared between the flake's own assembly modules.";
  };

  config.flake.lib = {
    style = import ../../lib/style.nix;

    mkPreviewHome =
      pkgs: extraModules:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
          inherit (config.flake.lib) style;
        };
        modules = [
          config.flake.modules.homeManager.utils
          config.flake.modules.homeManager.theme-engine
          {
            home.username = "preview";
            home.homeDirectory = "/tmp/theme-preview";
            home.stateVersion = "25.11";
          }
        ]
        ++ extraModules;
      };
  };
}
