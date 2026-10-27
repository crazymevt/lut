;;;; Focused launcher contracts and native error/cleanup regression checks.
(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(asdf:load-asd (truename "lut.asd"))
(ql:quickload "lut/raylib")

(defun with-start-functions (replacements function)
 (let ((saved (mapcar (lambda (pair) (cons (car pair) (symbol-function (car pair)))) replacements)))
   (unwind-protect
     (progn (dolist (pair replacements) (setf (symbol-function (car pair)) (cdr pair))) (funcall function))
     (dolist (pair saved) (setf (symbol-function (car pair)) (cdr pair))))))

;; Successful synchronous starts preserve the runner's result. An asynchronous
;; call must not intercept errors before the binding runner sees them.
(let ((window (lut:make-widget 'lut:window)) (expected (make-condition 'simple-error :format-control "Async fixture"))
      (lut::*window* nil) (waits nil) (recorded nil))
 (unwind-protect
   (with-start-functions
     (list (cons 'rl:running-p (constantly nil))
           (cons 'rl:run (lambda (function &key wait)
                          (push wait waits)
                          (handler-case (funcall function) (error (condition) (setf recorded condition) :recorded))))
           (cons 'lut:run (lambda (w &key frames) (declare (ignore w frames)) :result)))
     (lambda ()
       (assert (eq :result (lut:start window :wait t :frames 2)))
       (assert (equal '(t) waits))
       (setf (symbol-function 'lut:run) (lambda (w &key frames) (declare (ignore w frames)) (error expected)))
       (assert (eq :recorded (lut:start window)))
       (assert (eq expected recorded)) (assert (equal '(nil t) waits))))
   (lut:dispose window)))

;; Even WAIT T on a secondary launch returns its worker handle immediately;
;; the parent controller must keep servicing worker input and frames.
(let ((window (lut:make-widget 'lut:window)) (source (lut:make-widget 'lut:window)) (lut::*window* nil))
 (unwind-protect
   (with-start-functions
     (list (cons 'rl:running-p (constantly t))
           (cons 'rl:run (lambda (&rest args) (declare (ignore args)) (error "Unexpected primary runner")))
           (cons 'lut:spawn-window (lambda (w &key style-source)
                                    (assert (eq w window)) (assert (eq style-source source)) :worker)))
     (lambda () (setf lut:*window* source) (assert (eq :worker (lut:start window :wait t)))))
   (lut:dispose window) (lut:dispose source)))

(defclass start-error-label (lut:label) ((failure :initform nil :accessor start-label-failure)))
(defmethod lut:render :before ((label start-error-label))
 (when (start-label-failure label) (error (start-label-failure label))))

(defun check-native-start-error (mode &key threaded)
 (let* ((window (lut:make-widget 'lut:window :width 320 :height 160))
        (label (lut:add-child window (lut:make-widget 'start-error-label :text "Launcher regression")))
        (expected (make-condition 'simple-error :format-control "Expected native start failure"))
        (observed nil) (ticks 0) (closed nil) (done nil)
        ;; Stop a regressed interactive pause instead of hanging this script.
        (watchdog (bt:make-thread (lambda ()
                    (loop repeat 100 until done do (sleep 0.1))
                    (unless done (rl:stop))) :name "start-error watchdog")))
   (unwind-protect
     (progn
       (lut:on window :context-close (lambda (w p) (declare (ignore w p)) (setf closed t)
                                      (when (eq mode :cleanup) (error expected))))
       (lut:on window :tick (lambda (w dt)
         (declare (ignore w dt)) (incf ticks)
         (case mode
           (:tick (error expected))
           (:render (when (= ticks 2) (setf (start-label-failure label) expected))))))
       (flet ((launch ()
                (handler-case
                  (lut:start window :wait t :frames (case mode (:render 2) (:cleanup 1)))
                  (error (condition) (setf observed condition)))))
         (if threaded (bt:join-thread (bt:make-thread #'launch :name "synchronous-start caller")) (launch)))
       (assert (eq expected observed))
       (assert closed) (assert (= ticks (if (eq mode :render) 2 1)))
       (assert (not (rl:is-window-ready))) (assert (not (rl:running-p)))
       (assert (null lut::*primary-window*)) (assert (not lut::*controller-running-p*))
       ;; Native context cleanup does not destroy application-owned trees.
       (assert (not (lut:disposed-p window)))
       (format t "Synchronous START propagated ~a failure after native cleanup~:[~; to another thread~].~%" mode threaded))
     (setf done t) (bt:join-thread watchdog) (lut:dispose window))))

(check-native-start-error :tick)
(check-native-start-error :render)
(check-native-start-error :cleanup)
(check-native-start-error :tick :threaded t)
;; A fresh launch after these errors verifies the renderer/controller recovered.
(let ((window (lut:make-widget 'lut:window :width 320 :height 160)) (ticks 0))
 (unwind-protect
   (progn
     (lut:on window :tick (lambda (w dt) (declare (ignore w dt)) (incf ticks)))
     (lut:start window :wait t :frames 2)
     (assert (= ticks 2)) (assert (not (rl:running-p))))
   (lut:dispose window)))
(format t "START results, asynchronous error handling, worker routing and recovery passed.~%")
