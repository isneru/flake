{ ... }:
{
  flake.modules.nixos.nix = {
    programs.nix-ld.enable = true;

    nixpkgs.config.allowUnfree = true;

    nix.settings.warn-dirty = false;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    nix.optimise.automatic = true;
  };
}
