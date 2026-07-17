;; -*- lexical-binding: t; -*-

;; UI chrome
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-startup-screen t)
(add-to-list 'default-frame-alist '(undecorated . t))

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
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;; Theme
(setq catppuccin-flavor 'mocha)
(load-theme 'catppuccin :no-confirm)

(defun my/reload-theme ()
  "Re-read the theme-engine's generated palette and reapply it."
  (interactive)
  (let ((data-file (expand-file-name "~/.local/share/theme-engine/emacs-theme.el")))
    (when (file-exists-p data-file)
      (load data-file)
      (dolist (pair my/theme-colors)
        (catppuccin-set-color (car pair) (cdr pair) 'mocha))
      (catppuccin-reload))))

(my/reload-theme)

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

;; Multi-cursor / same-occurrence editing
(require 'iedit)
(require 'multiple-cursors)
(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)

;; Jump to definition (needs a language server on PATH per major mode)
(add-hook 'prog-mode-hook 'eglot-ensure)

;; Project-wide find and replace
(require 'wgrep)
(require 'rg)
(rg-enable-default-bindings)

;; Major Modes
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))

;; Fontification
(setq treesit-font-lock-level 4)

;; PDF
(pdf-tools-install)
(add-hook 'pdf-view-mode-hook (lambda () (display-line-numbers-mode -1)))

;; Dashboard
(recentf-mode 1)
(defvar my/notes-directory "~/notes/daily/"
  "Directory where daily notes are stored.")

(defun my/daily-note ()
  "Open (or create) today's daily note."
  (interactive)
  (let* ((dir (expand-file-name my/notes-directory))
         (file (expand-file-name (format-time-string "%Y-%m-%d.org") dir)))
    (make-directory dir t)
    (find-file file)
    (when (zerop (buffer-size))
      (insert (format-time-string "#+TITLE: %Y-%m-%d\n\n")))))

(defvar my/dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "n") #'my/daily-note)
    (define-key map (kbd "i") (lambda () (interactive) (find-file user-init-file)))
    (define-key map (kbd "c") (lambda () (interactive) (dired (file-name-directory user-init-file))))
    map)
  "Keymap for `my/dashboard-mode'.")

(define-derived-mode my/dashboard-mode special-mode "Dashboard"
  "Major mode for the startup dashboard.")

(defun my/dashboard ()
  "Build (or rebuild) the startup dashboard buffer."
  (with-current-buffer (get-buffer-create "*dashboard*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (propertize "* Actions\n\n" 'face 'bold))
      (insert-text-button "- [n] New daily note"
                           'face 'link
                           'action (lambda (_) (my/daily-note))
                           'follow-link t)
      (insert "\n")
      (insert-text-button "- [i] Open init.el"
                           'face 'link
                           'action (lambda (_) (find-file user-init-file))
                           'follow-link t)
      (insert "\n")
      (insert-text-button "- [c] Open emacs config dir"
                           'face 'link
                           'action (lambda (_) (dired (file-name-directory user-init-file)))
                           'follow-link t)
      (insert "\n\n")
      (insert (propertize "* Projects\n\n" 'face 'bold))
      (let ((repos-dir (expand-file-name "~/repos/")))
        (if (file-directory-p repos-dir)
            (let ((projects (seq-filter #'file-directory-p
                                         (directory-files repos-dir t directory-files-no-dot-files-regexp))))
              (if projects
                  (dolist (dir (sort projects #'string<))
                    (insert-text-button (concat "- " (file-name-nondirectory (directory-file-name dir)))
                                         'face 'link
                                         'action (let ((d dir)) (lambda (_) (dired d)))
                                         'follow-link t)
                    (insert "\n"))
                (insert (propertize "  (none yet)\n" 'face 'shadow))))
          (insert (propertize "  (~/repos not found)\n" 'face 'shadow))))
      (insert "\n")
      (insert (propertize "* Recent Files\n\n" 'face 'bold))
      (if recentf-list
          (dolist (file (seq-take recentf-list 10))
            (insert-text-button (concat "- " (abbreviate-file-name file))
                                 'face 'link
                                 'action (let ((f file)) (lambda (_) (find-file f)))
                                 'follow-link t)
            (insert "\n"))
        (insert (propertize "  (none yet)\n" 'face 'shadow)))
      (my/dashboard-mode)
      (goto-char (point-min)))
    (current-buffer)))

(setq initial-buffer-choice #'my/dashboard)
