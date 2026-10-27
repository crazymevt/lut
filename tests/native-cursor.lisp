;; Run from the LUT repository: sbcl --script tests/native-cursor.lisp
(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(asdf:load-system "lut/raylib")
;; Repeated frames must not allocate another native cursor. Each new native
;; window binds a fresh cache, so even the same first cursor must be sent again.
(let ((original (symbol-function 'rl:set-mouse-cursor)) (sent nil))
 (unwind-protect
     (progn
       (setf (symbol-function 'rl:set-mouse-cursor) (lambda (cursor) (push cursor sent)))
       (let ((lut::*native-cursor* nil))
         (dotimes (frame 60) (lut::update-native-cursor :resize-ew))
         (lut::update-native-cursor :resize-ns)
         (lut::update-native-cursor :resize-ns)
         (lut::update-native-cursor :default)
         (lut::update-native-cursor :default))
       (let ((lut::*native-cursor* nil))
         (lut::update-native-cursor :default))
       (assert (equal (reverse sent) '(:resize-ew :resize-ns :default :default))))
   (setf (symbol-function 'rl:set-mouse-cursor) original)))
(format t "Native cursor cache checks passed.~%")
