;;; core.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; Mise & Shell Environment Variables
(defun my/load-mise-env ()
  "Load mise environment variables and shims into Emacs without an interactive shell."
  (when-let* ((mise-bin (or (executable-find "mise")
                            (expand-file-name "~/.local/bin/mise")))
              (json (ignore-errors
                      (with-temp-buffer
                        (when (zerop (call-process mise-bin nil t nil "env" "--json"))
                          (goto-char (point-min))
                          (json-parse-buffer :object-type 'alist))))))
    (dolist (pair json)
      (let ((var (symbol-name (car pair)))
            (val (cdr pair)))
        (setenv var val)
        (when (string= var "PATH")
          (setq exec-path (append (parse-colon-path val) (list exec-directory))))))))

(my/load-mise-env)

(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x pgtk))
  :demand t
  :custom
  (exec-path-from-shell-arguments '("-l"))
  (exec-path-from-shell-variables '("PATH" "MANPATH" "MISE_SHELL" "MISE_DATA_DIR"))
  :config
  (exec-path-from-shell-initialize))

(use-package envrc
  :ensure t
  :hook (after-init . envrc-global-mode))

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

;; Restore normal GC percentage after startup
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-percentage 0.1)))

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

;; System clipboard integration (supports GUI and terminal/emacs -nw)
(setq select-enable-clipboard t
      save-interprogram-paste-before-kill t)

(defun my/clipboard-cut (text)
  "Copy TEXT to the system clipboard in GUI and terminal frames."
  (if (display-graphic-p)
      (gui-select-text text)
    (cond
     ((executable-find "wl-copy")
      (let ((process-connection-type nil))
        (let ((proc (start-process "wl-copy" nil "wl-copy")))
          (process-send-string proc text)
          (process-send-eof proc))))
     ((executable-find "xclip")
      (let ((process-connection-type nil))
        (let ((proc (start-process "xclip" nil "xclip" "-selection" "clipboard")))
          (process-send-string proc text)
          (process-send-eof proc))))
     ((executable-find "pbcopy")
      (let ((process-connection-type nil))
        (let ((proc (start-process "pbcopy" nil "pbcopy")))
          (process-send-string proc text)
          (process-send-eof proc)))))))

(defun my/clipboard-paste ()
  "Paste text from the system clipboard in GUI and terminal frames."
  (if (display-graphic-p)
      (gui-selection-value)
    (cond
     ((executable-find "wl-paste")
      (with-temp-buffer
        (when (zerop (call-process "wl-paste" nil t nil "--no-newline"))
          (let ((text (buffer-string)))
            (unless (string-empty-p text)
              text)))))
     ((executable-find "xclip")
      (with-temp-buffer
        (when (zerop (call-process "xclip" nil t nil "-selection" "clipboard" "-o"))
          (let ((text (buffer-string)))
            (unless (string-empty-p text)
              text)))))
     ((executable-find "pbpaste")
      (with-temp-buffer
        (when (zerop (call-process "pbpaste" nil t nil))
          (let ((text (buffer-string)))
            (unless (string-empty-p text)
              text))))))))

(setq interprogram-cut-function #'my/clipboard-cut
      interprogram-paste-function #'my/clipboard-paste)

;; MACOS Optimization
(setq inhibit-compacting-font-caches t)
(global-so-long-mode 1)
;; Use GNU tools instead of default mac tools.
(when (eq system-type 'darwin)
  (let* ((prefix (cond ((file-directory-p "/opt/homebrew") "/opt/homebrew")
                       ((file-directory-p "/usr/local") "/usr/local")
                       ((executable-find "brew")
                        (string-trim (shell-command-to-string "brew --prefix")))))
         (gnubin (when prefix (expand-file-name "opt/coreutils/libexec/gnubin" prefix))))
    (when (and gnubin (file-directory-p gnubin))
      (add-to-list 'exec-path gnubin)
      (setenv "PATH" (concat gnubin ":" (getenv "PATH"))))))


;; Tools

(defmacro cmd (&rest body)
  "Shortcut to create an interactive lambda with no arguments."
  `(lambda ()
     (interactive "^")
     ,@body))

(provide 'init/core)
;;; core.el ends here
