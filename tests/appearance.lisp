(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/raylib" :silent t)
;; Selected toggles retain distinct interaction feedback.
(let* ((w (lut:make-widget 'lut:toggle-button :value t))
       (normal (lut::selected-toggle-color w)))
  (setf (lut::hovered-p w) t)
  (let ((hover (lut::selected-toggle-color w)))
    (setf (lut::pressed-p w) t)
    (assert (not (equal normal hover)))
    (assert (not (equal hover (lut::selected-toggle-color w))))))
;; Exercise the specialized render methods in three palettes, including disabled
;; selection and the slider endpoints where the thumb must remain in bounds.
(loop for theme in (list lut:*light-theme* lut:*dark-theme*
                           '(:background (240 240 240 255) :accent (35 100 210 255)))
      for name in '("light" "dark" "custom") do
 (let ((w (lut:make-widget 'lut:window :width 480 :height 800 :theme theme))
       (frame 0) (samples nil)
       (path (format nil "/tmp/lut-controls-~a.png" name)))
   (dolist (class '(lut:check-button lut:radio-button lut:switch lut:toggle-button))
     (dolist (selected '(nil t))
       (lut:add-child w (lut:make-widget class :text (if selected (format nil "~a~%Selected" class) (symbol-name class))
         :height (if selected 60 36) :value selected)))
     (lut:add-child w (lut:make-widget class :text "Disabled selection" :value t :enabled-p nil)))
   (dolist (v '(0 50 100))
     (lut:add-child w (lut:make-widget 'lut:slider :value v)))
   (lut:add-child w (lut:make-widget 'lut:progress-bar :value 50))
   (lut:on w :tick (lambda (window dt)
     (declare (ignore window dt))
     (when (= (incf frame) 3)
       (setf samples
         (loop for control in (subseq (lut:children w) 6 8) append
           (let* ((h (min 22 (- (lut:height control) 16)))
                  (tx (- (+ (lut:x control) (lut:width control)) 8 (* 2 h)))
                  (cy (+ (lut:y control) (/ (lut:height control) 2))))
             (list (list (round (+ tx (/ h 2))) (round cy))
                   (list (round (+ tx (* 1.5 h))) (round cy))))))
       (let ((target (rl:load-render-texture (round (lut:width w)) (round (lut:height w)))))
          (unwind-protect
            (progn
              (rl:with-texture-mode (target)
                (rl:clear-background (lut:style-value w :background)) (lut::render-window w))
              (let ((image (rl:load-image-from-texture (rl:render-texture-texture target))))
                (unwind-protect
                  (progn (rl:image-flip-vertical image) (assert (rl:export-image image path)))
                  (rl:unload-image image))))
            (rl:unload-render-texture target))))))
   (lut:run w :frames 4)
   (let ((image (rl:load-image path)))
     (unwind-protect
       (let ((pixels (loop for (x y) in samples
                          collect (rl:color-to-int (rl:get-image-color image x y)))))
         ;; Off thumb is at left; on thumb is at right. Their shared color
         ;; must differ from the exposed track at the opposite side.
         (assert (= (first pixels) (fourth pixels)))
         (assert (/= (first pixels) (second pixels)))
         (assert (/= (third pixels) (fourth pixels))))
       (rl:unload-image image)))))
(format t "Control rendering passed and switch pixel assertions passed in built-in and partial themes.~%")
