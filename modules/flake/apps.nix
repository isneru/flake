{ config, lib, ... }:
{
  options.flake.previews = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            aspects = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ name ];
              description = "Home Manager aspects to evaluate for this preview.";
            };
            build = lib.mkOption {
              type = lib.types.functionTo lib.types.package;
              description = "Takes the preview context, returns the runnable package.";
            };
          };
        }
      )
    );
    default = { };
    description = "Apps exposed as `nix run .#<name>`.";
  };

  config.perSystem =
    { pkgs, lib, ... }:
    let
      previewConfigHome = pkgs.runCommand "theme-preview-config-home" { } ''
        mkdir -p $out/theme-engine
        ln -s ${../theme-engine/themes} $out/theme-engine/themes
      '';

      render = pkgs.writeShellScript "render-template" ''
                theme="$1" template="$2" target="$3"
                mkdir -p "$(dirname "$target")"
                XDG_CONFIG_HOME=${previewConfigHome} PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 - "$theme" "$template" "$target" <<'PY'
        import sys
        sys.path.insert(0, "${../theme-engine}")
        import theme_engine
        theme, template, target = sys.argv[1:4]
        tokens = theme_engine.load_theme(theme)
        rendered = theme_engine.render(open(template).read(), tokens)
        open(target, "w").write(rendered)
        PY
      '';

      argParser = ''
        theme="mocha"
        args=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --theme)
              theme="$2"
              shift 2
              ;;
            *)
              args+=("$1")
              shift
              ;;
          esac
        done
      '';

      ctxFor = preview: {
        inherit
          pkgs
          lib
          render
          argParser
          ;

        fontsConf = fonts: pkgs.makeFontsConf { fontDirectories = fonts; };

        mkApp =
          {
            name,
            runtimeInputs ? [ ],
            text,
          }:
          pkgs.writeShellApplication { inherit name runtimeInputs text; };

        hm =
          (config.flake.lib.mkPreviewHome pkgs (
            map (a: config.flake.modules.homeManager.${a}) (
              lib.subtractLists [
                "theme-engine"
                "utils"
              ] preview.aspects
            )
          )).config;
      };
    in
    {
      packages = lib.mapAttrs (_: preview: preview.build (ctxFor preview)) config.flake.previews;
    };
}
