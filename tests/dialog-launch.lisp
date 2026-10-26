(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload '("lut/raylib" "lut/gtk-demo") :silent t)
(defun click-in-worker (remote widget)
 (let ((x (+ (lut:x widget) (/ (lut:width widget) 2)))
       (y (+ (lut:y widget) (/ (lut:height widget) 2))))
   (lut:evaluate-in-window remote
     (loop for kind in '(:down :up) collect
       `(lut::forward-native-event (lut:make-event :kind ,kind :x ,x :y ,y))))))
(let* ((browser (lut-gtk-demo:browser)) (remote nil) (phase :launch)
       (deadline (+ (get-internal-real-time) (* 20 internal-time-units-per-second))))
 (lut:on browser :tick
  (lambda (w dt)
   (declare (ignore dt))
   (when (> (get-internal-real-time) deadline) (error "Dialog regression timed out at ~a" phase))
   (when (and remote (lut::remote-window-error remote)) (error (lut::remote-window-error remote)))
   (let ((root (and remote (lut::remote-window-root remote))))
    (case phase
     (:launch
      (lut:emit (lut:find-widget w :query) :change "dialog")
      (lut:emit (lut:find-widget w :query) :activate nil)
      (setf remote (first lut::*remote-windows*) phase :edit) (assert remote))
     (:edit
      (when (>= (lut::remote-window-frames remote) 3)
       (click-in-worker remote (lut:find-widget root :open)) (setf phase :apply)))
     (:apply
      (when (slot-value root 'lut::overlays)
       (click-in-worker remote (lut-gtk-demo::overlay-control root :accept))
       (setf phase :show-message)))
     (:show-message
      (when (null (slot-value root 'lut::overlays))
       (assert (string= "Ada" (lut-gtk-demo::state root :name)))
       (click-in-worker remote (lut:find-widget root :message)) (setf phase :close-message)))
     (:close-message
      (when (slot-value root 'lut::overlays)
       (let ((message (lut::input-root root)))
        (assert (eq (lut:id message) :message-dialog))
        (assert (string= "Message" (lut:text message))))
       (click-in-worker remote (lut-gtk-demo::overlay-control root :close-message))
       (setf phase :close-window)))
     (:close-window
      (when (null (slot-value root 'lut::overlays))
       (lut:close-window remote) (setf phase :closing)))
     (:closing
      (when (null (lut::remote-window-process remote)) (setf phase :done) (lut:stop)))))))
 (lut:run browser :frames 1500)
 (assert (eq phase :done)) (assert (null (lut::remote-window-error remote))))
(format t "Dialog launcher Edit / Apply / Show message / Close via worker input queue passed.~%")
