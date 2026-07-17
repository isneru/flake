;; Keep Emacs's runtime state (auto-save-list, eln-cache, recentf, etc.) out of
;; this symlinked config directory - it must run before anything else needs
;; user-emacs-directory.
(setq user-emacs-directory (expand-file-name "~/.cache/emacs/"))
