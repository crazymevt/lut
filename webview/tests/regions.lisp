;;; Spatial key / cache-record tests without a native window or CEF runtime.
(load (merge-pathnames "../scripts/bootstrap.lisp" *load-truename*))
(asdf:load-system "lut/cef")
(let* ((root (lut:make-widget 'lut:window :width 768 :height 512))
       (view (lut:add-child root (lut:make-widget 'lut-webview:webview :width 640 :height 400))))
  (unwind-protect
    (progn
      (assert (null (lut:widget-render-key view)))
      (let ((before (lut-webview::frame-render-regions view 1280 800)))
        (setf (gethash '(0 0) (lut-webview::damage-keys view)) 7)
        (let ((after (lut-webview::frame-render-regions view 1280 800)))
          (assert (= (length before) 70))
          (assert (equal (caar after) '(0 0 129/2 129/2)))
          (assert (= 1 (count nil (mapcar #'equal before after))))
          ;; Previously returned keys are immutable snapshots.
          (assert (= 0 (second (first before))))
          (assert (= 7 (second (first after))))))
      (let ((regions (lut-webview::frame-render-regions view 513 333)))
        (assert (= 15 (length regions)))
        (assert (= (third (first (car (last regions)))) (* 2 (/ 640 513)))))
      (assert (null (lut:widget-render-regions root))))
    (lut:dispose root)))
(format t "PASS: regional key stability, bounded grid, DPI mapping and clipped edges.~%")
