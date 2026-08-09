;;; terminal.el --- terminal config -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'project)

(defun my/toggle-terminal ()
  "Toggle a project-aware vterm terminal window."
  (interactive)
  (let* ((proj (project-current))
         (start-dir (cond
                     ((eq major-mode 'dashboard-mode) "~/")
                     (proj (project-root proj)) ; If in a project, use project root
                     (t default-directory)))    ; Otherwise, use current folder
         (proj-name (when proj (file-name-nondirectory (directory-file-name start-dir))))
         (buf-name (if proj (format "*vterm*<%s>" proj-name) "*vterm*"))
         (existing-win (get-buffer-window buf-name)))
    (cond
     (existing-win (delete-window existing-win))      ; If visible, hide it
     ((get-buffer buf-name) (pop-to-buffer buf-name)) ; If hidden, show it
     (t (let ((default-directory start-dir) (switch-to-buffer-obey-display-actions t))
          (save-window-excursion (vterm buf-name)) ; Pass our custom name to vterm
          (pop-to-buffer buf-name))))))

(use-package vterm
  :custom
  ;; Tell vterm to kill the buffer when the background shell exits
  (vterm-kill-buffer-on-exit t)
  :bind
  (("C-c t" . my/toggle-terminal))
  :config
  ;; Opens the terminal as vertical split
  (add-to-list 'display-buffer-alist
               '("^\\*vterm\\*"
                 (display-buffer-in-direction)
                 (direction . bottom)
                 (window-height . 0.3)
                 (dedicated . t))))

(provide 'extra/terminal)
;;; terminal.el ends here
