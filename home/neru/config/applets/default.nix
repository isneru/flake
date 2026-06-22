{ pkgs, utils, ... }:
let
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      pygobject3
      pulsectl
    ]
  );

  mkLauncher =
    name:
    pkgs.writeScript "${name}-launcher" ''
      #!${pythonEnv}/bin/python3
      import os, runpy
      os.environ.setdefault('GDK_BACKEND', 'wayland')
      cfg = os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config'))
      runpy.run_path(os.path.join(cfg, 'applets', '${name}.py'), run_name='__main__')
    '';

  applets = pkgs.stdenv.mkDerivation {
    pname = "applets";
    version = "0.1";
    src = pkgs.runCommand "empty" { } "mkdir $out";

    nativeBuildInputs = [
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
    ];

    buildInputs = [
      pkgs.gtk4
      pkgs.gtk4-layer-shell
      pkgs.glib
      pkgs.pango
      pkgs.networkmanager
    ];

    dontUnpack = true;
    dontBuild = true;

    preFixup = ''
      gappsWrapperArgs+=(
        --set LD_PRELOAD "${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so"
      )
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp ${mkLauncher "audio"}     $out/bin/audio-applet
      cp ${mkLauncher "wifi"}      $out/bin/wifi-applet
      cp ${mkLauncher "bluetooth"} $out/bin/bluetooth-applet
      chmod +x $out/bin/audio-applet $out/bin/wifi-applet $out/bin/bluetooth-applet
    '';
  };
in
{
  home.packages = [ applets ];
  xdg.configFile."applets".source = utils.create_symlink "${utils.dotfiles}/applets";
}
