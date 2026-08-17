;;; godot.el --- GDScript configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defun my/godot-lsp-contact (_interactive)
  "Dynamically determine the Godot LSP port based on the project version."
  (let ((port 6008) ;; Default to Godot 4 port
        (proj-dir (locate-dominating-file default-directory "project.godot")))
    (when proj-dir
      (with-temp-buffer
        (insert-file-contents (expand-file-name "project.godot" proj-dir))
        (goto-char (point-min))
        (when (re-search-forward "^config_version=4" nil t)
          (setq port 6005))))
    (list "127.0.0.1" port))) ; Eglote server Format

(use-package gdscript-mode
  :ensure t
  :hook (gdscript-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '(gdscript-mode . my/godot-lsp-contact))))


(provide 'lang/godot)
;;; godot.el ends here
