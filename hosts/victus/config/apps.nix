{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  programs.zsh.enable = true;
  programs.nix-ld.enable = true;
  programs.localsend.enable = true;
}
