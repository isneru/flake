{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/home/system
    ../../modules/home/nixos/apps
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
      "wireshark"
    ];
    shell = pkgs.zsh;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  # sources ~/.local/bin
  environment.localBinInPath = true;

  system.stateVersion = "25.11";
}
