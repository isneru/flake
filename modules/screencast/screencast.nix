{ inputs, ... }:
{
  flake.modules.homeManager.screencast =
    { pkgs, ... }:
    let
      picker = pkgs.writeShellApplication {
        name = "notch-share-picker";
        runtimeInputs = [
          # keep-sorted start
          inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
          pkgs.coreutils
          pkgs.jq
          pkgs.slurp
          pkgs.xdg-desktop-portal-hyprland
          # keep-sorted end
        ];
        text = builtins.readFile ./share-picker.sh;
      };
    in
    {
      home.packages = [ picker ];
      xdg.configFile."hypr/xdph.conf".text = ''
        screencopy {
            custom_picker_binary = ${picker}/bin/notch-share-picker
        }
      '';
    };
}
