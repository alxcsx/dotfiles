;;; init.el --- Emacs Initialization  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(eval-and-compile ;; to force the linter to load these directories.
  (add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
  (add-to-list 'custom-theme-load-path (expand-file-name "themes" user-emacs-directory)))

(setq debug-on-error t)
(add-to-list 'warning-suppress-types '(face))

;; Core:
(require 'init/elpaca)
(require 'init/core)
(require 'init/ui)
(require 'init/completion)
(require 'init/editing)
(require 'init/tools)
(require 'init/dashboard)

;; Language Specifics:
(require 'lang/lisp)
(require 'lang/lua)
(require 'lang/sh)
(require 'lang/elixir)

(setq debug-on-error nil)
;;; init.el ends here
