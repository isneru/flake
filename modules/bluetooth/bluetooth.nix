{ ... }:
{
  flake.modules.nixos.bluetooth = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
  };

  flake.modules.homeManager.bluetooth =
    {
      pkgs,
      inputs,
      ...
    }:
    let
      python = pkgs.python3.withPackages (
        p: with p; [
          dbus-python
          pygobject3
        ]
      );
      agent = pkgs.writeShellApplication {
        name = "notch-bt-agent";
        runtimeInputs = [
          # keep-sorted start
          inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
          python
          # keep-sorted end
        ];
        text = ''exec python3 ${./bt_agent.py} "$@"'';
      };
    in
    {
      home.packages = [ agent ];

      systemd.user.services.notch-bt-agent = {
        Unit = {
          Description = "BlueZ pairing agent rendered by the notch";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${agent}/bin/notch-bt-agent";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
