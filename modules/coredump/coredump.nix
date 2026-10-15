{ ... }:
{
  flake.modules.nixos.coredump = {
    systemd.coredump.settings.Coredump = {
      ProcessSizeMax = "1G";
      ExternalSizeMax = "1G";
    };
  };
}
