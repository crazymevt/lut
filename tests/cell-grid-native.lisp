(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/examples" :silent t)
(defvar *grid-times* (make-hash-table :test #'eq))
(defmethod lut:render :around ((grid lut:cell-grid))
 (let ((start (get-internal-real-time)))
   (multiple-value-prog1 (call-next-method)
     (push (/ (- (get-internal-real-time) start) internal-time-units-per-second)
           (gethash grid *grid-times*)))))
(defun benchmark-grid-window (scale title)
 (let* ((root (lut:make-widget 'lut:window :text title :width 820 :height 500 :ui-scale scale :content-layout :fill))
        (grid (lut:add-child root (lut:make-widget 'lut:cell-grid :style '(:font-size 16)))))
   (lut:on grid :grid-resize (lambda (widget size)
     (declare (ignore size))
     (dotimes (r (lut:grid-rows widget))
       (dotimes (c (lut:grid-columns widget))
         (lut:set-grid-cell widget c r (if (zerop (mod c 17)) #\λ (code-char (+ 33 (mod (+ c r) 90))))
           :foreground (if (evenp c) '(120 200 240 255) '(240 220 130 255))
           :background '(20 25 30 255) :bold (zerop (mod c 7)) :underline (zerop (mod r 5)))))))
   (values root grid)))
(dolist (scale '(1 2))
 (multiple-value-bind (root grid) (benchmark-grid-window scale "Cell grid primary")
   (multiple-value-bind (peer peer-grid) (benchmark-grid-window scale "Cell grid worker")
     (let ((ticks 0) (remote nil) (received nil) (sent nil) (changed nil) (dimensions (make-hash-table :test #'eq)))
       (unwind-protect
         (progn
           (lut:on peer-grid :raw-key (lambda (widget event)
             (declare (ignore widget)) (push (list (lut:event-base-key event) (lut:event-control-p event)) received)))
           (lut:on root :tick (lambda (window dt)
             (declare (ignore window dt)) (incf ticks)
             (when (= ticks 2) (setf remote (lut:spawn-window peer)))
             (when (and remote (not sent) (>= (lut::remote-window-frames remote) 2))
               (setf sent t)
               (lut:focus peer peer-grid) (lut:capture-keys peer-grid)
               ;; Send input over the real worker protocol, retaining modifiers.
               (lut:on-window remote
                 (lut::forward-native-event
                   (lut:make-event :kind :key :key :copy :base-key :c :control-p t :text ""))))
             (when (and received (not changed))
               (setf changed t)
               (lut:set-grid-cell grid 0 0 #\Z :background '(255 0 0 255))
               (lut:set-grid-cell peer-grid 0 0 #\Z :background '(255 0 0 255)))
             (when (> ticks 240) (error "Worker grid input timed out."))
             (when (and (> ticks 18) received remote (> (lut::remote-window-frames remote) 8))
               (dolist (widget (list grid peer-grid))
                 (setf (gethash widget dimensions) (list (lut:grid-columns widget) (lut:grid-rows widget))))
               (lut:stop))))
           (lut:run root :frames 245)
           (assert received) (assert (equal '(:c t) (first received)))
           (dolist (pair (list (list :primary grid) (list :worker peer-grid)))
             (destructuring-bind (kind widget) pair
               ;; Drop the first two frames (font loading/warmup).
               (let* ((times (nthcdr 2 (reverse (gethash widget *grid-times*))))
                      (milliseconds (* 1000 (/ (reduce #'+ times) (length times)))))
                 (assert (> (length times) 5))
                 (format t "GRID-BENCH ~a scale=~a cells=~dx~d frames=~d mean-ms=~,3f max-ms=~,3f~%"
                   kind scale (first (gethash widget dimensions)) (second (gethash widget dimensions)) (length times)
                   milliseconds (* 1000 (reduce #'max times)))))))
         (lut:dispose root) (lut:dispose peer))))))
;; The simulated example must lay out, render and dispose without a PTY.
(let ((root (lut-examples:cell-grid-demo)))
 (unwind-protect (lut:run root :frames 4) (lut:dispose root)))
(format t "Native cell grids, worker key capture and full redraw measurements passed.~%")
;; Pixel checks: a wide glyph must not bleed into its blank neighbour, and
;; clipping at the parent boundary must leave the outside render target intact.
(dolist (scale '(1 2))
 (let* ((root (lut:make-widget 'lut:window :width 60 :height 40 :ui-scale scale))
        (grid (lut:add-child root (lut:make-widget 'lut:cell-grid :style '(:font-size 18))))
        (tested nil))
   (lut:on root :tick (lambda (window dt)
     (declare (ignore window dt))
     (unless tested
       (setf tested t)
       (lut:layout grid 50 10 12 20) (lut:set-grid-cell-metrics grid 4 20)
       (lut:set-grid-cell grid 0 0 #\W :foreground '(255 255 255 255) :background '(255 0 0 255) :bold t)
       (lut:set-grid-cell grid 1 0 #\Space :background '(0 255 0 255))
       (lut:set-grid-cell grid 2 0 #\Space :background '(0 0 255 255))
       (let ((texture (rl:load-render-texture (* 80 scale) (* 60 scale))))
         (unwind-protect
           (progn
             (rl:with-texture-mode (texture)
               (rl:clear-background '(255 0 255 255)) (lut::render-window root))
             (let ((image (rl:load-image-from-texture (rl:render-texture-texture texture))))
               (unwind-protect
                 (progn
                   (rl:image-flip-vertical image)
                   ;; Full blank neighbour is green, despite the clipped bold W.
                   (loop for y from (* 10 scale) below (* 30 scale) do
                     (loop for x from (* 54 scale) below (* 58 scale) do
                       (assert (= #x00ff00ff (rl:color-to-int (rl:get-image-color image x y))))))
                   (assert (= #xff00ffff (logand #xffffffff (rl:color-to-int (rl:get-image-color image (* 61 scale) (* 15 scale))))))
                   (assert (rl:export-image image (format nil "/tmp/lut-cell-grid-clip-~d.png" scale))))
                 (rl:unload-image image))))
           (rl:unload-render-texture texture))))))
   (unwind-protect (lut:run root :frames 2) (lut:dispose root))
   (assert tested)))
(format t "Cell glyph and ancestor clipping pixels passed at 100/200% scale.~%")
