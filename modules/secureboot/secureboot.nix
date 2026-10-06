{ ... }:
{
  flake.modules.nixos.secureboot =
    { lib, ... }:
    {
      boot.lanzaboote.enable = true;
      boot.lanzaboote.pkiBundle = "/var/lib/sbctl";

      boot.loader.systemd-boot.enable = lib.mkForce false;
    };
}
