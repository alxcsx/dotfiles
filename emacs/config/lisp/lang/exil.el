;;; exil.el --- Major mode for Exil (Elixir Implemented Lisp) -*- lexical-binding: t; -*-

;;; Commentary:
;; Minimal, dynamic major mode and REPL for Exil, derived from `lisp-data-mode'
;; and `comint-mode'.

;;; Code:

(require 'lisp-mode)
(require 'comint)

(declare-function corfu-mode "corfu")

(defconst exil-keywords
  '("fn" "let" "if" "spec" "_ffi" "quote" "unquote" "unquote-splicing" "import" "as" "->")
  "Core non-def special forms in Exil.")

(defconst exil-font-lock-keywords
  `((,(regexp-opt exil-keywords 'symbols) . font-lock-keyword-face)
    ;; Any (def* name ...): highlight def* as keyword, lowercase target as function
    ("([ \t]*\\(def[^][ \t\n(){}#;]*\\)\\(?:[ \t]+\\([^][ \t\n(){}#;A-Z][^][ \t\n(){}#;]*\\)\\)?"
     (1 font-lock-keyword-face)
     (2 font-lock-function-name-face nil t))
    ;; Capitalized symbols (Types & Modules)
    ("\\_<[A-Z][[:alnum:]_-]*\\_>" . font-lock-type-face)
    ;; Keywords (:foo)
    ("\\_<:[^][ \t\n(){}#;,]+\\_>" . font-lock-constant-face)
    ;; Namespace prefix (ns/func)
    ("\\([^][ \t\n(){}#;,]+\\)/" (1 font-lock-type-face))))

(defun exil-indent-function (indent-point state)
  "Dynamic indentation: any `def*' or `exil-keywords' form indents by 2."
  (goto-char (1+ (elt state 1)))
  (let ((sym (thing-at-point 'symbol t)))
    (if (and sym (or (string-prefix-p "def" sym) (member sym exil-keywords)))
        (progn (goto-char (elt state 1)) (+ (current-column) lisp-body-indent))
      (lisp-indent-function indent-point state))))

;; ---------------------------------------------------------------------------
;; Dynamic Completion (Stdlib + Open Buffers)
;; ---------------------------------------------------------------------------

(defconst exil--scan-re
  "([ \t]*\\(def[^][ \t\n(){}#;]*\\)[ \t]+\\([^][ \t\n(){}#;]+\\)\\|\\_<\\([A-Z][[:alnum:]_-]*\\)\\_>")

(defvar exil--stdlib-symbols nil)

(defun exil--scan-buffer ()
  "Extract `def*' forms, defined names, and types from current buffer."
  (let ((case-fold-search nil) syms)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward exil--scan-re nil t)
        (unless (nth 8 (syntax-ppss))
          (when (match-string 1) (push (match-string-no-properties 1) syms))
          (push (or (match-string-no-properties 2)
                    (match-string-no-properties 3))
                syms))))
    syms))

(defun exil--stdlib-symbols ()
  "Lazily extract symbols from Exil's stdlib `.exl' files."
  (or exil--stdlib-symbols
      (setq exil--stdlib-symbols
            (when-let* ((bin (or (executable-find "exil") (executable-find "typed_lisp")))
                        (stdlib (expand-file-name "lib/stdlib" (file-name-directory (file-truename bin))))
                        ((file-directory-p stdlib)))
              (let (syms)
                (dolist (f (directory-files-recursively stdlib "\\.exls?\\'"))
                  (with-temp-buffer
                    (set-syntax-table lisp-data-mode-syntax-table)
                    (insert-file-contents f)
                    (setq syms (nconc (exil--scan-buffer) syms))))
                (delete-dups syms))))))

(defun exil-completion-at-point ()
  "Dynamic completion-at-point for Exil."
  (when-let* ((bounds (bounds-of-thing-at-point 'symbol)))
    (let ((cands (append exil-keywords (exil--stdlib-symbols))))
      (dolist (buf (buffer-list))
        (when (buffer-live-p buf)
          (with-current-buffer buf
            (when (derived-mode-p 'exil-mode 'exil-repl-mode)
              (setq cands (nconc (exil--scan-buffer) cands))))))
      (list (car bounds) (cdr bounds) (delete-dups cands)
            :company-kind
            (lambda (c)
              (let ((case-fold-search nil))
                (cond ((or (member c exil-keywords) (string-prefix-p "def" c)) 'keyword)
                      ((string-match-p "\\`[A-Z]" c) 'type)
                      (t 'function))))
            :exclusive 'no))))

;; ---------------------------------------------------------------------------
;; REPL & Runner
;; ---------------------------------------------------------------------------

(defun exil--command (&rest args)
  "Build shell command to run Exil with ARGS."
  (if-let* ((bin (or (executable-find "exil") (executable-find "typed_lisp"))))
      (mapconcat #'shell-quote-argument (cons bin args) " ")
    (let ((dir (locate-dominating-file default-directory "mix.exs"))
          (expr (format "CLI.main([%s])"
                        (mapconcat (lambda (a) (format "%S" a)) args ", "))))
      (format "%smix run -e %s"
              (if dir (format "cd %s && " (shell-quote-argument (expand-file-name dir))) "")
              (shell-quote-argument expr)))))

(defun exil-run-file ()
  "Run the current Exil file."
  (interactive)
  (compile (exil--command (or (buffer-file-name) (user-error "Buffer has no file")))))

(defun exil-repl-return ()
  "Send input if balanced, otherwise insert newline and indent."
  (interactive)
  (let* ((proc (get-buffer-process (current-buffer)))
         (ppss (and proc (parse-partial-sexp (process-mark proc) (point-max)))))
    (if (or (not ppss) (and (<= (nth 0 ppss) 0) (not (nth 3 ppss))))
        (comint-send-input)
      (newline-and-indent))))

(defvar-keymap exil-repl-mode-map
  "RET" #'exil-repl-return
  "C-j" #'comint-send-input)

(define-derived-mode exil-repl-mode comint-mode "Exil-REPL"
  "Major mode for the Exil interactive REPL."
  :syntax-table lisp-data-mode-syntax-table
  (setq-local comint-prompt-regexp "^\\(?:REPL>\\|\\.\\.\\.\\) *"
              comint-prompt-read-only t
              comint-move-point-for-output t
              comint-scroll-to-bottom-on-input 'this
              lisp-indent-function #'exil-indent-function
              font-lock-defaults '(exil-font-lock-keywords))
  (add-hook 'completion-at-point-functions #'exil-completion-at-point nil t)
  (when (fboundp 'corfu-mode) (corfu-mode 1)))

(defun exil-repl ()
  "Start or switch to the interactive Exil REPL."
  (interactive)
  (let ((buf (get-buffer-create "*Exil REPL*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'exil-repl-mode) (exil-repl-mode))
      (unless (comint-check-proc buf)
        (make-comint-in-buffer "Exil REPL" buf "sh" nil "-c" (exil--command "--repl"))))
    (pop-to-buffer buf)))

;; ---------------------------------------------------------------------------
;; Major Mode
;; ---------------------------------------------------------------------------

(defvar-keymap exil-mode-map
  "C-c C-c" #'exil-run-file
  "C-c C-z" #'exil-repl)

;;;###autoload
(define-derived-mode exil-mode lisp-data-mode "Exil"
  "Major mode for editing Exil code."
  (setq-local font-lock-defaults '(exil-font-lock-keywords)
              lisp-indent-function #'exil-indent-function)
  (add-hook 'completion-at-point-functions #'exil-completion-at-point nil t))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.exls?\\'" . exil-mode))

(provide 'lang/exil)
(provide 'exil-mode)
;;; exil.el ends here
