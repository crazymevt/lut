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
