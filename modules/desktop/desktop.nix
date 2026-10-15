{ ... }:
{
  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      programs.dconf.enable = true;

      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          xdg-desktop-portal-termfilechooser
        ];
        config.common.default = [ "gtk" ];
        config.common."org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        config.common."org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        config.common."org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      };

      services.power-profiles-daemon.enable = true;
      services.upower.enable = true;
      services.thermald.enable = true;
    };
}
