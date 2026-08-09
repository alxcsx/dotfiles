;;; tools.el -- --*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


;;; Load Environment Variables
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x pgtk))
  :config
  (exec-path-from-shell-initialize))

;;; Keybinding Discoverability
(if (fboundp 'which-key-mode)
    (which-key-mode 1)
  (use-package which-key
    :init
    (which-key-mode 1)))

;;; Better Describe
(use-package helpful
  :bind
  (("C-h f" . helpful-callable)
   ("C-h v" . helpful-variable)
   ("C-h k" . helpful-key)
   ("C-h C" . helpful-command)
   ("C-c C-d" . helpful-at-point)))

;;; Magit
(use-package transient)

(use-package magit
  :after transient
  :bind
  (("C-x g" . magit-status)
   ("C-x M-g" . magit-dispatch))
  :config
  (when (featurep 'nerd-icons) (setq magit-format-file-function #'magit-format-file-nerd-icons))
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;;; Pinentry
;; allow passphrase prompts inside of emacs instead of external popups.
(use-package pinentry
  :init
  (setq epa-pinentry-mode 'loopback)
  (pinentry-start))

;; Highlight symbols
(use-package idle-highlight-mode
  :ensure t
  :hook ((prog-mode . idle-highlight-mode)
         (text-mode . idle-highlight-mode)))

;; Click to go to definition
(require 'ffap)
(global-set-key (kbd "C-<down-mouse-1>") #'ffap-at-mouse)

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-force-searcher 'rg)
  :init
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
  :bind
  (("C-M-." . dumb-jump-go)
   ("C-M-," . dumb-jump-back)))


;; Mise
(use-package mise
  :if (executable-find "mise")
  :init
  (global-mise-mode 1))

;; Project Identification
(use-package project
  :ensure nil
  :custom
  (project-vc-extra-root-markers
   '(
     ".project"
     "mise.toml"
     ".mise.toml"
     ".tool-versions")))


(defun my/project-info ()
  "Print the current project root, or warn if not in a project."
  (interactive)
  (if-let ((proj (project-current)))
      (message "Current project root: %s" (project-root proj))
    (message "Not in a recognized project!")))

;;; Dirvish
(defun my/toggle-project-tree ()
  "Toggle Dirvish side tree, defaulting to ~ when on the dashboard."
  (interactive)
  (let ((tree-is-open (seq-find (lambda (w)
                                  (and (window-parameter w 'window-side)
                                       (with-current-buffer (window-buffer w)
                                         (derived-mode-p 'dired-mode))))
                                (window-list))))
    (if tree-is-open
        (dirvish-side) ; 1. If it's already open anywhere, close it!

      (let ((default-directory (if (eq major-mode 'dashboard-mode)
                                   (expand-file-name "~/")
                                 default-directory)))
        (dirvish-side)))))

(defun my/dirvish-smart-enter ()
  "Toggle subtree for folders. Open files and close the sidebar."
  (interactive)
  (let ((file (dired-get-filename nil t)))
    (if (and file (file-directory-p file))
        (dirvish-subtree-toggle)
      (call-interactively #'dired-find-file) ; default behaviour

      (let ((tree-win (seq-find (lambda (w) (window-parameter w 'window-side))
                                (window-list))))
        (when tree-win
          (delete-window tree-win))))))

(defun my/dirvish-smart-space ()
  "Toggle subtree if on a folder, do nothing on a file."
  (interactive)
  (let ((file (dired-get-filename nil t)))
    (when (and file (file-directory-p file))
      (dirvish-subtree-toggle))))

(use-package dirvish
  :init
  (dirvish-override-dired-mode)
  :custom

  (dired-listing-switches "-lAh --group-directories-first")
  (dired-kill-when-opening-new-dired-buffers t)
  (dirvish-attributes '(nerd-icons collapse subtree-state vc-state git-msg))
  (dirvish-side-width 25)
  (dirvish-hide-cursor t)
  :bind
  (("C-c e" . my/toggle-project-tree)
   :map dirvish-mode-map
   ("TAB" . dirvish-subtree-toggle)
   ("a"   . dirvish-layout-toggle)
   ("<backspace>" . dired-up-directory)
   ("<return>"    . my/dirvish-smart-enter)
   ("SPC"         . my/dirvish-smart-space)
   ("<S-return>"  . dired-find-file)))

;; Update Files when they change on disk
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)

;; Remember cursor position across sessions
(save-place-mode 1)

(provide 'init/tools)
;;; tools.el ends here
