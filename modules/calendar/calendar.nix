{ ... }:
{
  flake.modules.nixos.calendar = {
    sops.secrets.gcal-service-account.owner = "neru";
  };

  flake.modules.homeManager.calendar =
    { lib, pkgs, ... }:
    let
      gcal = pkgs.writeShellApplication {
        name = "gcal";
        runtimeInputs = [
          pkgs.openssl
          pkgs.python3
        ];
        text = ''exec python3 ${../../scripts/calendar/gcal.py} "$@"'';
      };
      watch = pkgs.writeShellApplication {
        name = "gcal-watch";
        runtimeInputs = [
          gcal
          pkgs.inotify-tools
        ];
        text = builtins.readFile ../../scripts/calendar/watch.sh;
      };
    in
    {
      home.packages = [ gcal ];

      xdg.configFile = {
        "bare/pick/deadlines.sh".source = pkgs.writeTextFile {
          name = "deadlines.sh";
          text = builtins.readFile ../../scripts/calendar/deadlines.sh;
          checkPhase = "${lib.getExe pkgs.shellcheck} -s bash -e SC2154 $target";
        };
        "hypr/extra.lua".text =
          ''bind({ MOD, "SHIFT" }, "D", hl.dsp.exec_cmd("bare-pick deadlines"), { group = "SHELL", desc = "Course deadlines" })'';
      };

      systemd.user.services.gcal-sync = {
        Unit.Description = "Sync Google Calendar into the bare shell agenda";
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
