{ lib, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    config = lib.mkForce null; 
  };

  xdg.configFile."sway".source = ./.;
}