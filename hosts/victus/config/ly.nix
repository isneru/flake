{ pkgs, ... }:
{
  services.displayManager.ly = {
    enable = true;
    settings = {
      bigclock = true;
      clear_password = true;
      center_box_h = true;
      center_box_v = true;
      brightness_down_cmd = "${pkgs.brightnessctl}/bin/brightnessctl -q -n s 10%-";
      brightness_up_cmd = "${pkgs.brightnessctl}/bin/brightnessctl -q -n s +10%";
    };
  };
}
