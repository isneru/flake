{ ... }:

{
  programs.wofi.enable = true;
  xdg.configFile."wofi".source = ./.;
}