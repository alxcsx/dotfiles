;;; lisp.el --- lisp defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package rainbow-delimiters
  :hook ((lisp-data-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)))

;; Structural Editing
(use-package puni
  :hook ((lisp-data-mode . puni-mode)
         (clojure-mode . puni-mode)
         (eval-expression-minibuffer-setup . puni-mode))
  :bind
  (:map puni-mode-map
        ("C-k" . puni-kill-line)
        ("C-=" . puni-expand-selection)
        ;; ("C-<right>" . puni-slurp-forward)
        ;; ("C-<left>" . puni-barf-forward)
        ("C-M-<left>" . puni-slurp-backward)
        ("C-M-<right>" . puni-barf-backward)
        ("M-s" . puni-splice)
        ("M-(" . puni-wrap-round)
        ("M-[" . puni-wrap-square)
        ("M-{" . puni-wrap-curly)))
;; Extra
;; ("M-<down>" . puni-transpose-forward)
;; ("M-<up>" . puni-transpose-backward)))

;; elisp specifics:

(use-package elisp-mode
  :ensure nil
  :bind
  (:map emacs-lisp-mode-map
        ("C-c C-e" . eval-at-point)
        ("C-c C-b" . eval-buffer)
        ("C-c C-r" . eval-region)))

(use-package eldoc
  :ensure nil
  :hook (emacs-lisp-mode . eldoc-mode))

;; Misc

(defun my/lisp-mode-setup ()
  "Common settings for all Lisp dialets."
  (setq-local electric-pair-inhibit-predicate `(lambda (char) (if (char-equal char ?\')
                                                                  t
                                                                (electric-pair-default-inhibit char)))))

(setq-local fill-column 80)
(add-hook 'lisp-data-mode-hook #'my/lisp-mode-setup)

(provide 'lang/lisp)
;;; lisp.el ends here
