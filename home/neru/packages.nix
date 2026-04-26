{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # keep-sorted start
    cmake
    curl
    deadnix
    distrobox
    ffmpeg
    fzf
    gcc
    gdb
    git
    gnumake
    graphviz
    grim
    inetutils
    inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    insomnia
    iw
    jetbrains.idea
    jq
    just
    keep-sorted
    killall
    lazygit
    librewolf
    libsForQt5.qt5ct
    maven
    networkmanager_dmenu
    nixfmt
    nixfmt-tree
    nmap
    nodejs
    obsidian
    pciutils
    pipx
    plantuml
    pulsemixer
    qt6Packages.qt6ct
    shfmt
    slurp
    stylua
    swappy
    swaybg
    swaylock
    thunar
    thunar-archive-plugin
    tinymist
    typst
    typst-live
    unzip
    vscode
    wavemon
    wget
    wl-clipboard
    wlogout
    xwayland
    xwayland-satellite
    zip
    # keep-sorted end
    (rstudioWrapper.override {
      packages = with rPackages; [
        ggplot2
        dplyr
        tidyverse
      ];
    })
    (writeShellScriptBin "start-monitor" (builtins.readFile ./scripts/start-monitor.sh))
    (writeShellScriptBin "stop-monitor" (builtins.readFile ./scripts/stop-monitor.sh))
    (writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        (nix-search-tv.overrideAttrs {
          env.GOEXPERIMENT = "jsonv2";
          allowGoReference = true;
        })
      ];
      text = ''exec "${nix-search-tv.src}/nixpkgs.sh" "$@"'';
    })
    (writeShellScriptBin "power-tui" (builtins.readFile ./scripts/power-tui.sh))
  ];
}
