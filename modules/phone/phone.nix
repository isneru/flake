{ ... }:
{
  flake.modules.nixos.phone =
    { config, pkgs, ... }:
    {
      networking.networkmanager.dispatcherScripts = [
        {
          source = pkgs.writeShellScript "phone-sync-up" ''
            [ "$2" = up ] || exit 0
            ${config.systemd.package}/bin/systemctl --user -M neru@ start --no-block phone-sync.service || true
          '';
        }
      ];
    };

  flake.modules.homeManager.phone =
    { pkgs, ... }:
    let
      sync = pkgs.writeShellApplication {
        name = "phone-sync";
        runtimeInputs = [
          # keep-sorted start
          (pkgs.python3.withPackages (ps: [ ps.pillow ]))
          pkgs.coreutils
          pkgs.gawk
          pkgs.iproute2
          pkgs.openssh
          # keep-sorted end
        ];
        text = ''
          known_hosts=${./known_hosts}
        ''
        + builtins.readFile ./phone-sync.sh;
      };
    in
    {
      systemd.user.services.phone-sync = {
        Unit.Description = "Push the wallpaper to the phone";
        Service = {
          Type = "oneshot";
          ExecStart = "${sync}/bin/phone-sync";
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.paths.phone-sync = {
        Unit.Description = "Watch the wallpaper for the phone";
        Path.PathChanged = "%h/.local/state/quickshell/wallpaper";
        Install.WantedBy = [ "default.target" ];
      };
    };
}
