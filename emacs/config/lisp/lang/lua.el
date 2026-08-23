;;; lua.el --- lua defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(add-to-list 'major-mode-remap-alist '(lua-mode . lua-ts-mode))


(use-package lua-ts-mode
  :ensure nil
  :hook (lua-ts-mode . eglot-ensure)
  :custom
  (lua-indent-level 4)
  :config
  (add-to-list 'treesit-language-source-alist
               '(lua "https://github.com/tree-sitter/tree-sitter-lua")))

(provide 'lang/lua)
;;; lua.el ends here
