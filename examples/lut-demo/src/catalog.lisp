(in-package #:lut-demo)

(defstruct example name description builder source)
(defvar *examples* nil)

(defmacro define-example (name description form)
  ;; Store the actual builder form, rather than maintaining a second code sample.
  `(progn
     (setf *examples* (remove ,name *examples* :key #'example-name :test #'string=))
     (setf *examples*
           (append *examples*
                   (list (make-example :name ,name :description ,description
                                       :builder (lambda (root) (declare (ignorable root)) ,form)
                                       :source ',form))))))

(defun demo-names () (mapcar #'example-name *examples*))

(define-example "Controls / Button" "Click the button to increment its counter."
  (let ((count 0) (button (lut:make-widget 'lut:button :id :counter :text "Clicked 0 times")))
    (lut:on button :activate
            (lambda (widget event) (declare (ignore event))
              (setf (lut:text widget) (format nil "Clicked ~d times" (incf count)))))
    button))

(define-example "Controls / Check button" "Click or press Space to toggle."
  (lut:make-widget 'lut:check-button :text "Enable notifications" :value t))
(define-example "Controls / Toggle button" "A button that retains its on/off state."
  (lut:make-widget 'lut:toggle-button :text "Bold"))
(define-example "Controls / Switch" "A boolean switch, accessible with Tab and Space."
  (lut:make-widget 'lut:switch :text "Airplane mode"))
(define-example "Controls / Radio buttons" "Only one option in a group can be selected."
  (let ((small (lut:make-widget 'lut:radio-button :text "Small" :value t))
        (large (lut:make-widget 'lut:radio-button :text "Large")))
    (lut:group-radios small large)
    (lut:with-ui (lut:box :height 100) small large)))
(define-example "Controls / Entry" "Select, edit, copy, paste, and undo text."
  (lut:make-widget 'lut:entry :text "Hello, Common Lisp!"))
(define-example "Controls / Slider and progress" "Move the slider to update the progress bar."
  (let ((slider (lut:make-widget 'lut:slider :id :slider :value 35))
        (progress (lut:make-widget 'lut:progress-bar :id :progress :value 35)))
    (lut:on slider :change (lambda (widget value) (declare (ignore widget))
                             (setf (lut:value progress) value)))
    (lut:with-ui (lut:box :height 110) slider progress)))
(define-example "Controls / Spin button" "Use arrows, mouse wheel, or the +/- buttons."
  (lut:make-widget 'lut:spin-button :value 5 :minimum 0 :maximum 20))
(define-example "Controls / Dropdown" "Open the popup and choose a color."
  (lut:make-widget 'lut:dropdown :items '("Red" "Green" "Blue") :value 0))
(define-example "Controls / Combo box" "Type a value or choose a suggestion with Down."
  (lut:make-widget 'lut:combo-box :text "Lisp" :items '("Lisp" "Scheme" "Clojure")))
(define-example "Views / Text" "Multiline text editing with selection and undo."
  (lut:make-widget 'lut:text-view :height 280
                   :text (format nil "A Lisp toolkit~%~%Edit this text and try Ctrl/Cmd+Z.")))
(define-example "Views / List" "Select rows with the mouse or Up/Down; scroll for more."
  (lut:make-widget 'lut:list-view :height 360
                   :items (loop for i from 1 to 50 collect (format nil "Item ~2,'0d" i))))
(define-example "Views / Tree" "Click a parent row to expand or collapse it."
  (lut:make-widget 'lut:tree-view :height 260
                   :nodes '((:text "Project" :open t :children
                              ((:text "src" :children ((:text "main.lisp") (:text "package.lisp"))))
                              (:text "README.md")))))
(define-example "Views / Table" "Click a column heading to sort; click a row to select."
  (lut:make-widget 'lut:table-view :height 260 :columns '("Language" "Style")
                   :rows '(("Common Lisp" "Multiparadigm") ("Scheme" "Minimal")
                           ("Clojure" "Functional"))))
(define-example "Views / Scroll view" "Scroll this panel to reach all forty controls."
  (let ((view (lut:make-widget 'lut:scroll-view :height 360)))
    (dotimes (i 40) (lut:add-child view (lut:make-widget 'lut:check-button
                                             :text (format nil "Option ~d" (1+ i)))))
    view))
(define-example "Layouts / Grid" "A uniform grid of six buttons."
  (let ((grid (lut:make-widget 'lut:grid :height 220 :columns 3)))
    (dotimes (i 6) (lut:add-child grid (lut:make-widget 'lut:button :text (format nil "~d" (1+ i)))))
    grid))
(define-example "Layouts / Split panes" "Drag the divider between the two panels."
  (lut:with-ui (lut:paned :height 260 :value 0.5)
    (lut:make-widget 'lut:label :text "Left pane")
    (lut:make-widget 'lut:label :text "Right pane")))
(define-example "Layouts / Tabs" "Click a tab, or focus the tabs and use Left/Right."
  (lut:with-ui (lut:notebook :height 260 :items '("First" "Second"))
    (lut:make-widget 'lut:label :text "First page: a static label. Switch to Second to edit text.")
    (lut:make-widget 'lut:entry :text "The second page")))
(define-example "Layouts / Expander" "Click the heading to reveal additional controls."
  (lut:with-ui (lut:expander :height 180 :text "Advanced options")
    (lut:make-widget 'lut:check-button :text "Enable tracing")
    (lut:make-widget 'lut:entry :text "Trace destination")))
(define-example "Features / Theme" "Switch the application's inherited light/dark palette."
  (let ((button (lut:make-widget 'lut:button :text "Toggle light / dark")))
    (lut:on button :activate (lambda (widget event) (declare (ignore widget event))
      (setf (lut:theme root) (if (eq (lut:theme root) lut:*dark-theme*)
                               lut:*light-theme* lut:*dark-theme*))))
    button))
(define-example "Features / Styles and tooltips" "Hover over the styled button to show its tooltip."
  (lut:make-widget 'lut:button :text "Styled button" :tooltip-text "Styles inherit through the widget tree."
                   :style '(:accent (140 70 180 255) :font-size 24 :radius 12)))
(define-example "Features / Dialog" "Open a native modal dialog; Close or Escape returns to this window."
  (let ((button (lut:make-widget 'lut:button :text "Open dialog")))
    (lut:on button :activate (lambda (widget event) (declare (ignore widget event))
      (let* ((dialog (lut:make-widget 'lut:dialog :text "A LUT dialog" :width 380 :height 200))
             (close (lut:make-widget 'lut:button :text "Close")))
        (lut:on close :activate (lambda (widget event) (declare (ignore widget event))
                                 (lut:dismiss-dialog dialog)))
        (lut:add-child dialog (lut:make-widget 'lut:label :text "Hello from a modal window."))
        (lut:add-child dialog close)
        (lut:show-dialog root dialog))))
    button))

(define-example "Controls / Search" "Type to edit; Enter or the search button submits; Escape or the clear icon clears."
 (let ((box (lut:make-widget 'lut:box :height 96))
       (search (lut:make-widget 'lut:search-control :search-hint "Search records"))
       (status (lut:make-widget 'lut:label :text "Waiting for a search")))
   (lut:on search :search (lambda (w query) (declare (ignore w))
                           (setf (lut:text status) (format nil "Search: ~a" query))) :owner status)
   (lut:add-child box search) (lut:add-child box status) box))
(define-example "Controls / Activity indicator" "A compact animated ring. Toggle Working to start or stop."
 (let ((box (lut:make-widget 'lut:box :height 100))
       (spinner (lut:make-widget 'lut:activity-indicator))
       (toggle (lut:make-widget 'lut:toggle-button :text "Working" :value t)))
   (lut:on toggle :change (lambda (w value) (declare (ignore w))
                           (setf (lut:activity-running-p spinner) value)) :owner spinner)
   (lut:add-child box toggle) (lut:add-child box spinner) box))
(define-example "Controls / Icon toggle" "Toggle with a click, Space or Enter. Supply :icon-source for an image."
 (lut:make-widget 'lut:icon-toggle-button :icon-source (asdf:system-relative-pathname "lut" "examples/assets/demo.png") :text "*" :width 48 :height 48 :tooltip-text "Favorite"))

(define-example "Controls / Date picker" "Click the date to open its calendar. +/- steps the selected field; Left/Right selects fields for keyboard editing."
 (lut:make-widget 'lut:date-picker :width 340))
(define-example "Controls / Time picker" "24-hour time: select a field; arrows, wheel or +/- adjust; type digits."
 (lut:make-widget 'lut:time-picker :clock-time '(14 30 0) :width 280))

(define-example "Controls / Time picker (12 hour)" "Select a field or AM/PM; use arrows, +/- or type A/P to change period."
 (lut:make-widget 'lut:time-picker :clock-time '(14 30 0) :time-format :12-hour :width 320))

(define-example "Views / Styled text" "Edit the snippet to test colors, bold keywords, italic comments and mixed font sizes. Toggle each style, select text, and try undo/redo."
 (let* ((sample (format nil "; Edit this example: colors update as you type.~%(defun greet (name)~%  ;; TODO: add your own greeting~%  (let ((count 42))~%    (format nil \"Hello, ~a! Count: ~d\" name count)))~%~%(greet \"Lut\")~%" "~a" "~d"))
        (box (lut:make-widget 'lut:box :height 450 :style '(:padding 0)))
        (toolbar (lut:make-widget 'lut:box :orientation :horizontal :height 40 :style '(:padding 0)))
        (typography (lut:make-widget 'lut:box :orientation :horizontal :height 40 :style '(:padding 0)))
        (highlight (lut:make-widget 'lut:toggle-button :id :styled-highlight :text "Colors" :value t :width 100))
        (bold (lut:make-widget 'lut:toggle-button :id :styled-bold :text "Bold" :value t :width 100 :style '(:bold t)))
        (italic (lut:make-widget 'lut:toggle-button :id :styled-italic :text "Italic" :value t :width 100 :style '(:italic t)))
        (sizes (lut:make-widget 'lut:toggle-button :id :styled-sizes :text "Mixed sizes" :value t :width 140))
        (lines (lut:make-widget 'lut:toggle-button :id :styled-lines :text "Line numbers" :value t :width 140))
        (reset (lut:make-widget 'lut:button :id :styled-reset :text "Reset" :width 80))
        (view (lut:make-widget 'lut:styled-text-view :id :styled-editor :text sample :height 300
                              :style '(:font-size 16 :line-height 34 :padding 12)))
        (status (lut:make-widget 'lut:label :id :styled-status :height 32 :style '(:font-size 14))))
   ;; This small demo lexer supplies presentation data; LUT handles editing,
   ;; selection, geometry and painting. It is not a complete Lisp reader.
   (labels ((refresh (widget payload)
              (declare (ignore widget payload))
              (let* ((text (lut:text view)) (length (length text)) (i 0) (runs nil) (decorations nil) (line-count 0))
                (loop while (< i length) do
                    (let ((start i) (char (char text i)) (color nil) (role nil))
                      (cond
                        ((char= char #\;) (setf i (or (position #\Newline text :start i) length)
                                                color (lut:style-value view :muted-color) role :comment))
                        ((char= char #\")
                         (incf i)
                         (loop while (< i length) do
                           (let ((next (char text i)))
                             (incf i)
                             (cond ((char= next #\\) (when (< i length) (incf i)))
                                   ((char= next #\") (return)))))
                         (setf color '(22 163 74 255) role :string))
                        ((digit-char-p char)
                         (loop while (and (< i length) (digit-char-p (char text i))) do (incf i))
                         (setf color '(217 119 6 255) role :number))
                        ((or (alpha-char-p char) (find char ":-+*/<>=!?"))
                         (loop while (and (< i length) (or (alphanumericp (char text i)) (find (char text i) ":-+*/<>=!?"))) do (incf i))
                         (when (or (char= char #\:) (member (subseq text start i) '("defun" "let" "if" "lambda" "format" "nil" "t") :test #'string-equal))
                           (setf color (lut:style-value view :accent) role :keyword)))
                        (t (incf i)))
                      (let ((style (append
                                      (when (and color (lut:value highlight)) (list :foreground color))
                                      (when (and (eq role :keyword) (lut:value bold)) (list :bold t))
                                      (when (and (eq role :comment) (lut:value italic)) (list :italic t))
                                      (when (and role (lut:value sizes))
                                        (list :font-size (ecase role (:comment 14) (:keyword 18) (:string 20) (:number 24)))))))
                        (when style (push (list :start start :end i :style style) runs)))))
                (when (lut:value highlight)
                  (loop for start = (search "TODO" text) then (search "TODO" text :start2 (+ start 4))
                        while start do (push (list :start start :end (+ start 4) :kind :underline :color '(217 119 6 255)) decorations)))
                (loop for start = 0 then (1+ end) for end = (position #\Newline text :start start) do
                  (incf line-count)
                  (when (lut:value lines)
                    (push (list :start start :end (or end length) :kind :gutter :text (princ-to-string line-count)
                                :color (lut:style-value view :muted-color)) decorations))
                  while end)
                (let ((gutter (if (lut:value lines) 44 0)))
                  (unless (= gutter (lut:gutter-width view)) (setf (lut:gutter-width view) gutter)))
                (lut:set-text-presentation view :runs (nreverse runs) :decorations (nreverse decorations) :reveal-cursor-p nil)
                (setf (lut:text status) (format nil "~d lines | ~d styled ranges | TODO underline" line-count (length (lut:text-runs view)))))))
     (lut:on view :change #'refresh :owner box)
     (lut:on highlight :change #'refresh :owner box)
     (lut:on lines :change #'refresh :owner box)
     (dolist (toggle (list bold italic sizes)) (lut:on toggle :change #'refresh :owner box))
     (lut:on reset :activate
       (lambda (widget payload)
         (declare (ignore widget payload))
         (setf (lut:text view) sample (lut:cursor view) 0 (lut:anchor view) 0
               (lut:text-offset view) 0 (lut:vertical-offset view) 0)
         (refresh nil nil)) :owner box)
     (refresh nil nil))
   (dolist (button (list highlight lines reset)) (lut:add-child toolbar button))
   (dolist (button (list bold italic sizes)) (lut:add-child typography button))
   (dolist (child (list toolbar typography view status)) (lut:add-child box child)) box))
