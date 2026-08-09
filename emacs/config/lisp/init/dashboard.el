;;; dashboard.el --- splash screen-*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


(use-package dashboard
  :init
  (setq dashboard-startup-banner 'logo-braille
        dashboard-center-content t
        dashboard-items '((projects . 5)
                          (recents . 10))
        dashboard-icon-type 'nerd-icons
        dashboard-display-icons-p t
        dashboard-set-file-icons t
        dashboard-set-heading-icons t
        dashboard-projects-backend 'project-el
        dashboard-projects-switch-function 'dired)
  :config
  (add-hook 'elpaca-after-init-hook #'dashboard-insert-startupify-lists)
  (add-hook 'elpaca-after-init-hook #'dashboard-initialize)
  (dashboard-setup-startup-hook))

(setq initial-buffer-choice 'dashboard-open)

(provide 'init/dashboard)
;;; dashboard.el ends here
