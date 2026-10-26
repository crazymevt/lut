(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lui.asd"))
(ql:quickload "lui/examples")
(dolist (builder '(lui-examples:hello-world lui-examples:todo lui-examples:editor
                   lui-examples:drawing lui-examples:clock lui-examples:adwaita lui-examples:gallery))
  (format t "Smoke: ~a~%" builder)
  (lui:run (funcall builder) :frames 3))
(format t "All seven native window smoke checks passed.~%")
