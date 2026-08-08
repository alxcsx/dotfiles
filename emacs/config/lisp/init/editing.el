;;; editing.el --- editing behaviour -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


;; Tabs, Indentation and Wrapping

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


;; fix backward kill word
(defun my/backward-kill-char-or-word ()
  "Kill last word or whitespace. defaults to kill a single char."
  (interactive)
  (cond
   ((looking-back (rx (char word)) 1)
    (backward-kill-word 1))
   ((looking-back (rx (char blank)) 1)
    (delete-horizontal-space t))
   (t
    (backward-delete-char 1))))

(global-set-key (kbd "C-<backspace>") #'my/backward-kill-char-or-word)

(provide 'init/editing)
;;; editing.el ends here
