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
        name = "bare-bt-agent";
        runtimeInputs = [
          # keep-sorted start
          inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
          python
          # keep-sorted end
        ];
        text = ''exec python3 ${../../scripts/bluetooth/bt_agent.py} "$@"'';
      };
    in
    {
      home.packages = [ agent ];

      systemd.user.services.bare-bt-agent = {
        Unit = {
          Description = "BlueZ pairing agent rendered by the bare shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${agent}/bin/bare-bt-agent";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
