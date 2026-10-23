{ ... }:
{
  flake.modules.homeManager.sc =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.renpy ];
    };
}
