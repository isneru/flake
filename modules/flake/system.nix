{ config, inputs, ... }:
{
  flake.nixosConfigurations.victus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (config.flake.lib) style;
    };
    modules = [
      ../../hosts/victus/default.nix
    ]
    ++ builtins.attrValues config.flake.modules.nixos
    ++ [
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "bak";
        home-manager.users.neru = {
          home.stateVersion = "25.11";
          imports = builtins.attrValues config.flake.modules.homeManager;
        };
        home-manager.extraSpecialArgs = {
          inherit inputs;
          inherit (config.flake.lib) style;
        };
      }
    ];
  };
}
