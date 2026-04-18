{ pkgs, ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "CaskaydiaCove NFM:size=12";
        terminal = "${pkgs.ghostty}/bin/ghostty";
        prompt = "'λ  '";
        layer = "overlay";
        border-width = 1;
        border-radius = 0;
        width = 30;
        horizontal-pad = 20;
        vertical-pad = 10;
        inner-pad = 5;
      };

      colors = {
        background = "232136ff";
        text = "e0def4ff";
        match = "ea9a97ff";
        selection = "393552ff";
        selection-text = "ea9a97ff";
        selection-match = "ea9a97ff";
        border = "ea9a97ff";
      };
    };
  };
}
