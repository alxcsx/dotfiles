;;; early-init.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(setq
 site-run-file nil ; prevent loading system-wide site-start.el
 inhibit-default-init t   ; prevent loading standard libraries
 package-enable-at-startup nil ; skip emacs package manager, i'll use elpaca instead
 gc-cons-threshold most-positive-fixnum) ; prevent garbage collector pauses during startup

(if (eq system-type 'darwin) (menu-bar-mode 1) (menu-bar-mode -1))
(tool-bar-mode -1)
(scroll-bar-mode -1)

;; put native compilation cache in a subdirectory of the config directory.
(when (and (fboundp 'startup-redirect-eln-cache)
           (fboundp 'native-comp-available-p)
           (native-comp-available-p))
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "var/eln-cache/" user-emacs-directory))))

(add-hook 'after-init-hook #'(lambda () (setq gc-cons-threshold (* 8 1024 1024))))

;; Theme Colors, default while the theme is being loaded
(add-to-list 'default-frame-alist '(background-color . "#181818"))
(add-to-list 'default-frame-alist '(foreground-color . "#ffffff"))
(load-theme 'modus-vivendi t)

(setq-default mode-line-format nil) ;;Hide the modeline because it was flashing

(when (eq system-type 'darwin)
  (require 'early-init-macos (expand-file-name "lisp/early-init-macos.el" user-emacs-directory)))

(provide 'early-init)
;;; early-init.el ends here
