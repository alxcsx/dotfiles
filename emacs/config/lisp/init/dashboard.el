;;; dashboard.el --- splash screen-*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defun my/dashboard-open-if-no-files ()
  "Initialize and display dashboard only if no file arguments were given."
  (when (and (null command-line-args-left)
             (not noninteractive))
    (dashboard-insert-startupify-lists)
    (dashboard-initialize)))

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
  (add-hook 'elpaca-after-init-hook #'my/dashboard-open-if-no-files)
  (dashboard-setup-startup-hook))

(setq initial-buffer-choice
      (lambda ()
        (if (or (daemonp) (null command-line-args-left))
            (get-buffer-create "*dashboard*")
          (current-buffer))))

(provide 'init/dashboard)
;;; dashboard.el ends here
