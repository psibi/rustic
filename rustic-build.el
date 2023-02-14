;;; rustic-build.el --- Build support -*-lexical-binding: t-*-
;;; Commentary:

;; This implements various functionalities related to cargo build to
;; show result of expansion

;;; Code:

(require 'rustic-cargo)
(require 'rustic-compile)

(defvar rustic-build-process-name "rustic-cargo-build-process"
  "Process name for build processes.")

(defvar rustic-build-buffer-name "cargo-build"
  "Buffer name for build buffers.")

(defvar-local rustic-build-arguments ""
  "Holds arguments for 'cargo build', similar to `compilation-arguments`.")

(defvar-local rustic-crate-hash nil
  "Project specific hash.")

(defun rustic-locate-project ()
  "Return the cargo.toml file location of the project."
  (with-temp-buffer
    (list (call-process "cargo" nil t t "locate-project" "--message-format" "plain" "--quiet") (s-trim (buffer-string)) )))

(defun rustic-project-hash ()
  "Return project specific hash.  Errors out on invalid invocation directory."
  (let ((crate-location (rustic-locate-project)))
     (if (eq (car crate-location) 0)
         (cl-subseq (md5 (car (cdr crate-location))) 0 5)
       (error (car (cdr crate-location))))))

(defvar rustic-cargo-build-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap recompile] 'rustic-cargo-build-rerun)
    map)
  "Local keymap for `rustic-cargo-build-mode' buffers.")

(define-derived-mode rustic-cargo-build-mode rustic-compilation-mode "cargo-build"
  :group 'rustic)

;;;###autoload
(defun rustic-cargo-build (&optional arg)
  "Run 'cargo build'.

If ARG is not nil, use value as argument and store it in
`rustic-build-arguments'.  When calling this function from
`rustic-popup-mode', always use the value of
`rustic-build-arguments'."
  (interactive "P")
  (when (not rustic-crate-hash)
    (setq-local rustic-crate-hash (rustic-project-hash)))
  (rustic-cargo-build-command
   (cond (arg
          (setq-local rustic-build-arguments (read-from-minibuffer "Cargo build arguments: " rustic-build-arguments)))
         (t ""))))

(defun rustic-cargo-build-command (&optional build-args)
  "Start compilation process for 'cargo build' with optional BUILD-ARGS."
  (let* ((command (list (rustic-cargo-bin) "build"))
         (c (append command (split-string (if build-args build-args ""))))
         (crate-hash rustic-crate-hash)
         (buf (format "*%s-%s*" rustic-build-buffer-name crate-hash))
         (proc (format "%s-%s" rustic-build-process-name crate-hash))
         (mode 'rustic-cargo-build-mode))
    (rustic-compilation c (list :buffer buf :process proc :mode mode))
    (with-current-buffer buf
      (setq-local rustic-crate-hash crate-hash)
      (setq-local rustic-build-arguments build-args))))

;;;###autoload
(defun rustic-cargo-build-rerun ()
  "Run 'cargo build' with `rustic-build-arguments'."
  (interactive)
  (rustic-cargo-build-command rustic-build-arguments))

(provide 'rustic-build)
;;; rustic-build.el ends here
