;;; ui.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;;   Modern UI configuration for Emacs 30+
;;;   Optimized for performance and stability
;;; Code:


;; General Settings
(setq-default fill-column 80
              bidi-paragraph-direction 'left-to-right
              truncate-string-ellipsis "…"
              auto-revert-check-vc-info nil
              truncate-lines t)

(setopt mouse-wheel-scroll-amount-horizontal 4
        hscroll-step 1
        hscroll-margin 2
        window-divider-default-right-width 6
        window-combination-resize nil)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(context-menu-mode 1)
(window-divider-mode 1)

(setopt frame-resize-pixelwise t)

;; Cursor & Focus
(setq-default cursor-type '(hbar . 2)
              cursor-in-non-selected-windows nil
              focus-follows-mouse t
              mouse-autoselect-window nil)
(blink-cursor-mode -1)
(pixel-scroll-precision-mode 1)

;; Font Configuration
(defconst my/ui-font-mono "JetBrains Mono")
(defconst my/ui-font-italic "Victor Mono")
(defconst my/ui-font-height 140)

(set-face-attribute 'default nil
                    :family my/ui-font-mono
                    :height my/ui-font-height
                    :weight 'regular)

(set-face-attribute 'bold nil
                    :family my/ui-font-mono
                    :weight 'medium)

(set-face-attribute 'italic nil
                    :family my/ui-font-italic
                    :weight 'semilight
                    :slant 'italic)

;; Theme
(defun my/ui--safe-color (color &optional fallback)
  (if (and (stringp color)
           (not (string-prefix-p "unspecified" color)))
      color
    fallback))

(defun my/ui-refresh-theme-faces ()
  (let* ((default-bg (my/ui--safe-color (face-background 'default nil 'default) "#181818"))
         (mode-line-bg (my/ui--safe-color (face-background 'mode-line nil 'default)))
         (mode-line-active-bg (my/ui--safe-color (face-background 'mode-line-active nil 'default)))
         (divider-bg (or mode-line-bg mode-line-active-bg default-bg)))
    ;; Frame background.
    (setq default-frame-alist (cons
                               (cons 'background-color default-bg)
                               (assq-delete-all 'background-color default-frame-alist)))

    (dolist (frame (frame-list))
      (when (display-graphic-p frame)
        (set-frame-parameter frame 'background-color default-bg)))

    ;; Flatten mode-line, but keep theme colors.
    (dolist (face '(mode-line mode-line-active mode-line-inactive))
      (when (facep face)
        (set-face-attribute face nil
                            :box nil
                            :overline nil
                            :underline nil)))

    (when (and (facep 'mode-line-active)
               mode-line-bg
               (or (not mode-line-active-bg)
                   (equal mode-line-active-bg default-bg)))
      (set-face-background 'mode-line-active mode-line-bg)
      (setq divider-bg mode-line-bg))

    ;; Separators.
    (dolist (face '(window-divider
                    window-divider-first-pixel
                    window-divider-last-pixel
                    vertical-border
                    fringe))
      (when (facep face)
        (set-face-background face divider-bg)
        (set-face-foreground face divider-bg)))))


(add-hook 'after-load-theme-hook #'my/ui-refresh-theme-faces)


;; Theme

(load-theme 'gruber-darker t)

;; Refresh correctly for emacsclient frames

(defun my/ui-refresh-client-frame (frame)
  (when (display-graphic-p frame)
    (load-theme 'gruber-darker t)
    (dolist (theme (remq 'gruber-darker custom-enabled-themes))
      (disable-theme theme))
    (my/ui-refresh-theme-faces)
    (remove-hook 'after-make-frame-functions #'my/ui-refresh-client-frame)))

(if (daemonp)
    (add-hook 'after-make-frame-functions #'my/ui-refresh-client-frame))

;; Faces
(defface my/ui-faded-face
  '((t :inherit shadow))
  "Face for faded UI elements.")

(defface my/ui-pill-face
  '((t :inherit font-lock-keyword-face
       :inverse-video t))
  "A native pill tag.")

;; Icons & Marginalia
(use-package nerd-icons
  :custom
  (nerd-icons-font-family "Symbols Nerd Font Mono"))

;; Display Table
(setq standard-display-table
      (or standard-display-table (make-display-table)))

(set-display-table-slot standard-display-table 'truncation
                        (make-glyph-code ?… 'my/ui-faded-face))

(set-display-table-slot standard-display-table 'wrap
                        (make-glyph-code ?↩ 'my/ui-faded-face))

;; Buffer & Window Interaction
(defvar my/ui-buffer-name-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down-mouse-1] #'my/ui-open-buffer-list)
    map)
  "Keymap for the mode-line buffer name.")

(defun my/ui-window-indicator ()
  "Return a circle indicating if the window is active."
  (let* ((active (mode-line-window-selected-p))
         (color (if active 'font-lock-keyword-face 'shadow))
         (icon (ignore-errors
                 (if active
                     (nerd-icons-faicon "circle")
                   (nerd-icons-faicon "circle-o")))))
    (propertize (concat (or icon (if active "◉" "○")) " ")
                'face color)))

(defun my/ui-open-buffer-list (event)
  "Open a buffer list from the mode line."
  (interactive "e")
  (select-window (posn-window (event-start event)))
  (if (fboundp 'consult-buffer)
      (call-interactively #'consult-buffer)
    (call-interactively #'list-buffers)))

;; Uniquify Buffer Names
(use-package uniquify
  :ensure nil
  :custom
  (uniquify-buffer-name-style 'forward)
  (uniquify-separator "/")
  (uniquify-after-kill-buffer-p t)
  (uniquify-ignore-buffers-re "^\\*"))

;; Mode Line Configuration
(defvar my/modeline-left
  `(" "
    (:eval (my/ui-window-indicator))
    " "
    (:eval (propertize (buffer-name)
                       'face (if (mode-line-window-selected-p) 'bold 'shadow)
                       'help-echo "Click to open buffer list"
                       'mouse-face 'highlight
                       'local-map my/ui-buffer-name-map))
    "  "
    (:eval (propertize (cond (buffer-read-only " RO ")
                             ((buffer-modified-p) " ** ")
                             (t " RW "))
                       'face 'my/ui-faded-face))
    "  "
    (:eval (propertize (format " %s " (format-mode-line mode-name))
                       'face 'my/ui-pill-face))
    "   "
    (:eval (if (use-region-p)
               (let ((lines (count-lines (region-beginning) (region-end)))
                     (chars (- (region-end) (region-beginning))))
                 (propertize (format "%d:%d" lines chars) 'face 'font-lock-keyword-face))
             (propertize "%l:%c" 'face 'my/ui-faded-face)))))

(defvar my/modeline-right
  `(" "
    (:eval (when defining-kbd-macro
             (propertize "⏺ REC  " 'face '(:inherit warning :weight bold))))
    (:eval (when (and vc-mode (stringp vc-mode))
             (let ((branch (replace-regexp-in-string "^[ -]*[A-Za-z]+[-:]" "" (substring-no-properties vc-mode))))
               (concat (propertize (if (fboundp 'nerd-icons-octicon)
                                       (nerd-icons-octicon "git-branch")
                                     "")
                                   'face 'my/ui-faded-face)
                       " "
                       (propertize branch 'face 'my/ui-faded-face)))))
    " "))

(setq-default mode-line-format
              '("%e"
                (:eval
                 (let* ((right (format-mode-line my/modeline-right))
                        (right-width (string-width right))
                        (left (format-mode-line my/modeline-left)))
                   (concat left
                           (propertize " "
                                       'display `(space :align-to (- right ,right-width)))
                           right)))))

;;  Line Numbers
(setq-default display-line-numbers-type t)
(setq-default display-line-numbers-width 3)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'conf-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

;;  Minibuffer & Misc
(setq use-dialog-box t)
(setq visible-bell t)
(setq use-short-answers t)
(set-face-attribute 'minibuffer-prompt nil
                    :weight 'bold
                    :height 1.2)

;;  Window Management
(defun my/move-to-clean-frame ()
  "Move the current buffer into a new clean frame."
  (interactive)
  (let* ((buf (current-buffer))
         (old-win (selected-window))
         (new-frame (make-frame))
         (new-win (frame-root-window new-frame)))
    (set-window-buffer new-win buf)
    (select-frame-set-input-focus new-frame)
    (set-window-dedicated-p new-win t)
    (when (window-deletable-p old-win)
      (delete-window old-win))))


(defun my/toggle-window-split ()
  "Toggle between horizontal and vertical split for two windows."
  (interactive)
  (unless (= (count-windows) 2)
    (user-error "This command only works when there are exactly 2 windows"))
  (let* ((this-buf (window-buffer))
         (other-buf (window-buffer (next-window)))
         (stacked (window-full-width-p)))
    (delete-other-windows)
    (if stacked
        (split-window-right)
      (split-window-below))
    (set-window-buffer (selected-window) this-buf)
    (set-window-buffer (next-window) other-buf)))

(keymap-global-set "C-c w" #'my/toggle-window-split)
(keymap-global-set "C-c f" #'my/move-to-clean-frame)

(provide 'init/ui)
;;; ui.el ends here
