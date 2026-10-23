{
  flake.modules.homeManager.neru =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      table =
        name: value:
        "declare -A ${name}=(\n"
        + lib.concatStrings (
          lib.mapAttrsToList (
            key: command: "  [${lib.escapeShellArg key}]=${lib.escapeShellArg (value command)}\n"
          ) config.neru.commands
        )
        + ")\n";

      neru = pkgs.writeShellApplication {
        name = "neru";
        runtimeInputs = [ pkgs.coreutils ];
        text =
          table "commands" (command: lib.getExe command.package)
          + table "descs" (command: command.desc)
          + builtins.readFile ../../scripts/neru/neru.sh;
      };
    in
    {
      options.neru.commands = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              package = lib.mkOption {
                type = lib.types.package;
                description = "Package whose main program this subcommand runs.";
              };
              desc = lib.mkOption {
                type = lib.types.str;
                description = "One line shown by `neru help` and the zsh completion.";
              };
            };
          }
        );
        default = { };
        description = "Subcommands of `neru`, keyed by one word or `group word`.";
      };

      config.home.packages = [
        (pkgs.symlinkJoin {
          name = "neru";
          paths = [
            neru
            (pkgs.writeTextDir "share/zsh/site-functions/_neru" (builtins.readFile ../../scripts/neru/_neru))
          ];
        })
      ];
    };
}
