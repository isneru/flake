{ ... }:
{
  flake.modules.nixos.virtualisation = {
    users.users.neru.extraGroups = [ "libvirtd" ];
    virtualisation.libvirtd = {
      enable = true;
      onShutdown = "shutdown";
    };
    programs.virt-manager.enable = true;
    networking.firewall.trustedInterfaces = [ "virbr0" ];
  };
}
