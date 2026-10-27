(in-package #:lut-demo)

(define-example "Foundations / Shared commands"
  "Two buttons and F6 share one context-sensitive command. Toggle availability."
  (let* ((panel (lut:make-widget 'lut:box :height 210))
         (allowed (lut:add-child panel (lut:make-widget 'lut:check-button :id :command-allowed :text "Enable action" :value t)))
         (first (lut:add-child panel (lut:make-widget 'lut:button :id :command-first)))
         (second (lut:add-child panel (lut:make-widget 'lut:button :id :command-second)))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :command-count :text "Count: 0")))
         (count 0)
         (command (lut:make-command :demo-increment "Increment (F6)"
                    (lambda (command context) (declare (ignore command context))
                      (setf (lut:text status) (format nil "Count: ~d" (incf count))))
                    :enabled-when (lambda (command context) (declare (ignore command context)) (lut:value allowed))
                    :shortcut :f6)))
    (lut:bind-command root command :widget first)
    (lut:bind-command root command :widget second :shortcut-p nil)
    (lut:on allowed :change (lambda (w v) (declare (ignore w v)) (lut:refresh-commands root)))
    panel))

(define-example "Foundations / Shared text and history"
  "Edit either view. Both share text and undo history; the right view can be read-only."
  (let* ((panel (lut:make-widget 'lut:box :height 420))
         (buffer (lut:make-text-buffer :text (format nil "One shared buffer~%Each view keeps its own caret and selection.")))
         (panes (lut:add-child panel (lut:make-widget 'lut:paned :height 250)))
         (left (lut:add-child panes (lut:make-widget 'lut:text-view :id :shared-left :view-buffer buffer)))
         (right (lut:add-child panes (lut:make-widget 'lut:text-view :id :shared-right :view-buffer buffer)))
         (undo (lut:add-child panel (lut:make-widget 'lut:button :id :shared-undo :text "Undo shared edit")))
         (redo (lut:add-child panel (lut:make-widget 'lut:button :id :shared-redo :text "Redo shared edit")))
         (locked (lut:add-child panel (lut:make-widget 'lut:check-button :id :shared-lock :text "Right view read-only"))))
    (lut:on undo :activate (lambda (w e) (declare (ignore w e)) (lut:undo left)))
    (lut:on redo :activate (lambda (w e) (declare (ignore w e)) (lut:redo left)))
    (lut:on locked :change (lambda (w v) (declare (ignore w)) (setf (lut:read-only-p right) v)))
    panel))

(define-example "Foundations / Indexed text and selection"
  "20,000 indexed lines. Jump to the last line, select a word, or navigate with Shift and arrows."
  (let* ((panel (lut:make-widget 'lut:box :height 390))
         (view (lut:add-child panel (lut:make-widget 'lut:text-view :id :indexed-view :height 280
                  :view-buffer (lut:make-text-buffer :text (format nil "~{~a~^~%~}"
                    (loop for i below 20000 collect (format nil "Line ~d: indexed text navigation" i)))))))
         (last (lut:add-child panel (lut:make-widget 'lut:button :id :indexed-last :text "Reveal last line")))
         (word (lut:add-child panel (lut:make-widget 'lut:button :id :indexed-word :text "Select first word"))))
    (lut:on last :activate (lambda (w e) (declare (ignore w e))
      (setf (lut:cursor view) (lut:text-length view)) (lut:reveal-text-cursor view) (lut:focus root view)))
    (lut:on word :activate (lambda (w e) (declare (ignore w e)) (lut:select-word view 0) (lut:focus root view)))
    panel))

(define-example "Foundations / Document presentation"
  "Formatting and links come from application data. Suggestions use the focused caret; Escape dismisses."
  (let* ((panel (lut:make-widget 'lut:box :height 380))
         (view (lut:add-child panel (lut:make-widget 'lut:document-view :id :document-view :height 190
                   :text (format nil "Document title~%Application-supplied formatting and links.~%Open help"))))
         (editor (lut:add-child panel (lut:make-widget 'lut:entry :id :suggestion-editor :text "Try suggestions")))
         (button (lut:add-child panel (lut:make-widget 'lut:button :id :suggestion-show :text "Show caret suggestions")))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :document-status :text "Links report targets; nothing opens automatically.")))
         (suggestions (lut:make-widget 'lut:suggestion-surface :width 280 :height 130 :items '("alpha" "beta" "gamma"))))
    (lut:set-text-presentation view
      :runs '((:start 0 :end 14 :style (:font-size 24 :foreground :blue)))
      :decorations '((:start 15 :end 26 :kind :underline :color :orange))
      :links (list (list :start (- (lut:text-length view) 9) :end (lut:text-length view) :target :help)))
    (lut:on view :link (lambda (w target) (declare (ignore w)) (setf (lut:text status) (format nil "Target: ~s" target))))
    (lut:on button :activate (lambda (w e) (declare (ignore w e))
      (lut:focus root editor) (lut:show-anchored-surface editor suggestions)))
    (lut:on suggestions :accept (lambda (w item) (declare (ignore w)) (lut:replace-selection editor item)) :owner panel)
    panel))

(define-example "Foundations / Virtual data and selection"
  "A million lazy rows without a million widgets. Ctrl/Cmd toggles selection; Shift extends it."
  (let* ((panel (lut:make-widget 'lut:box :height 380))
         (model (lut:make-function-model :count 1000000 :item (lambda (i) (format nil "Lazy row ~d" i))
                  :index (lambda (key) (when (and (integerp key) (<= 0 key) (< key 1000000)) key))))
         (selection (lut:make-selection-model model :mode :multiple))
         (view (lut:add-child panel (lut:make-widget 'lut:model-list-view :id :virtual-view :model model :selection selection :height 270)))
         (last (lut:add-child panel (lut:make-widget 'lut:button :id :virtual-last :text "Select and reveal row 999999")))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :virtual-status :text "Selected keys: NIL"))))
    (lut:on last :activate (lambda (w e) (declare (ignore w e))
      (lut:select-model-index selection 999999) (lut:reveal-model-index view 999999)))
    (lut:on view :selection-change (lambda (w keys) (declare (ignore w))
      (setf (lut:text status) (format nil "Selected keys: ~s" keys))))
    panel))

(define-example "Foundations / Editable model table"
  "Enter edits the Name column; Enter commits and Escape cancels. Sort preserves stable row keys."
  (let* ((panel (lut:make-widget 'lut:box :height 370))
         (model (lut:make-vector-model (list (list :id 1 :name "Alpha") (list :id 2 :name "Beta") (list :id 3 :name "Gamma"))
                  :key (lambda (item) (getf item :id))))
         (projection (lut:make-projection-model model))
         (table (lut:add-child panel (lut:make-widget 'lut:model-table-view :id :editable-table :model projection :height 260
                    :table-columns (list
                      (lut:make-data-column :id :name :title "Name (editable)" :getter (lambda (item) (getf item :name))
                        :setter (lambda (item value) (setf (getf item :name) value)))
                      (lut:make-data-column :id :id :title "Stable ID" :getter (lambda (item) (getf item :id)))))))
         (sort (lut:add-child panel (lut:make-widget 'lut:button :id :table-sort :text "Sort names Z–A"))))
    (declare (ignore table))
    (lut:on sort :activate (lambda (w e) (declare (ignore w e))
      (lut:set-model-query projection :lessp (lambda (a b) (string> (getf a :name) (getf b :name))))))
    panel))

(define-example "Foundations / Platform integration"
  "Try UI zoom, a context menu and a portable path picker. Selecting a path does not read or write its contents."
  (let* ((panel (lut:make-widget 'lut:box :height 270))
         (zoom (lut:add-child panel (lut:make-widget 'lut:button :id :platform-zoom :text "Cycle UI scale: 100 / 125 / 200%")))
         (picker (lut:add-child panel (lut:make-widget 'lut:button :id :platform-picker :text "Choose a file path (portable)")))
         (menu (lut:add-child panel (lut:make-widget 'lut:button :id :platform-menu :text "Open context menu")))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :platform-status :height 120 :style '(:wrap-text t)
                    :text (format nil "Menus: ~s~%Path pickers: ~s~%UI zoom affects the whole browser."
                            (getf (lut:platform-capability root :menus) :status)
                            (getf (lut:platform-capability root :path-pickers) :status))))))
    (lut:on zoom :activate (lambda (w e) (declare (ignore w e))
      (setf (lut:ui-scale root) (case (lut:ui-scale root) (1 5/4) (5/4 2) (otherwise 1)))))
    (lut:on menu :activate (lambda (w e) (declare (ignore e))
      (lut:open-context-menu root w (lut:make-event :kind :context :x (lut:x w) :y (+ (lut:y w) (lut:height w)))
        (list (list "Choose file path" (lambda () (lut:emit picker :activate nil)) t)
              :separator (list "Cycle UI scale" (lambda () (lut:emit zoom :activate nil)) t)))))
    (lut:on picker :activate (lambda (w e) (declare (ignore w e))
      (lut:request-path root (lambda (path) (setf (lut:text status) (format nil "Selected path: ~a" (or path "cancelled")))) :native nil)))
    panel))

(define-example "Foundations / Notebook composition"
  "Drag tabs to reorder. Badged pages veto close until you clear the badge; move a page between notebooks."
  (let* ((panel (lut:make-widget 'lut:box :height 390))
         (panes (lut:add-child panel (lut:make-widget 'lut:paned :height 260)))
         (left (lut:add-child panes (lut:make-widget 'lut:notebook :id :composition-left :items '("Draft" "Notes") :closable-p t :reorderable-p t :tab-group :demo)))
         (right (lut:add-child panes (lut:make-widget 'lut:notebook :id :composition-right :items '("Archive") :closable-p t :reorderable-p t :tab-group :demo)))
         (draft (lut:add-child left (lut:make-widget 'lut:entry :text "Protected draft" :tab-badge "unsaved")))
         (clear (lut:add-child panel (lut:make-widget 'lut:button :id :composition-clear :text "Clear draft badge")))
         (move (lut:add-child panel (lut:make-widget 'lut:button :id :composition-move :text "Move first left tab to right"))))
    (lut:add-child left (lut:make-widget 'lut:label :text "Notes"))
    (lut:add-child right (lut:make-widget 'lut:label :text "Archive"))
    (dolist (book (list left right))
      (lut:on book :page-close-request (lambda (w request) (declare (ignore w))
        (when (lut:tab-badge (lut:close-request-page request)) (setf (lut:close-request-veto-p request) t))))
      (lut:on book :page-closed (lambda (w request) (declare (ignore w)) (lut:dispose (lut:close-request-page request)))))
    (lut:on clear :activate (lambda (w e) (declare (ignore w e)) (setf (lut:tab-badge draft) nil)))
    (lut:on move :activate (lambda (w e) (declare (ignore w e))
      (when (lut:children left) (lut:move-page left (first (lut:children left)) right (length (lut:children right))))))
    panel))

(define-example "Foundations / Measured and flow layout"
  "Resize the split pane. Content-sized controls wrap into rows; prose determines its own height."
  (let* ((panel (lut:make-widget 'lut:measured-box :height 320 :spacing 12))
         (prose (lut:add-child panel (lut:make-widget 'lut:label :id :measured-prose :hexpand t :style '(:wrap-text t)
                   :text "Measured labels ask for their actual height at the available width. Narrow this pane to see prose and controls reflow.")))
         (flow (lut:add-child panel (lut:make-widget 'lut:flow-box :id :measured-flow :hexpand t :column-spacing 8 :row-spacing 8))))
    (dotimes (i 7) (lut:add-child flow (lut:make-widget 'lut:button :text (format nil "Action ~d" (1+ i)))))
    (let ((button (lut:add-child panel (lut:make-widget 'lut:button :id :measured-grow :text "Add more prose" :hexpand t))))
      (lut:on button :activate (lambda (w e) (declare (ignore w e))
        (setf (lut:text prose) (concatenate 'string (lut:text prose) " Content changes trigger new measurement.")))))
    panel))

(define-example "Foundations / Wrapped document blocks"
  "Selectable heading and paragraphs reflow. The editable composer grows to a 150-pixel limit, then scrolls."
  (let* ((panel (lut:make-widget 'lut:measured-box :height 390 :spacing 12))
         (document (lut:add-child panel (lut:make-widget 'lut:wrapped-document-view :id :wrapped-document :hexpand t :paragraph-spacing 10
                     :text (format nil "Document heading~%Resize to reflow this selectable paragraph. Formatting comes from application data, not a parser.~%Another paragraph with its own spacing.")))))
    (lut:set-text-presentation document :runs '((:start 0 :end 16 :style (:font-size 28))))
    (lut:add-child panel (lut:make-widget 'lut:wrapped-text-view :id :wrapped-composer :hexpand t :max-height 150
                          :text "Type here. The composer grows with its content until it reaches the configured maximum height."))
    panel))

(define-example "Foundations / Scrolling and follow-end"
  "Append messages, pause following to browse, reveal the first match, and resume following."
  (let* ((panel (lut:make-widget 'lut:box :height 470))
         (view (lut:add-child panel (lut:make-widget 'lut:text-view :id :follow-view :height 260
                   :text (format nil "~{~a~%~}" (loop for i from 1 to 30 collect (format nil "Message ~d" i))))))
         (append (lut:add-child panel (lut:make-widget 'lut:button :id :follow-append :text "Append a message")))
         (pause (lut:add-child panel (lut:make-widget 'lut:button :id :follow-pause :text "Pause following")))
         (first (lut:add-child panel (lut:make-widget 'lut:button :id :follow-first :text "Reveal first message")))
         (resume (lut:add-child panel (lut:make-widget 'lut:button :id :follow-resume :text "Follow end")))
         (count 30))
    (lut:set-follow-end view t)
    (lut:on append :activate (lambda (w e) (declare (ignore w e))
      (setf (lut:text view) (concatenate 'string (lut:text view) (format nil "Message ~d~%" (incf count))))))
    (lut:on pause :activate (lambda (w e) (declare (ignore w e)) (lut:set-follow-end view nil)))
    (lut:on first :activate (lambda (w e) (declare (ignore w e)) (lut:set-follow-end view nil) (lut:reveal-text-range view 0 9)))
    (lut:on resume :activate (lambda (w e) (declare (ignore w e)) (lut:set-follow-end view t)))
    panel))

(define-example "Foundations / Application adapters"
  "Inspect launch availability and window state. Opening a URI is an explicit action; no launch happens on selection."
  (let* ((panel (lut:make-widget 'lut:box :height 340))
         (uri (lut:add-child panel (lut:make-widget 'lut:entry :id :adapter-uri :text "https://example.com")))
         (open (lut:add-child panel (lut:make-widget 'lut:button :id :adapter-open :text "Open URI in its default application")))
         (maximize (lut:add-child panel (lut:make-widget 'lut:button :id :adapter-maximize :text "Maximize browser")))
         (restore (lut:add-child panel (lut:make-widget 'lut:button :id :adapter-restore :text "Restore browser")))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :adapter-status :height 120 :style '(:wrap-text t)
                    :text (format nil "Launcher: ~s~%Window state: ~s" (lut:default-application-capabilities) (lut:window-state root))))))
    (lut:on open :activate (lambda (w e) (declare (ignore w e))
      (handler-case (multiple-value-bind (submitted backend) (lut:launch-uri (lut:text uri))
                      (setf (lut:text status) (format nil "Submitted: ~s via ~s" submitted backend)))
        (error (condition) (setf (lut:text status) (princ-to-string condition))))))
    (lut:on maximize :activate (lambda (w e) (declare (ignore w e))
      (handler-case (lut:set-window-state root :maximized) (error (c) (setf (lut:text status) (princ-to-string c))))))
    (lut:on restore :activate (lambda (w e) (declare (ignore w e))
      (handler-case (lut:set-window-state root :normal) (error (c) (setf (lut:text status) (princ-to-string c))))))
    panel))

(define-example "Foundations / Cell grid and key capture"
  "A simulated grid, not a terminal. Capture keys, type text, release with F12. Drag selects; Alt-drag selects a rectangle."
  (let* ((panel (lut:make-widget 'lut:box :height 400))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :cell-status :text "F12 releases capture; Copy uses the current cell selection.")))
         (grid (lut:add-child panel (lut:make-widget 'lut:cell-grid :id :cell-grid :height 240 :style '(:font-size 16))))
         (capture (lut:add-child panel (lut:make-widget 'lut:button :id :cell-capture :text "Capture keys (F12 releases)")))
         (copy (lut:add-child panel (lut:make-widget 'lut:button :id :cell-copy :text "Copy cell selection")))
         (column 0) (row 1))
    (lut:on grid :grid-resize (lambda (w size) (declare (ignore size))
      (setf column 0 row (min 1 (max 0 (1- (lut:grid-rows w)))))
      (when (plusp (lut:grid-rows w))
        (loop for c below (min (lut:grid-columns w) 20) for character across "Cell grid foundation"
              do (lut:set-grid-cell w c 0 character :bold t :underline t)))))
    (lut:on grid :raw-key (lambda (w e) (declare (ignore w))
      (setf (lut:text status) (format nil "Base key ~s; Ctrl ~s; Cmd ~s; F12 releases."
        (lut:event-base-key e) (lut:event-control-p e) (lut:event-super-p e)))))
    (lut:on grid :raw-text (lambda (w e)
      (when (and (plusp (lut:grid-columns w)) (plusp (lut:grid-rows w)))
        (loop for character across (lut:event-text e)
              when (and (>= (char-code character) 32) (not (<= 127 (char-code character) 159))) do
                (lut:set-grid-cell w column row character) (incf column)
                (when (= column (lut:grid-columns w)) (setf column 0 row (mod (1+ row) (lut:grid-rows w))))))))
    (lut:on capture :activate (lambda (w e) (declare (ignore w e)) (lut:focus root grid) (lut:capture-keys grid)))
    (lut:on copy :activate (lambda (w e) (declare (ignore w e)) (lut:copy-grid-selection grid)))
    panel))


(define-example "Foundations / Keyed tree model"
  "Application-owned tree data uses stable keys. Right/Left expand or collapse; selection tracks keys."
  (let* ((panel (lut:make-widget 'lut:box :height 370))
         (model (lut:make-tree-model
                  '((:id :project :name "Project" :children
                      ((:id :source :name "Source") (:id :tests :name "Tests") (:id :docs :name "Documentation"))))
                  :key (lambda (item) (getf item :id)) :children (lambda (item) (getf item :children))))
         (view (lut:add-child panel (lut:make-widget 'lut:model-tree-view :id :keyed-tree :model model :height 260
                   :row-label-function (lambda (item) (getf item :name)))))
         (toggle (lut:add-child panel (lut:make-widget 'lut:button :id :tree-toggle :text "Expand / collapse Project")))
         (status (lut:add-child panel (lut:make-widget 'lut:label :id :tree-status :text "Selected keys: NIL"))))
    (lut:set-tree-expanded model :project t)
    (lut:on toggle :activate (lambda (w e) (declare (ignore w e))
      (lut:set-tree-expanded model :project (not (lut:tree-expanded-p model :project)))))
    (lut:on view :selection-change (lambda (w keys) (declare (ignore w))
      (setf (lut:text status) (format nil "Selected keys: ~s" keys))))
    panel))
