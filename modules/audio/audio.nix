{ ... }:
{
  flake.modules.nixos.audio = {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.extraConfig."51-easyeffects-source"."monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_input.*"; } ];
          actions.update-props."priority.session" = -1;
        }
      ];
    };
  };

  flake.modules.homeManager.audio =
    { pkgs, ... }:
    {
      services.easyeffects.enable = true;

      systemd.user.services.easyeffects.Service.ExecStartPre =
        "${pkgs.python3}/bin/python3 ${../../scripts/audio/output-passthrough.py}";
    };
}
