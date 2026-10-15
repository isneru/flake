{ ... }:
{
  flake.modules.nixos.sddm =
    { pkgs, ... }:
    let
      theme = pkgs.stdenvNoCC.mkDerivation {
        pname = "bare-sddm-theme";
        version = "1.0";
        dontUnpack = true;
        dontBuild = true;
        installPhase = ''
          d=$out/share/sddm/themes/bare
          mkdir -p $d
          cp ${./bare/Main.qml} $d/Main.qml
          cp ${./bare/metadata.desktop} $d/metadata.desktop
          cp ${../quickshell/lock/BareFace.qml} $d/BareFace.qml
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
        theme = "bare";
        wayland.enable = false;
        package = pkgs.kdePackages.sddm;
        extraPackages = with pkgs.kdePackages; [
          qtsvg
          qtdeclarative
          qt5compat
        ];
      };

      environment.systemPackages = [ theme ];

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
