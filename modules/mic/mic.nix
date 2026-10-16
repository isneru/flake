{ ... }:
{
  flake.modules.homeManager.mic =
    { pkgs, ... }:
    let
      load-preset = pkgs.writeShellApplication {
        name = "easyeffects-load-preset";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.easyeffects
        ];
        text = builtins.readFile ../../scripts/mic/load-preset.sh;
      };
    in
    {
      services.easyeffects.extraPresets.mic = builtins.fromJSON (builtins.readFile ./mic.json);

      systemd.user.services.easyeffects.Service.ExecStartPost =
        "${load-preset}/bin/easyeffects-load-preset";
    };
}
