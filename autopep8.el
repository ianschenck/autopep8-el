;;; autopep8.el --- autopep8 for python buffers

;; Credit must be given where credit is due, this is a copy and slight
;; modification of code extracted from go-mode.el, part of the Go
;; programming language toolchain (golang.org). The license for
;; go-mode.el follows.
;;
;; Copyright (c) 2012 The Go Authors. All rights reserved.

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:

;;    * Redistributions of source code must retain the above copyright
;; notice, this list of conditions and the following disclaimer.
;;    * Redistributions in binary form must reproduce the above
;; copyright notice, this list of conditions and the following disclaimer
;; in the documentation and/or other materials provided with the
;; distribution.
;;    * Neither the name of Google Inc. nor the names of its
;; contributors may be used to endorse or promote products derived from
;; this software without specific prior written permission.

;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;
;; Example Usage:
;;
;; (require 'autopep8)
;; (defun python-mode-keys ()
;;   "Modify python-mode local key map"
;;   (local-set-key (kbd "C-c C-p") 'autopep8))
;; (add-hook 'python-mode-hook 'python-mode-keys)
;; 
(require 'cl)

(defgroup autopep8 nil
  "autopep8 for python"
  :group 'languages)

(defcustom autopep8-command "autopep8"
  "The 'autopep8' command to use."
  :type 'string
  :group 'autopep8)

(defcustom autopep8-aggressive 1
  "The aggressiveness of autopep8."
  :type 'integer
  :options '(0 1 2)
  :group 'autopep8)

(defcustom autopep8-line-length 79
  "The maximum line length."
  :type 'integer
  :group 'autopep8)

(defun autopep8-before-save ()
  "Apply autopep8 to any python buffer before saving."
  (interactive)
  (when (eq major-mode 'python-mode) (autopep8)))

(defun autopep8 ()
  "Formats the current buffer with autopep8."

  (interactive)
  (let ((tmpfile (make-temp-file "autopep8" nil ".py"))
        (patchbuf (get-buffer-create "*autopep8 patch*"))
        (errbuf (get-buffer-create "*autopep8 Errors*"))
        (coding-system-for-read 'utf-8)
        (coding-system-for-write 'utf-8))

    (with-current-buffer errbuf
      (setq buffer-read-only nil)
      (erase-buffer))
    (with-current-buffer patchbuf
      (erase-buffer))

    (write-region nil nil tmpfile)

    (if (zerop (apply #'call-process (autopep8--commandline errbuf tmpfile)))
        (if (zerop (call-process-region (point-min) (point-max) "diff" nil patchbuf nil "-n" "-" tmpfile))
            (progn
              (kill-buffer errbuf)
              (message "Buffer is already pep8"))
          (autopep8--apply-rcs-patch patchbuf)
          (kill-buffer errbuf)
          (message "Applied autopep8"))
      (message "Could not apply autopep8. Check errors for details")
      (gofmt--process-errors (buffer-file-name) tmpfile errbuf))
    (kill-buffer patchbuf)
    (delete-file tmpfile)))

(defun autopep8--apply-rcs-patch (patch-buffer)
  "Apply an RCS-formatted diff from PATCH-BUFFER to the current
buffer."
  (let ((target-buffer (current-buffer))
        ;; Relative offset between buffer line numbers and line numbers
        ;; in patch.
        ;;
        ;; Line numbers in the patch are based on the source file, so
        ;; we have to keep an offset when making changes to the
        ;; buffer.
        ;;
        ;; Appending lines decrements the offset (possibly making it
        ;; negative), deleting lines increments it. This order
        ;; simplifies the forward-line invocations.
        (line-offset 0))
    (save-excursion
      (with-current-buffer patch-buffer
        (goto-char (point-min))
        (while (not (eobp))
          (unless (looking-at "^\\([ad]\\)\\([0-9]+\\) \\([0-9]+\\)")
            (error "invalid rcs patch or internal error in autopep8--apply-rcs-patch"))
          (forward-line)
          (let ((action (match-string 1))
                (from (string-to-number (match-string 2)))
                (len  (string-to-number (match-string 3))))
            (cond
             ((equal action "a")
              (let ((start (point)))
                (forward-line len)
                (let ((text (buffer-substring start (point))))
                  (with-current-buffer target-buffer
                    (decf line-offset len)
                    (goto-char (point-min))
                    (forward-line (- from len line-offset))
                    (insert text)))))
             ((equal action "d")
              (with-current-buffer target-buffer
                (autopep8--goto-line (- from line-offset))
                (incf line-offset len)
                (autopep8--delete-whole-line len)))
             (t
              (error "invalid rcs patch or internal error in autopep8--apply-rcs-patch")))))))))

(defun autopep8--commandline (errbuf tmpfile)
  ;; Build the autopep8 commandline.
  `(,autopep8-command nil ,errbuf nil ,@(make-list autopep8-aggressive "--aggressive") "--max-line-length" ,(number-to-string autopep8-line-length) "--in-place" ,tmpfile)
  )

(defun autopep8--goto-line (line)
  (goto-char (point-min))
  (forward-line (1- line)))

(defun autopep8--delete-whole-line (&optional arg)
  "Delete the current line without putting it in the `kill-ring'.
Derived from function `kill-whole-line'.  ARG is defined as for that
function."
  (setq arg (or arg 1))
  (if (and (> arg 0)
           (eobp)
           (save-excursion (forward-visible-line 0) (eobp)))
      (signal 'end-of-buffer nil))
  (if (and (< arg 0)
           (bobp)
           (save-excursion (end-of-visible-line) (bobp)))
      (signal 'beginning-of-buffer nil))
  (cond ((zerop arg)
         (delete-region (progn (forward-visible-line 0) (point))
                        (progn (end-of-visible-line) (point))))
        ((< arg 0)
         (delete-region (progn (end-of-visible-line) (point))
                        (progn (forward-visible-line (1+ arg))
                               (unless (bobp)
                                 (backward-char))
                               (point))))
        (t
         (delete-region (progn (forward-visible-line 0) (point))
                        (progn (forward-visible-line arg) (point))))))

(defun autopep8--process-errors (filename tmpfile errbuf)
  ;; Convert the autopep8 stderr to something understood by the compilation mode.
  (with-current-buffer errbuf
    (goto-char (point-min))
    (insert "autopep8 errors:\n")
    (while (search-forward-regexp (concat "^\\(" (regexp-quote tmpfile) "\\):") nil t)
      (replace-match (file-name-nondirectory filename) t t nil 1))
    (compilation-mode)
    (display-buffer errbuf)))

(provide 'autopep8)
