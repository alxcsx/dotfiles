;;; early-init-macos.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


(push '(ns-transparent-titlebar . t) default-frame-alist)
(push '(ns-appearance . dark) default-frame-alist)
(push '(undecorated-round . t) default-frame-alist)

(provide 'early-init-macos)
;;; early-init-macos.el ends here
