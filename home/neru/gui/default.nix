{ lib, useAmbxst, ... }:
{
  imports = [
    ./ghostty
    ./networkmanager-dmenu
    ./vesktop
    ./spotify.nix
  ]
  ++ lib.optional (useAmbxst) ./ambxst
  ++ lib.optional (useAmbxst) ./hyprland/ambxst

  ++ lib.optional (!useAmbxst) ./hyprland/waybar
  ++ lib.optional (!useAmbxst) ./waybar
  ++ lib.optional (!useAmbxst) ./vicinae.nix;
}
