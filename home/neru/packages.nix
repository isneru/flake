{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git
    vscode
    wget
    pipx
    nmap
    inetutils
    gcc
    gdb
    gnumake
    cmake
    qemu
    distrobox
    alacritty
    unzip
    jq
    insomnia
    just
    jdk21
    maven
    jetbrains.idea
    obsidian
    nemo
    nautilus
    swaybg
    wl-clipboard
    pavucontrol
    zip
    killall
    nixpkgs-fmt
    wavemon
    grim
    slurp
    swappy
    nodejs
    plantuml
    graphviz
    (pkgs.writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        (nix-search-tv.overrideAttrs {
          env.GOEXPERIMENT = "jsonv2";
          allowGoReference = true;
        })
      ];
      text = ''exec "${pkgs.nix-search-tv.src}/nixpkgs.sh" "$@"'';
    })
  ];
}
