(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/examples")
(dolist (builder '(lut-examples:hello-world lut-examples:todo lut-examples:editor
                   lut-examples:drawing lut-examples:clock lut-examples:adwaita lut-examples:gallery))
  (format t "Smoke: ~a~%" builder)
  (lut:run (funcall builder) :frames 3))
(format t "All seven native window smoke checks passed.~%")
