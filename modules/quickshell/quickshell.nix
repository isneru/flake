{ inputs, ... }:
{
  flake.previews.quickshell.build =
    {
      pkgs,
      hm,
      render,
      argParser,
      fontsConf,
      mkApp,
      ...
    }:
    let
      template = pkgs.writeText "notch-theme.tmpl" hm.theme-engine.apps.notch.template;
      fonts = fontsConf [
        pkgs.jetbrains-mono
        pkgs.material-symbols
        (pkgs.google-fonts.override { fonts = [ "DMSans" ]; })
      ];
    in
    mkApp {
      name = "quickshell";
      runtimeInputs = with pkgs; [
        # keep-sorted start
        brightnessctl
        cliphist
        hyprsunset
        libqalculate
        qrencode
        wl-clipboard
        # keep-sorted end
      ];
      text = ''
        ${argParser}
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        export XDG_DATA_HOME="$tmp/share"
        ${render} "$theme" ${template} "$XDG_DATA_HOME/theme-engine/notch-colors.json"
        export FONTCONFIG_FILE=${fonts}
        export QS_NO_RELOAD_POPUP=1
        exec ${
          inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
        }/bin/quickshell --path ${./.} "''${args[@]}"
      '';
    };

  flake.modules.nixos.quickshell = {
    services.gnome.gnome-keyring.enable = true;

    security.pam.services.quickshell = {
      enableGnomeKeyring = true;
    };
  };

  flake.modules.homeManager.quickshell =
    {
      pkgs,
      utils,
      ...
    }:
    {
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "quickshell ipc call lock lock";
            before_sleep_cmd = "quickshell ipc call lock lock";
            after_sleep_cmd = "hyprctl dispatch dpms on";
            ignore_dbus_inhibit = false;
          };
          listener = [
            {
              timeout = 600;
              on-timeout = "quickshell ipc call lock lock";
            }
            {
              timeout = 900;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        };
      };

      home.packages = [
        inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.brightnessctl
        pkgs.cliphist
        pkgs.hyprsunset
        pkgs.libqalculate
        pkgs.qrencode
        pkgs.jetbrains-mono
        pkgs.material-symbols
        (pkgs.google-fonts.override { fonts = [ "DMSans" ]; })
      ];

      systemd.user.services.quickshell = {
        Unit = {
          Description = "The notch shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${
            inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
          }/bin/quickshell";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      systemd.user.services.cliphist = {
        Unit = {
          Description = "Clipboard history for the notch shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      theme-engine.apps.notch = {
        target = "~/.local/share/theme-engine/notch-colors.json";
        template = ''
          {
            "theme": "{{theme}}",
            "scheme": "{{scheme}}",
            "accent": "{{accent}}",
            "success": "{{success}}",
            "warning": "{{warning}}",
            "error": "{{error}}",
            "info": "{{info}}",
            "bg": "{{bg}}",
            "bgDim": "{{bgDim}}",
            "bgAlt": "{{bgAlt}}",
            "border": "{{border}}",
            "fg": "{{fg}}",
            "fgDim": "{{fgDim}}",
            "fgMuted": "{{fgMuted}}",
            "black": "{{black}}",
            "red": "{{red}}",
            "green": "{{green}}",
            "yellow": "{{yellow}}",
            "blue": "{{blue}}",
            "magenta": "{{magenta}}",
            "cyan": "{{cyan}}",
            "white": "{{white}}",
            "brightBlack": "{{brightBlack}}",
            "brightRed": "{{brightRed}}",
            "brightGreen": "{{brightGreen}}",
            "brightYellow": "{{brightYellow}}",
            "brightBlue": "{{brightBlue}}",
            "brightMagenta": "{{brightMagenta}}",
            "brightCyan": "{{brightCyan}}",
            "brightWhite": "{{brightWhite}}",
            "mono": "{{mono}}",
            "size": "{{size}}",
            "sizeSmall": "{{sizeSmall}}"
          }
        '';
      };

      home.sessionVariables.QS_NO_RELOAD_POPUP = "1";

      xdg.configFile."quickshell/default".source = utils.create_symlink "${utils.dotfiles}/quickshell";
    };
}
