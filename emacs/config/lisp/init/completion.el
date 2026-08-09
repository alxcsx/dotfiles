;;; completion.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;;; name: init-completion.el
;;; desc: completion stack
;;; author: Alex Candido <github:alxcsx>

;; Vertico: Completion UI
(use-package vertico
  :init
  (vertico-mode 1)
  (vertico-mouse-mode 1)
  :custom
  (vertico-count 12)
  (vertico-resize nil)
  (vertico-cycle t))

;; match search results without exact order
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

;; annotation at minibuffer margins
(use-package marginalia
  :init
  (marginalia-mode 1))

;; Enhanced search
(use-package consult
  :bind
  (("C-s" . consult-line)
   ("C-x b" . consult-buffer)
   ("C-x C-b" . consult-buffer)
   ("C-c s" . consult-ripgrep)
   ("C-x p b" . consult-project-buffer)
   ("C-x C-r" . consult-recent-file)
   ("M-g g" . consult-goto-line) ; jump to line w/ preview
   ("M-y" . consult-yank-pop)) ; kill-ring (clipboard) history chooser
  :custom
  (consult-preview-key "<right>")
  (consult-narrow-key "<")
  :init
  ;; Hide M-x commands that don't apply to the current mode (so we don't clutter the search)
  (setq read-extended-command-predicate #'command-completion-default-include-p)
  :config
  (defvar my-modified-buffers-source
    `(:name     "Modified Buffers"
                :narrow   ?m
                :category buffer
                :face     font-lock-warning-face  ; The color applied to the text
                :items    ,(lambda ()
                             (consult--buffer-query
                              :sort 'visibility
                              :as #'buffer-name
                              :predicate (lambda (buf)
                                           (and (buffer-modified-p buf)
                                                (buffer-file-name buf)))))))

  ;; Add the custom source to Consult's buffer list
  (add-to-list 'consult-buffer-sources 'my-modified-buffers-source))

(use-package corfu
  :init
  (global-corfu-mode 1)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-quit-no-match 'separator))

;; Templating
(use-package tempel
  :custom
  (tempel-path (expand-file-name "templates.eld" user-emacs-directory))
  (tempel-trigger-prefix "<")
  :bind
  ("M-+" . tempel-complete)
  ("M-*" . tempel-insert)
  (:map tempel-map
        ("<tab>" . tempel-next)
        ("TAB" . tempel-next)
        ("S-TAB" . tempel-previous)
        ("<backtab>" . tempel-previous)))

(use-package tempel-collection)

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  :config
  ;; Setup combined completion for Elisp buffers
  (defun my/setup-elisp-capf ()
    (setq-local completion-at-point-functions
                (list (cape-capf-super
                       #'tempel-expand
                       #'elisp-completion-at-point)
                      #'cape-file
                      #'cape-dabbrev)))

  ;; Setup combined completion for Eglot LSP buffers
  (defun my/setup-eglot-capf ()
    (setq-local completion-at-point-functions
                (list (cape-capf-super
                       #'tempel-expand
                       #'eglot-completion-at-point)
                      #'cape-file
                      #'cape-dabbrev)))

  :hook
  ((emacs-lisp-mode . my/setup-elisp-capf)
   (eglot-managed-mode . my/setup-eglot-capf)))

(provide 'init/completion)
;;; completion.el ends here
