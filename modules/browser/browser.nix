{ ... }:
let
  mkUserscript =
    pkgs: name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (./userscripts + "/${name}.sh");
    };
in
{
  flake.previews.qutebrowser = {
    aspects = [ "browser" ];
    build =
      {
        pkgs,
        hm,
        render,
        argParser,
        mkApp,
        fontsConf,
        ...
      }:
      let
        template = pkgs.writeText "qutebrowser-theme.tmpl" hm.theme-engine.apps.qutebrowser.template;
      in
      mkApp {
        name = "qutebrowser";
        text = ''
          ${argParser}
          root=$(mktemp -d)
          trap 'rm -rf "$root"' EXIT

          mkdir -p "$root/config/qutebrowser"
          install -m 644 ${./config.py} "$root/config/qutebrowser/config.py"
          ${render} "$theme" ${template} "$root/config/qutebrowser/theme.py"

          export HOME="$root"
          export XDG_CONFIG_HOME="$root/config"
          export XDG_DATA_HOME="$root/data"
          export XDG_CACHE_HOME="$root/cache"
          export FONTCONFIG_FILE=${fontsConf [ pkgs.nerd-fonts.caskaydia-cove ]}
          exec ${pkgs.qutebrowser}/bin/qutebrowser "''${args[@]}"
        '';
      };
  };

  flake.modules.nixos.browser = {
    nixpkgs.overlays = [
      (final: prev: {
        qutebrowser =
          let
            stock-resources = "${prev.qt6Packages.qtwebengine}/resources";
            resources = final.runCommand "qtwebengine-resources-cell-cursor" { } ''
              ${final.python3.interpreter} ${./cell-cursor.py} ${stock-resources} $out
            '';
          in
          (prev.qutebrowser.override { enableWideVine = true; }).overrideAttrs (old: {
            preFixup =
              let
                patched = builtins.replaceStrings [ stock-resources ] [ "${resources}" ] old.preFixup;
              in
              assert patched != old.preFixup;
              patched;
          });
      })
    ];
  };

  flake.modules.homeManager.browser =
    {
      lib,
      pkgs,
      style,
      utils,
      ...
    }:
    let
      qute-reload = pkgs.writeShellApplication {
        name = "qute-reload";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./qute-reload.sh;
      };

      qute-ytdl = mkUserscript pkgs "qute-ytdl" (
        with pkgs;
        [
          libnotify
          util-linux
          yt-dlp
        ]
      );

      qute-mpv = mkUserscript pkgs "qute-mpv" (
        with pkgs;
        [
          systemd
          util-linux
        ]
      );

      qute-clone = mkUserscript pkgs "qute-clone" (
        with pkgs;
        [
          git
          libnotify
          util-linux
        ]
      );

      qute-open = mkUserscript pkgs "qute-open" [ ];

      userscripts = {
        inherit
          qute-clone
          qute-mpv
          qute-open
          qute-ytdl
          ;
      };
    in
    {
      home.packages = [
        pkgs.qutebrowser
        qute-reload
      ]
      ++ builtins.attrValues userscripts;

      xdg.configFile."qutebrowser/config.py".source =
        utils.create_symlink "${utils.dotfiles}/browser/config.py";
      xdg.configFile."qutebrowser/downloads.py".source =
        utils.create_symlink "${utils.dotfiles}/browser/downloads.py";
      xdg.configFile."qutebrowser/statusbar.py".source =
        utils.create_symlink "${utils.dotfiles}/browser/statusbar.py";
      xdg.configFile."qutebrowser/reload.py".source =
        utils.create_symlink "${utils.dotfiles}/browser/reload.py";

      xdg.dataFile =
        lib.mapAttrs' (name: drv: {
          name = "qutebrowser/userscripts/${name}";
          value.source = "${drv}/bin/${name}";
        }) userscripts
        // {
          "qutebrowser/greasemonkey/yt-ads.js".source =
            utils.create_symlink "${utils.dotfiles}/browser/greasemonkey/yt-ads.js";

          "qutebrowser/greasemonkey/yt-tweaks.js".source =
            utils.create_symlink "${utils.dotfiles}/browser/greasemonkey/yt-tweaks.js";

          "qutebrowser/greasemonkey/gh-wide.js".source =
            utils.create_symlink "${utils.dotfiles}/browser/greasemonkey/gh-wide.js";

          "qutebrowser/greasemonkey/x-minimal.js".source =
            utils.create_symlink "${utils.dotfiles}/browser/greasemonkey/x-minimal.js";
        };

      theme-engine.apps.qutebrowser-start = {
        target = "~/.local/share/qutebrowser/start.html";
        template = builtins.readFile ./start.html.tmpl;
      };

      theme-engine.apps.qutebrowser-sites = {
        target = "~/.local/share/qutebrowser/greasemonkey/site-theme.js";
        template = builtins.readFile ./sites.js.tmpl;
      };

      theme-engine.apps.qutebrowser = {
        target = "~/.config/qutebrowser/theme.py";
        template = builtins.replaceStrings [ "@sizeUi@" ] [ (toString style.fonts.sizeUi) ] (
          builtins.readFile ./theme.py.tmpl
        );
        reload = [ "qute-reload" ];
      };

    };
}
