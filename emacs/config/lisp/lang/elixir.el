;;; elixir.el --- elixir defaults-*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package elixir-ts-mode
  :ensure nil
  :mode ("\\.ex\\'" "\\.exs\\'")
  :hook (elixir-ts-mode . my/setup-lsp-and-format)
  :config
  (add-to-list 'treesit-language-source-alist '(elixir "https://github.com/elixir-lang/tree-sitter-elixir"))
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((elixir-ts-mode heex-ts-mode) . ("elixir-ls")))))

(use-package heex-ts-mode
  :ensure nil
  :mode "\\.heex\\'"
  :hook (heex-ts-mode . my/setup-lsp-and-format)
  :config
  (add-to-list 'treesit-language-source-alist
               '(heex "https://github.com/phoenixframework/tree-sitter-heex" "main")))


(provide 'lang/elixir)
;;; elixir.el ends here
