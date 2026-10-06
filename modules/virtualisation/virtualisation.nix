{ ... }:
{
  flake.modules.nixos.virtualisation = {
    virtualisation.libvirtd = {
      enable = true;
      onShutdown = "shutdown";
    };
    programs.virt-manager.enable = true;
    networking.firewall.trustedInterfaces = [ "virbr0" ];
  };
}
