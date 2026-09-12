;;; build.el --- shell scripting defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

(use-package just-mode
  :mode ("\\(?:[Jj]ustfile\\|\\.just\\)\\'" . just-mode))

(use-package dotenv-mode
  :ensure t
  :mode ("\\.env\\(?:\\..*\\)?\\'" . dotenv-mode))

(use-package dockerfile-ts-mode
  :ensure nil
  :mode "\\(?:Dockerfile\\(?:\\..*\\)?\\)\\'")

(add-to-list 'auto-mode-alist '("\\(?:[Tt]iltfile\\)\\'" . python-ts-mode))

(provide 'lang/build)
;;; build.el ends here
