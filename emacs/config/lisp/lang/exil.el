;;; exil.el --- Major mode for Exil (Elixir Implemented Lisp) -*- lexical-binding: t; -*-

;;; Commentary:
;; Minimal, dynamic major mode and REPL for Exil, derived from `lisp-data-mode'
;; and `comint-mode'.

;;; Code:

(require 'lisp-mode)
(require 'comint)

(declare-function corfu-mode "corfu")

(defgroup exil nil
  "Major mode and interactive REPL for Exil."
  :group 'languages)

(defcustom exil-executable nil
  "Path to the Exil executable, or nil to search PATH and known locations."
  :type '(choice (const :tag "Auto" nil) (file :tag "Path"))
  :group 'exil)

(defcustom exil-repl-window-width 0.5
  "Width proportion or column count for the Exil REPL window on the right."
  :type '(choice (float :tag "Proportion of frame (e.g. 0.5)")
                 (integer :tag "Columns (e.g. 80)"))
  :group 'exil)

(defface exil-eval-result
  '((t :inherit font-lock-comment-face :slant italic))
  "Face used for displaying Exil inline evaluation results."
  :group 'exil)

(defface exil-eval-error
  '((t :inherit error :slant italic))
  "Face used for displaying Exil inline evaluation errors."
  :group 'exil)

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

(defun exil--find-executable ()
  "Find the Exil executable if available."
  (or exil-executable
      (executable-find "exil")
      (executable-find "typed_lisp")
      (let ((known (expand-file-name "~/projects/cin/typed_lisp/exil")))
        (when (file-executable-p known) known))))

(defun exil--stdlib-symbols ()
  "Lazily extract symbols from Exil's stdlib `.exl' files."
  (or exil--stdlib-symbols
      (setq exil--stdlib-symbols
            (when-let* ((bin (exil--find-executable))
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
  (if-let* ((bin (exil--find-executable)))
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
              comint-scroll-to-bottom-on-output 'all
              lisp-indent-function #'exil-indent-function
              font-lock-defaults '(exil-font-lock-keywords))
  (add-hook 'completion-at-point-functions #'exil-completion-at-point nil t)
  (when (fboundp 'corfu-mode) (corfu-mode 1)))

(defun exil--ensure-repl ()
  "Ensure the interactive Exil REPL process is running and return it."
  (let ((buf (get-buffer-create "*Exil REPL*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'exil-repl-mode) (exil-repl-mode))
      (unless (comint-check-proc buf)
        (make-comint-in-buffer "Exil REPL" buf "sh" nil "-c" (exil--command "--repl"))))
    (let ((proc (get-buffer-process buf)))
      (with-current-buffer buf
        (let ((timeout 50))
          (while (and (> timeout 0)
                      (not (string-match-p "\\(?:REPL>\\|\\.\\.\\.\\)" (buffer-string))))
            (accept-process-output proc 0.05)
            (setq timeout (1- timeout)))))
      proc)))

(defun exil-repl ()
  "Start or switch to the interactive Exil REPL in a window on the right."
  (interactive)
  (let* ((proc (exil--ensure-repl))
         (buf (process-buffer proc)))
    (pop-to-buffer buf
                   `((display-buffer-reuse-window display-buffer-in-direction)
                     (direction . right)
                     (window-width . ,exil-repl-window-width)))))

;; Always display *Exil REPL* in a split window to the right
(add-to-list 'display-buffer-alist
             '("\\`\\*Exil REPL\\*\\'"
               (display-buffer-reuse-window display-buffer-in-direction)
               (direction . right)
               (window-width . 0.5)))

;; ---------------------------------------------------------------------------
;; Interactive Evaluation & Overlays
;; ---------------------------------------------------------------------------

(defvar-local exil--eval-overlay nil
  "Active overlay showing the last evaluation result.")

(defun exil--clear-overlay ()
  "Delete the active evaluation overlay."
  (when (overlayp exil--eval-overlay)
    (delete-overlay exil--eval-overlay)
    (setq exil--eval-overlay nil)))

(defun exil--show-result (pos result)
  "Display RESULT as an overlay below POS and in the echo area."
  (exil--clear-overlay)
  (save-excursion
    (goto-char pos)
    (let* ((eol (line-end-position))
           (ov (make-overlay eol eol (current-buffer) t nil))
           (is-err (string-match-p "\\`\\(?:Compiler \\)?Error" result))
           (face (if is-err 'exil-eval-error 'exil-eval-result)))
      (overlay-put ov 'exil-eval t)
      (overlay-put ov 'after-string
                   (concat "\n" (propertize (format "  %s" result) 'face face)))
      (setq exil--eval-overlay ov)
      (letrec ((clear-hook
                (lambda ()
                  (unless (memq this-command '(exil-eval-last-sexp
                                               exil-eval-defun
                                               exil-eval-region
                                               exil-eval-buffer
                                               exil-send-line))
                    (exil--clear-overlay)
                    (remove-hook 'pre-command-hook clear-hook t)))))
        (add-hook 'pre-command-hook clear-hook nil t))))
  (message "%s" result))

(defun exil-eval-string (str)
  "Send STR to Exil REPL process and return the cleaned result string."
  (let* ((proc (exil--ensure-repl))
         (buf (process-buffer proc))
         (pmark (with-current-buffer buf (marker-position (process-mark proc)))))
    (with-current-buffer buf
      (process-send-string proc (concat (string-trim str) "\n"))
      (let ((timeout 100))
        (while (and (> timeout 0)
                    (not (string-match-p "REPL>"
                                         (buffer-substring-no-properties pmark (point-max)))))
          (accept-process-output proc 0.05)
          (setq timeout (1- timeout))))
      (let* ((raw (buffer-substring-no-properties pmark (point-max)))
             (lines (split-string raw "\n" t))
             (filtered (seq-remove (lambda (l)
                                     (string-match-p "\\`[ \t\\.]*\\(REPL>\\)?[ \t]*\\'" l))
                                   lines)))
        (string-trim (string-join filtered "\n"))))))

(defun exil--sexp-bounds ()
  "Return (START . END) of the sexp before point."
  (save-excursion
    (skip-chars-backward " \t\r\n")
    (let ((end (point)))
      (backward-sexp 1)
      (cons (point) end))))

(defun exil--defun-bounds ()
  "Return (START . END) of the top-level form around point."
  (save-excursion
    (end-of-defun)
    (let ((end (point)))
      (beginning-of-defun)
      (cons (point) end))))

(defun exil-eval-last-sexp ()
  "Evaluate the expression preceding point and show result below the line."
  (interactive)
  (let* ((bounds (exil--sexp-bounds))
         (code (buffer-substring-no-properties (car bounds) (cdr bounds)))
         (res (exil-eval-string code)))
    (exil--show-result (cdr bounds) res)
    res))

(defun exil-eval-defun ()
  "Evaluate the top-level form around point and show result below the line."
  (interactive)
  (let* ((bounds (exil--defun-bounds))
         (code (buffer-substring-no-properties (car bounds) (cdr bounds)))
         (res (exil-eval-string code)))
    (exil--show-result (cdr bounds) res)
    res))

(defun exil-eval-region (start end)
  "Evaluate active region and show result below the region."
  (interactive "r")
  (let* ((code (buffer-substring-no-properties start end))
         (res (exil-eval-string code)))
    (exil--show-result end res)
    res))

(defun exil-send-line ()
  "Evaluate current line and show result below the line."
  (interactive)
  (let* ((line (string-trim (thing-at-point 'line t))))
    (if (string-empty-p line)
        (user-error "Linha vazia")
      (let ((res (exil-eval-string line)))
        (exil--show-result (line-end-position) res)
        res))))

(defun exil-eval-buffer ()
  "Evaluate the entire buffer sexp-by-sexp in the REPL."
  (interactive)
  (let (last-res (count 0))
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (skip-chars-forward " \t\r\n")
        (unless (or (eobp) (eq (char-after) ?\;))
          (let ((start (point)))
            (forward-sexp 1)
            (let* ((code (buffer-substring-no-properties start (point)))
                   (res (exil-eval-string code)))
              (setq last-res res
                    count (1+ count)))))))
    (if last-res
        (progn
          (exil--show-result (point-max) last-res)
          (message "Buffer avaliado (%d expressões). Último resultado: %s" count last-res))
      (message "Buffer vazio ou sem expressões válidas."))))

(defun exil--file-to-module-name (file-path)
  "Convert FILE-PATH to an Exil PascalCase module name relative to project root."
  (let* ((root (or (locate-dominating-file file-path ".exil")
                   (locate-dominating-file file-path "mix.exs")
                   default-directory))
         (rel (file-relative-name file-path root))
         (without-ext (file-name-sans-extension rel))
         (segments (split-string without-ext "/" t)))
    (mapconcat
     (lambda (seg)
       (mapconcat #'capitalize (split-string seg "[_-]+" t) ""))
     segments
     "/")))

(defun exil-load-file ()
  "Save the current buffer and import it as a module into the Exil REPL."
  (interactive)
  (let ((file (buffer-file-name)))
    (unless file
      (user-error "Buffer does not have an associated file"))
    (when (buffer-modified-p)
      (save-buffer))
    (let* ((mod (exil--file-to-module-name file))
           (cmd (format "(import %s)" mod))
           (res (exil-eval-string cmd)))
      (if (string-match-p "\\`\\(?:Compiler \\)?Error" res)
          (message "Erro ao carregar módulo %s: %s" mod res)
        (message "Módulo %s carregado no REPL com sucesso! (%s)" mod cmd)))))

;; ---------------------------------------------------------------------------
;; Major Mode
;; ---------------------------------------------------------------------------

(defvar-keymap exil-mode-map
  "C-c C-c" #'exil-run-file
  "C-c C-k" #'exil-load-file
  "C-c C-z" #'exil-repl
  "C-x C-e" #'exil-eval-last-sexp
  "C-c C-e" #'exil-eval-last-sexp
  "C-M-x"   #'exil-eval-defun
  "C-c C-d" #'exil-eval-defun
  "C-c C-r" #'exil-eval-region
  "C-c C-l" #'exil-send-line
  "C-c C-b" #'exil-eval-buffer)

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
