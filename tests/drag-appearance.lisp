(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/examples" :silent t)
(dolist (theme (list lut:*light-theme* lut:*dark-theme*))
 (let* ((root (lut-examples:drag-tabs)) (left (lut:find-widget root :left-tabs))
        (right (lut:find-widget root :right-tabs)) (page (first (lut:children left)))
        (frame 0) (point nil) (path "/tmp/lut-drag-tabs.png"))
   (setf (lut:theme root) theme)
   (lut:on root :tick (lambda (w dt)
     (declare (ignore w dt))
     (case (incf frame)
       (2
         (lut:dispatch root (lut:make-event :kind :down :x (+ (lut:x left) 20) :y (+ (lut:y left) 10)))
         (lut:dispatch root (lut:make-event :kind :move :x (- (+ (lut:x right) (lut:width right)) 5) :y (+ (lut:y right) 10)))
         (assert (eq right (lut:drag-target (lut:current-drag root))))
         (setf point (list (- (+ (lut:x right) (lut:width right)) 1) (+ (lut:y right) 24)))
         (let ((texture (rl:load-render-texture (round (lut:width root)) (round (lut:height root)))))
           (unwind-protect
             (progn
               (rl:with-texture-mode (texture)
                 (rl:clear-background (lut:style-value root :background))
                 (lut::render-window root))
               (assert (eq :dragging (lut:drag-state (lut:current-drag root))))
               (let ((image (rl:load-image-from-texture (rl:render-texture-texture texture))))
                 (unwind-protect
                   (progn (rl:image-flip-vertical image) (assert (rl:export-image image path)))
                   (rl:unload-image image))))
             (rl:unload-render-texture texture))))
       (3
         (lut:dispatch root (lut:make-event :kind :up :x (- (+ (lut:x right) (lut:width right)) 5) :y (+ (lut:y right) 10)))
         (assert (eq right (lut:parent page)))
         (assert (equal (lut:items right) '("Three" "One")))
         (assert (null (lut:current-drag root)))))))
   (unwind-protect
     (progn
       (lut:run root :frames 4)
       (let ((image (rl:load-image path)))
         (unwind-protect
           (assert (= (rl:color-to-int (rl:get-image-color image (round (first point)) (round (second point))))
                      (rl:color-to-int (lut:style-value right :focus-color))))
           (rl:unload-image image))))
     (lut:dispose root))))
(format t "Notebook drag insertion feedback and native input transfer passed in both themes.~%")
