{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chromium
    git
    vscode
    wget
    pipx
    xterm
    python3
    nmap
    inetutils
    gcc
    gdb
    gnumake
    cmake
    qemu
    gnome-terminal
    distrobox
    alacritty
    unzip
    nix-output-monitor
    jq
    insomnia
    swappy
  ];
}
