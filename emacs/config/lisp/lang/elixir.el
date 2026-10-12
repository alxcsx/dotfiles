;;; elixir.el --- elixir defaults-*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package elixir-ts-mode
  :ensure nil
  :mode ("\\.ex\\'" "\\.exs\\'")
  :hook
  (elixir-ts-mode . eglot-ensure)
  :config
  (add-to-list 'treesit-language-source-alist '(elixir "https://github.com/elixir-lang/tree-sitter-elixir")))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((elixir-mode elixir-ts-mode heex-ts-mode) . ("elixir-ls")))
  ;; Optimize ElixirLS: disable background Dialyzer to prevent freezes/CPU spikes,
  ;; disable auto fetchDeps to avoid lockfile conflicts, enable specs.
  (my/eglot-merge-workspace-config
   :elixirLS
   '(:dialyzerEnabled :json-false
     :fetchDeps :json-false
     :suggestSpecs t
     :autoBuild t
     :enableTestLenses :json-false)))

(use-package heex-ts-mode
  :ensure nil
  :mode "\\.heex\\'"
  :hook (heex-ts-mode . eglot-ensure)
  :config
  (add-to-list 'treesit-language-source-alist
               '(heex "https://github.com/phoenixframework/tree-sitter-heex" "main")))

;; Format on save with mix format via Apheleia
(with-eval-after-load 'apheleia
  (add-to-list 'apheleia-mode-alist '(elixir-ts-mode . mix-format))
  (add-to-list 'apheleia-mode-alist '(heex-ts-mode . mix-format)))

(provide 'lang/elixir)
;;; elixir.el ends here
