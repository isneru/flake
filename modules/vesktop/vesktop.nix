{ ... }:
{
  flake.modules.nixos.vesktop = {
    services.pipewire.wireplumber.extraConfig."51-vesktop-voice"."stream.rules" = [
      {
        matches = [
          {
            "application.name" = "Chromium";
            "target.object" = "~.+";
          }
        ];
        actions.update-props."application.id" = "vesktop.voice";
      }
    ];
  };

  flake.modules.homeManager.vesktop =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:
    let
      customVencord = pkgs.vencord.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.fetchpatch {
            url = "https://github.com/Vendicated/Vencord/commit/90aea0ddbbfbee16ce052b2c7ab610ffe957b4ca.patch";
            hash = "sha256-e61pY4st0ZsjlffOIp7ujHcx1hhWLEpRDfd33E80iGs=";
          })
        ];

        preBuild = (old.preBuild or "") + ''
          mkdir -p src/userplugins
          for dir in ${inputs.vesktop-plugins}/*/; do
            cp -r "$dir" src/userplugins/
          done
        '';

        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/main/ipcMain.ts \
            --replace-fail \
              'sender.postMessage(IpcEvents.QUICK_CSS_UPDATE, await readCss());' \
              'try { sender.postMessage(IpcEvents.QUICK_CSS_UPDATE, await readCss()); } catch { }' \
            --replace-fail \
              'sender.postMessage(IpcEvents.THEME_UPDATE, void 0);' \
              'try { sender.postMessage(IpcEvents.THEME_UPDATE, void 0); } catch { }'
        '';
      });

      customVesktop = pkgs.vesktop.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/main/vencordFilesDir.ts \
            --replace-fail 'State.store.vencordDir || ' ""
        '';

        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

        postFixup = (old.postFixup or "") + ''
          mv $out/bin/vesktop $out/bin/.vesktop-unlogged
          makeWrapper ${lib.getExe' pkgs.systemd "systemd-cat"} $out/bin/vesktop \
            --add-flags "--identifier=vesktop" \
            --add-flags "--stderr-priority=warning" \
            --add-flags "$out/bin/.vesktop-unlogged" \
            --add-flags "--enable-logging=stderr" \
            --add-flags "--log-level=2" \
            --set-default ELECTRON_ENABLE_STACK_DUMPING 1 \
            --set-default __EGL_VENDOR_LIBRARY_FILENAMES \
              /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
        '';
      });

    in
    {
      services.arrpc.enable = true;

      xdg.configFile = {
        "vesktop/theme-modes/bare.css".source = ./bare.css;
        "vesktop/theme-modes/notch.css".source = ./notch.css;
      };

      home.activation.vesktopMode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        mode=$(cat ${lib.escapeShellArg "${config.xdg.stateHome}/quickshell/mode"} 2>/dev/null || echo notch)
        [ "$mode" = bare ] || mode=notch
        $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg "${config.xdg.configHome}/vesktop/themes"}
        $DRY_RUN_CMD install -m 644 \
          ${lib.escapeShellArg "${config.xdg.configHome}/vesktop/theme-modes"}/"$mode".css \
          ${lib.escapeShellArg "${config.xdg.configHome}/vesktop/themes/mode.css"}
      '';

      theme-engine.apps.vesktop = {
        template = builtins.readFile ./theme.css.tmpl;
        target = "~/.config/vesktop/themes/theme.css";
      };

      programs.vesktop = {
        enable = true;
        package = customVesktop.override { vencord = customVencord; };
        vencord.useSystem = true;
        settings = {
          discordBranch = "stable";
          firstLaunch = false;
          arRPC = "off";
          minimizeToTray = "on";
          closeToTray = "on";
          hardwareAcceleration = true;
          customTitleBar = false;
          appBadge = true;
          transparentWindow = false;
        };
        vencord.settings = {
          notifyAboutUpdates = false;
          autoUpdate = true;
          autoUpdateNotification = false;
          useQuickCss = true;
          themeLinks = [ ];
          enabledThemes = [
            "theme.css"
            "mode.css"
          ];
          enableReactDevtools = false;
          frameless = true;
          transparent = false;
          winCtrlQ = false;
          macosTranslucency = false;
          disableMinSize = false;
          winNativeTitleBar = false;
          plugins = {
            # keep-sorted start
            "WebRichPresence (arRPC)".enabled = true;
            BypassDnD.enabled = true;
            ClearURLs.enabled = true;
            CrashHandler.enabled = true;
            FixCodeblockGap.enabled = true;
            MarkdownPreview.enabled = true;
            MessageLogger.enabled = true;
            NotchVoice.enabled = true;
            ShikiCodeblocks.enabled = true;
            ShowHiddenChannels.enabled = true;
            TypingTweaks.enabled = true;
            Unindent.enabled = true;
            YoutubeAdblock.enabled = true;
            # keep-sorted end
          };
        };
      };
    };
}
