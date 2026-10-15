{ ... }:
{
  flake.modules.nixos.phone =
    { config, pkgs, ... }:
    {
      nixpkgs.config.android_sdk.accept_license = true;

      services.openssh = {
        enable = true;
        openFirewall = false;
        startWhenNeeded = true;
        settings = {
          AllowUsers = [ "neru" ];
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      users.users.neru.openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];
      networking.firewall.interfaces."enp0s20f0u+".allowedTCPPorts = [ 22 ];

      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
      };

      networking.networkmanager.dispatcherScripts = [
        {
          source = pkgs.writeShellScript "phone-sync-up" ''
            [ "$2" = up ] || exit 0
            ${config.systemd.package}/bin/systemctl --user -M neru@ start --no-block phone-sync.service || true
          '';
        }
      ];
    };

  flake.modules.homeManager.phone =
    { lib, pkgs, ... }:
    let
      sdk =
        (pkgs.androidenv.composeAndroidPackages { platformVersions = [ "36" ]; }).androidsdk
        + "/libexec/android-sdk";
      palettes = pkgs.writeText "themes.json" (
        builtins.toJSON (
          lib.sort (a: b: a.name < b.name) (
            map (file: (lib.importTOML file).colors // { name = lib.removeSuffix ".toml" (baseNameOf file); }) (
              lib.filesystem.listFilesRecursive ../theme-engine/themes
            )
          )
        )
      );
      launcher =
        pkgs.runCommand "bare-launcher.apk"
          {
            __structuredAttrs = true;
            nativeBuildInputs = [
              pkgs.kotlin
              pkgs.zip
            ];
            src = ./launcher;
            fonts = [
              pkgs.nerd-fonts.departure-mono
              pkgs.nerd-fonts.geist-mono
              pkgs.nerd-fonts.go-mono
            ];
            families = lib.unique (
              map (
                file:
                let
                  fonts = (lib.importTOML file).fonts;
                in
                fonts.chrome or fonts.mono
              ) (lib.filesystem.listFilesRecursive ../theme-engine/themes)
            );
          }
          ''
            tools=$(echo ${sdk}/build-tools/*)
            platform=${sdk}/platforms/android-36
            mkdir -p assets/fonts dex
            cp ${./termux/bin/pc} assets/pc
            cp ${./termux/bin/serve} assets/serve
            cp ${palettes} assets/themes.json
            for family in "''${families[@]}"; do
              name=''${family// /}
              cp "$(find "''${fonts[@]}" -name "$name-Regular.*" -print -quit)" "assets/fonts/$name.ttf"
            done
            kotlinc -no-reflect -include-runtime -cp $platform/android.jar -d classes.jar $src/*.kt
            $tools/d8 --lib $platform/android.jar --min-api 34 --output dex classes.jar
            $tools/aapt2 link -o base.apk -I $platform/android.jar --manifest $src/AndroidManifest.xml \
              -A assets --min-sdk-version 34 --target-sdk-version 36 --version-code 1 --version-name 1
            touch -d 1980-01-01 dex/classes.dex
            zip -X -j base.apk dex/classes.dex
            $tools/zipalign -f 4 base.apk $out
          '';
      stickersDex = pkgs.runCommand "stickers-dex" { nativeBuildInputs = [ pkgs.kotlin ]; } ''
        tools=$(echo ${sdk}/build-tools/*)
        platform=${sdk}/platforms/android-36
        kotlinc -no-reflect -include-runtime -cp $platform/android.jar -d classes.jar ${./stickers}/*.kt
        mkdir $out
        $tools/d8 --lib $platform/android.jar --min-api 34 --output $out classes.jar
      '';
      stickers = pkgs.writeShellApplication {
        name = "phone-stickers";
        runtimeInputs = [
          # keep-sorted start
          pkgs.android-tools
          pkgs.apksigner
          pkgs.coreutils
          pkgs.curl
          pkgs.ffmpeg-headless
          pkgs.jdk
          pkgs.openssh
          pkgs.python3
          pkgs.tailscale
          pkgs.zip
          # keep-sorted end
        ];
        text = ''
          tools=$(echo ${sdk}/build-tools/*)
          platform=${sdk}/platforms/android-36
          manifest=${./stickers/AndroidManifest.xml}
          dex=${stickersDex}/classes.dex
          known_hosts=${./known_hosts}
        ''
        + builtins.readFile ./phone-ssh.sh
        + builtins.readFile ./phone-stickers.sh;
      };
      tailscaled =
        pkgs.runCommand "tailscaled-android-${pkgs.tailscale.version}"
          { nativeBuildInputs = [ pkgs.tailscale.go ]; }
          ''
            cp -r ${pkgs.tailscale.src} src
            chmod -R u+w src
            cd src
            cp -r ${pkgs.tailscale.goModules} vendor
            cp ${./android_ifaces.go} cmd/tailscaled/android_ifaces.go
            export HOME=$TMPDIR GOCACHE=$TMPDIR/cache GOFLAGS=-mod=vendor GOOS=linux GOARCH=arm64 CGO_ENABLED=0
            go build -trimpath -tags ts_include_cli -o $out \
              -ldflags "-s -w -X tailscale.com/version.longStamp=${pkgs.tailscale.version} -X tailscale.com/version.shortStamp=${pkgs.tailscale.version}" \
              ./cmd/tailscaled
          '';
      install = pkgs.writeShellApplication {
        name = "phone-install";
        runtimeInputs = [
          # keep-sorted start
          pkgs.android-tools
          pkgs.apksigner
          pkgs.coreutils
          pkgs.jdk
          pkgs.openssh
          pkgs.python3
          pkgs.tailscale
          # keep-sorted end
        ];
        text = ''
          apk=${launcher}
          known_hosts=${./known_hosts}
        ''
        + builtins.readFile ./phone-ssh.sh
        + builtins.readFile ./phone-install.sh;
      };
      walls = pkgs.writeShellApplication {
        name = "phone-walls";
        runtimeInputs = [
          (pkgs.python3.withPackages (ps: [ ps.pillow ]))
          pkgs.systemd
        ];
        text = ''exec python3 ${./phone-walls.py} "$@"'';
      };
      sync = pkgs.writeShellApplication {
        name = "phone-sync";
        runtimeInputs = [
          # keep-sorted start
          (pkgs.python3.withPackages (ps: [ ps.pillow ]))
          pkgs.coreutils
          pkgs.fontconfig
          pkgs.gawk
          pkgs.iproute2
          pkgs.openssh
          pkgs.tailscale
          # keep-sorted end
        ];
        text = ''
          known_hosts=${./known_hosts}
        ''
        + builtins.readFile ./phone-ssh.sh
        + builtins.readFile ./phone-sync.sh;
      };
    in
    {
      home.packages = [
        install
        pkgs.tmux
        stickers
        walls
      ];

      xdg.dataFile."phone/tailscaled".source = tailscaled;

      theme-engine.apps.phone = {
        target = "~/.local/share/theme-engine/phone.json";
        template = builtins.readFile ./phone.json.tmpl;
      };

      theme-engine.apps.phone-termux = {
        target = "~/.local/share/theme-engine/phone-termux.properties";
        template = builtins.readFile ./colors.properties.tmpl;
      };

      systemd.user.services.phone-sync = {
        Unit.Description = "Push the wallpaper and theme to the phone";
        Service = {
          Type = "oneshot";
          ExecStart = "${sync}/bin/phone-sync";
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.paths.phone-sync = {
        Unit.Description = "Watch the wallpaper and theme for the phone";
        Path.PathChanged = [
          "%h/.local/state/quickshell/wallpaper"
          "%h/.local/share/theme-engine/phone.json"
          "%h/.local/share/theme-engine/phone-termux.properties"
        ];
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.timers.phone-sync = {
        Unit.Description = "Retry pushes the phone missed";
        Timer = {
          OnBootSec = "15min";
          OnUnitActiveSec = "15min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
