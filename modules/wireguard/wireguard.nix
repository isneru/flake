{ ... }:
{
  flake.modules.nixos.wireguard = {
    networking.wg-quick.interfaces.lab = {
      address = [ "10.10.10.2/24" ];
      privateKeyFile = "/etc/wireguard/lab.key";
      autostart = false;
      peers = [
        {
          publicKey = "esT2RQxa57uh/BTtkLFA4sVwpkK3Q1cM6oIZmcBGTR8=";
          endpoint = "192.168.122.10:51820";
          allowedIPs = [
            "10.10.10.0/24"
            "192.168.1.0/24"
          ];
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
