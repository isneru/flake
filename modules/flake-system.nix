{ config, inputs, ... }:
let
  style = import ../lib/style.nix;
in
{
  flake.nixosConfigurations.victus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs style; };
    modules = [
      ../hosts/victus/default.nix
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
          imports = builtins.attrValues config.flake.modules.homeManager ++ [
            inputs.catppuccin.homeModules.catppuccin
            inputs.helium.homeModules.default
            inputs.noctalia.homeModules.default
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
