{ inputs, ... }:
{
  flake.nixosConfigurations.victus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ../hosts/victus/default.nix
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "bak";
        home-manager.users.neru = import ../home/neru;
        home-manager.extraSpecialArgs = {
          inherit inputs;
        };
      }
    ];
  };
}
