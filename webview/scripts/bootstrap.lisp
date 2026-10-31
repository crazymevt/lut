(require :asdf)
(defparameter *lut-checkout*
  (truename (merge-pathnames "../../" (uiop:pathname-directory-pathname *load-truename*))))
(let ((deps (merge-pathnames "webview/deps/" *lut-checkout*)))
  (if (probe-file deps)
      (asdf:initialize-source-registry
        `(:source-registry (:directory ,*lut-checkout*) (:tree ,deps) :inherit-configuration))
      (load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))))
(asdf:load-asd (merge-pathnames "lut.asd" *lut-checkout*))
(defvar *lut-short-cache* nil)
(defun lut-short-cache-file (path &rest ignored)
  (declare (ignore ignored))
  (let ((hash #xcbf29ce484222325))
    (loop for ch across (namestring path) do
      (setf hash (ldb (byte 64 0) (* (logxor hash (char-code ch)) #x100000001b3))))
    (merge-pathnames (make-pathname :name (format nil "~16,'0x-~a" hash (pathname-name path))
                                   :type (pathname-type path)) *lut-short-cache*)))
(let ((base (uiop:getenv "LUT_WEBVIEW_CACHE")))
  (when base
    (let* ((marker (merge-pathnames "webview/BUILD_ID" *lut-checkout*))
           (build (if (probe-file marker) (with-open-file (stream marker) (read-line stream)) "development")))
      (setf *lut-short-cache*
        (merge-pathnames (format nil "~a/~a/" (lisp-implementation-version) build)
                         (uiop:ensure-directory-pathname base))))
    (asdf:initialize-output-translations
      '(:output-translations (t (:function lut-short-cache-file)) :ignore-inherited-configuration))))
