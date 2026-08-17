;;; sh.el --- shell scripting defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(defun my/sh-mode-setup ()
  "Automatically make file executable on save if it has a shebang."
  (require 'executable)
  (add-hook 'after-save-hook #'executable-make-buffer-file-executable-if-script-p nil t))

(use-package sh-script
  :ensure nil
  :custom
  (sh-basic-offset 2)
  :init
  (add-to-list 'major-mode-remap-alist '(sh-mode . bash-ts-mode))
  :config
  (add-to-list 'treesit-language-source-alist '(bash "https://github.com/tree-sitter/tree-sitter-bash"))
  :hook
  (bash-ts-mode . eglot-ensure)
  (bash-ts-mode . my/sh-mode-setup))

(use-package fish-mode
  :mode "\\.fish\\'"
  :custom
  (fish-indent-offset 2))

(with-eval-after-load 'eglot
  (my/eglot-merge-workspace-config
   :bashIde
   '(:backgroundAnalysisMaxFiles 100
                                 :explainshellEndpoint ""
                                 :glob "**/*@(.sh|.inc|.bash|.command)")))

(provide 'lang/sh)
;;; sh.el ends here
