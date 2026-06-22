{ style, ... }:
{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: with epkgs; [
      # keep-sorted start
      catppuccin-theme
      magit
      marginalia
      orderless
      vertico
      # keep-sorted end
    ];
    extraConfig = ''
      ;; UI chrome
      (menu-bar-mode -1)
      (tool-bar-mode -1)
      (scroll-bar-mode -1)
      (setq inhibit-startup-screen t)

      ;; Files
      (setq make-backup-files nil)
      (setq auto-save-default t)
      (setq create-lockfiles nil)

      ;; Encoding
      (set-charset-priority 'unicode)
      (prefer-coding-system 'utf-8)
      (set-default-coding-systems 'utf-8)
      (set-terminal-coding-system 'utf-8)
      (set-keyboard-coding-system 'utf-8)

      ;; Editing
      (electric-pair-mode 1)
      (show-paren-mode 1)

      ;; Appearance
      (set-face-attribute 'default nil
        :family "${style.fonts.mono}"
        :height 160)
      (setq display-line-numbers-type 'relative)
      (global-display-line-numbers-mode 1)

      ;; Theme
      (setq catppuccin-flavor 'mocha)
      (load-theme 'catppuccin :no-confirm)

      ;; Completion
      (vertico-mode 1)
      (marginalia-mode 1)
      (require 'orderless)
      (setq completion-styles '(orderless basic))
      (setq completion-category-overrides
            '((file (styles basic partial-completion))))

      ;; Discovery
      (which-key-mode 1)

      ;; Dired
      (setq dired-listing-switches "-alh --group-directories-first")
      (setq dired-dwim-target t)
      (setq dired-auto-revert-buffer t)

      ;; Magit
      (global-set-key (kbd "C-x g") 'magit-status)
    '';
  };
}
