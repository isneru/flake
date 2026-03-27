{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  programs.zsh.enable = true;
}
