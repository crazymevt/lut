(require :asdf)
(defparameter *lut-checkout*
  (truename (merge-pathnames "../../" (uiop:pathname-directory-pathname *load-truename*))))
(let ((deps (merge-pathnames "webview/deps/" *lut-checkout*)))
  (if (probe-file deps)
      (asdf:initialize-source-registry
        `(:source-registry (:directory ,*lut-checkout*) (:tree ,deps) :inherit-configuration))
      (load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))))
(asdf:load-asd (merge-pathnames "lut.asd" *lut-checkout*))
