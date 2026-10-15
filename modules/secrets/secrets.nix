{ ... }:
{
  flake.modules.nixos.secrets = {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      age.keyFile = "/var/lib/sops-nix/key.txt";
    };
  };

  flake.modules.homeManager.secrets =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # keep-sorted start
        age
        sops
        # keep-sorted end
      ];
    };
}
