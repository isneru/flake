{ pkgs, ... }:
{
  services.displayManager.ly.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  programs.niri.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
    };
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
