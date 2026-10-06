{ ... }:
{
  flake.modules.nixos.packages =
    { pkgs, ... }:
    {
      programs.wireshark = {
        enable = true;
        package = pkgs.wireshark;
      };
    };

  flake.modules.homeManager.packages =
    { pkgs, ... }:
    let
      monitor =
        name:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [
            # keep-sorted start
            iproute2
            iw
            # keep-sorted end
          ];
          text = builtins.readFile ./${name}.sh;
        };
    in
    {
      home.packages = [
        (monitor "start-monitor")
        (monitor "stop-monitor")
      ]
      ++ (with pkgs; [
        # keep-sorted start
        ani-cli
        ani-skip
        eduvpn-client
        insomnia
        nmap
        wavemon
        # keep-sorted end
      ]);
    };
}
