{ config, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      hm = config.flake.nixosConfigurations.victus.config.home-manager.users.neru;
      engine = ./theme-engine;

      templates = pkgs.linkFarm "theme-engine-templates" (
        lib.mapAttrsToList (name: app: {
          name = "${name}.tmpl";
          path = pkgs.writeText "${name}.tmpl" app.template;
        }) hm.theme-engine.apps
      );

      appsJson = pkgs.writeText "apps.json" (
        builtins.toJSON (lib.mapAttrs (_: app: { inherit (app) target reload; }) hm.theme-engine.apps)
      );
    in
    {
      # Renders every theme against every registered template and shader;
      # fails on missing required theme keys or leftover {{tokens}}, so a
      # broken theme or template is caught by `just check`, not live.
      checks.theme-render =
        pkgs.runCommand "theme-render-check"
          {
            env.PYTHONDONTWRITEBYTECODE = "1";
          }
          ''
            mkdir config
            mkdir config/theme-engine
            ln -s ${engine}/themes config/theme-engine/themes
            ln -s ${templates} config/theme-engine/templates
            ln -s ${appsJson} config/theme-engine/apps.json
            XDG_CONFIG_HOME=$PWD/config ${pkgs.python3}/bin/python3 ${engine}/check_render.py
            touch $out
          '';
    };
}
