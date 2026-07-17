{ ... }:
{
  flake.modules.homeManager.vesktop =
    {
      pkgs,
      inputs,
      ...
    }:
    let
      customVencord = pkgs.vencord.overrideAttrs (old: {
        preBuild = (old.preBuild or "") + ''
          mkdir -p src/userplugins
          for dir in ${inputs.vesktop-plugins}/*/; do
            cp -r "$dir" src/userplugins/
          done
        '';
      });

      customVesktop = pkgs.vesktop.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/main/vencordFilesDir.ts \
            --replace-fail 'State.store.vencordDir || ' ""
        '';
      });

    in
    {
      theme-engine.apps.vesktop = {
        # No reload command at all: Vencord watches its themes directory and
        # hot-swaps CSS live.
        template = builtins.readFile ./vesktop/theme.css.tmpl;
        target = "~/.config/vesktop/themes/theme.css";
      };

      programs.vesktop = {
        enable = true;
        package = customVesktop.override { vencord = customVencord; };
        vencord.useSystem = true;
        settings = {
          discordBranch = "stable";
          firstLaunch = false;
          arRPC = "on";
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
          enabledThemes = [ "theme.css" ];
          enableReactDevtools = false;
          frameless = true;
          transparent = false;
          winCtrlQ = false;
          macosTranslucency = false;
          disableMinSize = false;
          winNativeTitleBar = false;
          plugins = {
            # keep-sorted start
            BypassDnD.enabled = true;
            ClearURLs.enabled = true;
            CrashHandler.enabled = true;
            FixCodeblockGap.enabled = true;
            MarkdownPreview.enabled = true;
            MessageLogger.enabled = true;
            ShikiCodeblocks.enabled = true;
            ShowHiddenChannels.enabled = true;
            TypingTweaks.enabled = true;
            Unindent.enabled = true;
            WebRichPresence.enabled = true;
            YoutubeAdblock.enabled = true;
            # keep-sorted end
          };
        };
      };
    };
}
