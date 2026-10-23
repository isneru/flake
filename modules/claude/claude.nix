{ ... }:
{
  flake.modules.homeManager.claude =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    {
      home.file.".claude/skills/mascot" = lib.mkIf (config.systemd.user.services ? quickshell) {
        source = utils.create_symlink "${utils.dotfiles}/claude/mascot";
      };
      home.file.".claude/skills/readable".source =
        utils.create_symlink "${utils.dotfiles}/claude/readable";

      neru.commands.render = {
        package = pkgs.writeShellApplication {
          name = "readable-render";
          runtimeInputs = with pkgs; [
            imagemagick
            mermaid-cli
            plantuml
            (texliveBasic.withPackages (
              ps: with ps; [
                cancel
                jknapltx
                mathtools
                rsfs
                stmaryrd
                xcolor
              ]
            ))
            typst
          ];
          text = builtins.readFile ../../scripts/claude/render.sh;
        };
        desc = "render a diagram or formula to PNG (Claude's readable mod)";
      };
    };
}
