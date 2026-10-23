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
        name = "bare-localsend";
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
      systemd.user.services.bare-localsend = {
        Unit = {
          Description = "LocalSend for the bare shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${daemon}/bin/bare-localsend";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
