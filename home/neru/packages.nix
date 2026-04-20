{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # keep-sorted start
    claude-code
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
    inputs.gazelle.packages.${pkgs.system}.default
    inputs.helium.packages.${system}.default
    insomnia
    iw
    jetbrains.idea
    jq
    just
    keep-sorted
    killall
    lazygit
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
    zathura
    zip
    # keep-sorted end
    (rstudioWrapper.override {
      packages = with rPackages; [
        ggplot2
        dplyr
        tidyverse
      ];
    })
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
