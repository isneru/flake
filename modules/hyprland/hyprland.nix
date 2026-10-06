{ ... }:
{
  flake.modules.nixos.hyprland =
    { ... }:
    {
      programs.hyprland.enable = true;
      programs.uwsm.enable = true;
    };

  flake.modules.homeManager.hyprland =
    { pkgs, utils, ... }:
    {
      home.packages = [ pkgs.awww ];

      xdg.configFile."hypr/hyprland.lua".source =
        utils.create_symlink "${utils.dotfiles}/hyprland/hyprland.lua";

      xdg.configFile."xkb/rules/evdev".source =
        utils.create_symlink "${utils.dotfiles}/hyprland/xkb/rules/evdev";
      xdg.configFile."xkb/symbols/custom".source =
        utils.create_symlink "${utils.dotfiles}/hyprland/xkb/symbols/custom";

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
        template = builtins.readFile ./theme-colors.lua.tmpl;
        reload = [
          "hyprctl"
          "reload"
        ];
      };
    };
}
