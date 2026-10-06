{ ... }:
{
  flake.modules.homeManager.packages =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # keep-sorted start
        (texliveBasic.withPackages (ps: [ ps.latexmk ]))
        cmake
        ffmpeg
        gcc
        gdb
        gh
        gnumake
        graphviz
        inetutils
        jq
        keep-sorted
        killall
        nixfmt
        nodejs
        pciutils
        pipx
        plantuml
        pulsemixer
        qt6.qtdeclarative
        ripgrep
        seahorse
        shfmt
        slurp
        socat
        stylua
        tree
        typst
        typstyle
        unzip
        wget
        wlopm
        yt-dlp
        zip
        # keep-sorted end
      ];
    };
}
