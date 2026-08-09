;;; early-init-macos.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(setq frame-inhibit-implied-resize t)
(push '(font . "JetBrains Mono-14") default-frame-alist)
(push '(ns-transparent-titlebar . t) default-frame-alist)
(push '(ns-appearance . dark) default-frame-alist)

(set-selection-coding-system 'utf-8)
(prefer-coding-system 'utf-8)

(add-to-list 'default-frame-alist '(undecorated-round . t))

(provide 'early-init-macos)
;;; early-init-macos.el ends here
