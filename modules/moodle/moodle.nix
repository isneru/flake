{ inputs, ... }:
{
  flake.modules.homeManager.moodle =
    { pkgs, utils, ... }:
    let
      quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

      cli = pkgs.writeShellApplication {
        name = "moodle";
        runtimeInputs = [
          # keep-sorted start
          pkgs.libnotify
          pkgs.python3
          pkgs.qutebrowser
          # keep-sorted end
        ];
        text = ''exec python3 ${./moodle.py} "$@"'';
      };

      app = pkgs.writeShellApplication {
        name = "moodle-app";
        runtimeInputs = [
          # keep-sorted start
          cli
          pkgs.hyprland
          quickshell
          # keep-sorted end
        ];
        text = builtins.readFile ./moodle-app.sh;
      };
    in
    {
      home.packages = [
        app
        cli
      ];

      xdg.configFile = {
        "quickshell/moodle/shell.qml".source =
          utils.create_symlink "${utils.dotfiles}/moodle/qml/shell.qml";
        "quickshell/moodle/store".source = utils.create_symlink "${utils.dotfiles}/moodle/qml/store";
        "quickshell/moodle/ui".source = utils.create_symlink "${utils.dotfiles}/moodle/qml/ui";
        "quickshell/moodle/components".source =
          utils.create_symlink "${utils.dotfiles}/quickshell/components";
        "quickshell/moodle/singletons".source =
          utils.create_symlink "${utils.dotfiles}/quickshell/singletons";
      };

      xdg.desktopEntries.moodle = {
        name = "Moodle";
        genericName = "Course materials";
        exec = "${app}/bin/moodle-app";
        icon = "applications-education";
        terminal = false;
        categories = [
          "Education"
          "Office"
        ];
      };

      systemd.user.services.moodle-sync = {
        Unit.Description = "Mirror Moodle courses, materials and deadlines";
        Service = {
          Type = "oneshot";
          ExecStart = "${cli}/bin/moodle sync";
        };
      };

      systemd.user.timers.moodle-sync = {
        Unit.Description = "Periodic Moodle sync";
        Timer = {
          OnStartupSec = "2m";
          OnUnitActiveSec = "20m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
