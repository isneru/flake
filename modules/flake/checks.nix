{ config, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      engine = ../theme-engine;

      hm =
        (config.flake.lib.mkPreviewHome pkgs (
          builtins.attrValues (
            removeAttrs config.flake.modules.homeManager [
              "theme-engine"
              "utils"
            ]
          )
        )).config;

      templates = pkgs.linkFarm "theme-engine-templates" (
        lib.mapAttrsToList (name: app: {
          name = "${name}.tmpl";
          path = pkgs.writeText "${name}.tmpl" app.template;
        }) hm.theme-engine.apps
      );

      appsJson = pkgs.writeText "apps.json" (
        builtins.toJSON (config.flake.lib.serializeThemeApps hm.theme-engine.apps)
      );
    in
    {
      checks.theme-render =
        pkgs.runCommand "theme-render-check"
          {
            env.PYTHONDONTWRITEBYTECODE = "1";
            nativeBuildInputs = [ pkgs.lua ];
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
