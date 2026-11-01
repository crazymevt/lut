;;; Fresh-process native regression: continuous pulse, regional upload/cache reuse,
;;; packed-row correctness, skipped consumer frames, resize and unchanged frames.
(load (merge-pathnames "../scripts/bootstrap.lisp" *load-truename*))
(asdf:load-system "lut/cef")
(defun cache-image (root cached)
 (let ((target (rl:load-render-texture (round (* (lut:width root) (lut:ui-scale root)))
                                       (round (* (lut:height root) (lut:ui-scale root))))))
   (unwind-protect
     (progn
       (rl:with-texture-mode (target)
         (rl:clear-background (lut:style-value root :background))
         ;; Match opaque framebuffer coverage when capturing into an RGBA texture:
         ;; RGB blends normally; alpha accumulates with ONE, not SRC_ALPHA.
         (cffi:foreign-funcall "rlSetBlendFactorsSeparate"
           :int #x0302 :int #x0303 :int 1 :int #x0303 :int #x8006 :int #x8006 :void)
         (let ((lut::*composite-window-cache* (and cached (lut::render-identity root)))
               (lut::*render-cache-painting* t))
           (rl:with-blend-mode (:custom-separate) (lut::render-window root))))
       (let ((image (rl:load-image-from-texture (rl:render-texture-texture target))))
         (rl:image-flip-vertical image) image))
     (rl:unload-render-texture target))))
(defun cached-parity (root)
  (lut::prepare-window-cache root :pixel-scale 1)
  (let ((direct (cache-image root nil)) (cached (cache-image root t)))
    (unwind-protect
      (dotimes (i (* 4 (rl:image-width direct) (rl:image-height direct)))
        (assert (= (cffi:mem-aref (rl:image-data direct) :unsigned-char i)
                   (cffi:mem-aref (rl:image-data cached) :unsigned-char i))))
      (rl:unload-image direct) (rl:unload-image cached))))
(defun texture-parity (v)
  (cffi:with-foreign-objects ((w :int) (h :int) (revision :uint64))
    (let* ((pixels (lut-webview::%frame (lut-webview::handle v) w h revision))
           (image (rl:load-image-from-texture (lut-webview::texture v))))
      (unwind-protect
        (dotimes (i (* 4 (cffi:mem-ref w :int) (cffi:mem-ref h :int)))
          (assert (= (cffi:mem-aref pixels :unsigned-char i)
                     (cffi:mem-aref (rl:image-data image) :unsigned-char i))))
        (rl:unload-image image)))))
(lut-webview:call-with-native-run
 (lambda ()
  ;; CEF workers must not inherit SBCL's SIGPROF handler unmasked on macOS.
  (let ((mask #+(and sbcl darwin) (cffi:foreign-funcall "sb_toggle_sigprof" :pointer (cffi:null-pointer) :int 1 :int)
              #-(and sbcl darwin) nil))
   (unwind-protect
    (progn
     (lut-webview:initialize-cef)
     (let* ((root (lut:make-widget 'lut:window :width 768 :height 512 :text "CEF regional damage test"
                                  :style '(:background (24 32 32 255) :padding 0)))
            (view (lut:add-child root (lut:make-widget 'lut-webview:webview
                      :local-messages-p t :height 512
                      :url (concatenate 'string "file://" #+win32 "/"
                             (namestring (merge-pathnames "damage.html" *load-truename*))))))
            (frame 0) baseline stats cpu wall)
       (lut-webview:attach-webview view root)
       (lut:on root :tick
         (lambda (w dt)
           (declare (ignore dt)) (incf frame)
           ;; Pump without consuming for 20 frames: regional history must survive.
           (if (<= 200 frame 220) (lut-webview::%pump) (lut-webview:pump-webviews w))
           (case frame
             (90 (texture-parity view) (cached-parity w)
                 (setf baseline (lut-webview:statistics view) stats (lut:window-cache-statistics w)
                       cpu (get-internal-run-time) wall (get-internal-real-time)))
             (180
              (let* ((now (lut-webview:statistics view)) (cache (lut:window-cache-statistics w))
                     (uploads (- (getf now :texture-uploads) (getf baseline :texture-uploads)))
                     (bytes (- (getf now :uploaded-bytes) (getf baseline :uploaded-bytes)))
                     (full (* 4 (rl:texture-width (lut-webview::texture view))
                                (rl:texture-height (lut-webview::texture view)))))
                (assert (> uploads 20))
                (assert (< bytes (* uploads full 1/4)))
                (assert (= (getf stats :layout-passes) (getf cache :layout-passes)))
                (assert (< (- (getf cache :repaints) (getf stats :repaints)) (* uploads 5)))
                (format t "PULSE: ~D uploads, ~D bytes (~,2F% of full uploads), ~,2F% CPU; cache ~S~%"
                  uploads bytes (* 100.0 (/ bytes (* uploads full)))
                  (* 100.0 (/ (- (get-internal-run-time) cpu) (- (get-internal-real-time) wall))) cache))
              (texture-parity view) (cached-parity w))
             (205 (assert (lut-webview:execute-script view "Object.assign(document.getElementById('dot').style,{left:'600px',top:'350px'})")))
             (215 (assert (lut-webview:execute-script view "document.body.style.background='#243040'")))
             (221 (texture-parity view) (cached-parity w)
                  (lut-webview:execute-script view "document.getElementById('dot').style.animation='none'"))
             (250 (texture-parity view) (setf baseline (lut-webview:statistics view)))
             (280 (assert (= (getf baseline :texture-uploads)
                             (getf (lut-webview:statistics view) :texture-uploads)))
                  ;; Force an odd-sized native surface and exercise clipped edge blocks.
                  (lut-webview::%resize (lut-webview::handle view) 513 333 1.0d0))
             (282 (assert (lut-webview:execute-script view "Object.assign(document.getElementById('dot').style,{left:'510px',top:'330px',background:'#22ff11'})")))
             (289 (texture-parity view) (cached-parity w)
                  (assert (= 513 (rl:texture-width (lut-webview::texture view))))
                  (assert (= 333 (rl:texture-height (lut-webview::texture view))))))))
       (unwind-protect (lut:run root :frames 290)
         (lut:dispose root) (lut-webview:close-session))))
     #+(and sbcl darwin)
     (cffi:foreign-funcall "sb_toggle_sigprof" :pointer (cffi:null-pointer) :int mask :int)))))
(format t "PASS: CEF regional damage, retained pulse, skipped frames and texture parity.~%")
