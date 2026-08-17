;;; early-init.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(setq
 gc-cons-threshold most-positive-fixnum ; prevent garbage collector pauses during startup
 gc-cons-percentage 0.6)

(setq
 site-run-file nil ; prevent loading system-wide site-start.el
 inhibit-default-init t   ; prevent loading standard libraries
 package-enable-at-startup nil) ; skip emacs package manager, i'll use elpaca instead

(setq-default native-comp-async-report-warnings-errors 'silent)


;; put native compilation cache in a subdirectory of the config directory.
(when (and (fboundp 'startup-redirect-eln-cache)
           (fboundp 'native-comp-available-p)
           (native-comp-available-p))
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "var/eln-cache/" user-emacs-directory))))


;; Prevent GUI flicker and redundant redraw calculations
(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t)

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars . nil) default-frame-alist)
;; Mouse Scroll
(setq redisplay-dont-pause t
      fast-but-imprecise-scrolling t
      scroll-conservatively 101
      scroll-margin 0)
;; Performance Optimizations
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)
;; Theme Colors, default while the theme is being loaded
(push '(background-color . "#181818") default-frame-alist)
(push '(foreground-color . "#ffffff") default-frame-alist)
(push '(font . "JetBrains Mono-14") default-frame-alist)
(setq-default mode-line-format nil) ;;Hide the modeline because it was flashing

(set-selection-coding-system 'utf-8)
(prefer-coding-system 'utf-8)


(when (eq system-type 'darwin)
  (require 'early-init-macos (expand-file-name "lisp/early-init-macos.el" user-emacs-directory)))

(provide 'early-init)
;;; early-init.el ends here
