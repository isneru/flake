{ ... }:
{
  flake.modules.nixos.hyprland =
    { ... }:
    {
      programs.hyprland.enable = true;
      # Separate from programs.hyprland.enable above - that one only generates
      # the hyprland-uwsm.desktop session entry (the uwsm binary happens to
      # already be in the store), it does NOT install uwsm's own required
      # systemd unit templates (wayland-session-bindpid@.service etc). Without
      # this, selecting that session crashed near-instantly: confirmed live via
      # `uwsm: Command ['systemctl', '--user', 'start',
      # 'wayland-session-bindpid@<pid>.service'] returned non-zero exit status
      # 5` (systemd's "unit not found" code) in the journal.
      programs.uwsm.enable = true;
    };

  flake.modules.homeManager.hyprland =
    { utils, ... }:
    {
      # Structural config only (input, binds, window rules) - lives in the repo,
      # edited live via the out-of-store symlink. Colors/rounding are a separate
      # sibling file (theme-colors.lua) owned by the theme engine below, so a
      # theme switch never touches this one.
      xdg.configFile."hypr/hyprland.lua".source =
        utils.create_symlink "${utils.dotfiles}/hyprland/hyprland.lua";

      # blueman-applet/nm-applet aren't declared as packages anywhere in this
      # repo - they're pulled in automatically by nixpkgs' networkmanager/
      # bluetooth modules once services.xserver.enable is on (added for the SDDM
      # greeter), each bundling their own XDG autostart .desktop entry. Noctalia
      # already has native network/bluetooth widgets in its bar, so the redundant
      # legacy tray icons get suppressed the standard XDG way - a higher-priority
      # autostart entry with Hidden=true - rather than fighting whichever module
      # actually installs the underlying packages (which stay available to run
      # manually if ever needed).
      xdg.configFile."autostart/nm-applet.desktop".text = ''
        [Desktop Entry]
        Hidden=true
      '';
      xdg.configFile."autostart/blueman.desktop".text = ''
        [Desktop Entry]
        Hidden=true
      '';

      theme-engine.apps.hyprland = {
        target = "~/.config/hypr/theme-colors.lua";
        template = builtins.readFile ./hyprland/theme-colors.lua.tmpl;
        # Hyprland also auto-reloads its config on file change (inotify), same
        # as driftwm did - explicit reload here keeps the theme engine's
        # write-then-reload contract deterministic instead of racing that watch.
        reload = [
          "hyprctl"
          "reload"
        ];
      };
    };
}
