;;; sh.el --- shell scripting defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package sh-script
  :ensure nil
  :custom
  (sh-basic-offset 2)
  :init
  (add-to-list 'major-mode-remap-alist '(sh-mode . bash-ts-mode))
  :config
  (add-to-list 'treesit-language-source-alist '(bash "https://github.com/tree-sitter/tree-sitter-bash"))
  (unless (treesit-language-available-p 'bash) (treesit-install-language-grammar 'bash))
  :hook
  ((sh-mode bash-ts-mode) . my/setup-lsp-and-format)
  ((sh-mode bash-ts-mode) . my/sh-mode-setup))

(use-package fish-mode
  :mode "\\.fish\\'"
  :custom
  (fish-indent-offset 2))

(defun my/sh-mode-setup ()
  "Custom hooks for shell scripting."
  ;; Automatically make file executable on save if it has a shebang
  (add-hook 'after-save-hook #'executable-make-buffer-file-executable-p nil t))

(provide 'lang/sh)
;;; sh.el ends here
