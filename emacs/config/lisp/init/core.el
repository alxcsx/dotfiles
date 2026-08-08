;;; core.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(use-package no-littering
  :config
  (no-littering-theme-backups)
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t))))


;; disable network lock-files
(setq create-lockfiles nil)

(setq ring-bell-function 'ignore)

(use-package gcmh
  :init
  (gcmh-mode 1))

(use-package recentf
  :ensure nil
  :after no-littering
  :config
  (recentf-mode 1)
  :custom
  (recentf-max-saved-items 100))

(provide 'init/core)
;;; core.el ends here
