(require :asdf)
(let ((*standard-output* *error-output*) (*trace-output* *error-output*))
  (let ((quicklisp (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
    (when (probe-file quicklisp) (load quicklisp)))
  (asdf:load-asd (merge-pathnames "../lut.asd" *load-truename*))
  (asdf:load-system "lut/raylib"))
#+(and ccl darwin) (ccl::call-in-initial-process #'lut::worker-main)
#-(and ccl darwin) (lut::worker-main)
;; CCL otherwise starts its listener after --load returns and writes a banner to
;; the already-closed IPC output pipe. A worker has no interactive listener.
(uiop:quit 0)
