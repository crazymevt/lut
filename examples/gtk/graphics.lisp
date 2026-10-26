(in-package #:lut-gtk-demo)
(defun sample-image () (asdf:system-relative-pathname "lut" "examples/assets/demo.png"))
(defun regular-points (cx cy radius count &optional (phase 0))
 (loop for i below count for angle = (+ phase (* 2 pi (/ i count)))
       collect (point (+ cx (* radius (cos angle))) (+ cy (* radius (sin angle))))))
(defun transformed (p angle scale &optional (cx 0) (cy 0))
 (point (+ cx (* scale (- (* (first p) (cos angle)) (* (second p) (sin angle)))))
        (+ cy (* scale (+ (* (first p) (sin angle)) (* (second p) (cos angle)))))))
(defun graphic-root (title kind painter &key controls input (height 340))
 (let ((root (app title)))
   (setf (state root :time) 0 (state root :running) t)
   (lut:add-child root (scene root kind painter :input input :height height))
   (dolist (spec controls)
     (destructuring-bind (key caption low high initial) spec
       (let ((slider (node 'lut:slider key :minimum low :maximum high :value initial :step (/ (- high low) 100))))
         (setf (state root key) initial)
         (changed slider (lambda (w value) (declare (ignore w)) (setf (state root key) value)) root)
         (lut:add-child root (lut:with-ui (lut:header-bar :height 34)
                              (labeled nil caption :width 170) slider)))))
   (lut:add-child root (labeled :status title))
   (add-action root :pause "Pause / resume" (lambda () (setf (state root :running) (not (state root :running)))))
   (add-action root :reset "Reset animation" (lambda () (setf (state root :time) 0)))
   (lut:on root :tick (lambda (w dt) (declare (ignore w)) (when (state root :running) (incf (state root :time) dt))) :owner root)
   (setf (lut:height root) (+ height 190 (* 42 (length controls)))) root))
(defun check-animation (root)
 (let ((before (operations root))) (tick root 0.5) (assert (not (equalp before (operations root)))))
 (press root :pause) (let ((time (state root :time))) (tick root 1) (assert (= time (state root :time))))
 (press root :reset) (assert (zerop (state root :time))))
(defun checker-operations (width height &optional (cell 20))
 (loop for y from 0 below height by cell append
   (loop for x from 0 below width by cell collect (op :rect x y cell cell (if (evenp (+ (floor x cell) (floor y cell))) :lightgray :white)))))
(defun stroke-input (root canvas event)
 (let ((kind (lut:event-kind event))
       (p (point (- (lut:event-x event) (lut:x canvas)) (- (lut:event-y event) (lut:y canvas)))))
   (case kind
     (:down (setf (state root :drawing) t) (push (list p) (state root :strokes)) t)
     (:move (when (state root :drawing) (push p (first (state root :strokes)))) t)
     (:up (setf (state root :drawing) nil) t)
     (:wheel (setf (state root :brush) (clamp (+ (state root :brush 3) (lut:event-delta event)) 1 40)) t))))
(defun draw-strokes (root)
 (loop for stroke in (state root :strokes) collect
   (if (rest stroke) (op :polyline (reverse stroke) (state root :brush 3) (state root :ink :maroon))
       (op :circle (caar stroke) (cadar stroke) (state root :brush 3) (state root :ink :maroon)))))
(defun painting-demo (tablet)
 (let ((root (graphic-root (if tablet "Paint" "Drawing area") (if tablet :paint :drawingarea)
   (lambda (canvas) (append (checker-operations (lut:width canvas) (if tablet 0 100))
                           (draw-strokes (scene-root canvas))))
   :input #'stroke-input :controls '((:brush "Brush width" 1 40 3)))))
   (setf (state root :ink) :maroon)
   (add-action root :clear "Clear canvas" (lambda () (setf (state root :strokes) nil)))
   (add-action root :color "Change ink" (lambda () (setf (state root :ink) (if (eq (state root :ink) :maroon) :blue :maroon)))) root))
(defun painting-test (root)
 (let ((c (control root :canvas)))
   (dolist (spec '((:down 30 150) (:move 60 170) (:move 90 160) (:up 90 160)))
     (destructuring-bind (kind x y) spec
       (lut:handle-event c (lut:make-event :kind kind :x (+ x (lut:x c)) :y (+ y (lut:y c)))))))
 (assert (= 3 (length (first (state root :strokes)))))
 (assert (find :polyline (operations root) :key #'first))
 (press root :color) (assert (eq :blue (state root :ink)))
 (press root :clear) (assert (null (state root :strokes))))
(defdemo "drawingarea" "Checkerboard drawing and a persistent pointer scribble canvas with brush, ink and clear controls."
 (painting-demo nil) (painting-test root))
(defdemo "paint" "Freehand paint canvas with variable brush size, pointer strokes, color and clearing."
 (painting-demo t) (painting-test root) (set-number root :brush 12) (assert (= 12 (state root :brush))))
(defun gear-points (cx cy radius teeth angle)
 (loop for i below (* teeth 4) for a = (+ angle (* 2 pi (/ i (* teeth 4))))
       for r = (* radius (if (member (mod i 4) '(1 2)) 1 0.78))
       collect (point (+ cx (* r (cos a))) (+ cy (* r (sin a))))))
(defdemo "gears" "Three interlocking animated gears with tooth geometry, speed and view rotation controls."
 (graphic-root "Gears" :gears
   (lambda (c) (let* ((r (scene-root c)) (angle (* (state r :time) (state r :speed))))
     (list (op :polygon (gear-points 220 175 110 20 angle) :red)
           (op :polygon (gear-points 380 170 55 10 (+ (- (* angle 2)) 0.12)) :green)
           (op :polygon (gear-points 225 10 55 10 (- (* angle 2))) :blue)
           (op :circle 220 175 25 :darkgray) (op :circle 380 170 12 :darkgray))))
   :controls '((:speed "Rotation speed" 0.1 4 1)))
 (assert (= 80 (length (second (first (operations root)))))) (check-animation root))
(defun project-3d (p yaw pitch &optional (scale 120))
 (destructuring-bind (x y z) p
   (let* ((x1 (- (* x (cos yaw)) (* z (sin yaw)))) (z1 (+ (* x (sin yaw)) (* z (cos yaw))))
          (y1 (- (* y (cos pitch)) (* z1 (sin pitch)))) (z2 (+ (* y (sin pitch)) (* z1 (cos pitch))))
          (factor (/ scale (+ 4 z2))))
     (list (+ 320 (* x1 factor)) (+ 170 (* y1 factor)) z2))))
(defdemo "glarea" "Interactive projected triangle with independent X/Y/Z rotations rendered through raylib's OpenGL backend."
 (graphic-root "OpenGL area" :glarea
   (lambda (c) (let* ((r (scene-root c)) (z (state r :z)))
     (list (op :polygon (loop for p in '((-2 -1 0) (2 -1 0) (0 2 0))
       for projected = (project-3d p (state r :x) (state r :y) 240)
       collect (transformed (point (- (first projected) 320) (- (second projected) 170)) z 1 320 170)) :orange))))
   :controls '((:x "X rotation" -3.14 3.14 0) (:y "Y rotation" -3.14 3.14 0) (:z "Z rotation" -3.14 3.14 0)))
 (let ((before (operations root))) (set-number root :x 1) (assert (not (equalp before (operations root)))))
 (assert (= 3 (length (second (first (operations root)))))))
(defparameter *fragment-shader*
 "#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform float iTime;
uniform vec3 iResolution;
void main(){vec2 uv=fragTexCoord;finalColor=vec4(0.5+0.5*cos(iTime+uv.xyx*6.0+vec3(0,2,4)),1.0);}")
(defdemo "shadertoy" "Editable fragment shader with iTime/iResolution uniforms and live apply/pause/reset."
 (let* ((root (graphic-root "Shadertoy" :shadertoy
   (lambda (c) (let ((r (scene-root c))) (list (op :shader (state r :shader) (state r :time) (lut:width c) (lut:height c))))) :height 220))
        (editor (node 'lut:text-view :shader-code :text *fragment-shader* :height 150)))
   (setf (state root :shader) *fragment-shader*) (lut:add-child root editor)
   (add-action root :apply "Apply shader" (lambda ()
     (unless (and (search "void main" (lut:text editor)) (search "finalColor" (lut:text editor))) (error "Fragment shader needs main/finalColor"))
     (setf (state root :shader) (lut:text editor)))) (setf (lut:height root) 760) root)
 (assert (eq :shader (caar (operations root)))) (check-animation root)
 (set-entry (control root :shader-code) (concatenate 'string *fragment-shader* (string #\Newline)))
 (press root :apply) (assert (string= (lut:text (control root :shader-code)) (state root :shader))))
(defdemo "frames" "Frame-rate benchmark with a changing canvas color and measured frame/elapsed counters."
 (let ((root (graphic-root "Frame benchmark" :frames
   (lambda (c) (let ((r (scene-root c)))
     (list (op :rect 0 0 (lut:width c) (lut:height c)
               (if (evenp (floor (* 10 (state r :time)))) :skyblue :gold))))))))
   (lut:on root :tick (lambda (w dt) (declare (ignore w))
     (incf (state root :frames 0)) (incf (state root :elapsed 0) dt)
     (status root (format nil "~d frames; ~,1f FPS" (state root :frames)
                         (/ (state root :frames) (max 0.001 (state root :elapsed)))))) :owner root) root)
 (tick root 0.1) (tick root 0.1) (assert (= 2 (state root :frames)))
 (assert (near 10 (/ (state root :frames) (state root :elapsed)))))
(defun init-fish (root count)
 (setf (state root :fish) (loop for i below count collect
   (list (mod (* i 37) 620) (mod (* i 73) 300) (+ 20 (mod (* i 11) 90)) (+ 20 (mod (* i 17) 70))))))
(defun reflect-coordinate (position velocity dt bound)
 (let* ((p (mod (+ position (* velocity dt)) (* 2 bound)))
        (reflected (> p bound)))
   (values (if reflected (- (* 2 bound) p) p) (if reflected (- (abs velocity)) (abs velocity)))))
(defdemo "fishbowl" "Configurable moving-object benchmark with wall collisions and animation pause."
 (let ((root (graphic-root "Fishbowl" :fishbowl
   (lambda (c) (loop for (x y vx vy) in (state (scene-root c) :fish)
     collect (op :circle x y 6 (if (> vx vy) :skyblue :orange))))
   :controls '((:population "Population" 1 1024 64)))))
   (init-fish root 64)
   (changed (control root :population) (lambda (w count) (declare (ignore w)) (init-fish root (round count))) root)
   (lut:on root :tick (lambda (w dt) (declare (ignore w))
     (when (state root :running)
       (dolist (fish (state root :fish))
         (multiple-value-bind (p v) (reflect-coordinate (first fish) (third fish) dt 620) (setf (first fish) p (third fish) v))
         (multiple-value-bind (p v) (reflect-coordinate (second fish) (fourth fish) dt 300) (setf (second fish) p (fourth fish) v))))) :owner root) root)
 (set-number root :population 128) (assert (= 128 (length (state root :fish))))
 (tick root 100) (assert (every (lambda (f) (and (<= 0 (first f) 620) (<= 0 (second f) 300))) (state root :fish))))
(defun image-ops (root)
 (let ((zoom (state root :zoom 1)))
   (list (op :image (sample-image) 50 30 (* 160 zoom) (* 90 zoom) (state root :filter :bilinear)))))
(defdemo "images" "Shared image source shown at intrinsic and icon sizes, with visibility and animation controls."
 (let ((root (graphic-root "Images" :images
   (lambda (c) (let ((r (scene-root c)))
     (when (state r :show t) (list (op :image (sample-image) 20 20 320 180)
                                  (op :image (sample-image) 400 20 48 48)
                                  (op :image (sample-image) (+ 400 (* 30 (sin (state r :time)))) 100 96 54))))))))
   (setf (state root :show) t)
   (add-action root :toggle "Show / hide images" (lambda () (setf (state root :show) (not (state root :show))))) root)
 (assert (= 3 (length (operations root)))) (check-animation root)
 (press root :toggle) (assert (null (operations root))))
(defdemo "image_scaling" "Image zoom and nearest/bilinear filtering, including a reusable right-click zoom menu."
 (let ((root (graphic-root "Image scaling" :image_scaling (lambda (c) (image-ops (scene-root c)))
              :controls '((:zoom "Zoom" 0.25 4 1)))))
   (setf (state root :filter) :bilinear)
   (add-action root :filter "Nearest / bilinear" (lambda () (setf (state root :filter)
                          (if (eq (state root :filter) :bilinear) :point :bilinear))))
   (lut:on (control root :canvas) :context (lambda (w event)
     (lut:open-context-menu root w event (loop for scale in '(0.5 1 2 4)
       collect (list (format nil "~a x" scale) (lambda () (set-number root :zoom scale)))))) :owner root) root)
 (set-number root :zoom 2) (assert (= 320 (fifth (first (operations root)))) )
 (press root :filter) (assert (eq :point (state root :filter))))
(defparameter *filter-fragment*
 "#version 330
in vec2 fragTexCoord;out vec4 finalColor;uniform sampler2D texture0;
void main(){vec4 c=texture(texture0,fragTexCoord);c.rgb=(c.rgb-0.5)*CONTRAST+0.5+BRIGHTNESS;
float g=dot(c.rgb,vec3(0.299,0.587,0.114));c.rgb=mix(vec3(g),c.rgb,SATURATION);finalColor=c;}")
(defun substitute-text (text token value)
 (let ((p (search token text)))
   (if p (concatenate 'string (subseq text 0 p) value (substitute-text (subseq text (+ p (length token))) token value)) text)))
(defun filter-source (root)
 (let ((source *filter-fragment*))
   (dolist (spec '(("CONTRAST" :contrast) ("BRIGHTNESS" :brightness) ("SATURATION" :saturation)))
     (setf source (substitute-text source (first spec) (format nil "~f" (float (state root (second spec))))))) source))
(defdemo "image_filtering" "GPU image brightness, contrast and saturation controls with a live response graph."
 (graphic-root "Image filtering" :image_filtering
   (lambda (c) (let ((root (scene-root c)))
     (list (op :shader (filter-source root) (state root :time) (lut:width c) (lut:height c) (sample-image))
           (op :polyline (loop for x from 0 to 255 by 8 collect
             (point (+ 20 x) (- 300 (* 90 (clamp (+ (* (- (/ x 255) 0.5) (state root :contrast)) 0.5 (state root :brightness)) 0 1)))))
             2 :red))))
   :controls '((:brightness "Brightness" -1 1 0) (:contrast "Contrast" 0 3 1) (:saturation "Saturation" 0 3 1)))
 (let ((before (filter-source root))) (set-number root :contrast 2) (assert (not (string= before (filter-source root)))))
 (assert (search "texture(texture0" (filter-source root))))
(defun layers (root)
 (list (op :rect 0 0 640 340 :raywhite)
       (op :circle 250 170 100 '(255 40 40 180))
       (op :blend (state root :blend :alpha) (list (op :circle 350 170 100 '(30 100 255 180))))))
(defdemo "css_blendmodes" "Interactive background compositing using alpha, additive and multiplied blend modes."
 (let* ((root (graphic-root "Blend modes" :css_blendmodes (lambda (c) (layers (scene-root c)))))
        (choice (node 'lut:dropdown :blend :items '("Alpha" "Additive" "Multiply") :value 0)))
   (lut:add-child root choice) (changed choice (lambda (w i) (declare (ignore w))
     (setf (state root :blend) (nth i '(:alpha :additive :multiplied)))) root) root)
 (choose-index root :blend 2) (assert (eq :multiplied (second (third (operations root))))))
(defdemo "css_multiplebgs" "Multiple composited backgrounds with independent size, placement and opacity."
 (graphic-root "Multiple backgrounds" :css_multiplebgs
   (lambda (c) (let ((r (scene-root c)))
     (list (op :gradient 0 0 (lut:width c) (lut:height c) :skyblue :darkblue)
           (op :image (sample-image) (state r :offset) 30 240 135)
           (op :circle 400 180 (state r :radius) '(255 255 255 140)))))
   :controls '((:offset "Background position" 0 350 40) (:radius "Overlay radius" 20 160 100)))
 (set-number root :offset 100) (assert (= 100 (third (second (operations root))))))
(defdemo "css_pixbufs" "Eight independently transformed images animate as layered background paintables."
 (graphic-root "Animated backgrounds" :css_pixbufs
   (lambda (c) (let ((r (scene-root c)))
     (loop for p in (regular-points 320 160 120 8 (state r :time)) for i from 0
       collect (op :image (sample-image) (first p) (second p) (+ 30 (* i 3)) (+ 18 (* i 2)) :bilinear)))))
 (assert (= 8 (length (operations root)))) (check-animation root))
(defdemo "css_shadows" "Layered soft shadows with adjustable offset, spread and opacity."
 (graphic-root "Shadows" :css_shadows
   (lambda (c) (let ((r (scene-root c)))
     (append (loop for spread from 20 downto 1 collect
       (op :rect (+ 150 (state r :offset) (- spread)) (+ 80 (state r :offset) (- spread))
           (+ 260 (* 2 spread)) (+ 130 (* 2 spread)) (list 0 0 0 (round (/ (state r :opacity) 20)))))
       (list (op :rect 150 80 260 130 :white)))))
   :controls '((:offset "Shadow offset" -40 40 10) (:opacity "Shadow opacity" 0 255 160)))
 (assert (= 21 (length (operations root))))
 (let ((before (operations root))) (set-number root :offset 25) (assert (not (equalp before (operations root))))))
(defdemo "css_accordion" "Pointer-controlled accordion panels animate between compact and expanded widths."
 (let ((root (graphic-root "Accordion" :css_accordion
   (lambda (c) (let* ((r (scene-root c)) (active (state r :active 0)) (progress (state r :open 0)) (x 0))
     (loop for i below 5 for width = (if (= i active) (+ 100 (* 200 progress)) (- 100 (* 50 progress)))
       append (prog1 (list (op :rect x 30 width 250 (nth i '(:red :orange :gold :green :skyblue)))
                          (op :text (format nil "Panel ~d" (1+ i)) (+ x 5) 40 16 :black)) (incf x width)))))
   :input (lambda (r c e) (when (eq (lut:event-kind e) :move)
     (setf (state r :active) (clamp (floor (- (lut:event-x e) (lut:x c)) 100) 0 4)) t)))))
   (lut:on root :tick (lambda (w dt) (declare (ignore w)) (setf (state root :open) (min 1 (+ (state root :open 0) dt)))) :owner root) root)
 (let ((c (control root :canvas))) (lut:handle-event c (lut:make-event :kind :move :x (+ (lut:x c) 220) :y 50)))
 (tick root 1) (assert (= 2 (state root :active)))
 (assert (= 300 (fourth (fifth (operations root))))))
(defdemo "spinner" "Busy-state spinner with explicit start/stop and pulse progression."
 (graphic-root "Spinner" :spinner
   (lambda (c) (let ((r (scene-root c)))
     (loop for p in (regular-points 320 160 60 12) for i from 0
       collect (op :circle (first p) (second p) 8 (list 40 110 220
          (+ 30 (mod (+ (* i 18) (floor (* 120 (state r :time)))) 225))))))))
 (assert (= 12 (length (operations root)))) (check-animation root))
