{ ... }:
{
  flake.modules.homeManager.zathura =
    {
      config,
      lib,
      pkgs,
      style,
      ...
    }:
    let
      theme = "${config.xdg.configHome}/zathura/theme";
      state = "${config.xdg.stateHome}/zathura/mode";

      zathura-mode = pkgs.writeShellApplication {
        name = "zathura-mode";
        runtimeInputs = with pkgs; [
          # keep-sorted start
          coreutils
          systemd
          # keep-sorted end
        ];
        text = builtins.readFile ./zathura-mode.sh;
      };
    in
    {
      home.packages = [ zathura-mode ];

      programs.zathura = {
        enable = true;
        options = {
          selection-notification = true;
          guioptions = "none";
        };
        mappings."<C-r>" = "exec zathura-mode";
        extraConfig = ''
          include ${theme}
          include ${state}
        '';
      };

      xdg.configFile = {
        "zathura/modes/light".text = ''
          set recolor false
        '';
        "zathura/modes/dark".text = ''
          set recolor true
          set recolor-keephue true
          set recolor-lightcolor "#000000"
          set recolor-darkcolor "#ffffff"
        '';
        "zathura/modes/theme".text = ''
          set recolor true
          set recolor-keephue false
        '';
      };

      home.activation.zathuraMode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e ${lib.escapeShellArg state} ]; then
          $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg (dirOf state)}
          $DRY_RUN_CMD ln -sfn ${lib.escapeShellArg "${config.xdg.configHome}/zathura/modes/theme"} ${lib.escapeShellArg state}
        fi
      '';

      theme-engine.apps.zathura = {
        target = "~/.config/zathura/theme";
        reload = [
          "zathura-mode"
          "reload"
        ];
        template = ''
          set font "{{mono}} ${toString style.fonts.sizeUi}"

          set default-fg "{{fg}}"
          set default-bg "{{bg}}"

          set statusbar-fg "{{fg}}"
          set statusbar-bg "{{bgDim}}"
          set inputbar-fg "{{fg}}"
          set inputbar-bg "{{bg}}"

          set completion-fg "{{fg}}"
          set completion-bg "{{bgAlt}}"
          set completion-group-fg "{{fgDim}}"
          set completion-group-bg "{{bgDim}}"
          set completion-highlight-fg "{{bg}}"
          set completion-highlight-bg "{{accent}}"

          set notification-fg "{{fg}}"
          set notification-bg "{{bg}}"
          set notification-error-fg "{{error}}"
          set notification-error-bg "{{bg}}"
          set notification-warning-fg "{{warning}}"
          set notification-warning-bg "{{bg}}"

          set index-fg "{{fg}}"
          set index-bg "{{bg}}"
          set index-active-fg "{{fg}}"
          set index-active-bg "{{bgAlt}}"

          set render-loading-fg "{{fgMuted}}"
          set render-loading-bg "{{bg}}"

          set highlight-fg "{{fg}}"
          set highlight-color "rgba({{fgMutedRgb}}, 0.3)"
          set highlight-active-color "rgba({{accentRgb}}, 0.3)"

          set signature-success-color "{{success}}"
          set signature-warning-color "{{warning}}"
          set signature-error-color "{{error}}"

          set recolor-lightcolor "{{bg}}"
          set recolor-darkcolor "{{fg}}"
        '';
      };
    };
}
