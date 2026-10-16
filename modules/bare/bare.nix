{
  flake.modules.homeManager.bare =
    { pkgs, ... }:
    let
      wmenu = pkgs.wmenu.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./wmenu-preview.patch
          ./wmenu-readout.patch
          ./wmenu-center.patch
          ./wmenu-alt.patch
        ];
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.gdk-pixbuf ];
      });

      bare-menu = pkgs.writeShellApplication {
        name = "bare-menu";
        runtimeInputs = [ wmenu ];
        text = builtins.readFile ../../scripts/bare/bare-menu.sh;
      };

      bare-look = pkgs.writeShellApplication {
        name = "bare-look";
        runtimeInputs = [ ];
        text = builtins.readFile ../../scripts/bare/bare-look.sh;
      };

      bare-pick = pkgs.writeShellApplication {
        name = "bare-pick";
        runtimeInputs = with pkgs; [
          # keep-sorted start
          bare-menu
          cliphist
          findutils
          gdk-pixbuf
          jq
          libnotify
          libqalculate
          networkmanager
          note
          systemd
          util-linux
          wl-clipboard
          # keep-sorted end
        ];
        text = builtins.readFile ../../scripts/bare/bare-pick.sh;
      };

      note = pkgs.writeShellApplication {
        name = "note";
        runtimeInputs = with pkgs; [
          bare-menu
          coreutils
          findutils
        ];
        text = builtins.readFile ../../scripts/bare/note.sh;
      };
    in
    {
      home.packages = [
        bare-look
        bare-menu
        bare-pick
        note
      ];

      theme-engine.apps.wmenu = {
        target = "~/.config/wmenu/colors.env";
        template = builtins.readFile ./colors.env.tmpl;
      };
    };
}
