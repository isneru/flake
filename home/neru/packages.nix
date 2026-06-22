{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # keep-sorted start
    bat
    cmake
    curl
    deadnix
    distrobox
    eduvpn-client
    eza
    ffmpeg
    fzf
    gcc
    gdb
    gh
    git
    gnumake
    graphviz
    inetutils
    insomnia
    iw
    jetbrains.idea
    jq
    just
    keep-sorted
    killall
    lazygit
    libnotify
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
    shfmt
    slurp
    socat
    stylua
    thunar
    thunar-archive-plugin
    thunar-volman
    xarchiver
    tree
    typst
    unzip
    vscode
    wavemon
    wget
    wl-clipboard
    wlopm
    zip
    # keep-sorted end
    (writeShellScriptBin "power-menu" (builtins.readFile ./scripts/power-menu.sh))
    (writeShellScriptBin "start-monitor" (builtins.readFile ./scripts/start-monitor.sh))
    (writeShellScriptBin "stop-monitor" (builtins.readFile ./scripts/stop-monitor.sh))
    (writeShellApplication {
      name = "battery-notify";
      runtimeInputs = with pkgs; [ libnotify ];
      text = builtins.readFile ./scripts/battery-notify.sh;
    })
    (writeShellApplication {
      name = "screenshot";
      runtimeInputs = with pkgs; [
        slurp
        wl-clipboard
        libnotify
      ];
      text = builtins.readFile ./scripts/screenshot.sh;
    })
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
