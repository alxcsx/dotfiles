;;; dotnet.el --- .NET (C# and F#) and Unity configuration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'lang/core)

;; Project markers for Unity & .NET solutions
(with-eval-after-load 'project
  (dolist (marker '("Assets" "ProjectSettings/ProjectVersion.txt" "*.sln"))
    (add-to-list 'project-vc-extra-root-markers marker)))

(defun my/dotnet-unity-project-p ()
  "Check whether the current buffer is inside a Unity project."
  (or (locate-dominating-file default-directory "Assets")
      (locate-dominating-file default-directory "ProjectSettings/ProjectVersion.txt")))

(defun my/csharp-lsp-contact (&optional _interactive _project)
  "Determine the LSP contact for C# files, configuring Omnisharp for Unity if needed."
  (if (my/dotnet-unity-project-p)
      ;; In Unity projects, ensure OmniSharp loads solutions and references correctly
      '("omnisharp" "-lsp" "-s" ".")
    ;; Default C# alternatives: omnisharp or csharp-ls
    (cond
     ((executable-find "omnisharp") '("omnisharp" "-lsp"))
     ((executable-find "OmniSharp") '("OmniSharp" "-lsp"))
     (t '("csharp-ls")))))

;; C# configuration
(use-package csharp-mode
  :ensure nil
  :mode ("\\.cs\\'" . csharp-mode)
  :hook (csharp-mode . eglot-ensure)
  :config
  (add-to-list 'treesit-language-source-alist
               '(c-sharp "https://github.com/tree-sitter/tree-sitter-c-sharp"))
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
