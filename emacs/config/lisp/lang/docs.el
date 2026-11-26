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
  (markdown-fontify-code-blocks-natively t))

;; Render tables aligned (composition, no buffer rewriting), pipes as
;; full-height bars, and the separator row as a line.
(use-package valign
  :hook (markdown-mode . valign-mode)
  :custom
  (valign-fancy-bar t)
  :config
  ;; Upstream only accepts a separator when `-' or `:' directly follows the
  ;; bar, so the common `| :--- | :--- |' style gets no alignment at all.
  ;; ponytail: upstream bug, drop when valign fixes valign--separator-p.
  (defun my/valign-separator-p (orig &optional point)
    "Treat a whole `| :--- | :--- |' row as a separator."
    (or (funcall orig point)
        (save-excursion
          (beginning-of-line)
          (looking-at-p "[ \t]*|[ \t]*:?-+:?[ \t]*\\(|[ \t]*:?-+:?[ \t]*\\)*|?[ \t]*$"))))
  (unless (advice-member-p #'my/valign-separator-p 'valign--separator-p)
    (advice-add 'valign--separator-p :around #'my/valign-separator-p)))

;; Org Mode
(use-package org
  :ensure nil
  :hook (org-mode . org-indent-mode)
  :custom
  (org-ellipsis " ▾")
  (org-hide-emphasis-markers t)
  (org-startup-folded 'content)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-edit-src-content-indentation 2))

;; LaTeX / TeX
(use-package tex-mode
  :ensure nil
  :mode ("\\.tex\\'" . latex-mode)
  :hook (latex-mode . flymake-mode)
  :custom
  (tex-run-command "pdflatex"))

(provide 'lang/docs)
;;; docs.el ends here
