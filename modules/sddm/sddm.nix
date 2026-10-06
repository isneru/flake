{ ... }:
{
  flake.modules.nixos.sddm =
    { pkgs, ... }:
    let
      theme = pkgs.stdenvNoCC.mkDerivation {
        pname = "notch-sddm-theme";
        version = "1.0";
        dontUnpack = true;
        dontBuild = true;
        installPhase = ''
          d=$out/share/sddm/themes/notch
          mkdir -p $d
          cp ${./notch/Main.qml} $d/Main.qml
          cp ${./notch/metadata.desktop} $d/metadata.desktop
          cp ${../quickshell/lock/LockFace.qml} $d/LockFace.qml
          cp ${../quickshell/lock/Glyph.qml} $d/Glyph.qml
          ln -sf /var/lib/sddm-theme/theme.conf $d/theme.conf
        '';
      };
    in
    {
      services.displayManager.defaultSession = "hyprland-uwsm";
      services.displayManager.autoLogin = {
        enable = true;
        user = "neru";
      };

      services.xserver.enable = true;

      services.displayManager.sddm = {
        enable = true;
        theme = "notch";
        wayland.enable = false;
        package = pkgs.kdePackages.sddm;
        extraPackages = with pkgs.kdePackages; [
          qtsvg
          qtdeclarative
          qt5compat
        ];
      };

      environment.systemPackages = [ theme ];

      fonts.packages = [
        (pkgs.google-fonts.override { fonts = [ "DMSans" ]; })
        pkgs.jetbrains-mono
        pkgs.material-symbols
      ];

      systemd.tmpfiles.rules = [
        "R /var/lib/sddm/.cache"
        "d /var/lib/sddm-theme 0755 neru users -"
      ];
    };

  flake.modules.homeManager.sddm = {
    theme-engine.apps.sddm = {
      template = builtins.readFile ./theme.conf.tmpl;
      target = "/var/lib/sddm-theme/theme.conf";
    };
  };
}
