(in-package #:lut)
;; Shared and standalone histories own only changed strings and numeric selections.
(defun text-difference (old new)
 "Find the minimal single contiguous replacement from OLD to NEW."
 (let* ((a (length old)) (b (length new)) (start 0) (suffix 0))
   (loop while (and (< start (min a b)) (char= (char old start) (char new start))) do (incf start))
   (loop while (and (< suffix (- (min a b) start))
                    (char= (char old (- a suffix 1)) (char new (- b suffix 1)))) do (incf suffix))
   (values start (- a suffix) (subseq new start (- b suffix)))))
(defstruct (buffer-history-entry (:constructor %make-buffer-history-entry))
 ;; Only changed substrings and numeric selections; never full-buffer snapshots
 ;; or references to views. Strings are immutable once stored in the record.
 start removed inserted before-cursor before-anchor after-cursor after-anchor)
(defun buffer-history-characters (entry)
 (+ (length (buffer-history-entry-removed entry)) (length (buffer-history-entry-inserted entry))))
(defun bounded-buffer-history (buffer entries)
 (loop for entry in entries for count from 1
       for characters = (buffer-history-characters entry) then (+ characters (buffer-history-characters entry))
       while (and (<= count (history-limit buffer))
                  (plusp (history-character-limit buffer))
                  (or (<= characters (history-character-limit buffer))
                      (and (= count 1) (history-retain-newest-p buffer))))
       collect entry))
(defvar *record-history* t)
(defvar *standalone-selection-after* nil)
(defun history-overflow-payload (owner record operation stack)
 (when (and record (plusp (history-limit owner)) (plusp (history-character-limit owner))
            (> (buffer-history-characters record) (history-character-limit owner)))
   (list :operation operation :stack stack :characters (buffer-history-characters record)
         :limit (history-character-limit owner))))
(defun emit-history-overflow (owner payload)
 (when payload
   (let ((*standalone-selection-after* nil)) (emit owner :history-overflow payload))))
(defun notify-history-overflow (owner record operation stack)
 (emit-history-overflow owner (history-overflow-payload owner record operation stack)))
(defun make-standalone-history-entry (entry new-text)
 (multiple-value-bind (start end inserted) (text-difference (text entry) new-text)
   (%make-buffer-history-entry :start start :removed (subseq (text entry) start end) :inserted inserted
     :before-cursor (cursor entry) :before-anchor (slot-value entry 'anchor))))
(defun restore-standalone-history (entry direction)
 (let* ((undo-p (eq direction :undo))
        (from (if undo-p 'undo-history 'redo-history))
        (to (if undo-p 'redo-history 'undo-history))
        (record (first (slot-value entry from))))
   (when record
     (let* ((inverse (copy-buffer-history-entry record))
            (start (buffer-history-entry-start record))
            (removed (if undo-p (buffer-history-entry-inserted record) (buffer-history-entry-removed record)))
            (inserted (if undo-p (buffer-history-entry-removed record) (buffer-history-entry-inserted record)))
            (selection
              (if undo-p (list (buffer-history-entry-before-cursor record) (buffer-history-entry-before-anchor record))
                  (list (buffer-history-entry-after-cursor record) (buffer-history-entry-after-anchor record)))))
       ;; Capture the selection at invocation, just as snapshot undo/redo did.
       (if undo-p
           (setf (buffer-history-entry-after-cursor inverse) (cursor entry)
                 (buffer-history-entry-after-anchor inverse) (slot-value entry 'anchor))
           (setf (buffer-history-entry-before-cursor inverse) (cursor entry)
                 (buffer-history-entry-before-anchor inverse) (slot-value entry 'anchor)))
       ;; SETF validates before either stack moves. Errors preserve the record.
       (let ((*record-history* nil) (*standalone-selection-after* (cons entry selection)))
         (setf (text entry) (concatenate 'string (subseq (text entry) 0 start) inserted
                                        (subseq (text entry) (+ start (length removed))))))
       (setf (slot-value entry to) (bounded-buffer-history entry (cons inverse (slot-value entry to)))
             (slot-value entry from) (rest (slot-value entry from)))
       (notify-history-overflow entry inverse direction (if undo-p :redo :undo))
       (emit entry :change (text entry)) t))))
