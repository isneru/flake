{ pkgs, ... }:
{
  services.udisks2.enable = true;

  services.displayManager.sessionPackages = [ pkgs.driftwm ];
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
    config.common.default = [ "gtk" ];
    config.common."org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
    config.common."org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
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
