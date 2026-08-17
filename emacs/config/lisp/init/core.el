;;; core.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; Load Environment Variables
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x pgtk))
  :defer 0.1
  :config
  (setq exec-path-from-shell-variables '("PATH" "MANPATH"))
  (setq exec-path-from-shell-arguments '("-l"))
  (exec-path-from-shell-initialize))


(use-package no-littering
  :config
  (no-littering-theme-backups)
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t))))


;; disable network lock-files
(setq create-lockfiles nil
      ring-bell-function 'ignore)

(use-package gcmh
  :init
  (setq gcmh-idle-delay 5
        gcmh-high-cons-threshold (* 64 1024 1024))
  :config
  (gcmh-mode 1))

(use-package recentf
  :ensure nil
  :after no-littering
  :config
  (recentf-mode 1)
  :custom
  (recentf-max-saved-items 100))

(use-package trust-manager
  :ensure t
  :config
  (trust-manager-mode 1))


;; Auto-kill old buffers
(use-package midnight
  :ensure nil
  :config
  (midnight-mode 1)
  (setq clean-buffer-list-delay-general 3))

;; MACOS Optimization
(setq inhibit-compacting-font-caches t)
(global-so-long-mode 1)
;; Use GNU tools instead of deafult mac tools.
(when (eq system-type 'darwin)
  (when-let* ((brew-bin (executable-find "brew"))
              (prefix (string-trim (shell-command-to-string (format "%s --prefix" brew-bin))))
              (gnubin (expand-file-name "opt/coreutils/libexec/gnubin" prefix)))
    (when (file-directory-p gnubin)
      (add-to-list 'exec-path gnubin)
      (setenv "PATH" (concat gnubin ":" (getenv "PATH"))))))

(provide 'init/core)
;;; core.el ends here
