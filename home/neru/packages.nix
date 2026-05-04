{ pkgs, ... }:

let
  helium =
    let
      pname = "helium";
      version = "0.11.6.1";
      src = pkgs.fetchurl {
        url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
        hash = "sha256-NvsSVeKr82ME8oPupU8Oyh9IbYerxAWJ5vRjvj4WyLo=";
      };
      contents = pkgs.appimageTools.extract { inherit pname version src; };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      extraInstallCommands = ''
        install -m 444 -D ${contents}/helium.desktop $out/share/applications/helium.desktop
        substituteInPlace $out/share/applications/helium.desktop \
          --replace 'Exec=AppRun' 'Exec=helium'
        cp -r ${contents}/usr/share/icons $out/share
      '';
    };
in
{
  home.packages = with pkgs; [
    # keep-sorted start
    bat
    curl
    deadnix
    distrobox
    eduvpn-client
    eza
    ffmpeg
    fzf
    git
    grim
    helium
    insomnia
    jq
    just
    keep-sorted
    killall
    lazygit
    librewolf
    libsForQt5.qt5ct
    networkmanager_dmenu
    nixfmt
    nixfmt-tree
    nodejs
    obsidian
    pciutils
    pipx
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
    unzip
    vscode
    wget
    wl-clipboard
    wlogout
    xwayland
    xwayland-satellite
    zip
    # keep-sorted end
    (writeShellScriptBin "mkenv" (builtins.readFile ./scripts/mkenv.sh))
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
