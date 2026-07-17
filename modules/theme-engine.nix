{ ... }:
{
  flake.modules.homeManager.theme-engine =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.theme-engine;

      theme-set = pkgs.writeShellApplication {
        name = "theme-set";
        runtimeInputs = [
          pkgs.python3
          pkgs.libnotify
          pkgs.kitty
          pkgs.swaynotificationcenter
          pkgs.dconf
          pkgs.procps
          # The same emacs the daemon runs (emacs-pgtk), not pkgs.emacs - only
          # emacsclient is needed here, and pulling plain emacs would drag a
          # second full Emacs into the closure.
          config.programs.emacs.finalPackage
          pkgs.systemd
          config.programs.noctalia.package
        ];
        text = ''exec python3 ${./theme-engine/theme_engine.py} "$@"'';
      };
    in
    {
      # Each app module registers itself here instead of editing a Python-side
      # list: the option is serialized to apps.json for theme-set, and the
      # template lands in templates/<name>.tmpl automatically.
      options.theme-engine.apps = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              template = lib.mkOption {
                type = lib.types.lines;
                description = "Template text with {{token}} placeholders.";
              };
              target = lib.mkOption {
                type = lib.types.str;
                description = "Path the rendered template is written to (~ is expanded).";
              };
              reload = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = "Command run after every template has been written.";
              };
            };
          }
        );
        default = { };
        description = "Apps themed by the runtime theme engine.";
      };

      config = {
        home.packages = [ theme-set ];

        home.file =
          lib.mapAttrs' (name: app: {
            name = ".config/theme-engine/templates/${name}.tmpl";
            value.text = app.template;
          }) cfg.apps
          // {
            ".config/theme-engine/apps.json".text = builtins.toJSON (
              lib.mapAttrs (_: app: { inherit (app) target reload; }) cfg.apps
            );
          };

        # Symlinked as a whole folder, same as driftwm's shaders/ dir - dropping a
        # new theme .toml in here works with zero rebuild, matching how theme-set
        # already scans this dir at runtime.
        xdg.configFile."theme-engine/themes".source =
          utils.create_symlink "${utils.dotfiles}/theme-engine/themes";

        # Re-apply whatever theme was last picked on every activation, so a `just
        # switch` doesn't reset the live theme back to a Nix default (reapply
        # seeds the default theme on the first-ever run). Must run after
        # `linkGeneration`, which is what actually creates the seeded
        # theme/template files on disk.
        home.activation.applyTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD ${theme-set}/bin/theme-set reapply
        '';
      };
    };
}
