;;; dashboard.el --- splash screen-*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defun my/dashboard-close-other-buffers ()
  "Kill all live buffers except the dashboard buffer itself and internal buffers."
  (let* ((name (if (boundp 'dashboard-buffer-name) dashboard-buffer-name "*dashboard*"))
         (dash-buf (get-buffer name)))
    (when (and dash-buf (eq (current-buffer) dash-buf))
      (delete-other-windows)
      (dolist (buf (buffer-list))
        (unless (or (eq buf dash-buf)
                    (string-prefix-p " " (buffer-name buf))
                    (string= (buffer-name buf) "*Messages*")
                    (string= (buffer-name buf) "*elpaca-log*"))
          (ignore-errors
            (with-current-buffer buf
              (when (and (buffer-modified-p) (buffer-file-name))
                (save-buffer)))
            (kill-buffer buf)))))))

(defun my/dashboard-open-if-no-files ()
  "Initialize and display dashboard only if no file arguments were given."
  (when (and (null command-line-args-left)
             (not noninteractive))
    (dashboard-insert-startupify-lists)
    (dashboard-initialize)
    (my/dashboard-close-other-buffers)))

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
  (add-hook 'dashboard-after-initialize-hook #'my/dashboard-close-other-buffers)
  (dashboard-setup-startup-hook))

(setq initial-buffer-choice
      (lambda ()
        (if (or (daemonp) (null command-line-args-left))
            (get-buffer-create "*dashboard*")
          (current-buffer))))

(provide 'init/dashboard)
;;; dashboard.el ends here
