;;; tools.el -- --*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:


;;; Keybinding Discoverability
(if (fboundp 'which-key-mode)
    (which-key-mode 1)
  (use-package which-key
    :init
    (which-key-mode 1)))

;;; Better Describe
(use-package helpful
  :bind
  (("C-h f" . helpful-callable)
   ("C-h v" . helpful-variable)
   ("C-h k" . helpful-key)
   ("C-h C" . helpful-command)
   ("C-c C-d" . helpful-at-point)))

;;; Magit
(use-package transient)
(setq vc-handled-backends '(Git)) ;; Ignore other backends
(use-package magit
  :after transient
  :bind
  (("C-x g" . magit-status)
   ("C-x M-g" . magit-dispatch))
  :config
  (when (featurep 'nerd-icons) (setq magit-format-file-function #'magit-format-file-nerd-icons))
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;;; Pinentry
;; allow passphrase prompts inside of emacs instead of external popups.
(use-package pinentry
  :init
  (setq epa-pinentry-mode 'loopback)
  (pinentry-start))

;; Highlight symbols
(use-package idle-highlight-mode
  :ensure t
  :hook ((prog-mode . idle-highlight-mode)
         (text-mode . idle-highlight-mode)))

;; Click to go to definition
(require 'ffap)
(global-set-key (kbd "C-<down-mouse-1>") #'ffap-at-mouse)

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-force-searcher 'rg)
  :init
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
  :bind
  (("C-M-." . dumb-jump-go)
   ("C-M-," . dumb-jump-back)))


;; Mise
(use-package mise
  :if (executable-find "mise")
  :hook (after-init . mise-mode)
  :init
  (global-mise-mode 1))

;; Project Identification
(use-package project
  :ensure nil
  :custom
  (project-vc-extra-root-markers
   '(
     ".project"
     "mise.toml"
     ".mise.toml"
     ".tool-versions")))


;;; Dirvish
(use-package dired
  :ensure nil
  :hook
  (dired-mode . (lambda () (setq-local mouse-1-click-follows-link nil)))
  :bind
  (:map dired-mode-map
        ("RET"              . my/dirvish-smart-enter)
        ("<return>"         . my/dirvish-smart-enter)
        ("SPC"              . my/dirvish-smart-space)
        ("<down-mouse-1>"   .  my/dirvish-smart-mouse)
        ("<mouse-1>"   . ignore)
        ("<double-mouse-1>" . ignore)
        ("<drag-mouse-1>"   . my/dirvish-smart-mouse)
        ([remap dired-mouse-find-file] . my/dirvish-smart-mouse)))

(use-package dirvish
  :demand t
  :init
  (dirvish-override-dired-mode)
  :custom
  (dired-listing-switches "-lAh --group-directories-first")
  (dired-kill-when-opening-new-dired-buffers t)
  (dirvish-attributes '(nerd-icons collapse subtree-state))
  (dirvish-side-width 38)
  (dirvish-hide-cursor t)
  :bind
  (("C-c e" . my/toggle-project-tree)
   :map dirvish-mode-map
   ("TAB" . dirvish-subtree-toggle)
   ("a"   . dirvish-layout-toggle)
   ("<backspace>" . dired-up-directory)
   ("<return>"    . my/dirvish-smart-enter)
   ("<down-mouse-1>"   .  my/dirvish-smart-mouse)
   ("<mouse-1>"   . ignore)
   ("<double-mouse-1>" . ignore)
   ("<drag-mouse-1>"   . my/dirvish-smart-mouse)
   ("SPC"         . my/dirvish-smart-space)
   ("<S-return>"  . dired-find-file)))

;; Update Files when they change on disk
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)

;; Remember cursor position across sessions
(save-place-mode 1)

(defun my/kill-buffer-and-window ()
  "Kill current buffer and close its window if others exist."
  (interactive)
  (let ((buf (current-buffer)))
    (call-interactively #'kill-buffer)
    (when (and (not (buffer-live-p buf))
               (> (length (window-list)) 1))
      (delete-window))))

(global-set-key (kbd "C-x k") #'my/kill-buffer-and-window)

;; Helpers

(defun my/project-info ()
  "Print the current project root, or warn if not in a project."
  (interactive)
  (if-let ((proj (project-current)))
      (message "Current project root: %s" (project-root proj))
    (message "Not in a recognized project!")))

(defun my/dirvish-side-windows ()
  "Return Dirvish side tree windows in the current frame."
  (seq-filter
   (lambda (w)
     (and (window-parameter w 'window-side)
          (with-current-buffer (window-buffer w)
            (derived-mode-p 'dired-mode))))
   (window-list)))

(defun my/toggle-project-tree ()
  "Toggle Dirvish side tree globally."
  (interactive)
  (require 'dirvish nil t)
  (if-let ((wins (my/dirvish-side-windows)))
      (dolist (win wins)
        (when (window-deletable-p win)
          (delete-window win)))
    (let ((default-directory
           (if (eq major-mode 'dashboard-mode)
               (expand-file-name "~/")
             default-directory)))
      (dirvish-side))))



(defun my/main-window ()
  "Return the largest non-side window."
  (let ((best nil)
        (best-size -1))
    (walk-window-tree
     (lambda (w)
       (unless (or (window-parameter w 'window-side)
                   (window-minibuffer-p w))
         (let ((size (* (window-height w)
                        (window-width w))))
           (when (> size best-size)
             (setq best w best-size size))))))
    (or best (selected-window))))

(defun my/display-buffer-in-main-window (buffer _alist)
  "Display BUFFER in the largest non-side window."
  (let ((window (my/main-window)))
    (when window
      (let ((dedicated (window-dedicated-p window)))
        (set-window-dedicated-p window nil)
        (set-window-buffer window buffer)
        (set-window-dedicated-p window dedicated))
      (select-window window)
      window)))

(defun my/delete-dirvish-side-window ()
  "Delete the Dirvish side tree window if it exists."
  (when-let ((win (seq-find
                   (lambda (w)
                     (and (window-parameter w 'window-side)
                          (with-current-buffer (window-buffer w)
                            (derived-mode-p 'dired-mode))))
                   (window-list))))
    (when (window-deletable-p win)
      (delete-window win))))

(defun my/dirvish-open-entry (file)
  (cond
   ((and file (file-directory-p file))
    (dirvish-subtree-toggle))
   (file
    (let ((buf (find-file-noselect file)))
      (my/display-buffer-in-main-window buf nil))
    (my/delete-dirvish-side-window))))

(defun my/dirvish-smart-enter ()
  "Keyboard version."
  (interactive)
  (my/dirvish-open-entry (dired-get-filename nil t)))

(defun my/dirvish-smart-mouse (event)
  "Mouse version."
  (interactive "e")
  (let* ((posn (event-start event))
         (win (posn-window posn)))
    (when (window-live-p win)
      (with-current-buffer (window-buffer win)
        (goto-char (posn-point posn))
        (my/dirvish-open-entry (dired-get-filename nil t))))))

(defun my/dirvish-smart-space ()
  "Toggle subtree if on a folder, do nothing on a file."
  (interactive)
  (let ((file (dired-get-filename nil t)))
    (when (and file (file-directory-p file))
      (dirvish-subtree-toggle))))


(provide 'init/tools)
;;; tools.el ends here
