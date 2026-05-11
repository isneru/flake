{ pkgs, style, ... }:
let
  hx = { "0"=0;"1"=1;"2"=2;"3"=3;"4"=4;"5"=5;"6"=6;"7"=7;"8"=8;"9"=9;"a"=10;"b"=11;"c"=12;"d"=13;"e"=14;"f"=15;"A"=10;"B"=11;"C"=12;"D"=13;"E"=14;"F"=15; };
  byte = hex: o: hx.${builtins.substring o 1 hex} * 16 + hx.${builtins.substring (o + 1) 1 hex};

  # setvtrgb format: 3 lines of 16 comma-separated decimal values (R / G / B)
  # Slots 0-7 map to TB_BLACK..TB_WHITE used by ly with full_color=false
  palette = [
    style.colors.bg        style.colors.red     style.colors.success
    style.colors.warning   style.colors.red     style.colors.purple
    style.colors.cyan      style.colors.fg      style.colors.bgDim
    style.colors.error     style.colors.success style.colors.warning
    style.colors.blue      style.colors.magenta style.colors.info
    style.colors.fgDim
  ];
  ch = channel: builtins.concatStringsSep "," (map (c: toString (byte c channel)) palette);
  colorFile = pkgs.writeText "ly-vtcolors" ''
    ${ch 1}
    ${ch 3}
    ${ch 5}
  '';

  paletteScript = pkgs.writeShellScript "ly-vt-palette" ''
    fb=/sys/class/graphics/fb0/virtual_size
    if [ -r "$fb" ]; then
      cols=$(cut -d, -f1 "$fb")
      rows=$(cut -d, -f2 "$fb")
      stty -F /dev/tty1 cols $((cols / 8)) rows $((rows / 16))
    fi
    ${pkgs.kbd}/bin/setvtrgb ${colorFile}
    printf '\033[?25l' > /dev/tty1
  '';
in
{
  services.displayManager.ly = {
    enable = true;
    settings = {
      bigclock = true;
      clear_password = true;
      center_box_h = true;
      center_box_v = true;
      full_color = false;
      bg = 1; # TB_BLACK → slot 0 → style.colors.bg
      fg = 8; # TB_WHITE → slot 7 → style.colors.fg
      border_fg = 5; # TB_BLUE → slot 4 → style.colors.red
      brightness_down_cmd = "${pkgs.brightnessctl}/bin/brightnessctl -q -n s 10%-";
      brightness_up_cmd = "${pkgs.brightnessctl}/bin/brightnessctl -q -n s +10%";
    };
  };

  systemd.services.ly-vt-palette = {
    description = "Set VT colour palette for ly";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    after = [ "plymouth-quit-wait.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = paletteScript;
    };
  };
}
