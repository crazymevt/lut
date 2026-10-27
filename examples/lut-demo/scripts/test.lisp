(load (merge-pathnames "bootstrap.lisp" *load-truename*))
(asdf:test-system "lut/demo")
