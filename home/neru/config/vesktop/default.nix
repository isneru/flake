{ style, ... }:

{
  xdg.configFile."vesktop/themes/theme.css".text = ''
    :root, .theme-dark {
      /* New layout system */
      --app-frame-background: ${style.colors.bgDim};
      --background-base-lowest: ${style.colors.bgDim};
      --background-base-lower: ${style.colors.bgDim};
      --background-base-low: ${style.colors.bg};
      --background-surface-high: ${style.colors.bgAlt};
      --background-surface-higher: ${style.colors.bgAlt};
      --background-surface-highest: ${style.colors.bgAlt};
      --chat-background: ${style.colors.bg};
      --chat-background-default: ${style.colors.bgAlt};
      --channel-background-default: ${style.colors.bgDim};
      --channeltextarea-background: ${style.colors.bgAlt};
      --modal-background: ${style.colors.bgAlt};
      --modal-footer-background: ${style.colors.bgAlt};
      --card-background-default: ${style.colors.bgAlt};
      --home-background: ${style.colors.bgAlt};
      --embed-background: ${style.colors.bgAlt};
      --embed-background-alternate: ${style.colors.bg};
      --background-secondary-alt: ${style.colors.bgAlt};

      /* Text */
      --text-default: ${style.colors.fg};
      --text-strong: ${style.colors.fg};
      --text-subtle: ${style.colors.fgDim};
      --text-muted: ${style.colors.fgMuted};
      --text-link: ${style.colors.blue};
      --text-feedback-positive: ${style.colors.success};
      --text-feedback-warning: ${style.colors.warning};
      --text-feedback-critical: ${style.colors.error};
      --text-feedback-info: ${style.colors.cyan};
      --channels-default: ${style.colors.fgDim};
      --channel-icon: ${style.colors.fgMuted};
      --channel-text-area-placeholder: ${style.colors.fgMuted};
      --input-placeholder-text-default: ${style.colors.fgMuted};

      /* Interactive */
      --interactive-text-default: ${style.colors.fgDim};
      --interactive-text-hover: ${style.colors.fg};
      --interactive-text-active: ${style.colors.fg};
      --interactive-icon-default: ${style.colors.fgDim};
      --interactive-icon-hover: ${style.colors.fg};
      --interactive-icon-active: ${style.colors.fg};
      --interactive-muted: ${style.colors.fgMuted};

      /* Brand / accent */
      --brand-experiment: ${style.colors.accent};
      --brand-experiment-300: ${style.colors.accent};
      --brand-experiment-330: ${style.colors.accent};
      --brand-experiment-360: ${style.colors.accent};
      --brand-experiment-400: ${style.colors.accent};
      --brand-experiment-430: ${style.colors.purple};
      --brand-experiment-460: ${style.colors.purple};
      --brand-experiment-500: ${style.colors.purple};
      --focus-primary: ${style.colors.accent};

      /* Scrollbar */
      --scrollbar-thin-thumb: ${style.colors.border};
      --scrollbar-auto-thumb: ${style.colors.border};
      --scrollbar-auto-track: ${style.colors.bgDim};

      /* Hover/selection modifiers */
      --background-modifier-hover: rgba(${style.colors.hexToRgbValues style.colors.accent}, 0.08);
      --background-modifier-active: rgba(${style.colors.hexToRgbValues style.colors.accent}, 0.16);
      --background-modifier-selected: rgba(${style.colors.hexToRgbValues style.colors.accent}, 0.24);
      --background-modifier-accent: rgba(${style.colors.hexToRgbValues style.colors.accent}, 0.12);
    }
  '';

  programs.vesktop = {
    enable = true;
    settings = {
      discordBranch = "stable";
      firstLaunch = false;
      arRPC = "on";
      splashColor = style.colors.hexToRgb style.colors.accent;
      splashBackground = style.colors.hexToRgb style.colors.bgDim;
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
