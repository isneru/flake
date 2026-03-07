{ pkgs, ... }:

{
  services.xserver.enable = true;
  services.displayManager.ly.enable = true;
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.gvfs.enable = true;
  services.udisks2.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
