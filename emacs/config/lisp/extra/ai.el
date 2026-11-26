;;; ai.el -- -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


(use-package copilot
  :ensure (:host github :repo "copilot-emacs/copilot.el" :files ("*.el" "dist"))
  :custom (copilot-indent-offset-warning-disable t)
  :hook (prog-mode . copilot-mode)
  :config

  (defvar my/copilot--starting-server nil)
  (defun my/copilot--start-server-once (orig &rest args)
    "Call ORIG, but never re-enter `copilot--start-server'."
    (if my/copilot--starting-server
        (error "Copilot server failed to start; check `node' and *copilot stderr*")
      (let ((my/copilot--starting-server t))
        (apply orig args))))
  (advice-add 'copilot--start-server :around #'my/copilot--start-server-once)
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB" . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("C-TAB" . copilot-accept-completion-by-word)
              ("C-n" . copilot-next-completion)
              ("C-p" . copilot-previous-completion)))


(provide 'extra/ai)
;;; ai.el ends here
