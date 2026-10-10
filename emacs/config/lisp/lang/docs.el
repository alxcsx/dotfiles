;;; docs.el --- Markdown, Org, and LaTeX configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; Markdown
(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'"       . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :custom
  (markdown-header-scaling t)
  (markdown-fontify-code-blocks-natively t)
  :config
  (add-hook 'markdown-mode-hook #'visual-line-mode))

;; Org Mode
(use-package org
  :ensure nil
  :hook ((org-mode . visual-line-mode)
         (org-mode . org-indent-mode))
  :custom
  (org-ellipsis " ▾")
  (org-hide-emphasis-markers t)
  (org-startup-folded 'content)
  (org-startup-indented t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-edit-src-content-indentation 2))

;; LaTeX / TeX
(use-package tex-mode
  :ensure nil
  :mode ("\\.tex\\'" . latex-mode)
  :hook ((latex-mode . visual-line-mode)
         (latex-mode . flymake-mode))
  :custom
  (tex-run-command "pdflatex"))

(provide 'lang/docs)
;;; docs.el ends here
