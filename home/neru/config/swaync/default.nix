{ style, ... }:
{
  catppuccin.swaync.enable = false;

  systemd.user.services.swaync.Unit.After = [ "driftwm.service" ];

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      cssPriority = "application";
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-width = 500;
      control-center-height = 600;
      notification-icon-size = 64;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      fit-to-screen = true;
      notification-window-width = 400;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;
      notification-grouping = true;
      relative-timestamps = true;
      widgets = [
        "title"
        "dnd"
        "mpris"
        "notifications"
      ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        mpris = {
          image-size = 96;
          blur = true;
        };
      };
    };
    style = ''
      * {
        font-family: "${style.fonts.mono}", monospace;
        font-size: 13px;
        text-shadow: none;
      }

      * {
        -gtk-icon-shadow: none;
        box-shadow: none;
        outline: none;
      }

      .control-center,
      .floating-notifications,
      .floating-notifications.background,
      .blank-window,
      notificationwindow,
      blankwindow {
        background: transparent;
        border: none;
        box-shadow: none;
      }

      .control-center {
        background: transparent;
        border: none;
      }

      .control-center-list {
        background: transparent;
      }

      .control-center-list-placeholder,
      .control-center-list-placeholder image,
      .control-center-list-placeholder label {
        opacity: 0;
        background: transparent;
        border: none;
        padding: 0;
        margin: 0;
        min-width: 0;
        min-height: 0;
        -gtk-icon-size: 0;
        font-size: 0;
      }

      .blank-window {
        background: alpha(black, 0.1);
      }

      .notification-row,
      .notification-row:focus,
      .notification-row:hover {
        background: transparent;
        outline: none;
      }

      .floating-notifications.background .notification-row {
        margin: 20px 20px 0 0;
      }

      .notification-background {
        padding: 6px 0;
      }

      .notification {
        background: ${style.colors.bg};
        color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        padding: 0;
        margin: 0;
      }

      .notification.critical {
        border-color: ${style.colors.error};
      }

      .notification-default-action {
        background: transparent;
        color: ${style.colors.fg};
        border: none;
        border-radius: ${toString style.radius}px;
        padding: 12px 14px;
      }

      .notification-content {
        background: transparent;
        color: ${style.colors.fg};
        border: none;
        border-radius: ${toString style.radius}px;
        padding: 0;
      }

      .notification-default-action:hover {
        background: ${style.colors.bgAlt};
      }

      .notification-default-action:not(:only-child) {
        border-bottom-left-radius: 0;
        border-bottom-right-radius: 0;
      }

      .notification-content .summary {
        font-weight: bold;
        font-size: 14px;
        color: ${style.colors.fg};
      }

      .notification-content .time {
        font-size: 12px;
        color: ${style.colors.fgMuted};
        margin-right: 8px;
      }

      .notification-content .body {
        font-size: 13px;
        color: ${style.colors.fgDim};
      }

      .notification-content .image {
        border-radius: 8px;
        margin: 4px 10px 4px 4px;
      }

      .notification-content .app-icon {
        margin: 4px;
        color: ${style.colors.fgMuted};
      }

      .notification-content .body-image {
        margin-top: 6px;
        background: ${style.colors.bgAlt};
        border-radius: 8px;
      }

      .inline-reply {
        margin-top: 6px;
      }

      .inline-reply-entry {
        background: ${style.colors.bgAlt};
        color: ${style.colors.fg};
        caret-color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        padding: 4px 8px;
      }

      .inline-reply-button {
        background: ${style.colors.bg};
        color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        margin-left: 4px;
        padding: 4px 10px;
      }

      .inline-reply-button:hover {
        background: ${style.colors.bgAlt};
      }

      .inline-reply-button:disabled {
        color: ${style.colors.fgMuted};
        border-color: ${style.colors.fgMuted};
      }

      .notification-alt-actions {
        background: transparent;
        border-top: 1px solid ${style.colors.border};
        border-bottom-left-radius: ${toString style.radius}px;
        border-bottom-right-radius: ${toString style.radius}px;
        padding: 4px;
      }

      .notification-action {
        margin: 4px;
      }

      .notification-action > button {
        background: ${style.colors.bgAlt};
        color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        padding: 4px 8px;
      }

      .notification-action > button:hover {
        background: ${style.colors.border};
      }

      .close-button {
        background: transparent;
        color: ${style.colors.fgMuted};
        border: none;
        border-radius: 999px;
        min-width: 22px;
        min-height: 22px;
        padding: 0;
        margin: 6px 8px 0 0;
      }

      .close-button:hover {
        background: ${style.colors.error};
        color: ${style.colors.bg};
      }

      .notification-group {
        background: transparent;
      }

      .notification-group-headers {
        margin: 0 8px;
        color: ${style.colors.fg};
      }

      .notification-group-header {
        color: ${style.colors.fg};
        font-weight: bold;
      }

      .notification-group-icon {
        color: ${style.colors.fgMuted};
        -gtk-icon-size: 18px;
      }

      .notification-group-buttons {
        margin: 0 8px;
      }

      .notification-group-buttons > button,
      .notification-group-collapse-button,
      .notification-group-close-all-button {
        background: transparent;
        color: ${style.colors.fgMuted};
        border: 1px solid ${style.colors.border};
        border-radius: 999px;
        min-width: 24px;
        min-height: 24px;
        padding: 0;
        margin: 4px 4px;
      }

      .notification-group-buttons > button:hover,
      .notification-group-collapse-button:hover,
      .notification-group-close-all-button:hover {
        background: ${style.colors.bgAlt};
        color: ${style.colors.fg};
      }

      .notification-group.collapsed.not-expanded {
        opacity: 0.5;
      }

      .notification-group.collapsed .notification-row .notification {
        background: ${style.colors.bg};
      }

      .widget {
        background: ${style.colors.bg};
        color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        margin: 6px 0;
        padding: 10px 14px;
      }

      .widget-notifications {
        background: transparent;
        border: none;
        padding: 0;
        margin: 0;
      }

      .widget-title {
        font-size: 15px;
      }

      .widget-title > label {
        font-weight: bold;
        color: ${style.colors.fg};
      }

      .widget-title > button {
        background: ${style.colors.bgAlt};
        color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        padding: 2px 10px;
        margin-left: 8px;
      }

      .widget-title > button:hover {
        background: ${style.colors.border};
      }

      .widget-dnd > label {
        color: ${style.colors.fg};
        font-size: 14px;
      }

      .widget-dnd > switch {
        background: ${style.colors.bgAlt};
        border: 1px solid ${style.colors.border};
        border-radius: 999px;
        min-height: 22px;
        min-width: 46px;
        padding: 0;
      }

      .widget-dnd > switch:checked {
        background: ${style.colors.accent};
      }

      .widget-dnd > switch slider {
        background: ${style.colors.fg};
        border-radius: 999px;
        min-height: 18px;
        min-width: 18px;
        margin: -2px;
      }

      .widget-mpris {
        padding: 0;
        background: transparent;
        border: none;
        margin: 6px 0;
      }

      .widget-mpris-player {
        background: ${style.colors.bg};
        color: ${style.colors.fg};
        border: 1px solid ${style.colors.border};
        border-radius: ${toString style.radius}px;
        padding: 10px;
        margin: 0;
      }

      .widget-mpris .mpris-background {
        filter: none;
        background: transparent;
        background-image: none;
        opacity: 0;
      }

      .widget-mpris .mpris-overlay {
        background: transparent;
        padding: 0;
      }

      .widget-mpris-title {
        font-weight: bold;
        font-size: 14px;
        color: ${style.colors.fg};
      }

      .widget-mpris-subtitle {
        font-size: 12px;
        color: ${style.colors.fgMuted};
      }

      .widget-mpris-album-art {
        border-radius: 8px;
        -gtk-icon-size: 56px;
      }

      .widget-mpris button {
        background: transparent;
        color: ${style.colors.fg};
        border: none;
        border-radius: 999px;
        min-width: 28px;
        min-height: 28px;
        padding: 4px;
        margin: 0 2px;
      }

      .widget-mpris button:hover {
        background: ${style.colors.bgAlt};
      }

      .widget-mpris > box > button {
        background: ${style.colors.bgAlt};
        border: 1px solid ${style.colors.border};
        border-radius: 999px;
        min-width: 24px;
        min-height: 24px;
      }

      .widget-mpris > box > button:disabled {
        color: ${style.colors.fgMuted};
        border-color: ${style.colors.fgMuted};
      }

      progressbar {
        min-height: 6px;
        border-radius: 999px;
        background: transparent;
        border: none;
      }

      progressbar trough {
        min-height: 6px;
        border-radius: 999px;
        background: ${style.colors.bgAlt};
        border: 1px solid ${style.colors.border};
      }

      progressbar progress {
        min-height: 6px;
        border-radius: 999px;
        background: ${style.colors.accent};
        border: none;
      }
    '';
  };
}
