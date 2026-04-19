{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    inputs.gazelle.packages.${pkgs.system}.default
    inputs.helium.packages.${system}.default
    git
    jq
    just
    killall
    unzip
    wget
    zip
    fzf
    ffmpeg
    curl
    insomnia
    jetbrains.idea
    obsidian
    lazygit
    vscode
    (rstudioWrapper.override {
      packages = with rPackages; [
        ggplot2
        dplyr
        tidyverse
      ];
    })
    cmake
    gcc
    gdb
    gnumake
    maven
    nodejs
    pipx
    graphviz
    plantuml
    inetutils
    networkmanager_dmenu
    nmap
    wavemon
    iw
    pciutils
    distrobox
    grim
    thunar
    thunar-archive-plugin
    pulsemixer
    slurp
    swappy
    swaybg
    swaylock
    wlogout
    wl-clipboard
    xwayland-satellite
    xwayland
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    nixfmt-tree
    (writeShellScriptBin "start-monitor" ''
      IFACE=''${1:-wlp5s0} 
      echo "Creating virtual interface 'mon0' from $IFACE..."
      if sudo iw dev "$IFACE" interface add mon0 type monitor; then
        sudo ip link set mon0 up
        echo "Done. Interface 'mon0' is up."
      else
        echo "Error creating interface. Check if it already exists or if you need sudo privileges."
      fi
    '')
    (writeShellScriptBin "stop-monitor" ''
      echo "Removing virtual interface 'mon0'..."
      sudo ip link set mon0 down 2>/dev/null
      if sudo iw dev mon0 del; then
        echo "Interface 'mon0' removed successfully."
      else
        echo "Error removing interface. Maybe it doesn't exist or you need sudo privileges."
      fi
    '')
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
  ];
}
