;;; editing.el --- editing behaviour -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


;; Tabs, Indentation and Wrapping
(require 'init/core)

(setq-default indent-tabs-mode nil
	            tab-always-indent 'complete
	            tab-width 2)

(use-package editorconfig
  :init
  (editorconfig-mode 1))

(add-hook 'text-mode-hook #'visual-line-mode)

;; Parenthesis

                                        ;highlight matching parenthesis
(use-package paren
  :ensure nil ; built-in package, no need to download
  :init
  (show-paren-mode 1)
  :custom
  (show-paren-style 'parenthesis)
  (show-paren-when-point-in-periphery t)
  (show-paren-when-point-inside-paren nil))

                                        ; auto-insert matching pair
(use-package elec-pair
  :ensure nil ; built-in package, no need to download
  :init
  (electric-pair-mode 1))

;; Region and Line Highlighting
                                        ; typing while something is selected overwrites the selected text
(delete-selection-mode 1)

                                        ;highlight the active line
(use-package hl-line
  :ensure nil ; built-in package, no need to download
  :init
  (global-hl-line-mode 1))

(add-hook 'before-save-hook #'delete-trailing-whitespace)

;; UX Utilities
;; allow repeating of commands:
(when (fboundp 'repeat-mode) (repeat-mode 1))

;; Drag lines/regions with Alt + Arrow keys
(use-package drag-stuff
  :ensure t
  :init
  (drag-stuff-global-mode 1)
  :config
  ;; Custom bindings for M-<up> and M-<down>
  :bind
  ("M-<up>"   . drag-stuff-up)
  ("M-<down>" . drag-stuff-down))

(use-package multiple-cursors
  :bind (("C-M-<down>" . mc/mark-next-lines)
         ("C-c d" . mc/mark-next-like-this)
         ("C-c <f2>" . mc/mark-all-like-this)))

;; duplicate line with alt-shift-down
(global-set-key (kbd "M-S-<down>") 'duplicate-dwim)

(add-hook 'prog-mode-hook #'subword-mode)

(defun my/forward-token ()
  "Move forward by token based on syntax classes."
  (interactive "^")
  ;; 1. Skip spaces (Your logic: "if next char is space...")
  (skip-syntax-forward " ")
  (unless (eobp)
    (let ((syntax (char-syntax (char-after))))
      (cond
       ((eq syntax ?w) (forward-word 1))
       ((memq syntax '(?_ ?.)) (skip-syntax-forward "_."))
       ((memq syntax '(?\( ?\))) (forward-char 1))
       (t (forward-char 1))))))

(defun my/backward-token ()
  "Move backward by token based on syntax classes."
  (interactive "^")
  (skip-syntax-backward " ")
  (unless (bobp)
    (let ((syntax (char-syntax (char-before))))
      (cond
       ((eq syntax ?w) (backward-word 1))
       ((memq syntax '(?_ ?.)) (skip-syntax-backward "_."))
       ((memq syntax '(?\( ?\))) (backward-char 1))
       (t (backward-char 1))))))

(global-set-key (kbd "C-<left>")  #'my/backward-token)
(global-set-key (kbd "C-<right>") #'my/forward-token)

(defun my/backward-delete-token ()
  "Delete the previous token without adding it to the 'kill-ring'."
  (interactive)
  (let ((end (point)))
    (my/backward-token)
    (delete-region (point) end)))

;; Bind it to Ctrl+Backspace
(global-set-key (kbd "C-<backspace>") #'my/backward-delete-token)


(provide 'init/editing)
;;; editing.el ends here
