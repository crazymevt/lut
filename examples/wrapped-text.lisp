(in-package #:lut-examples)
(export 'wrapped-text)
(defun wrapped-text ()
 "A growing composer and application-authored document blocks."
 (let* ((root (lut:make-widget 'lut:window :text "Wrapped text and document blocks"
                :width 640 :height 500 :content-layout :fill))
        (body (lut:add-child root (lut:make-widget 'lut:measured-box :spacing 12)))
        (document (lut:add-child body (lut:make-widget 'lut:wrapped-document-view :id :wrapped-document
                    :text (format nil "Document heading~%Resize to reflow this selectable paragraph. The application supplies text and heading styles; LUT supplies visual rows.~%Another paragraph with its own spacing.")
                    :paragraph-spacing 12 :hexpand t)))
        (composer (lut:add-child body (lut:make-widget 'lut:wrapped-text-view :id :wrapped-composer
                    :text "Type here. This composer grows with content up to 150 pixels, then scrolls."
                    :max-height 150 :hexpand t))))
   (lut:set-text-presentation document :runs '((:start 0 :end 16 :style (:font-size 30))))
   (lut:focus root composer) root))
