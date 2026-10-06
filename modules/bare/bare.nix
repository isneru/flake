{
  flake.modules.homeManager.bare =
    { pkgs, ... }:
    let
      wmenu = pkgs.wmenu.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./wmenu-preview.patch
          ./wmenu-readout.patch
          ./wmenu-center.patch
        ];
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.gdk-pixbuf ];
      });

      notch-menu = pkgs.writeShellApplication {
        name = "notch-menu";
        runtimeInputs = [ wmenu ];
        text = builtins.readFile ./notch-menu.sh;
      };

      notch-mode = pkgs.writeShellApplication {
        name = "notch-mode";
        runtimeInputs = [ ];
        text = builtins.readFile ./notch-mode.sh;
      };

      notch-pick = pkgs.writeShellApplication {
        name = "notch-pick";
        runtimeInputs = with pkgs; [
          # keep-sorted start
          cliphist
          findutils
          gdk-pixbuf
          jq
          libnotify
          libqalculate
          networkmanager
          notch-menu
          note
          systemd
          util-linux
          wl-clipboard
          # keep-sorted end
        ];
        text = builtins.readFile ./notch-pick.sh;
      };

      note = pkgs.writeShellApplication {
        name = "note";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          notch-menu
        ];
        text = builtins.readFile ./note.sh;
      };
    in
    {
      home.packages = [
        notch-menu
        notch-mode
        notch-pick
        note
      ];

      theme-engine.apps.wmenu = {
        target = "~/.config/wmenu/colors.env";
        template = builtins.readFile ./colors.env.tmpl;
      };
    };
}
