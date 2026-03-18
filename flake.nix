{
  description = "neru's dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ambxst.url = "github:Axenide/ambxst";
  };

  outputs =
    {
      self,
      nixpkgs,
      lanzaboote,
      home-manager,
      ambxst,
      ...
    }@inputs:
    let
      useAmbxst = true;
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      nixosConfigurations.victus = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs useAmbxst; };
        modules = [
          ./hosts/victus/default.nix
          lanzaboote.nixosModules.lanzaboote
          ambxst.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.neru = import ./home/neru/default.nix;
            home-manager.extraSpecialArgs = { inherit inputs useAmbxst; };
          }
        ];
      };
    };
}
