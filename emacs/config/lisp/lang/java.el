;;; java.el --- Java configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package java-ts-mode
  :ensure nil
  :mode "\\.java\\'"
  :hook (java-ts-mode . eglot-ensure)
  :config
  (add-to-list 'treesit-language-source-alist
               '(java "https://github.com/tree-sitter/tree-sitter-java")))

(provide 'lang/java)
;;; java.el ends here
