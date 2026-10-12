;;; dotnet.el --- .NET (C# and F#) and Unity configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

;; Project markers for Unity & .NET solutions
(with-eval-after-load 'project
  (dolist (marker '("*.slnx" "*.sln" "Assets" "ProjectSettings/ProjectVersion.txt"))
    (add-to-list 'project-vc-extra-root-markers marker)))

(defun my/dotnet-unity-project-p (&optional dir)
  "Check whether the current buffer or DIR is inside a Unity project."
  (let* ((dir (or dir default-directory))
         (proj (project-current nil dir))
         (root (and proj (project-root proj))))
    (if root
        (or (file-exists-p (expand-file-name "Assets" root))
            (file-exists-p (expand-file-name "ProjectSettings/ProjectVersion.txt" root)))
      (or (locate-dominating-file dir "Assets")
          (locate-dominating-file dir "ProjectSettings/ProjectVersion.txt")))))

;; Hide Unity .meta files in Dired / Dirvish
(with-eval-after-load 'dired
  (require 'dired-x)
  (defun my/unity-dired-setup ()
    "Automatically hide .meta files when browsing a Unity project."
    (when (my/dotnet-unity-project-p)
      (setq-local dired-omit-files
                  (concat (or dired-omit-files "\\`\\..*") "\\|\\.meta\\'"))
      (dired-omit-mode 1)))
  (add-hook 'dired-mode-hook #'my/unity-dired-setup))

;; Ignore .meta files in project searches for Unity projects
(with-eval-after-load 'project
  (defun my/project-unity-ignores (orig-fun project &rest args)
    (let ((ignores (apply orig-fun project args)))
      (if (my/dotnet-unity-project-p)
          (cons "*.meta" ignores)
        ignores)))
  (advice-add 'project-ignores :around #'my/project-unity-ignores))

;; Ignore .meta files in file completion when inside a Unity project buffer
(defun my/unity-ignore-meta-in-completion ()
  (when (my/dotnet-unity-project-p)
    (setq-local completion-ignored-extensions
                (cons ".meta" completion-ignored-extensions))))
(add-hook 'find-file-hook #'my/unity-ignore-meta-in-completion)


(defun my/csharp-lsp-contact (&optional _interactive _project)
  "Determine the LSP contact for C# files, configuring OmniSharp or falling back to csharp-ls."
  (let ((omnisharp-bin (or (executable-find "omnisharp")
                           (executable-find "OmniSharp"))))
    (cond
     (omnisharp-bin
      (list omnisharp-bin "-lsp" "-s" "."))
     (t '("csharp-ls")))))

(add-to-list 'treesit-language-source-alist
             '(c-sharp "https://github.com/tree-sitter/tree-sitter-c-sharp"))

(when (treesit-ready-p 'c-sharp t)
  (add-to-list 'major-mode-remap-alist '(csharp-mode . csharp-ts-mode)))

;; C# configuration
(use-package csharp-mode
  :ensure nil
  :mode ("\\.cs\\'" . csharp-mode)
  :hook ((csharp-mode . eglot-ensure)
         (csharp-ts-mode . eglot-ensure))
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((csharp-mode csharp-ts-mode) . my/csharp-lsp-contact))
    ;; OmniSharp workspace configuration (enable Roslyn analyzers & decompilation)
    (my/eglot-merge-workspace-config
     :csharp
     '(:omnisharp (:enableRoslynAnalyzers t
                   :enableEditorConfigSupport t
                   :useModernNet t)))))

;; Unity asset & shader file associations
(add-to-list 'auto-mode-alist '("\\.shader\\'" . csharp-mode))
(add-to-list 'auto-mode-alist '("\\.cginc\\'"  . csharp-mode))
(add-to-list 'auto-mode-alist '("\\.hlsl\\'"   . csharp-mode))

;; F# configuration
(use-package fsharp-mode
  :mode ("\\.fs[iylx]?\\'" . fsharp-mode)
  :hook (fsharp-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(fsharp-mode . ("fsautocomplete" "--adaptive-lsp-server-enabled")))))

(provide 'lang/dotnet)
;;; dotnet.el ends here
