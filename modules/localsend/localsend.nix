{ ... }:
{
  flake.modules.nixos.localsend = {
    networking.firewall.allowedTCPPorts = [ 53317 ];
    networking.firewall.allowedUDPPorts = [ 53317 ];
  };

  flake.modules.homeManager.localsend =
    { pkgs, ... }:
    let
      daemon = pkgs.writeShellApplication {
        name = "notch-localsend";
        runtimeInputs = [
          # keep-sorted start
          pkgs.openssl
          pkgs.python3
          # keep-sorted end
        ];
        text = ''exec python3 ${./localsend_daemon.py} "$@"'';
      };

    in
    {
      home.packages = [ daemon ];

      systemd.user.services.notch-localsend = {
        Unit = {
          Description = "LocalSend for the notch shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${daemon}/bin/notch-localsend";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
