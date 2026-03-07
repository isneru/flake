{ ... }:

{
  programs.vesktop.enable = true;
  xdg.configFile."vesktop/settings.json".source = ./settings.json;
  xdg.configFile."vesktop/settings/settings.json".source = ./settings/settings.json;
}
