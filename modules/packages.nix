{ ... }:
{
  flake.modules.homeManager.packages =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # keep-sorted start
        ani-cli
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
        nixfmt
        nmap
        nodejs
        obsidian
        pciutils
        pipx
        plantuml
        pulsemixer
        ripgrep
        shfmt
        slurp
        socat
        stylua
        thunar
        thunar-archive-plugin
        thunar-volman
        tree
        typescript-language-server
        typst
        unzip
        vscode
        wavemon
        wget
        wl-clipboard
        wlopm
        xarchiver
        zip
        # keep-sorted end
      ];
    };
}
