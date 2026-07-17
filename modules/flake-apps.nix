{ config, inputs, ... }:
let
  style = import ../lib/style.nix;

  # A throwaway, out-of-tree Home Manager evaluation containing exactly one
  # aspect (plus the shared utils/theme-engine plumbing it needs to
  # type-check) - reused instead of hand-duplicating any app's settings, so a
  # `nix run` preview can never silently drift from what `just switch` would
  # actually produce. Only ever used to pull *values* (settings, plugin
  # lists) out of `.config` - no activation, no $HOME writes.
  mkPreviewHome =
    pkgs: extraModules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs style; };
      modules = [
        config.flake.modules.homeManager.utils
        config.flake.modules.homeManager.theme-engine
        {
          home.username = "preview";
          home.homeDirectory = "/tmp/theme-preview";
          home.stateVersion = "25.11";
        }
      ]
      ++ extraModules;
    };
in
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # $out/theme-engine/themes resolves the way theme_engine.py's own
      # XDG_CONFIG_HOME-derived THEMES_DIR expects to find it.
      previewConfigHome = pkgs.runCommand "theme-preview-config-home" { } ''
        mkdir -p $out/theme-engine
        ln -s ${../modules/theme-engine/themes} $out/theme-engine/themes
      '';

      # Renders one theme-engine app's template for a chosen theme straight
      # to a scratch file, reusing theme_engine.py's own load_theme/render so
      # a preview can never render differently than `theme-set` itself would.
      # Never touches $HOME/$XDG_CONFIG_HOME - the caller decides what to do
      # with the rendered file (usually: pass it to the app's own --config).
      renderTemplate = pkgs.writeShellScript "render-template" ''
                theme="$1" template="$2" target="$3"
                mkdir -p "$(dirname "$target")"
                XDG_CONFIG_HOME=${previewConfigHome} PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 - "$theme" "$template" "$target" <<'PY'
        import sys
        sys.path.insert(0, "${../modules/theme-engine}")
        import theme_engine
        theme, template, target = sys.argv[1:4]
        tokens = theme_engine.load_theme(theme)
        rendered = theme_engine.render(open(template).read(), tokens)
        open(target, "w").write(rendered)
        PY
      '';

      # Fonts bundled per-app via FONTCONFIG_FILE, not left to whatever's
      # installed system-wide - a `nix run` preview must render with the
      # right font regardless of the host it's run on.
      fontsConf = pkgs.makeFontsConf { fontDirectories = [ pkgs.nerd-fonts.caskaydia-cove ]; };

      mkArgParser = ''
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
    in
    {
      # kitty ships its own kitty.conf (HM-rendered, build time - font,
      # opacity, keybinds, ...) and the theme-engine's theme.conf (rendered
      # here, per invocation) as two explicit --config flags. No $HOME, no
      # XDG paths, no "include" directive relying on both files sharing a
      # directory.
      packages.kitty =
        let
          hmConfig = (mkPreviewHome pkgs [ config.flake.modules.homeManager.kitty ]).config;
          app = hmConfig.theme-engine.apps.kitty;
          templateFile = pkgs.writeText "kitty-theme.tmpl" app.template;
          # The live aspect's kitty.conf ends in "include theme.conf",
          # resolved relative to kitty.conf's own directory - meaningless
          # once kitty.conf is an immutable store path with no sibling
          # theme.conf next to it. Passing theme.conf as a second --config
          # achieves the same effect without that relative lookup.
          kittyConf = pkgs.writeText "kitty.conf" (
            lib.removeSuffix "include theme.conf\n" hmConfig.xdg.configFile."kitty/kitty.conf".text
          );
        in
        pkgs.writeShellApplication {
          name = "kitty";
          text = ''
            ${mkArgParser}
            themeConf=$(mktemp)
            trap 'rm -f "$themeConf"' EXIT
            ${renderTemplate} "$theme" ${templateFile} "$themeConf"
            export FONTCONFIG_FILE=${fontsConf}
            exec ${pkgs.kitty}/bin/kitty --config ${kittyConf} --config "$themeConf" "''${args[@]}"
          '';
        };

      # tofi's entire config is the theme-engine template - nothing else to
      # bundle beyond the rendered file itself and its font.
      packages.tofi =
        let
          hmConfig = (mkPreviewHome pkgs [ config.flake.modules.homeManager.tofi ]).config;
          app = hmConfig.theme-engine.apps.tofi;
          templateFile = pkgs.writeText "tofi.tmpl" app.template;
        in
        pkgs.writeShellApplication {
          name = "tofi";
          text = ''
            ${mkArgParser}
            conf=$(mktemp)
            trap 'rm -f "$conf"' EXIT
            ${renderTemplate} "$theme" ${templateFile} "$conf"
            export FONTCONFIG_FILE=${fontsConf}
            exec ${pkgs.tofi}/bin/tofi --config "$conf" "''${args[@]}"
          '';
        };

      # Plugins and config aren't discovered via $XDG_CONFIG_HOME (that's
      # exactly the live-checkout-dependent, XDG-convention-based lookup this
      # package is meant to avoid) - they're passed explicitly: -u points
      # straight at a bundled, immutable copy of modules/nvim, and --cmd
      # prepends every declared plugin's own store path onto runtimepath.
      # programs.neovim.finalPackage is still the base binary purely for its
      # extraPackages (LSP servers etc) being on PATH; its own config
      # discovery is entirely overridden by the flags below. The one
      # remaining $HOME use is unavoidable: modules/nvim/lua/neru/theme.lua
      # hardcodes `~/.local/share/theme-engine/nvim-theme.lua` (pcall-guarded
      # - falls back to unthemed catppuccin mocha if missing), so a scratch
      # $HOME is the only way to honor --theme for nvim's own colors without
      # forking that file for preview purposes.
      packages.nvim =
        let
          hmConfig = (mkPreviewHome pkgs [ config.flake.modules.homeManager.nvim ]).config;
          app = hmConfig.theme-engine.apps.nvim;
          templateFile = pkgs.writeText "nvim-theme.tmpl" app.template;
          rtp = lib.concatMapStringsSep "," (p: "${p}") hmConfig.programs.neovim.plugins;
        in
        pkgs.writeShellApplication {
          name = "nvim";
          text = ''
            ${mkArgParser}
            tmp=$(mktemp -d)
            trap 'rm -rf "$tmp"' EXIT
            export HOME="$tmp"
            ${renderTemplate} "$theme" ${templateFile} "$HOME/.local/share/theme-engine/nvim-theme.lua"
            exec ${hmConfig.programs.neovim.finalPackage}/bin/nvim \
              --cmd "set rtp^=${../modules/nvim},${rtp}" \
              -u ${../modules/nvim}/init.lua \
              "''${args[@]}"
          '';
        };
    };
}
