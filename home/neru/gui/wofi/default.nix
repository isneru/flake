{ ... }:

{
  programs.wofi.enable = true;
  xdg.configFile."wofi".source = ./.;
  xdg.configFile."networkmanager-dmenu/config.ini".text = ''
    [dmenu]
    dmenu_command = wofi --dmenu --prompt "Wi-Fi" --width 400 --lines 10

    [editor]
    terminal = ghostty
    gui_if_available = True
  '';
}
