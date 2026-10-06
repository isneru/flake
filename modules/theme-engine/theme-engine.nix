{ lib, ... }:
let
  serializeApps = lib.mapAttrs (_: app: { inherit (app) target reload; });
in
{
  flake.lib.serializeThemeApps = serializeApps;

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
          (pkgs.python3.withPackages (ps: [ ps.pillow ]))
          pkgs.awww
          pkgs.libnotify
          pkgs.kitty
          pkgs.dconf
        ];
        text = ''exec python3 ${./theme_engine.py} "$@"'';
      };
    in
    {
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
            ".config/theme-engine/apps.json".text = builtins.toJSON (serializeApps cfg.apps);
          };

        xdg.configFile."theme-engine/themes".source =
          utils.create_symlink "${utils.dotfiles}/theme-engine/themes";

        home.activation.applyTheme =
          lib.hm.dag.entryAfter
            [
              "linkGeneration"
              "dconfSettings"
            ]
            ''
              $DRY_RUN_CMD ${theme-set}/bin/theme-set reapply
            '';
      };
    };
}
