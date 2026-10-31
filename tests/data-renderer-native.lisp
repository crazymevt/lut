;;;; Lightweight host embedding: no LUT window controller or owned font atlas.
(require :asdf)
(asdf:load-asd (merge-pathnames "../lut.asd" *load-truename*))
(ql:quickload "lut/data-renderer")
(let ((done nil))
  (rl:run
   (lambda ()
     (rl:with-window (640 400 "LUT embedded table check" :exit-key nil :flags '(:window-highdpi))
       (let* ((calls 0)
              (model (lut:make-vector-model (loop for i below 10000 collect i)))
              (root (lut:make-widget 'lut:window :style '(:padding 0 :font-size 14 :row-height 24)))
              (pane (lut:add-child root (lut:make-widget 'lut:scroll-container)))
              (table (lut:add-child pane (lut:make-widget 'lut:model-table-view
                       :model model :min-column-width 100
                       :table-columns (loop for i below 8 collect
                         (lut:make-data-column :id i :title (format nil "Column ~d" i)
                           :getter (lambda (row) (incf calls) (write-to-string row)))))))
              (font (rl:get-font-default)) (cache (lut:make-render-cache)))
         (unwind-protect
              (progn
                (lut:layout root 20 20 260 160)
                (lut:layout pane 20 20 260 160)
                (flet ((paint () (lut:render-data-scroll-container pane font)))
                  (lut:update-cached-region cache :table '(20 20 260 160) 1 #'paint :background :white)
                  (assert (< 0 calls 100))
                  (let ((before calls))
                    (lut:update-cached-region cache :table '(20 20 260 160) 1 #'paint :background :white)
                    (assert (= before calls)))
                  (rl:with-drawing (:white) (lut:draw-cached-region cache :table)))
                (lut:dispatch root (lut:make-event :kind :down :x 35 :y 55))
                (assert (equal '(0) (lut:selected-keys (lut:view-selection table))))
                (lut:dispatch root (lut:make-event :kind :wheel :x 35 :y 55 :shift-p t :delta -2))
                (assert (plusp (nth-value 2 (lut:scroll-geometry table :horizontal)))))
           (lut:dispose cache) (lut:dispose root) (lut:dispose model))
         (assert (rl:is-font-valid font))
         (format t "Embedded table virtualization, cache reuse, selection, scrolling and borrowed font passed.~%")))
     (setf done t)) :wait t)
  (assert done))
