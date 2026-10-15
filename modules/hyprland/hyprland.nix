{ ... }:
{
  flake.modules.nixos.hyprland =
    { ... }:
    {
      programs.hyprland.enable = true;
      programs.uwsm.enable = true;
    };

  flake.modules.homeManager.hyprland =
    {
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      inherit (pkgs) hyprland;
      athanor-notch = hyprland.stdenv.mkDerivation {
        pname = "athanor-notch";
        inherit (hyprland) version;
        src = ./frame-plugin;
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ hyprland.dev ] ++ hyprland.buildInputs;
        installPhase = "install -Dm755 athanor-notch.so $out/lib/athanor-notch.so";
      };
    in
    {
      home.packages = [ pkgs.awww ];

      xdg.configFile."hypr/frame-plugin.lua".text = ''
        hl.plugin.load("${athanor-notch}/lib/athanor-notch.so")
      '';

      xdg.configFile."hypr/extra.lua".text = lib.mkMerge [
        (lib.mkBefore "return function(bind, MOD, blur)")
        (lib.mkAfter "end")
      ];

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
