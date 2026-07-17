{ ... }:
{
  flake.modules.homeManager.emacs =
    {
      style,
      pkgs,
      utils,
      ...
    }:
    {
      programs.emacs = {
        enable = true;
        package = pkgs.emacs-pgtk;
        extraPackages =
          epkgs: with epkgs; [
            # keep-sorted start
            catppuccin-theme
            iedit
            magit
            marginalia
            multiple-cursors
            nix-mode
            orderless
            pdf-tools
            rg
            vertico
            wgrep
            which-key
            # keep-sorted end
          ];
        extraConfig = ''
          ;; Font (Nix-interpolated, kept out of the live-reloaded init.el).
          ;; :height is 10x the point size, tied to the shared style font size.
          (set-face-attribute 'default nil
            :family "${style.fonts.mono}"
            :height ${toString (style.fonts.size * 10)})
        '';
      };

      services.emacs.enable = true;

      xdg.configFile."emacs".source = utils.create_symlink "${utils.dotfiles}/emacs";

      theme-engine.apps.emacs = {
        target = "~/.local/share/theme-engine/emacs-theme.el";
        reload = [
          "emacsclient"
          "--eval"
          "(my/reload-theme)"
        ];
      };
      theme-engine.apps.emacs.template = ''
        (setq my/theme-colors
          '((base . "{{bg}}")
            (mantle . "{{bgDim}}")
            (surface0 . "{{bgAlt}}")
            (surface1 . "{{border}}")
            (text . "{{fg}}")
            (subtext1 . "{{fgDim}}")
            (overlay0 . "{{fgMuted}}")
            (mauve . "{{accent}}")
            (red . "{{red}}")
            (yellow . "{{warning}}")
            (green . "{{success}}")
            (sky . "{{info}}")
            (peach . "{{orange}}")
            (blue . "{{blue}}")))
      '';
    };
}
