{ inputs, ... }:
let
  mkAskpass =
    pkgs:
    pkgs.writeShellApplication {
      name = "bare-askpass";
      runtimeInputs = [
        # keep-sorted start
        inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.coreutils
        pkgs.jq
        pkgs.libsecret
        pkgs.procps
        # keep-sorted end
      ];
      text = builtins.readFile ../../scripts/auth/askpass.sh;
    };
in
{
  flake.modules.nixos.auth =
    { pkgs, ... }:
    let
      bin = "${mkAskpass pkgs}/bin/bare-askpass";
    in
    {
      programs.ssh.askPassword = bin;

      environment.sessionVariables = {
        SSH_ASKPASS_REQUIRE = "prefer";

        GIT_ASKPASS = bin;

        SUDO_ASKPASS = bin;
      };
    };

  flake.modules.homeManager.auth = {
    programs.zsh.initContent = ''
      sudo() {
        if [[ -n $WAYLAND_DISPLAY && -z $SSH_CONNECTION ]]; then
          BARE_ASK_SOURCE=sudo command sudo -A "$@"
        else
          command sudo "$@"
        fi
      }
    '';
  };
}
