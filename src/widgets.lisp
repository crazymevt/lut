(in-package #:lut)
(defwidget toggle-button (check-button) "Persistent on/off button; VALUE is boolean." ())
(defwidget switch (toggle-button) "Boolean switch with the same keyboard semantics as a toggle." ())
(defwidget radio-button (check-button) "Exclusive selection in GROUP. Activation deselects peers."
 ((group nil list "Other radio-button instances in this exclusive group.")))
(defwidget spin-button (slider) "Numeric field incremented by arrows, wheel or its +/- actions. Pointer actions commit on release within the same icon."
 ((spin-hover nil (member nil :minus :plus) "Internal hovered icon.")
  (spin-press nil (member nil :minus :plus) "Internal pressed icon.")))
(defwidget dropdown (list-view) "Closed selection opens a reusable popup list."
 ((expanded-p nil boolean "Whether the option popup is open.")))
(defclass selection-list (list-view) ()
 (:documentation "Internal popup list: arrows preview, Enter commits, Escape cancels."))
(defwidget combo-box (entry) "Editable selection with suggested string ITEMS."
 ((items nil list "Available completion strings.")
  (expanded-p nil boolean "Whether the option popup is open.")))
(defwidget stack (widget) "Only child at selected page VALUE participates in layout and input."
 ((value 0 (integer 0 *) "Visible zero-based page index.")))
(defwidget vertical-notebook (stack) "Left-hand vertical tab strip and one selected page. Tabs scroll vertically; optional local reordering is disabled by default."
 ((items nil list "Tab labels corresponding to child pages.")
  (tab-strip-width 144 (real 0 *) "Preferred width of the left tab strip in logical pixels.")
  (tab-offset 0 (real 0 *) "Vertical strip scroll offset, clamped during layout.")
  (reorderable-p nil boolean "Allow dragging tabs to reorder pages within this widget.")
  (hovered-row nil (or null (integer 0 *)) "Internal hovered tab index; independent of selection.")
  (vertical-tab-press nil list "Internal pointer press index, Y, and movement flag.")))
(defwidget notebook (stack) "Tabbed stack with optional page reordering and grouped tab transfer."
 ((action-press nil list "Internal pressed page/action pair.")
  (action-tooltip-active nil boolean "Internal action tooltip state.")
  (action-tooltip-original nil (or null string) "Internal previous notebook tooltip.")
  (hovered-row nil (or null (integer 0 *)) "Hovered tab index, separate from selected page.")
  (closable-p nil boolean "Show tab close affordances; requests may be vetoed.")
  (tab-offset 0 (real 0 *) "Horizontal tab-strip scroll offset in pixels; clamped during layout.")
  (tab-reveal-p t boolean "Internal request to reveal the selected tab.")
  (tab-layout-extent -1 real "Internal previous strip extent.")
  (tab-layout-width -1 real "Internal previous widget width.")
  (reorderable-p nil boolean "Enable pointer tab reordering; disabled by default.")
  (tab-group nil (or null symbol string) "Equal non-NIL groups permit transfers between reorderable notebooks in one window.")
  (items nil list "Tab labels corresponding to children.")))
(defwidget grid (widget) "Uniform grid layout with configurable COLUMNS and SPACING."
 ((columns 2 (integer 1 *) "Positive number of equal-width columns.")
  (spacing 8 (real 0 *) "Gap between rows and columns.")))
(defwidget paned (widget) "Two resizable panes separated by a draggable splitter."
 ((orientation :horizontal (member :horizontal :vertical) "Splitter direction.")
  (value 0.5 (real 0 1) "Fraction of available space assigned to the first pane.")))
(defwidget header-bar (box) "Horizontal title/action container."
 ((orientation :horizontal (member :horizontal :vertical) "Default horizontal orientation.")))
(defwidget menu-bar (header-bar) "Horizontal container of menu buttons." ())
(defwidget menu-separator (widget) "Noninteractive separator between menu actions; :SEPARATOR entries create these in drawn menus."
 ((height 8 (real 0 *) "Logical height reserved for the separator rule.")))
(defwidget popover (dialog) "Pointer-positioned popup dismissed by an outside click."
 ((popup-owner nil (or null widget) "Control owning this popup, when applicable.")
  (position-mode :absolute (member :center :absolute) "Popup position is in root pixels.")
  (draggable-p nil boolean "Popups do not drag by default.")))
(defwidget tooltip (popover) "Noninteractive tooltip surface." ())
(defwidget expander (box) "Header toggles visibility of its content."
 ((text "Details" string "Header caption.")
  (value nil boolean "Whether content is expanded.")))
(defwidget tree-view (list-view) "Expandable tree. NODES are (:TEXT string :CHILDREN nodes :OPEN boolean)."
 ((nodes nil list "Nested node property lists; expansion is stored in each node.")))
(defwidget table-view (list-view) "Rows of column values, selected as a list."
 ((columns nil list "Column header strings.")
  (rows nil list "Rows, each a list of printable cell values.")))
(defwidget column-view (table-view) "Table with user-supplied column headings and rows." ())
(defwidget image (widget) "Image loaded from a file, preserving aspect ratio."
 ((max-image-scale nil (or null (real (0) *)) "Optional upper scale bound; 1 prevents enlarging small images.")
  (source nil (or null string pathname) "Image file pathname; NIL draws nothing.")))
(defwidget file-chooser (dialog) "Portable file chooser with directory navigation and explicit filename."
 ((directory (user-homedir-pathname) pathname "Current directory.")
  (value nil (or null pathname) "Chosen file pathname.")))
(defwidget color-chooser (dialog) "RGBA color chooser built from numeric channel controls."
 ((value '(0 0 0 255) list "Four integer channels, each 0..255.")))
(defwidget font-chooser (dialog) "Portable font chooser accepting an explicit font file and pixel size."
 ((value nil (or null string pathname) "Selected TrueType/OpenType font file.")
  (font-size 18 (integer 1 *) "Selected positive pixel size.")))
(defgeneric active-children (widget) (:documentation "Children included in layout, drawing and input."))
(defmethod active-children ((w widget)) (remove-if-not (lambda (c) (and (visible-p c) (not (disposed-p c)))) (children w)))
(defmethod active-children ((w stack))
 (let ((c (nth (value w) (children w)))) (when (and c (visible-p c)) (list c))))
(defmethod active-children ((w expander)) (when (value w) (call-next-method)))
(defmethod layout :after ((w grid) x y width height)
 (let* ((cs (active-children w)) (n (length cs)) (pad (style-value w :padding 8))
        (rows (max 1 (ceiling n (columns w))))
        (cw (max 0 (/ (- width (* 2 pad) (* (1- (columns w)) (spacing w))) (columns w))))
        (ch (max 0 (/ (- height (* 2 pad) (* (1- rows) (spacing w))) rows))))
   (loop for c in cs for i from 0 do
     (layout c (+ x pad (* (mod i (columns w)) (+ cw (spacing w))))
               (+ y pad (* (floor i (columns w)) (+ ch (spacing w)))) cw ch))))
(defmethod layout :after ((w stack) x y width height)
 (let ((top (if (typep w 'notebook) (style-value w :title-height 28) 0)))
   (dolist (c (active-children w)) (layout c x (+ y top) width (max 0 (- height top))))))
(defmethod layout :after ((w paned) x y width height)
 (let* ((horizontal (eq (orientation w) :horizontal)) (gap (style-value w :padding 8))
        (size (max 0 (- (if horizontal width height) gap))) (first-size (* size (value w))))
   (when (first (children w))
     (layout (first (children w)) x y (if horizontal first-size width) (if horizontal height first-size)))
   (when (second (children w))
     (layout (second (children w)) (if horizontal (+ x first-size gap) x)
             (if horizontal y (+ y first-size gap))
             (if horizontal (- size first-size) width) (if horizontal height (- size first-size))))))
(defun tree-rows (tree)
 "Return flattened visible (node depth) pairs, respecting each node's :OPEN value."
 (labels ((visit (nodes depth)
            (loop for n in nodes append (cons (list n depth)
                  (when (getf n :open) (visit (getf n :children) (1+ depth)))))))
   (visit (nodes tree) 0)))
(defun refresh-items (w)
 "Synchronize tree/table display rows from their models; return W."
 (cond ((typep w 'tree-view)
        (setf (items w) (loop for (node depth) in (tree-rows w)
                        collect (format nil "~v@T~a ~a" (* 2 depth)
                          (if (getf node :children) (if (getf node :open) "-" "+") " ") (getf node :text "")))))
       ((typep w 'table-view)
        (setf (items w) (loop for row in (rows w) collect (format nil "~{~a~^ | ~}" row))))) w)
(defun select-page (stack index)
 "Select a valid child INDEX and emit :CHANGE with that index."
 (unless (< -1 index (length (children stack))) (error "Page index out of range."))
 (setf (value stack) index) (emit stack :change index) index)
(defun group-radios (&rest radios)
 "Put RADIOS in one exclusive group and return the list."
 (dolist (r radios) (setf (group r) radios)) radios)
(defmethod validate-slot ((w color-chooser) slot v)
 (when (eq slot 'value)
   (unless (and (= 4 (length v)) (every (lambda (c) (typep c '(integer 0 255))) v))
     (error "Color requires four byte channels."))) v)

(defmethod initialize-instance :after ((w tree-view) &key)
 (setf (nodes w) (copy-tree (nodes w))) (refresh-items w))
(defmethod initialize-instance :after ((w table-view) &key) (refresh-items w))
(defmethod layout :after ((w expander) x y width height)
 (declare (ignore x y width height))
 (dolist (c (active-children w)) (layout c (x c) (+ (y c) (line-height w)) (width c) (height c))))
(defmethod layout :after ((w dialog) x y width height)
 (declare (ignore x y width height))
 (unless (or (native-p w) (typep w 'popover) (typep w 'context-menu))
   (dolist (c (active-children w))
     (layout c (x c) (+ (y c) (style-value w :title-height)) (width c) (height c)))))

(defun sort-table (table column &key descending)
 "Stable-sort TABLE rows by the printed cell in zero-based COLUMN; emit :CHANGE with current selection."
 (unless (< -1 column (length (columns table))) (error "Column out of range."))
 (setf (rows table) (stable-sort (copy-list (rows table)) (if descending #'string-greaterp #'string-lessp)
                                :key (lambda (row) (princ-to-string (nth column row)))))
 (refresh-items table) (emit table :change (value table)) table)

(defmethod surface-closed ((d popover))
 (let ((owner (popup-owner d)))
   (when (typep owner '(or dropdown combo-box))
     (setf (expanded-p owner) nil)
     (let ((root (root-of owner)))
       (when (and (typep root 'window) (not (disposed-p owner))
                  (loop for node = owner then (parent node) while node
                        always (and (visible-p node) (enabled-p node)))
                  (loop for node = owner then (parent node) while node
                        thereis (eq node (input-root root))))
         (focus root owner))))))

(defclass search-submit-button (button) ())
(defclass search-clear-button (button) ())
(defclass calendar-day-button (toggle-button) ())
(defclass calendar-nav-button (button) ())

(defwidget date-picker (button)
 "Gregorian date picker with segmented editing and a popup calendar. User changes emit :CHANGE with a copied (year month day) list; programmatic assignment is silent."
 ((width 300 (real 0 *) "Preferred width of the segmented picker.")
  (calendar-date (multiple-value-bind (second minute hour day month year) (get-decoded-time)
                   (declare (ignore second minute hour)) (list year month day))
                 list "Gregorian (year month day), year 1..9999; defaults to the current local date. Copied on read/write.")
  (picker-field 0 (integer 0 3) "Selected field: year/month/day or hour/minute/second; field 3 is AM/PM in 12-hour time.")
  (picker-popup nil (or null popover) "Internal owned calendar popup.")
  (picker-press nil (or null keyword integer) "Internal pressed picker region.")
  (picker-hover nil (or null keyword integer) "Internal hovered picker region.")
  (picker-digits "" string "Internal pending digit sequence.")))
(defwidget time-picker (date-picker)
 "Local wall-clock picker with 12/24-hour display options; no timezone conversion. User changes emit :CHANGE with copied (hour minute second)."
 ((clock-time '(0 0 0) list "24-hour (hour minute second); copied on read/write.")
  (time-format :24-hour (member :12-hour :24-hour) "Display/edit in 12-hour AM/PM or 24-hour format; stored CLOCK-TIME is always 24-hour.")))

(defwidget search-control (entry)
 "Single-line search entry. Editing emits :CHANGE; Enter/search emits :SEARCH with TEXT; Escape/clear emits :CANCEL after clearing editable text. SETF TEXT is silent."
 ((search-hint "Search" string "Hint shown while empty; never part of TEXT.")
  (search-submit nil (or null button) "Internal owned submit button.")
  (search-clear nil (or null button) "Internal owned clear button.")))
(defwidget activity-indicator (widget)
 "Noninteractive indeterminate spinner. Running indicators animate during normal rendering; stopped indicators draw nothing."
 ((activity-running-p t boolean "Whether the spinner is visible and animating.")
  (width 24 (real 0 *) "Preferred spinner width; artwork stays compact under stretching.")
  (height 24 (real 0 *) "Preferred spinner height.")))
(defwidget icon-toggle-button (toggle-button)
 "Boolean image button with standard toggle input and :CHANGE/:ACTIVATE events. TEXT is a centered fallback when no image is supplied; TOOLTIP-TEXT can describe the action."
 ((icon-source nil (or null string pathname) "Image pathname, rendered aspect-preserving within the button padding; NIL uses TEXT.")))

(defmethod layout :after ((tip tooltip) x y width height)
 ;; Tooltip content has one inset. Generic box/label padding would double it
 ;; and the inherited line-height would leave single-line text top-heavy.
 (let ((horizontal (style-value tip :tooltip-padding-x 8))
       (vertical (style-value tip :tooltip-padding-y 5)))
   (dolist (child (children tip))
     (layout child (+ x horizontal) (+ y vertical)
             (max 0 (- width (* 2 horizontal))) (max 0 (- height (* 2 vertical)))))))
