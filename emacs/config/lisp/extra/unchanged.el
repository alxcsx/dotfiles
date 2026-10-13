;;; unchanged.el -- -*- lexical-binding: t; -*-
;;; Commentary:
;;; Emacs flags a buffer as modified on any change, even when you move text
;;; around and put it back. This clears the flag once the buffer text matches
;;; the file on disk again, so VC/magit and kill-buffer stop lying.
;;; Code:

(defconst my/unchanged-check-max-size 2000000
  "Skip the comparison for buffers larger than this many characters.")

(defvar-local my/unchanged-check-timer nil)

(defun my/clear-modified-if-unchanged (buffer)
  "Clear BUFFER's modified flag when its text equals its file on disk."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and buffer-file-name
                 (buffer-modified-p)
                 (not (file-remote-p buffer-file-name))
                 (file-regular-p buffer-file-name)
                 (<= (buffer-size) my/unchanged-check-max-size))
        (let* ((file buffer-file-name)
               (file-text (with-temp-buffer
                            (insert-file-contents file)
                            (buffer-string))))
          (when (equal file-text (buffer-string))
            (set-buffer-modified-p nil)))))))

(defun my/schedule-unchanged-check (&rest _)
  "Arm an idle check after a change, unless one is already pending."
  (when (and buffer-file-name
             (buffer-modified-p)
             (not (timerp my/unchanged-check-timer)))
    (setq my/unchanged-check-timer
          (run-with-idle-timer 0.5 nil
                               (lambda (buf)
                                 (with-current-buffer buf
                                   (setq my/unchanged-check-timer nil))
                                 (my/clear-modified-if-unchanged buf))
                               (current-buffer)))))

(defun my/clean-modified-before-kill ()
  "Run the check before the kill-buffer prompt fires."
  (my/clear-modified-if-unchanged (current-buffer))
  t)

(add-hook 'after-change-functions #'my/schedule-unchanged-check)
(add-hook 'kill-buffer-query-functions #'my/clean-modified-before-kill)

(defun my/unchanged-self-test ()
  "Check that the flag clears on a no-op change and stays on a real one."
  (interactive)
  (let ((file (make-temp-file "unchanged-test" nil ".txt")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "hello\nworld\n"))
          (with-current-buffer (find-file-noselect file)
            (goto-char (point-min))
            (insert "x")
            (delete-char -1)
            (unless (buffer-modified-p) (error "no-op change left the flag clear"))
            (my/clear-modified-if-unchanged (current-buffer))
            (when (buffer-modified-p) (error "flag not cleared for unchanged buffer"))
            (insert "x")
            (my/clear-modified-if-unchanged (current-buffer))
            (unless (buffer-modified-p) (error "flag wrongly cleared for changed buffer"))
            (set-buffer-modified-p nil)
            (kill-buffer)))
      (delete-file file)))
  t)

(provide 'extra/unchanged)
;;; unchanged.el ends here
