;;;; Shared raylib region cache. No widget tree or application model required.
(in-package #:lut)

(defvar *render-ui-scale* 1)
(defvar *render-target-x* 0)
(defvar *render-target-y* 0)
(defvar *render-pixel-scale-x* 1)
(defvar *render-pixel-scale-y* 1)

(defun render-scissor-box (x y width height &key (scale *render-ui-scale*))
  "Convert a logical clip to native pixels for the active screen/texture target."
  (let* ((sx (* scale *render-pixel-scale-x*)) (sy (* scale *render-pixel-scale-y*))
         (x (- x *render-target-x*)) (y (- y *render-target-y*))
         (left (floor (* x sx))) (top (floor (* y sy))))
    (list left top (max 0 (- (ceiling (* (+ x width) sx)) left))
                   (max 0 (- (ceiling (* (+ y height) sy)) top)))))

(defun begin-ui-scissor (x y width height)
  "Begin clipping in logical coordinates for the active render transform."
  (apply #'rl:begin-scissor-mode (render-scissor-box x y width height)))
(defmacro with-ui-scissor ((x y width height) &body body)
  "Render BODY in a logical scissor. Restore an outer scissor when nesting."
  `(progn (begin-ui-scissor ,x ,y ,width ,height)
          (unwind-protect (progn ,@body) (rl:end-scissor-mode))))

(defun call-with-render-transform (function &key (scale 1))
  "Apply logical SCALE and the active cached target's pixel scale/origin.
Use outside an existing camera/transform; all drawing stays in global logical
coordinates. Input coordinates are unaffected. Native main thread only."
  (let ((*render-ui-scale* scale))
    (cffi:foreign-funcall "rlDrawRenderBatchActive" :void)
    (cffi:foreign-funcall "rlPushMatrix" :void)
    (unwind-protect
         (progn
           (cffi:foreign-funcall "rlTranslatef"
             :float (float (- (* *render-target-x* scale *render-pixel-scale-x*)))
             :float (float (- (* *render-target-y* scale *render-pixel-scale-y*)))
             :float 0.0 :void)
           (cffi:foreign-funcall "rlScalef"
             :float (float (* scale *render-pixel-scale-x*))
             :float (float (* scale *render-pixel-scale-y*)) :float 1.0 :void)
           (funcall function))
      (cffi:foreign-funcall "rlDrawRenderBatchActive" :void)
      (cffi:foreign-funcall "rlPopMatrix" :void))))

(defstruct cached-region target key box (paints 0))
(defstruct (render-cache (:constructor make-render-cache ()))
  (regions (make-hash-table :test #'equal)) disposed-p)

(defmethod disposed-p ((cache render-cache)) (render-cache-disposed-p cache))

(defun check-render-cache (cache)
  (when (render-cache-disposed-p cache) (error "Render cache is disposed."))
  (unless (rl:is-window-ready) (error "Render caches require an open native window.")))

(defun render-cache-paint-count (cache &optional (id nil id-p))
  "Return successful repaints of ID, or the total across all cached regions."
  (if id-p
      (let ((region (gethash id (render-cache-regions cache))))
        (if region (cached-region-paints region) 0))
      (loop for region being the hash-values of (render-cache-regions cache)
            sum (cached-region-paints region))))

(defun invalidate-render-cache (cache &optional (id nil id-p))
  "Invalidate ID, or every region. The next UPDATE-CACHED-REGION repaints it."
  (labels ((invalidate (region) (when region (setf (cached-region-key region) nil))))
    (if id-p (invalidate (gethash id (render-cache-regions cache)))
        (maphash (lambda (key region) (declare (ignore key)) (invalidate region))
                 (render-cache-regions cache))))
  cache)

(defmethod dispose ((cache render-cache))
  "Release native targets before closing their context. Idempotent, main thread."
  (unless (render-cache-disposed-p cache)
    (maphash (lambda (id region)
               (declare (ignore id))
               (when (cached-region-target region)
                 (rl:unload-render-texture (cached-region-target region))))
             (render-cache-regions cache))
    (clrhash (render-cache-regions cache))
    (setf (render-cache-disposed-p cache) t))
  cache)

(defun update-cached-region (cache id bounds key painter &key (scale 1) (background :blank))
  "Refresh ID only when KEY, BOUNDS, SCALE, BACKGROUND or backing DPI changes.
KEY must be an immutable EQUAL-comparable snapshot/revision supplied by the app.
BOUNDS is (x y width height) in logical coordinates. PAINTER takes no arguments;
it draws in global logical coordinates, already transformed for this region.
Use LUT clipping helpers (or RENDER-SCISSOR-BOX in custom adapters). Call before
screen drawing, outside an active camera, texture target or scissor. A failed
paint stays invalid for retry. Returns the region and a repaint boolean. Dispose
the cache before closing its native context. Hidden regions may simply be omitted."
  (check-render-cache cache)
  (unless (and (realp scale) (plusp scale)) (error "Render scale must be positive."))
  (destructuring-bind (x y width height) bounds
    (unless (and (plusp width) (plusp height))
      (invalidate-render-cache cache id)
      (return-from update-cached-region (values nil nil)))
    (let* ((region (or (gethash id (render-cache-regions cache))
                       (setf (gethash id (render-cache-regions cache)) (make-cached-region))))
           (sx (/ (rl:get-render-width) (max 1 (rl:get-screen-width))))
           (sy (/ (rl:get-render-height) (max 1 (rl:get-screen-height))))
           (scale-x (* scale sx)) (scale-y (* scale sy))
           (left (floor (* x scale-x))) (top (floor (* y scale-y)))
           (width-px (max 1 (- (ceiling (* (+ x width) scale-x)) left)))
           (height-px (max 1 (- (ceiling (* (+ y height) scale-y)) top)))
           (key (list (copy-list bounds) scale sx sy
                      (if (typep background 'rl:color)
                          (list (rl:color-r background) (rl:color-g background)
                                (rl:color-b background) (rl:color-a background))
                          (copy-tree background)) key))
           (target (cached-region-target region)))
      (when (or (null target)
                (/= width-px (rl:texture-width (rl:render-texture-texture target)))
                (/= height-px (rl:texture-height (rl:render-texture-texture target))))
        (when target (rl:unload-render-texture target))
        (setf (cached-region-target region) nil (cached-region-key region) nil)
        (setf target (rl:load-render-texture width-px height-px))
        (unless (rl:is-render-texture-valid target)
          (error "Cannot allocate ~dx~d cached region." width-px height-px))
        (setf (cached-region-target region) target))
      (if (equal key (cached-region-key region)) (values region nil)
          (progn
            ;; Never publish a partially rendered target after an exception.
            (setf (cached-region-key region) nil)
            (let ((*render-target-x* (/ left scale-x)) (*render-target-y* (/ top scale-y))
                  (*render-pixel-scale-x* sx) (*render-pixel-scale-y* sy))
              (rl:with-texture-mode (target)
                (let* ((color (etypecase background
                                (rl:color background)
                                (list (apply #'rl:color background))
                                ((or symbol integer) (rl:color background))))
                       (alpha (/ (rl:color-a color) 255)))
                  (rl:clear-background (rl:color (round (* alpha (rl:color-r color)))
                                                (round (* alpha (rl:color-g color)))
                                                (round (* alpha (rl:color-b color)))
                                                (rl:color-a color))))
                ;; RGB uses ordinary alpha blending; coverage must accumulate
                ;; with ONE so glyph edges do not lower an opaque target's alpha.
                (cffi:foreign-funcall "rlSetBlendFactorsSeparate"
                  :int #x0302 :int #x0303 :int 1 :int #x0303 :int #x8006 :int #x8006 :void)
                (rl:with-blend-mode (:custom-separate)
                  (call-with-render-transform painter :scale scale))))
            (setf (cached-region-key region) key
                  (cached-region-box region)
                  (list (/ left scale-x) (/ top scale-y) (/ width-px scale-x) (/ height-px scale-y)))
            (incf (cached-region-paints region))
            (values region t))))))

(defun draw-cached-region (cache id)
  "Composite ID inside the caller's logical screen transform. Return NIL if invalid."
  (check-render-cache cache)
  (let ((region (gethash id (render-cache-regions cache))))
    (when (and region (cached-region-key region))
      (destructuring-bind (x y width height) (cached-region-box region)
        (let ((texture (rl:render-texture-texture (cached-region-target region))))
          (rl:with-blend-mode (:alpha-premultiply)
            (rl:draw-texture-pro texture
            (rl:rect 0 0 (rl:texture-width texture) (- (rl:texture-height texture)))
            (rl:rect x y width height) (rl:vec2 0 0) 0 :white))))
      t)))
