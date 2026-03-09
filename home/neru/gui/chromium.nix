{ ... }:

{
  programs.chromium = {
    enable = true;
    commandLineArgs = [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland" # Força o Chromium a correr nativamente em Wayland (ótimo para o Sway)
      "--ignore-gpu-blocklist"
      "--enable-zero-copy"
    ];
    extensions = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh"
    ];
  };
}
