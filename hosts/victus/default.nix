{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../modules/system
    ../../modules/apps
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "victus";
  networking.networkmanager.enable = true;

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

  nix.settings.warn-dirty = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # sources ~/.local/bin
  environment.localBinInPath = true;

  system.stateVersion = "25.11";
}
