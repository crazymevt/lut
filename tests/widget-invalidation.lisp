(in-package #:lut-tests)
(defun widget-invalidation-tests ()
 (let* ((root (lut:make-widget 'lut:window))
        (box (lut:add-child root (lut:make-widget 'lut:box)))
        (label (lut:add-child box (lut:make-widget 'lut:label :text "hello"))))
   (unwind-protect
     (progn
       (assert (lut:cache-enabled-p root)) (assert (eq :auto (lut:cache-mode label)))
       (let ((revision (lut::render-revision label)))
         (setf (lut:width label) (lut:width label)) (assert (= revision (lut::render-revision label)))
         (setf (lut:text label) "changed") (assert (< revision (lut::render-revision label))))
       (let ((revision (lut::render-revision label)))
         (setf (lut:style box) '(:font-size 22)) (assert (< revision (lut::render-revision label))))
       (let ((revision (lut::render-revision label)))
         (lut:invalidate-widget box :descendants t) (assert (< revision (lut::render-revision label))))
       (let ((key (lut:widget-render-key label)))
         (setf (lut:text label) "another") (assert (not (equal key (lut:widget-render-key label)))))
       (assert (zerop (getf (lut:window-cache-statistics root) :tiles))))
     (lut:dispose root)))
 ;; Layout may temporarily clamp scrolling before its final allocation. Compare
 ;; final viewport keys rather than permanently dirtying an unchanged region.
 (dolist (class '(lut:list-view lut:scroll-view lut:notebook lut:vertical-notebook))
   (let* ((view (lut:make-widget class)) (key (lut:widget-render-key view))
          (revision (lut::render-revision view)))
     (unwind-protect
       (progn
         (if (typep view '(or lut:notebook lut:vertical-notebook))
             (setf (lut:tab-offset view) 10) (setf (lut:scroll-offset view) 10))
         (assert (not (equal key (lut:widget-render-key view))))
         (if (typep view '(or lut:notebook lut:vertical-notebook))
             (setf (lut:tab-offset view) 0) (setf (lut:scroll-offset view) 0))
         (assert (equal key (lut:widget-render-key view)))
         (assert (= revision (lut::render-revision view))))
       (lut:dispose view)))) t)
