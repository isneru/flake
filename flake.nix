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
};

outputs = { self, nixpkgs, lanzaboote, home-manager, ... }@inputs: {
	nixosConfigurations.victus = nixpkgs.lib.nixosSystem {
			system = "x86_64-linux";
			specialArgs = { inherit inputs; };
			modules = [
				./hosts/victus/default.nix
				lanzaboote.nixosModules.lanzaboote
				home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.neru = import ./home/neru/default.nix;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
			];
		};
};

}
