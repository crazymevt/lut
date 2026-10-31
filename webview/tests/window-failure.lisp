(load (merge-pathnames "../scripts/bootstrap.lisp" *load-truename*))
(asdf:load-system "lut/cef")
(let* ((names '(rl:init-window rl:is-window-ready rl:close-window rl::prepare-app rl::release-app))
       (originals (mapcar #'symbol-function names))
       (closed nil) (released nil) (failed nil))
  (unwind-protect
    (progn
      (setf (symbol-function 'rl:init-window) (lambda (&rest args) (declare (ignore args)) nil)
            (symbol-function 'rl:is-window-ready) (lambda () nil)
            (symbol-function 'rl:close-window) (lambda () (setf closed t))
            (symbol-function 'rl::prepare-app) (lambda () nil)
            (symbol-function 'rl::release-app) (lambda () (setf released t)))
      (handler-case
        (lut-webview::call-with-native-run
          (lambda () (rl::call-with-window (lambda () (error "Unexpected drawing")) 100 100 "Failure test")))
        (error (condition) (setf failed (search "couldn't open" (princ-to-string condition)))))
      (assert failed) (assert released) (assert (not closed)))
    (loop for name in names for original in originals do (setf (symbol-function name) original))))
(format t "PASS: failed OpenGL initialization does not call native window cleanup.~%")
