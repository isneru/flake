{ pkgs, lib, ... }:
{
  # Not started on session start - the stats widget toggles it on/off,
  # so idle is off by default until the user enables it.
  systemd.user.services.swayidle.Install.WantedBy = lib.mkForce [ ];

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 120;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 5%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      {
        timeout = 240;
        command = "${pkgs.wlopm}/bin/wlopm --off '*'";
        resumeCommand = "${pkgs.wlopm}/bin/wlopm --on '*'";
      }
      {
        timeout = 540;
        command = "systemctl suspend";
      }
    ];
    events = {
      before-sleep = "${pkgs.wlopm}/bin/wlopm --off '*'";
      after-resume = "${pkgs.wlopm}/bin/wlopm --on '*'";
    };
  };
}
