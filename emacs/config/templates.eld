;; Templates for Tempel

emacs-lisp-mode

(header ";;; " (file-name-nondirectory (buffer-file-name)) " --- " p " -*- lexical-binding: t; -*-" n n
        ";;; Commentary:" n
        ";; " p n n
        ";;; Code:" n n
        q n n
        "(provide '" (file-name-sans-extension (file-relative-name (buffer-file-name) (expand-file-name "lisp" user-emacs-directory))) ")" n
        ";;; " (file-name-nondirectory (buffer-file-name)) " ends here")

(sheader ";;; " (file-name-nondirectory (buffer-file-name)) " --- " p " -*- lexical-binding: t; -*-" n
         ";;; Commentary: " n
         ";;; Code:" n n
         q)
