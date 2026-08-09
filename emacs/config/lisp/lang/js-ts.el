;;; js-ts.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defun my-js-ts-project-type ()
  "Determine the JavaScript/TypeScript runtime by checking root files."
  (cond
   ((or (locate-dominating-file default-directory "deno.json")
        (locate-dominating-file default-directory "deno.jsonc"))
    'deno)
   ((locate-dominating-file default-directory "bunfig.toml") ;; Future-proofing for Bun
    'bun)
   (t 'node)))

(defun my-js-ts-lsp (_interactive)
  "Dynamically route Eglot to the correct LSP server."
  (pcase (my-js-ts-project-type)
    ('deno '("deno" "lsp"))
    (_ '("typescript-language-server" "--stdio"))))

(defun my-apheleia-set-fmt ()
  "Override aphelia default fmt."
  (when (or (locate-dominating-file default-directory "deno.json")
            (locate-dominating-file default-directory "deno.jsonc"))
    (setq-local apheleia-formatter 'denofmt)))

(use-package typescript-ts-mode
  :ensure nil
  :mode (("\\.ts\\'" . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode)
         ("\\.js\\'"  . js-ts-mode)
         ("\\.jsx\\'" . js-ts-mode))
  :hook ((typescript-ts-mode tsx-ts-mode js-ts-mode) . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '((typescript-ts-mode tsx-ts-mode js-ts-mode) . my-js-ts-lsp))))


(with-eval-after-load 'apheleia
  ;; Hook our check into the modern JS/TS modes when they load
  (add-hook 'typescript-ts-mode-hook #'my-apheleia-set-fmt)
  (add-hook 'tsx-ts-mode-hook #'my-apheleia-set-fmt)
  (add-hook 'js-ts-mode-hook #'my-apheleia-set-fmt))

(provide 'lang/js-ts)
;;; js-ts.el ends here
