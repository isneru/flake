{
  flake.modules.homeManager.icons =
    { config, pkgs, ... }:
    let
      name = "Papirus-Dark-Accent";
      theme = "Papirus-Dark";
      root = "${pkgs.papirus-icon-theme}/share/icons";
      colors = "${config.xdg.dataHome}/theme-engine/icons.json";

      manifest = pkgs.runCommand "papirus-folders.json" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${./recolor.py} manifest --root ${root} --theme ${theme} > $out
      '';

      icons-recolor = pkgs.writeShellApplication {
        name = "icons-recolor";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec python3 ${./recolor.py} build \
            --root ${root} \
            --theme ${theme} \
            --light-theme Papirus-Light \
            --manifest ${manifest} \
            --colors ${colors} \
            --icons ${config.xdg.dataHome}/icons \
            --name ${name}
        '';
      };
    in
    {
      home.packages = [ icons-recolor ];

      gtk.iconTheme = {
        inherit name;
        package = pkgs.papirus-icon-theme;
      };

      theme-engine.apps.icons = {
        target = colors;
        template = builtins.readFile ./colors.json.tmpl;
        reload = [ "icons-recolor" ];
      };
    };
}
