{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;

    age.sshKeyPaths = [ "/home/neru/.ssh/id_ed25519" ];
  };
}
