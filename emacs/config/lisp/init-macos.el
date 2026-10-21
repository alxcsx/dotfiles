;;; init-macos.el --- macos specific properties -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(setq insert-directory-program "gls"
      dired-use-ls-dired t)


(setq mac-command-modifier 'control)
(setq mac-option-modifier 'meta)
(setq mac-control-modifier 'control)

;; Fix macOS Nextstep display matching in server.el so emacsclient -r reuses existing GUI frames
(defun my/server--on-display-p (orig-fn frame display)
  "Fix display matching on macOS Nextstep GUI so emacsclient -r reuses frames."
  (or (funcall orig-fn frame display)
      (and (equal display "ns")
           (eq (framep frame) 'ns))))

(advice-add 'server--on-display-p :around #'my/server--on-display-p)

;; Raise and focus frame on macOS when client opens a buffer
(add-hook 'server-switch-hook
          (lambda ()
            (when (eq window-system 'ns)
              (select-frame-set-input-focus (selected-frame)))))

(provide 'init-macos)
;;; init-macos.el ends here
