{ ... }:
{
  flake.modules.nixos.sc =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.jdk ];

      environment.variables.JAVA_HOME = pkgs.jdk.home;
    };

  flake.modules.homeManager.sc =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # keep-sorted start
        gradle
        jetbrains.idea
        maven
        # keep-sorted end
      ];
    };
}
