(load (merge-pathnames "../scripts/bootstrap.lisp" *load-truename*))
(asdf:load-system "lut/cef")
(lut-webview::call-with-native-run (lambda () (error "intentional CI runner failure")))
;; Reaching here would reproduce the false-green failure mode.
(uiop:quit 0)
