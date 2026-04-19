{ ... }:
{
  programs.tofi = {
    enable = true;
    settings = {
      width = "100%";
      height = "100%";
      border-width = 0;
      outline-width = 0;

      padding-left = "35%";
      padding-top = "35%";
      result-spacing = 25;
      num-results = 5;

      font = "CaskaydiaCove NFM";
      font-size = 18;

      background-color = "#000A";
      text-color = "#a9b1d6";

      selection-color = "#ea9a97";
      selection-background = "#232136";
      selection-background-padding = "5, 10";
      selection-background-corner-radius = 0;

      prompt-color = "#bb9af7";
    };
  };
}
