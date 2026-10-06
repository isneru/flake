{ ... }:
{
  flake.modules.nixos.calendar = {
    sops.secrets.gcal-service-account.owner = "neru";
  };

  flake.modules.homeManager.calendar =
    { pkgs, ... }:
    let
      gcal = pkgs.writeShellApplication {
        name = "gcal";
        runtimeInputs = [
          pkgs.openssl
          pkgs.python3
        ];
        text = ''exec python3 ${./gcal.py} "$@"'';
      };
      watch = pkgs.writeShellApplication {
        name = "gcal-watch";
        runtimeInputs = [
          gcal
          pkgs.inotify-tools
        ];
        text = builtins.readFile ./watch.sh;
      };
    in
    {
      home.packages = [ gcal ];

      systemd.user.services.gcal-sync = {
        Unit.Description = "Sync Google Calendar into the notch agenda";
        Service = {
          Type = "oneshot";
          ExecStart = [
            "-${gcal}/bin/gcal push"
            "${gcal}/bin/gcal sync"
          ];
        };
      };

      systemd.user.services.gcal-watch = {
        Unit.Description = "Push deadline notes to Google Calendar on save";
        Service = {
          ExecStart = "${watch}/bin/gcal-watch";
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.timers.gcal-sync = {
        Unit.Description = "Periodic Google Calendar sync";
        Timer = {
          OnStartupSec = "30s";
          OnUnitActiveSec = "5m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
