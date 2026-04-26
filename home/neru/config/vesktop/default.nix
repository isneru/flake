{ colors, ... }:

{
  programs.vesktop = {
    enable = true;
    settings = {
      discordBranch = "stable";
      firstLaunch = false;
      arRPC = "on";
      splashColor = colors.hexToRgb colors.accent;
      splashBackground = colors.hexToRgb colors.bgDim;
      splashTheming = true;
      minimizeToTray = "on";
      closeToTray = "on";
      hardwareAcceleration = true;
      customTitleBar = true;
      appBadge = true;
      transparentWindow = false;
    };
    vencord.settings = {
      notifyAboutUpdates = false;
      autoUpdate = true;
      autoUpdateNotification = false;
      useQuickCss = true;
      themeLinks = [ ];
      enabledThemes = [ ];
      enableReactDevtools = false;
      frameless = true;
      transparent = false;
      winCtrlQ = false;
      macosTranslucency = false;
      disableMinSize = false;
      winNativeTitleBar = false;
      plugins = {
        # keep-sorted start
        ClearURLs.enabled = true;
        CrashHandler.enabled = true;
        FixCodeblockGap.enabled = true;
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
}
