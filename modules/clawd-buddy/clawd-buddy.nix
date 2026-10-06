{ ... }:
{
  flake.modules.homeManager.clawd-buddy =
    { pkgs, utils, ... }:
    {
      home.file.".claude/skills/clawd-buddy".source =
        utils.create_symlink "${utils.dotfiles}/clawd-buddy/plugin";

      home.packages = [
        (pkgs.writeShellApplication {
          name = "clawd-demo";
          runtimeInputs = [ pkgs.nodejs ];
          text = ''exec node ${utils.dotfiles}/clawd-buddy/demo.mts "$@"'';
        })
      ];
    };
}
