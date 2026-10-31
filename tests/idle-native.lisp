(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/raylib" :silent t)
(let* ((root (lut:make-widget 'lut:window :width 400 :height 180))
       (label (lut:add-child root (lut:make-widget 'lut:label :text "Waiting")))
       (frames 0) (delivered nil) (posted nil) (first-time nil) (last-time nil) (elapsed 0) (presents 0)
       (thread (bt:make-thread
         (lambda ()
           (sleep 0.25)
           (setf posted (/ (get-internal-real-time) internal-time-units-per-second))
           (lut:on-widget label
             (setf (lut:text label) "Queued work delivered"
                   delivered (/ (get-internal-real-time) internal-time-units-per-second)))))))
 (lut:on root :tick
   (lambda (window dt)
     (incf frames)
     (unless first-time (setf first-time (/ (get-internal-real-time) internal-time-units-per-second)))
     (setf last-time (/ (get-internal-real-time) internal-time-units-per-second))
     (when (> frames 1) (incf elapsed dt))
     (when (= frames 60) (setf presents (getf (lut:window-cache-statistics window) :presents)))))
 (unwind-protect
   (progn
     (lut:run root :frames 61)
     (bt:join-thread thread)
     (assert delivered) (assert (< (- delivered posted) 0.25))
     (assert (string= "Queued work delivered" (lut:text label)))
     (assert (< (abs (- elapsed (- last-time first-time))) 0.1))
     (assert (< presents 10)))
   (lut:dispose root)))
(format t "PASS: idle queue delivery, monotonic tick deltas and limited buffer presentation.~%")
