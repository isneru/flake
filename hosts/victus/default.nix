{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/home/system
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "victus";

  time.timeZone = "Europe/Lisbon";

  programs.zsh.enable = true;

  users.users.neru = {
    isNormalUser = true;
    description = "Diogo Nogueira";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.shellAliases = {
    build-sw = "sudo nixos-rebuild switch --flake ~/Developer/flake#victus";
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  # sources ~/.local/bin
  environment.localBinInPath = true;

  system.stateVersion = "25.11";
}
