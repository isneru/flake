{ inputs, ... }:
let
  style = import ../home/neru/style.nix;
in
{
  flake.nixosConfigurations.victus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs style; };
    modules = [
      ../hosts/victus/default.nix
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
        nixpkgs.overlays = [
          (final: prev: { driftwm = inputs.driftwm.packages.${final.stdenv.hostPlatform.system}.default; })
        ];
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "bak";
        home-manager.users.neru = {
          imports = [
            ../home/neru
            inputs.catppuccin.homeModules.catppuccin
            inputs.helium.homeModules.default
            inputs.spicetify.homeManagerModules.default
          ];
        };
        home-manager.extraSpecialArgs = {
          inherit inputs style;
        };
      }
    ];
  };
}
