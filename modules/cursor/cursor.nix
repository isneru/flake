{
  flake.modules.homeManager.cursor =
    { config, pkgs, ... }:
    let
      name = "Bibata-Modern-Accent";
      inherit (config.home) pointerCursor;
      colors = "${config.xdg.dataHome}/theme-engine/cursor.json";
      bibata = pkgs.bibata-cursors.src;

      cursor-recolor = pkgs.writeShellApplication {
        name = "cursor-recolor";
        runtimeInputs = with pkgs; [
          # keep-sorted start
          dconf
          librsvg
          python3
          xcursorgen
          # keep-sorted end
        ];
        text = ''
          exec python3 ${./recolor.py} \
            --svgs ${bibata}/svg/modern \
            --config ${bibata}/configs/normal/x.build.toml \
            --colors ${colors} \
            --icons ${config.xdg.dataHome}/icons \
            --name ${name} \
            --inherits ${pointerCursor.name} \
            --size ${toString pointerCursor.size}
        '';
      };
    in
    {
      home.packages = [ cursor-recolor ];

      home.sessionVariables = {
        XCURSOR_THEME = name;
        HYPRCURSOR_THEME = name;
        HYPRCURSOR_SIZE = pointerCursor.size;
      };

      gtk.cursorTheme = {
        inherit name;
        inherit (pointerCursor) size;
      };

      theme-engine.apps.cursor = {
        target = colors;
        template = builtins.readFile ./colors.json.tmpl;
        reload = [ "cursor-recolor" ];
      };
    };
}
