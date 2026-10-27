(require :asdf)
;; Resolve the enclosing checkout from this file, independent of CWD and any
;; older sibling lut-demo installation in Quicklisp's registry.
(let* ((scripts (uiop:pathname-directory-pathname *load-truename*))
       (library (truename (merge-pathnames "../../../lut.asd" scripts))))
  (asdf:load-asd library))
