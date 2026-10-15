{ ... }:
{
  flake.modules.homeManager.mic =
    { pkgs, ... }:
    {
      services.easyeffects.extraPresets.mic = builtins.fromJSON (builtins.readFile ./mic.json);

      systemd.user.services.easyeffects.Service.ExecStartPost = toString (
        pkgs.writeShellScript "easyeffects-load-preset" ''
          for _ in $(seq 100); do
            [ -S "$XDG_RUNTIME_DIR/EasyEffectsServer" ] && break
            sleep 0.1
          done
          exec ${pkgs.easyeffects}/bin/easyeffects --load-preset mic
        ''
      );
    };
}
