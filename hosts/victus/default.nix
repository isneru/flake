{ pkgs, ... }:
{
  # Host identity and hardware, not a feature - deliberately outside modules/
  # entirely (same reasoning as lib/style.nix) and wired directly into
  # flake-system.nix's module list instead of the flake.modules.nixos aspect
  # pool. Pooling it via `builtins.attrValues config.flake.modules.nixos`
  # would mean any future second host silently inherits this host's identity
  # and hardware quirks too, since that helper has no concept of "which host
  # this aspect belongs to".
  imports = [ ./hardware.nix ];

  users.users.neru = {
    isNormalUser = true;
    description = "Diogo Nogueira";
    extraGroups = [
      # keep-sorted start
      "docker"
      "libvirtd"
      "networkmanager"
      "wheel"
      "wireshark"
      # keep-sorted end
    ];
    shell = pkgs.zsh;
  };

  networking.hostName = "victus";
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
    plugins = [ pkgs.networkmanager-openvpn ];
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  boot.initrd.kernelModules = [ "i915" ];
  # The nvidia dGPU is unused (panel is wired to the intel iGPU) but its
  # /dev/dri node makes chromium/electron apps block ~1.6s at startup waking
  # it from runtime suspend. No driver -> no node -> no wake. HDMI port (wired
  # to the dGPU) is dead while this is in place.
  boot.blacklistedKernelModules = [ "nouveau" ];
  # With no driver bound, udev leaves the dGPU's power/control at "on" and it
  # idles at D0 forever; "auto" lets the PCI core runtime-suspend it to D3cold.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"
  '';

  environment.localBinInPath = true;
  nixpkgs.config.allowUnfree = true;

  nix.settings.warn-dirty = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Same retention `just clean` uses, on a timer instead of by hand.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;

  system.stateVersion = "25.11";
}
