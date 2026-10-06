{ ... }:
{
  flake.modules.nixos.networking =
    { pkgs, ... }:
    {
      networking.networkmanager = {
        enable = true;
        wifi.powersave = false;
        plugins = [ pkgs.networkmanager-openvpn ];
      };

      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
    };
}
