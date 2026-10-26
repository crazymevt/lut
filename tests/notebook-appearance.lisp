(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/examples" :silent t)
(dolist (theme (list lut:*light-theme* lut:*dark-theme*))
 (let* ((root (lut-examples:overflow-tabs)) (book (lut:find-widget root :left-tabs))
        (frame 0) (points nil) (path "/tmp/lut-tab-overflow.png"))
   (setf (lut:theme root) theme)
   (lut:on root :tick (lambda (w dt)
     (declare (ignore w dt))
     (when (= (incf frame) 2)
       (lut:select-page book (1- (length (lut:children book))))
       (lut::layout-window root)
       (multiple-value-bind (tab left viewport button) (lut::tab-strip-geometry book)
         (declare (ignore tab))
         (assert (plusp button))
         (assert (= (1- (length (lut:children book)))
                    (lut:tab-at-position book (- (+ left viewport) 10) (+ (lut:y book) 10))))
         (setf points (list (list (- (+ left viewport) 10) (+ (lut:y book) 25))
                            (list (+ left viewport 2) (+ (lut:y book) 25)))))
       (let ((texture (rl:load-render-texture (round (lut:width root)) (round (lut:height root)))))
         (unwind-protect
           (progn
             (rl:with-texture-mode (texture)
               (rl:clear-background (lut:style-value root :background)) (lut::render-window root))
             (let ((image (rl:load-image-from-texture (rl:render-texture-texture texture))))
               (unwind-protect
                 (progn (rl:image-flip-vertical image) (assert (rl:export-image image path)))
                 (rl:unload-image image))))
           (rl:unload-render-texture texture))))))
   (unwind-protect
     (progn
       (lut:run root :frames 3)
       (let ((image (rl:load-image path)))
         (unwind-protect
           (let ((colors (loop for (x y) in points collect
                           (rl:color-to-int (rl:get-image-color image (round x) (round y))))))
             (assert (= (first colors) (rl:color-to-int (lut:style-value book :accent))))
             ;; The tab strip must not paint over its navigation buttons.
             (assert (= (second colors) (rl:color-to-int (lut:style-value book :surface)))))
           (rl:unload-image image))))
     (lut:dispose root))))
(format t "Overflow selection reveal, tab clipping and arrow backgrounds passed in both themes.~%")
