{ ... }:
{
  imports = [
    ./config
    ./cli.nix
    ./theme.nix
    ./packages.nix
  ];

  home.stateVersion = "25.11";
}
