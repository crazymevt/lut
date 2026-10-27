(in-package #:lut-demo)

(defclass catalog-view (lut:list-view) ())
(defun reveal-catalog-selection (catalog)
  (let ((index (lut:value catalog)))
    (when (and index (<= 0 index) (< index (length (lut:items catalog))))
      (lut:reveal-rectangle catalog 0 (* index (lut:row-height catalog))
                            (lut:width catalog) (lut:row-height catalog)))))
(defmethod lut:layout :around ((catalog catalog-view) x y width height)
  (let ((old-height (lut:height catalog)))
    (prog1 (call-next-method)
      ;; Reveal on resize, not every frame: wheel browsing must remain free.
      (unless (= old-height (lut:height catalog)) (reveal-catalog-selection catalog)))))

(defun source-text (example)
  (let ((*package* (find-package :lut-demo))
        (*print-case* :downcase) (*print-pretty* t) (*print-right-margin* 72)
        (*print-level* nil) (*print-length* nil))
    (format nil ";; Requires (ql:quickload \"lut\").~%;; ROOT is the containing LUT window.~%~%~a~%"
            (with-output-to-string (out)
              (write `(lambda (root) (declare (ignorable root)) ,(example-source example))
                     :stream out :pretty t)))))

(defun show-example (root example)
  (let ((page (lut:find-widget root :demo-page))
        (source (lut:find-widget root :source)))
    ;; Disposing the old tree releases callbacks and any input references.
    (dolist (child (copy-list (lut:children page)))
      (lut:remove-child page child :dispose t))
    (setf (lut:scroll-offset page) 0)
    (lut:add-child page (lut:make-widget 'lut:label :height 72
                          :style '(:wrap-text t) :text (example-description example)))
    (lut:add-child page (funcall (example-builder example) root))
    (lut:refresh-commands root)
    (setf (lut:text source) (source-text example)
          (lut:cursor source) 0 (lut:vertical-offset source) 0 (lut:text-offset source) 0)
    (lut:select-all source)
    (setf (lut:cursor source) 0)))

(defun make-app ()
  "Build the two-pane browser without opening a native window."
  (let* ((root (lut:make-widget 'lut:window :text "LUT — Controls, Views & Features"
                                :width 1180 :height 780 :content-layout :fill))
         (split (lut:make-widget 'lut:paned :id :panes :value 0.29))
         (list (lut:make-widget 'catalog-view :id :catalog :items (demo-names) :value 0
                                :style '(:font-size 16)))
         (tabs (lut:make-widget 'lut:notebook :id :tabs :items '("Demo" "Code")))
         (page (lut:make-widget 'lut:scroll-view :id :demo-page))
         (source (lut:make-widget 'lut:text-view :id :source :history-limit 0
                                  :style '(:font-size 15))))
    (lut:add-child root split)
    (lut:add-child split list)
    (lut:add-child split tabs)
    (lut:add-child tabs page)
    (lut:add-child tabs source)
    (lut:on list :change
      (lambda (widget index)
        (when (and (integerp index) (<= 0 index) (< index (length *examples*)))
          (show-example root (nth index *examples*))
          (reveal-catalog-selection widget))) :owner root)
    (show-example root (first *examples*))
    root))

(defun main (&key frames)
  "Run the browser. FRAMES optionally bounds a native smoke run."
  (asdf:load-system "lut/raylib")
  (let ((root (make-app)))
    (unwind-protect (lut:run root :frames frames)
      (lut:dispose root))))
