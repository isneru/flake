{ pkgs, ... }:
{
  programs.discord = {
    enable = true;
    package = pkgs.discord.override { withVencord = true; };
    settings = {
      openasar = {
        setup = true;
        quickstart = true;
      };
      IS_MAXIMIZED = true;
      IS_MINIMIZED = false;
      trayBalloonShown = true;
    };
  };
}
