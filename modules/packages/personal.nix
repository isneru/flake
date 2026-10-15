{ ... }:
{
  flake.modules.nixos.packages =
    { pkgs, ... }:
    {
      users.users.neru.extraGroups = [
        # keep-sorted start
        "dialout"
        "wireshark"
        # keep-sorted end
      ];

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
        arduino-ide
        eduvpn-client
        insomnia
        nmap
        processing
        wavemon
        # keep-sorted end
      ]);
    };
}
