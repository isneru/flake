{ inputs, ... }:
{
  flake.modules.homeManager.excalidraw =
    { pkgs, utils, ... }:
    let
      upstream = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

      core = upstream.unwrapped.overrideAttrs (o: {
        postPatch = (o.postPatch or "") + ''
          substituteInPlace src/launch/launch.cpp --replace-fail "auto qArgC = 0;" "auto qArgC = 1;"
        '';
      });

      quickshell = (upstream.withModules [ pkgs.qt6.qtwebengine ]).overrideAttrs {
        installPhase = ''
          mkdir -p $out
          cp -r ${core}/* $out
        '';
      };

      web = pkgs.buildNpmPackage {
        pname = "excalidraw-local";
        version = "0.18.1";
        src = ./web;
        npmDepsHash = "sha256-WwkPvMrfTMfLUWm5SgWpxok/ryrIgYIL1LnKRpOefNw=";
        npmFlags = [ "--ignore-scripts" ];
        nativeBuildInputs = [ pkgs.esbuild ];
        buildPhase = ''
          runHook preBuild
          esbuild main.jsx --bundle --minify --format=iife --jsx=automatic \
            --define:process.env.NODE_ENV='"production"' --conditions=production \
            --external:'*.woff2' --outdir=dist
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp dist/* index.html $out/
          cp -r node_modules/@excalidraw/excalidraw/dist/prod/fonts $out/
          runHook postInstall
        '';
      };

      app = pkgs.writeShellApplication {
        name = "excalidraw";
        runtimeInputs = [
          # keep-sorted start
          pkgs.hyprland
          quickshell
          # keep-sorted end
        ];
        text = ''
          export EXCALIDRAW_WEB=${web}
        ''
        + builtins.readFile ../../scripts/excalidraw/excalidraw.sh;
      };
    in
    {
      xdg.configFile = {
        "quickshell/excalidraw/shell.qml".source =
          utils.create_symlink "${utils.dotfiles}/excalidraw/qml/shell.qml";
        "quickshell/excalidraw/singletons".source =
          utils.create_symlink "${utils.dotfiles}/quickshell/singletons";
      };

      xdg.desktopEntries.excalidraw = {
        name = "Excalidraw";
        genericName = "Whiteboard";
        exec = "${app}/bin/excalidraw";
        icon = "applications-graphics";
        terminal = false;
        categories = [ "Graphics" ];
      };
    };
}
