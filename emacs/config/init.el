;;; init.el --- Emacs Initialization  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(eval-and-compile ;; force load
  (add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
  (add-to-list 'custom-theme-load-path (expand-file-name "themes" user-emacs-directory))
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory)))

(setq debug-on-error t)
(add-to-list 'warning-suppress-types '(face))

(when (file-exists-p custom-file)
  (load custom-file nil t))

(when (eq system-type 'darwin)
  (require 'init-macos) )

;; Core:
(require 'init/elpaca)
(require 'init/core)
(require 'init/ui)
(require 'init/completion)
(require 'init/editing)
(require 'init/tools)
(require 'init/dashboard)

;; Language:
(require 'lang/lisp)
(require 'lang/lua)
(require 'lang/sh)
(require 'lang/elixir)
(require 'lang/godot)
(require 'lang/js-ts)
(require 'lang/csharp)

;; Extra:
(require 'extra/terminal)

(setq debug-on-error nil)
;;; init.el ends here
