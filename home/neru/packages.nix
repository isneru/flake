{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # cli and system utils
    git
    jq
    just
    killall
    unzip
    wget
    zip

    # gui apps
    inputs.helium.packages.${pkgs.system}.default
    insomnia
    jetbrains.idea
    obsidian
    vscode
    (rstudioWrapper.override {
      packages = with rPackages; [
        ggplot2
        dplyr
        tidyverse
      ];
    })

    # development and compilers
    cmake
    gcc
    gdb
    gnumake
    jdk21
    maven
    nodejs
    pipx

    # puml
    graphviz
    plantuml

    # networking
    inetutils
    networkmanager_dmenu
    nmap
    wavemon

    # virtualization and containers
    distrobox

    # desktop utils
    grim
    thunar
    thunar-archive-plugin
    gvfs
    pulsemixer
    slurp
    swappy
    swaybg
    wl-clipboard
    xwayland-satellite
    xwayland
    xdg-desktop-portal-gtk

    # nix
    pkgs.nixfmt
    pkgs.nixfmt-tree
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
