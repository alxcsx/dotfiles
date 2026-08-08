;;; lua.el --- lua defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package lua-mode
  :mode "\\.lua\\'"
  :custom
  (lua-indent-level 4)
  :config
  (add-to-list 'major-mode-remap-alist '(lua-mode . lua-ts-mode)))

(add-hook 'lua-mode-hook #'my/setup-lsp-and-format)
(add-hook 'lua-ts-mode-hook #'my/setup-lsp-and-format)

(provide 'lang/lua)
;;; lua.el ends here
