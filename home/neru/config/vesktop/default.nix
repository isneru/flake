{ colors, ... }:

{
  xdg.configFile."vesktop/themes/theme.css".text = ''
    :root, .theme-dark {
      /* New layout system */
      --app-frame-background: ${colors.bgDim};
      --background-base-lowest: ${colors.bgDim};
      --background-base-lower: ${colors.bgDim};
      --background-base-low: ${colors.bg};
      --background-surface-high: ${colors.bgAlt};
      --background-surface-higher: ${colors.bgAlt};
      --background-surface-highest: ${colors.bgAlt};
      --chat-background: ${colors.bg};
      --chat-background-default: ${colors.bgAlt};
      --channel-background-default: ${colors.bgDim};
      --channeltextarea-background: ${colors.bgAlt};
      --modal-background: ${colors.bgAlt};
      --modal-footer-background: ${colors.bgAlt};
      --card-background-default: ${colors.bgAlt};
      --home-background: ${colors.bgAlt};
      --embed-background: ${colors.bgAlt};
      --embed-background-alternate: ${colors.bg};
      --background-secondary-alt: ${colors.bgAlt};

      /* Text */
      --text-default: ${colors.fg};
      --text-strong: ${colors.fg};
      --text-subtle: ${colors.fgDim};
      --text-muted: ${colors.fgMuted};
      --text-link: ${colors.blue};
      --text-feedback-positive: ${colors.success};
      --text-feedback-warning: ${colors.warning};
      --text-feedback-critical: ${colors.error};
      --text-feedback-info: ${colors.cyan};
      --channels-default: ${colors.fgDim};
      --channel-icon: ${colors.fgMuted};
      --channel-text-area-placeholder: ${colors.fgMuted};
      --input-placeholder-text-default: ${colors.fgMuted};

      /* Interactive */
      --interactive-text-default: ${colors.fgDim};
      --interactive-text-hover: ${colors.fg};
      --interactive-text-active: ${colors.fg};
      --interactive-icon-default: ${colors.fgDim};
      --interactive-icon-hover: ${colors.fg};
      --interactive-icon-active: ${colors.fg};
      --interactive-muted: ${colors.fgMuted};

      /* Brand / accent */
      --brand-experiment: ${colors.accent};
      --brand-experiment-300: ${colors.accent};
      --brand-experiment-330: ${colors.accent};
      --brand-experiment-360: ${colors.accent};
      --brand-experiment-400: ${colors.accent};
      --brand-experiment-430: ${colors.purple};
      --brand-experiment-460: ${colors.purple};
      --brand-experiment-500: ${colors.purple};
      --focus-primary: ${colors.accent};

      /* Scrollbar */
      --scrollbar-thin-thumb: ${colors.border};
      --scrollbar-auto-thumb: ${colors.border};
      --scrollbar-auto-track: ${colors.bgDim};

      /* Hover/selection modifiers */
      --background-modifier-hover: rgba(${colors.hexToRgbValues colors.accent}, 0.08);
      --background-modifier-active: rgba(${colors.hexToRgbValues colors.accent}, 0.16);
      --background-modifier-selected: rgba(${colors.hexToRgbValues colors.accent}, 0.24);
      --background-modifier-accent: rgba(${colors.hexToRgbValues colors.accent}, 0.12);
    }
  '';

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
