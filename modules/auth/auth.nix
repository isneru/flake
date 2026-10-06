{ inputs, ... }:
let
  mkAskpass =
    pkgs:
    pkgs.writeShellApplication {
      name = "notch-askpass";
      runtimeInputs = [
        # keep-sorted start
        inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.coreutils
        pkgs.jq
        pkgs.libsecret
        pkgs.procps
        # keep-sorted end
      ];
      text = builtins.readFile ./askpass.sh;
    };
in
{
  flake.modules.nixos.auth =
    { pkgs, ... }:
    let
      bin = "${mkAskpass pkgs}/bin/notch-askpass";
    in
    {
      programs.ssh.askPassword = bin;

      environment.sessionVariables = {
        SSH_ASKPASS_REQUIRE = "prefer";

        GIT_ASKPASS = bin;

        SUDO_ASKPASS = bin;
      };
    };

  flake.modules.homeManager.auth =
    { pkgs, ... }:
    {
      home.packages = [ (mkAskpass pkgs) ];

      programs.zsh.initContent = ''
        sudo() {
          if [[ -n $WAYLAND_DISPLAY ]]; then
            NOTCH_ASK_SOURCE=sudo command sudo -A "$@"
          else
            command sudo "$@"
          fi
        }
      '';
    };
}
