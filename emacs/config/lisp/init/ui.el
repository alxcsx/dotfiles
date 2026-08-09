;;; ui.el ---  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; Core
(setq-default fill-column 80
              sentence-end-double-space nil
              bidi-paragraph-direction 'left-to-right
              truncate-string-ellipsis "…")

(when (fboundp 'pixel-scroll-precision-mode) (pixel-scroll-precision-mode 1))
(setq mouse-wheel-scroll-amount-horizontal 4)
(setq hscroll-step 1 hscroll-margin 2)
(blink-cursor-mode 0)
(setq-default cursor-type '(hbar . 2)
	            cursor-in-non-selected-windows nil)

(setq-default truncate-lines t)

;; Color Scheme
(use-package gruber-darker-theme
  :config
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'gruber-darker t))

;; Layout
(setq window-divider-default-right-width 1
      window-divider-default-bottom-width 1
      window-combination-resize nil)

(window-divider-mode 1)
(set-face-attribute 'window-divider nil :foreground 'unspecified :inherit 'shadow)

(modify-all-frames-parameters
 '((internal-border-width . 4)
   (right-fringe . 0)
   (left-fringe . 2)))

;; Icons

(use-package nerd-icons
  :custom
  (nerd-icons-font-family "Symbols Nerd Font Mono"))

(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode 1)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

;; Typography
(set-face-attribute 'default nil :family "JetBrains Mono" :height 140 :weight 'regular)
(set-face-attribute 'bold nil :family "JetBrains Mono" :weight 'medium)
(set-face-attribute 'italic nil :family "Victor Mono" :weight 'semilight :slant 'italic)


;; Mode-Line
(defface my-ui-faded-face
  '((t :inherit shadow))
  "Face for faded UI elements, like ellipses, line numbers, and wrap symbols.")

(set-display-table-slot standard-display-table 'truncation (make-glyph-code ?… 'my-ui-faded-face))
(set-display-table-slot standard-display-table 'wrap (make-glyph-code ?↩ 'my-ui-faded-face))

;; Native pill tags (replaces heavy svg-lib generation)
(defface my-ui-pill-face
  '((t :inherit font-lock-keyword-face
       :inverse-video t
       :box (:line-width (3 . 6) :style flat-button)
       :weight bold))
  "A native pill tag.")

(require 'uniquify)
(setq uniquify-buffer-name-style 'forward
      uniquify-separator "/"
      uniquify-after-kill-buffer-p t
      uniquify-ignore-buffers-re "^\\*")



(defun my-ui-open-buffer-list (event)
  "Open `consult-buffer` interactively via a mouse click on the mode-line."
  (interactive "e") ;
  ;; Ensure we open ibuffer in the window you actually clicked
  (select-window (posn-window (event-start event)))
  (consult-buffer))

(defvar my-ui-buffer-name-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down-mouse-1] #'my-ui-open-buffer-list)
    map)
  "Keymap for the mode-line buffer name.")

(defun my-ui-window-indicator ()
  "Return a circle indicating if the window is active."
  (let* ((active (mode-line-window-selected-p))
         (color (if active 'font-lock-keyword-face 'shadow))
         (icon (ignore-errors
                 (if active
                     (nerd-icons-faicon "nf-fa-circle")
                   (nerd-icons-faicon "nf-fa-circle_o")))))
    (propertize (concat (or icon (if active "◉" "○")) " ")
                'face color)))


(defvar my-modeline-left
  `(" "
    ;; ACTIVE WINDOW INDICATOR
    (:eval (my-ui-window-indicator))
    ;; Narrow Warning
    " "
    (:eval (when (buffer-narrowed-p)
             (propertize " NARROWED " 'face '(:inherit warning :inverse-video t :weight bold))))
    ;; Buffer name
    (:eval (propertize (buffer-name)
                       'face (if (mode-line-window-selected-p) 'bold 'shadow)
                       'help-echo "Left-click: Open Buffer List"
                       'mouse-face 'highlight
                       'local-map my-ui-buffer-name-map))
    "  "
    ;; Read-Only / Modified Status
    (:eval (cond (buffer-read-only (propertize "RO" 'face 'my-ui-faded-face))
                 ((buffer-modified-p) (propertize "**" 'face 'warning))
                 (t (propertize "RW" 'face 'shadow))))
    "  "
    ;; Major Mode (Language) using pill face
    (:eval (propertize (format " %s " (format-mode-line mode-name))
                       'face 'my-ui-pill-face))
    ;; Line/Col numbers OR Selection Stats
    "   "
    (:eval (if (use-region-p)
               (let ((lines (count-lines (region-beginning) (region-end)))
                     (chars (- (region-end) (region-beginning))))
                 (propertize (format "%d:%d" lines chars) 'face 'font-lock-keyword-face))
             (propertize "%l:%c" 'face 'my-ui-faded-face)))))

(defvar my-modeline-right
  '(;; Macro Recording Indicator
    (:eval (when defining-kbd-macro
             (propertize "⏺ REC  " 'face '(:inherit warning :weight bold))))

    ;; Git Branch
    (:eval (when (and vc-mode (stringp vc-mode))
             (let ((branch (replace-regexp-in-string "^[ -]*[A-Za-z]+[-:]" "" (substring-no-properties vc-mode))))
               (concat (propertize (if (fboundp 'nerd-icons-octicon)
                                       (nerd-icons-octicon "nf-oct-git_branch")
                                     "")
                                   'face 'my-ui-faded-face)
                       " "
                       (propertize branch 'face 'my-ui-faded-face)))))
    " "))

(setq-default mode-line-format
              `("%e"
                ,@my-modeline-left

                ;; The magic spacer that pushes the right side
                (:eval (propertize " " 'display
                                   `(space :align-to (- right ,(string-width (format-mode-line my-modeline-right))))))

                ,@my-modeline-right))

;; Apply the 3D-removal tweaks at the same time
(set-face-attribute 'mode-line nil :box nil :overline t :background 'unspecified)
(set-face-attribute 'mode-line-inactive nil :box nil :overline t :background 'unspecified)
;; Remove 3D effect from mode-line

;; Line numbers
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'conf-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

(setq-default display-line-numbers-type t)
(setq-default display-line-numbers-width 3)

;; Confirmation Prompt

(setq use-dialog-box t)
(setq visible-bell t)
(setopt use-short-answers t)

(set-face-attribute 'minibuffer-prompt nil
                    :weight 'bold
                    :height 1.2)

;; Mouse Focus

(setq mouse-autoselect-window -0.1)
(setq focus-follows-mouse t)


;; Frame Control

(defun my/move-to-clean-frame ()
  "Move the current window into a new, dedicated, mode-line-free frame."
  (interactive)
  (let ((buf (current-buffer))
        (orig-win (selected-window)))
    (let* ((new-frame (make-frame '((menu-bar-lines . 0)
                                    (tool-bar-lines . 0)
                                    (vertical-scroll-bars . nil))))
           (new-win (frame-root-window new-frame)))
      (set-window-buffer new-win buf)
      (set-window-dedicated-p new-win t)
      (select-frame-set-input-focus new-frame)
      (when (window-deletable-p orig-win)
        (delete-window orig-win)))))

(global-set-key (kbd "C-c f") #'my/move-to-clean-frame)

(defun my/toggle-window-split ()
  "Toggle between a horizontal and vertical split for 2 windows."
  (interactive)
  (if (not (= (count-windows) 2))
      (message "This command only works when there are exactly 2 windows on screen.")
    (let ((this-buf (window-buffer))
          (other-buf (window-buffer (next-window)))
          (stacked (= (window-width) (frame-width))))
      (delete-other-windows)
      (if stacked
          (split-window-right)   ; Pivot to side-by-side
        (split-window-below))    ; Pivot back to top-and-bottom
      (set-window-buffer (next-window) other-buf))))

(global-set-key (kbd "C-c w") #'my/toggle-window-split)

(provide 'init/ui)
;;; ui.el ends here
