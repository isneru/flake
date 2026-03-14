{ pkgs, ... }:

{
  programs.vicinae = {
    enable = true;

    systemd.enable = true;

    settings = {
      theme = {
        dark.name = "rose-pine";
      };
    };

    themes = {
      "rose-pine" = {
        meta = {
          version = 1;
          name = "Rosé Pine";
          description = "All natural pine, faux fur and a bit of soho vibes";
          variant = "dark";
        };

        colors = {
          core = {
            background = "#191724";
            foreground = "#e0def4";
            secondary_background = "#1f1d2e";
            border = "#26233a";
            accent = "#c4a7e7";
          };
          accents = {
            blue = "#9ccfd8";
            green = "#31748f";
            magenta = "#c4a7e7";
            orange = "#ebbcba";
            purple = "#c4a7e7";
            red = "#eb6f92";
            yellow = "#f6c177";
            cyan = "#9ccfd8";
          };
        };
      };
    };
  };
}
