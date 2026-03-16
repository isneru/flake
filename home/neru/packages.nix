{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # --- CLI & System Utilities ---
    git
    jq
    just
    killall
    unzip
    wget
    zip

    # --- Desktop & GUI Apps ---
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

    # --- Development & Compilers ---
    cmake
    gcc
    gdb
    gnumake
    jdk21
    maven
    nodejs
    pipx

    # --- Diagrams & Visualization ---
    graphviz
    plantuml

    # --- Networking Tools ---
    inetutils
    networkmanager_dmenu
    nmap
    wavemon

    # --- Virtualization & Containers ---
    distrobox

    # --- Wayland & Desktop Utilities ---
    grim # Screenshots
    thunar # file manager
    thunar-archive-plugin # Thunar plugin for archive management
    gvfs # Thunar dependency for mounting drives
    pulsemixer # Audio control
    slurp # Screen selection for screenshots
    swappy # Screenshot editor
    swaybg # Sway wallpaper utility
    wl-clipboard # Wayland clipboard
    xdg-desktop-portal-gtk

    # --- Nix & Custom Scripts ---
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
