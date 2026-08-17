;;; core.el --- core defaults for language settings-*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


;;Syntax-Highlighting configuration

(use-package treesit
  :ensure nil
  :custom
  (treesit-font-lock-level 3)
  :config ;; Using tree-sitter mode for some simple common langs
  (add-to-list 'major-mode-remap-alist '(json-mode . json-ts-mode))
  (add-to-list 'major-mode-remap-alist '(yaml-mode . yaml-ts-mode)))

;; LSP Client

;; async formatting
(use-package apheleia
  :config
  (apheleia-global-mode +1))

(setq eldoc-idle-delay 0.5
      eldoc-echo-area-use-multiline-p nil)

(use-package eglot
  :ensure nil
  :custom
  (eglot-autoshutdown t)
  (eglot-sync-connect 0)
  (eglot-events-buffer-size 0)
  :bind
  (:map eglot-mode-map
        ("C-c l r" . eglot-rename)
        ("C-c l a" . eglot-code-actions)
        ("C-c l f" . apheleia-format-buffer)
        ("C-c l d" . eglot-find-declarations)
        ("M-."     . xref-find-definitions)
        ("M-?"     . xref-find-references)
        ("C-c a" . eglot-code-actions))
  :config
  (defun my/eglot-format-on-save ()
    (add-hook 'before-save-hook #'eglot-format-buffer nil t)))

(setq-default eglot-workspace-configuration '())

(defun my/eglot-merge-workspace-config (key val)
  "Incrementally merge KEY and VAL into `eglot-workspace-configuration`."
  (setq-default eglot-workspace-configuration
                (plist-put (default-value 'eglot-workspace-configuration) key val)))

;; improve performance by converting JSON payloads into native bytecote (uses a rust service in the background)
(use-package eglot-booster
  :ensure (eglot-booster :host github :repo "jdtsmith/eglot-booster")
  :if (executable-find "emacs-lsp-booster") ;; You need to install it to make it work.
  :after eglot
  :config
  (eglot-booster-mode))

;; Inline Linter
(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind
  (:map flymake-mode-map
        ("M-n" . flymake-goto-next-error)
        ("M-p" . flymake-goto-prev-error)
        ("C-c l e" . flymake-show-buffer-diagnostics)))

;; Code Folding
(use-package hs-minor-mode
  :ensure nil
  :hook (prog-mode . hs-minor-mode)
  :bind
  (:map hs-minor-modemap
        ("C-c TAB" . hs-toggle-hiding)))


;; MISC
(defun my/setup-lsp-and-format()
  "Lint and format."
  (interactive)
  (eglot-ensure))


(provide 'lang/core)
;;; core.el ends here
