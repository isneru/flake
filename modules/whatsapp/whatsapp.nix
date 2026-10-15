{ inputs, ... }:
{
  flake.modules.homeManager.whatsapp =
    { pkgs, utils, ... }:
    let
      quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

      daemon = pkgs.buildGoModule {
        pname = "whatsapp";
        version = "0";
        src = ./daemon;
        vendorHash = "sha256-0gJTVPDZWX6ANurQHwG3D+7L8mzx9osd8F1lt5plMoQ=";
      };

      cli = pkgs.writeShellApplication {
        name = "whatsapp";
        runtimeInputs = [
          # keep-sorted start
          pkgs.ffmpeg-headless
          pkgs.libnotify
          # keep-sorted end
        ];
        text = ''exec ${daemon}/bin/whatsapp "$@"'';
      };

      paste = pkgs.writeShellApplication {
        name = "whatsapp-paste";
        runtimeInputs = [
          # keep-sorted start
          pkgs.curl
          pkgs.wl-clipboard
          # keep-sorted end
        ];
        text = builtins.readFile ./whatsapp-paste.sh;
      };

      app = pkgs.writeShellApplication {
        name = "whatsapp-app";
        runtimeInputs = [
          # keep-sorted start
          paste
          pkgs.hyprland
          quickshell
          # keep-sorted end
        ];
        runtimeEnv.QT_PLUGIN_PATH = "${pkgs.qt6.qtimageformats}/lib/qt-6/plugins";
        text = builtins.readFile ./whatsapp-app.sh;
      };
    in
    {
      home.packages = [
        app
        cli
      ];

      xdg.configFile = {
        "hypr/extra.lua".text = ''table.insert(blur, "whatsapp")'';
        "quickshell/whatsapp/shell.qml".source =
          utils.create_symlink "${utils.dotfiles}/whatsapp/qml/shell.qml";
        "quickshell/whatsapp/store".source = utils.create_symlink "${utils.dotfiles}/whatsapp/qml/store";
        "quickshell/whatsapp/ui".source = utils.create_symlink "${utils.dotfiles}/whatsapp/qml/ui";
        "quickshell/whatsapp/components".source =
          utils.create_symlink "${utils.dotfiles}/quickshell/components";
        "quickshell/whatsapp/singletons".source =
          utils.create_symlink "${utils.dotfiles}/quickshell/singletons";
      };

      xdg.desktopEntries.whatsapp = {
        name = "WhatsApp";
        genericName = "Messages";
        exec = "${app}/bin/whatsapp-app";
        icon = "whatsapp";
        terminal = false;
        categories = [
          "Network"
          "InstantMessaging"
        ];
      };

      systemd.user.services.whatsapp = {
        Unit = {
          Description = "WhatsApp linked device";
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${cli}/bin/whatsapp daemon";
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
