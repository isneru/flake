{ ... }:
{
  flake.modules.homeManager.scripts =
    { pkgs, config, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "start-monitor";
          # iw/ip run under sudo, which resolves them through its own
          # secure_path rather than this wrapper's PATH.
          runtimeInputs = [ ];
          text = builtins.readFile ./scripts/start-monitor.sh;
        })
        (pkgs.writeShellApplication {
          name = "stop-monitor";
          runtimeInputs = [ ];
          text = builtins.readFile ./scripts/stop-monitor.sh;
        })
        (pkgs.writeShellApplication {
          name = "screenshot";
          runtimeInputs = with pkgs; [
            grim
            slurp
            jq
            wl-clipboard
            satty
          ];
          text = builtins.readFile ./scripts/screenshot.sh;
        })
        (pkgs.writeShellApplication {
          name = "powermenu";
          runtimeInputs = [
            pkgs.tofi
            config.programs.noctalia.package
          ];
          text = builtins.readFile ./scripts/powermenu.sh;
        })
        (pkgs.writeShellApplication {
          name = "ns";
          runtimeInputs = with pkgs; [
            fzf
            (nix-search-tv.overrideAttrs {
              env.GOEXPERIMENT = "jsonv2";
              allowGoReference = true;
            })
          ];
          text = ''exec "${pkgs.nix-search-tv.src}/nixpkgs.sh" "$@"'';
        })
      ];
    };
}
