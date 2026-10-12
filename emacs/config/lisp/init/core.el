;;; core.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; Shell Environment Variables (mise itself is handled per-buffer by mise.el in tools.el)
(use-package exec-path-from-shell
  :if (or (daemonp) (memq window-system '(mac ns x pgtk)))
  :demand t
  :custom
  (exec-path-from-shell-arguments '("-l"))
  (exec-path-from-shell-variables '("PATH" "MANPATH" "MISE_SHELL" "MISE_DATA_DIR" "DOTNET_ROOT" "DOTNET_CLI_HOME"))
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

(defun my/clipboard-command (paste)
  "Return the first available clipboard argv for copying, or pasting if PASTE."
  (seq-find (lambda (argv) (executable-find (car argv)))
            (if paste
                '(("wl-paste" "--no-newline") ("xclip" "-selection" "clipboard" "-o") ("pbpaste"))
              '(("wl-copy") ("xclip" "-selection" "clipboard") ("pbcopy")))))

(defun my/clipboard-cut (text)
  "Copy TEXT to the system clipboard in GUI and terminal frames."
  (if (display-graphic-p)
      (gui-select-text text)
    (when-let* ((argv (my/clipboard-command nil)))
      (let* ((process-connection-type nil)
             (proc (apply #'start-process "clipboard" nil argv)))
        (process-send-string proc text)
        (process-send-eof proc)))))

(defun my/clipboard-paste ()
  "Paste text from the system clipboard in GUI and terminal frames."
  (if (display-graphic-p)
      (gui-selection-value)
    (when-let* ((argv (my/clipboard-command t))
                (text (with-temp-buffer
                        (when (zerop (apply #'call-process (car argv) nil t nil (cdr argv)))
                          (buffer-string)))))
      ;; nil when unchanged, so the kill ring doesn't collect duplicates
      (unless (or (string-empty-p text) (equal text (car kill-ring)))
        text))))

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


(provide 'init/core)
;;; core.el ends here
