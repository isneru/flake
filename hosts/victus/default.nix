{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./cfg
  ];

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

  networking.hostName = "victus";
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  environment.localBinInPath = true;
  nixpkgs.config.allowUnfree = true;

  nix.settings.warn-dirty = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11";
}
