(in-package #:lut)

(defun request-layout (widget)
 "Schedule root layout after external geometry changes; ordinary setters do this automatically. No native calls. Return WIDGET."
 (unless (or *performing-window-layout* (disposed-p widget))
   (let ((root (root-of widget)))
     (when (typep root 'window) (incf (slot-value root 'layout-revision))))) widget)

(defun invalidate-widget (widget &key descendants)
 "Mark WIDGET's painted region dirty. With DESCENDANTS, invalidate owned children/overlays too. No native calls; use ON-UI while a native loop is active. Return WIDGET."
 (unless (disposed-p widget)
   (request-layout widget)
   (incf (slot-value widget 'render-revision))
   (when descendants
     (dolist (child (children widget)) (invalidate-widget child :descendants t))
     (when (typep widget 'window)
       (dolist (overlay (slot-value widget 'overlays)) (invalidate-widget overlay :descendants t))))) widget)
(defmethod note-widget-change ((widget widget) slot value)
 (declare (ignore value))
 (when (member slot '(x y width height tab-offset scroll-offset text-offset vertical-offset))
   (request-layout widget))
 ;; Measurement/index caches are consequences of painting, not visible mutations.
 ;; Focus is included only in the focused widget's render key, avoiding a root repaint.
 (unless (member slot '(x y width height tab-offset scroll-offset text-offset vertical-offset
                       tab-layout-width tab-layout-extent tab-reveal-p
                       layout-revision render-revision render-identity geometry-cache text-root indexed-string
                       horizontal-extent-cache last-cursor navigation-x layout-width-hint layout-height-hint
                       focused-widget focus-visible-p pressed-widget handlers connections command-links
                       native-operation-generation native-state-settle-frames native-window-mode
                       native-normal-width native-normal-height native-state-pending))
   (invalidate-widget widget :descendants
     (member slot '(style state-style theme style-rules style-source ui-scale parent enabled-p visible-p)))))

(defgeneric widget-render-key (widget)
 (:documentation "Return an immutable EQUAL key for externally owned visual state. Built-ins supply text/model/presentation dependencies. Custom retained views specialize and combine CALL-NEXT-METHOD, or call INVALIDATE-WIDGET when external data changes. Never mutate returned key objects."))
(defmethod widget-render-key ((w widget)) nil)
(defmethod widget-render-key ((w label)) (target-text-index w))
(defmethod widget-render-key ((w entry))
 (list (call-next-method) (cursor w) (anchor w) (text-offset w) (vertical-offset w) (read-only-p w)))
(defmethod widget-render-key ((w styled-text-view))
 (list (call-next-method) (text-presentation-revision w)))
(defmethod widget-render-key ((w list-view)) (scroll-offset w))
(defmethod widget-render-key ((w scroll-view)) (scroll-offset w))
(defmethod widget-render-key ((w vertical-notebook)) (tab-offset w))
(defmethod widget-render-key ((w image))
 (let ((source (source w)))
   (list (and source (ignore-errors (file-write-date source))))))
(defmethod widget-render-key ((w icon-toggle-button))
 (list (call-next-method) (and (icon-source w) (ignore-errors (file-write-date (icon-source w))))))
(defmethod widget-render-key ((w search-control))
 (let ((root (root-of w)))
   (list (call-next-method) (and (typep root 'window) (member (focused-widget root) (children w)) t))))
(defmethod widget-render-key ((w model-list-view))
 (let ((model (view-model w)) (selection (view-selection w)))
   (list (call-next-method) (and model (not (disposed-p model)) (model-revision model))
         (and selection (copy-list (selection-keys selection)))
         (and selection (selection-focus selection)) (row-label-function w))))
(defmethod widget-render-key ((w model-table-view))
 (list (call-next-method) (table-horizontal-offset w) (active-column w)
       (copy-list (table-columns w)) (table-edit-state w)))
(defmethod widget-render-key ((w notebook))
 (list (tab-offset w) (mapcar (lambda (page)
                 (let ((action (page-action w page)))
                   (list (render-identity page) (tab-badge page)
                         (when action (list (notebook-action-label action) (notebook-action-enabled-p action)
                                            (notebook-action-width action) (notebook-action-draw-function action))))))
               (children w))))

(defgeneric window-cache-statistics (window)
 (:documentation "Return a fresh plist of native window cache tile/repaint/memory counters; backend-free windows report zeros. Counters count tile paints, not individual widget draws."))
(defmethod window-cache-statistics ((window window))
 (list :enabled-p (cache-enabled-p window) :tiles 0 :repaints 0 :last-repaints 0 :memory-bytes 0))
