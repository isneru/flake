{ pkgs, inputs, ... }:
{
  services.displayManager.ly.enable = true;
  services.udisks2.enable = true;

  programs.niri = {
    enable = true;
    useNautilus = false;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "gnome"
      "gtk"
    ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.rtkit.enable = true;

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
}
