{ pkgs, config, ... }:

{
  home.pointerCursor = {
    enable = true;
    name = "BreezeX-RosePine-Linux";
    package = pkgs.rose-pine-cursor;
    size = 24;
    dotIcons.enable = false;
    gtk.enable = true;
    x11.enable = true;
  };
}
