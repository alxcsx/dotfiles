;;; haskell.el --- Haskell configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package haskell-mode
  :mode ("\\.[gh]s\\'" "\\.l[gh]s\\'" "\\.cabal\\'")
  :hook
  ((haskell-mode . eglot-ensure)
   (haskell-mode . interactive-haskell-mode))
  :custom
  (haskell-process-type 'cabal-repl)
  (haskell-process-suggest-remove-import-lines t)
  (haskell-process-auto-import-loaded-modules t))

(provide 'lang/haskell)
;;; haskell.el ends here
