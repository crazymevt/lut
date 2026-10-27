;; Run from the LUT repository: sbcl --script tests/update-font-discovery-native.lisp
(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(asdf:load-system "lut/raylib")
(defclass update-font-window (lut:window) ())
(defvar *update-discoveries* 0)
(defmethod lut::discover-font-codepoints :around ((root update-font-window))
  (incf *update-discoveries*) (call-next-method))
(defun check-visible-font-pass (view expected)
  (let ((before *update-discoveries*))
    (lut:map-visible-text-lines view
      (lambda (&rest row)
        (declare (ignore row))
        (dotimes (lookup 50) (assert (plusp (lut:text-width view (lut:text view)))))
        (assert (member (char-code expected) (lut::font-codepoints view)))
        ;; A glyph introduced after discovery still extends the atlas.
        (assert (lut::font-glyph-member-p (lut::widget-glyph-set view "Ω") (char-code #\Ω)))))
    (assert (= 1 (- *update-discoveries* before)))))
(let* ((root (lut:make-widget 'update-font-window :width 300 :height 150))
       (view (lut:add-child root (lut:make-widget 'lut:text-view :text "initial")))
       (frames 0))
  (unwind-protect
      (progn
        (lut:on root :tick
          (lambda (window dt)
            (declare (ignore window dt))
            (incf frames)
            (setf (lut:text view) (format nil "initial λ~%second~%third"))
            (check-visible-font-pass view #\λ)
            ;; Two queries in one callback must see edits made between them.
            (setf (lut:text view) (format nil "updated ξ~%second~%third"))
            (check-visible-font-pass view #\ξ)))
        (lut:start root :frames 3 :wait t)
        (assert (= frames 3)))
    (lut:dispose root)))
(format t "Visible-line glyph discovery: one scan per query, fresh after edits, late glyph coverage passed.~%")
