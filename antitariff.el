; Copyright (c) 2013 Jason Lingle
;
; Emacs integration of antitariff, including minor mode.
(provide 'antitariff)

(defun antitariff-first-import ()
  "Moves to the position of the first import statement in the file."
  (interactive)
  (goto-char (point-min))
  (or
   (search-forward-regexp "^import " nil t)
   (and
    (search-forward-regexp "^package ")
    (forward-line 2)))
  (move-beginning-of-line nil))

(defun antitariff-get-first-import-pos ()
  "Returns the point of the first import statement in the file."
  (save-excursion
    (antitariff-first-import)
    (point)))

(defun antitariff-last-import ()
  "Moves to the line past the last import statement in the file."
  (interactive)
  (goto-char (point-max))
  (or
   (search-backward-regexp "^import " nil t)
   (antitariff-get-first-import-pos))
  (forward-line 1))

(defun antitariff-get-last-import-pos ()
  "Returns the point of the last import statement in the file."
  (save-excursion
    (antitariff-last-import)
    (point)))

(defun antitariff-next-best-match (import-line limit n)
  (search-forward-regexp (concat "^" (substring import-line 0 n)) limit t))

(defun antitariff-most-similar-import (import-line limit n)
  (if (antitariff-next-best-match import-line limit n)
      (if (= n (length import-line))
          ; Exact match, nothing to import
          nil
        ; No match yet, keep searching
        (move-beginning-of-line nil)
        (antitariff-most-similar-import import-line limit (1+ n)))
    ; Found best match; insert before or after this line
    (move-beginning-of-line nil)))

(defun antitariff-insert-before-or-after-this-line (import-line)
  (let ((begin (point)))
    (insert import-line)
    (forward-line 1)
    (sort-lines nil begin (point))))

(defun antitariff-insert-import (import-line)
  (save-excursion
    (let ((end (antitariff-get-last-import-pos)))
      (antitariff-first-import)
      (if (antitariff-most-similar-import import-line end 1)
          ; Actually have something to insert
          (antitariff-insert-before-or-after-this-line import-line)))))

(defun antitariff-import-class-at-point (try-harder)
  "Automatically insert an import statement for the class name under or near
point. This has no effect if the class is already imported, though it will
still add an import statement if the class is already in the current package.

With a universal argument, re-index antitariff if the class is not found on the
first try."
  (interactive "P")
  (let* ((flags (if try-harder "-H" ""))
         (command (concat "antitariff-find " flags " " (buffer-file-name) " "
                          (word-at-point)))
         (result (shell-command-to-string command)))
    (if (string-equal result "")
        (message "Not found: %s" (word-at-point))
      (antitariff-insert-import result)
      (message "%s" result))))

; TODO: Automatic minor mode
; This needs to wait until the auto-importer is smarter. Ie, it shouldn't add
; imports for things in the current package, should prioritise java* over
; others (so I get "java.util.List" instead of "antlr.collections.List"), and
; probably should understand globs.
