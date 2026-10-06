{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./hp-wmi.nix
  ];

  users.users.neru = {
    isNormalUser = true;
    description = "Diogo Nogueira";
    extraGroups = [
      # keep-sorted start
      "libvirtd"
      "networkmanager"
      "wheel"
      "wireshark"
      # keep-sorted end
    ];
    shell = pkgs.zsh;
  };

  networking.hostName = "victus";

  time.timeZone = "Europe/Lisbon";
  services.xserver.xkb.layout = "pt";

  boot.initrd.kernelModules = [ "i915" ];
  boot.blacklistedKernelModules = [ "nouveau" ];

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  system.stateVersion = "25.11";
}
