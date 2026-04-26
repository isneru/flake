{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./config
  ];

  users.users.neru = {
    isNormalUser = true;
    description = "Diogo Nogueira";
    extraGroups = [
      # keep-sorted start
      "docker"
      "networkmanager"
      "wheel"
      "wireshark"
      # keep-sorted end
    ];
    shell = pkgs.zsh;
  };

  networking.hostName = "victus";
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  environment.localBinInPath = true;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-38.8.4"
  ];

  nix.settings.warn-dirty = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11";
}
