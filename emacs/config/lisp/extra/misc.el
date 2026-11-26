;;; misc.el -- -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defun my/discord-running-p ()
  "Non-nil when a Discord IPC socket exists (i.e. Discord is running)."
  (seq-some (lambda (dir)
              (and dir (directory-files dir nil "\\`discord-ipc-")))
            (list (getenv "XDG_RUNTIME_DIR") (getenv "TMPDIR") "/tmp")))

(use-package elcord
  :if (my/discord-running-p)
  :init
  (setq elcord-refresh-rate 300  ; presence update every 5 minutes
        elcord-idle-timer 600    ; "idle" status after 10 minutes
        elcord-quiet t)          ; don't spam *Messages*
  (elcord-mode t))

;; (require 'extra/unchanged)

(provide 'extra/misc)
;;; misc.el ends here
