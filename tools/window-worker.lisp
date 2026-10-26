(require :asdf)
(let ((*standard-output* *error-output*) (*trace-output* *error-output*))
  (let ((quicklisp (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
    (when (probe-file quicklisp) (load quicklisp)))
  (asdf:load-asd (merge-pathnames "../lui.asd" *load-truename*))
  (asdf:load-system "lui/raylib"))
#+(and ccl darwin) (ccl::call-in-initial-process #'lui::worker-main)
#-(and ccl darwin) (lui::worker-main)
;; CCL otherwise starts its listener after --load returns and writes a banner to
;; the already-closed IPC output pipe. A worker has no interactive listener.
(uiop:quit 0)
