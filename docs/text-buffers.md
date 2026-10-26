# Shared text buffers

A `text-buffer` owns text, content revision and bounded undo/redo history.
`entry` and `text-view` widgets can attach to the same buffer while keeping
independent cursor, selection, styles and viewport state. The buffer is nonvisual;
do not add it as a visual child.

```lisp
(let ((buffer (lut:make-text-buffer :text "Edit either view")))
  (lut:with-ui (lut:paned :height 300)
    (lut:make-widget 'lut:text-view :view-buffer buffer)
    (lut:make-widget 'lut:text-view :view-buffer buffer)))
```

Try `(lut:start (lut-examples:shared-text))` after loading `lut/examples`. The
example also uses shared commands for Undo/Redo and has a per-view read-only
switch. The GTK `textview` demo now uses this model instead of copying strings
between independent entry histories.

## Editing and positions

`text` reads the buffer contents from any attached view. Existing text input,
`replace-selection`, `undo` and `redo` work with shared views. An entry without
`view-buffer` keeps its standalone text and selection behavior, using range history.

`replace-buffer-range` replaces the half-open character range `[start,end)`:

```lisp
(lut:replace-buffer-range buffer 0 0 "Prefix: ")
```

The optional `:origin` is a live view attached to this buffer. Its cursor and
selection collapse after the inserted text. Other views keep independent state:
positions before the replaced range stay put, positions after it shift by the
length difference, and positions inside it collapse to the new end. Insertions
have right affinity: a position exactly at the insertion point moves after the
inserted text. Scroll offsets are not copied between views; normal rendering can
still reveal each view's own remapped caret.

`(setf (text buffer) string)` and `(setf (text view) string)` replace the model
contents, using the smallest single contiguous difference to remap positions.
They notify automatically; do not manually emit another `:change`. The setter
preserves/remaps positions rather than collapsing the origin's selection.
Shared edits validate proposed text against the model and every attached view
before changing content or history. Put custom text invariants in `validate-slot`
and observe edits through `:edit`/`:change`; synchronization updates internal
slots as one operation rather than calling raw text setters on every peer.
Strings are copied into the model. Treat returned strings as immutable: use the
editing APIs rather than changing characters in place.

Indices count Common Lisp characters, not bytes, shaped glyphs or grapheme
clusters. This model does not add shaping, bidi or IME support.

## History and read-only policy

History belongs to the model, so editing either view contributes to the same
undo/redo stacks. Configure `history-limit` and `history-character-limit` on the
buffer; view-local limits apply only when the view is standalone. Both histories
store range records: start position, removed text, inserted text and numeric
selection data. The character budget counts removed plus inserted characters per
stack, not the size of the buffer. Small edits to large files therefore retain
undo normally. New content edits clear redo. A no-op content replacement does
not add history, emit content notifications or increment the revision; replacing a view's identical selected
text can still collapse that selection.

Undo/redo can be called on a buffer or an attached view. Invoking through a view
restores the numeric selection saved with the history record, when one exists,
into that invoking view, even if a different view originated the edit. Other
views remap their current positions. Model-only edits have no saved view
selection. Histories never retain view objects. Limits retain a contiguous newest
prefix; a single edit whose removed+inserted text exceeds the budget is not undoable and
clears older undo history, since skipping it would make older range operations
unsafe. Raise the budget for large paste/replacement operations. A zero history
limit or zero character budget intentionally disables retention silently. A
single oversized record with positive limits emits `:history-overflow`; see below.

`can-undo-p`, `can-redo-p` and `editable-p` are suitable command predicates.
`read-only-p` can be set on one view or on the shared model. Read-only prevents
text input, range/selection replacement, undo/redo and editing keyboard/menu
actions; selection, navigation and copying remain available. A read-only view
still reflects edits made through another writable view.

Read-only is an editing policy, not a security boundary: explicit programmatic
`setf text` remains available for loading/refreshing a read-only display, and is
recorded as a model edit. Temporarily changing the policy is not required for
that operation.

## Revisions and notifications

`buffer-revision` starts at zero and increases once per effective content change,
including undo, redo and programmatic setters. All text and attached view
positions are updated before notifications run:

1. The buffer emits `:edit` with a `buffer-edit` record.
2. The buffer emits `:change` with its resulting text.
3. Each still-attached live view emits `:change` once, in attachment order.

The edit record exposes `edit-start`, `edit-old-end`, `edit-new-end`,
`edit-revision` and optional `edit-origin`. It describes a contiguous character
replacement and can drive application analysis/cache invalidation without
embedding a parser in LUT. Retaining a record with an origin intentionally keeps
that view alive; the buffer itself does not retain these notification records.

Callbacks execute on the GUI/controller thread. Reentrant edits to the same
buffer during its notifications are rejected before changing history or text;
queue follow-up edits with `on-ui`. Callback errors propagate after the edit is
committed; all view state stays synchronized, but subsequent callbacks are not
guaranteed to run after an error. Changes are not rolled back.

## Attachment and lifetime

Set `view-buffer` to another live buffer to rebind, or NIL to detach. Attaching
uses the model's text (including when `:text` is also supplied at construction),
clamps cursor/selection, clears stale local history and resets viewport offsets.
Detaching preserves the current text as a standalone snapshot and clears local
history. The view's own read-only flag remains unchanged. Content changes caused
by explicit rebinding emit a view `:change`; model contents are unchanged.

A buffer retains its attached views. Dispose views, or detach them explicitly,
when they are no longer needed; merely removing a view from a container preserves
its model attachment for reuse. Disposing a view detaches it without changing
the model or other views. Disposing a window disposes its views but does not
destroy a model that might be shared with another window.

Disposing a buffer detaches all surviving views into read-only snapshots before
clearing the model's text/history and observers. Never attach a disposed buffer.
Owned `on` connections work normally for buffer notifications. Collection tests
keep a buffer and its history alive while verifying that disposed views and their
owned observer closures become unreachable.


## Indexed storage and viewport geometry

Shared buffers use an immutable balanced tree with character and newline counts
in each branch and owned chunks of at most 1,024 characters. A range edit copies
boundary chunks and tree paths, preserving untouched chunks. Undo/redo still
stores changed ranges. `text-length`, `text-range`, `text-line-count`,
`text-line-range` and `text-position-line` query this index without constructing
a full string. They also accept standalone labels/views and strings. A standalone
view caches an index until its text changes; passing a raw string constructs a
temporary index for line queries. Treat source strings as immutable.

Lines are zero based. `text-line-range` returns two values, start and exclusive
end, excluding the newline. Empty text has one empty line, and a trailing newline
adds an empty final line. A position on a newline belongs to the preceding line;
EOF is a valid insertion position. Invalid indices signal an error.

```lisp
(multiple-value-bind (start end) (lut:text-line-range buffer 1000)
  (lut:text-range buffer start end))
(lut:text-position-line buffer (lut:text-length buffer))
```

`text-position-rectangle` takes an entry/text view and display character position
and returns four values: root X, Y, styled caret width and line height.
`text-point-position` takes the view and root X/Y and returns the nearest insertion
position, using character midpoints and clamping to line bounds. Both include
padding and the view's independent horizontal/vertical pixel offsets. Geometry
is for unwrapped logical lines with additive character advances. It does not add
shaping, bidi, grapheme navigation or tab stops. `display-text` overrides such as
password masking should preserve character indices.

`map-visible-text-lines` calls a function with `(line start end x y)` for each
logical line intersecting the vertical content viewport, including partially
visible lines. It returns the number visited and does not copy the line text.
Bounds index `display-text`; use `text-range` for ordinary unformatted views.
Do not edit, rebind or dispose the view during iteration.

```lisp
(lut:map-visible-text-lines view
  (lambda (line start end x y)
    (declare (ignore line x y))
    (format t "Visible range: ~d..~d~%" start end)))
```

Drawing and pointer hit testing share these measurements. Keyboard line
navigation, caret reveal and wheel extents use the same line index. Drawing
visits visible rows and horizontal fragments rather than allocating every line
or passing an entire long line to the backend. Font glyph discovery likewise
uses bounded visible prefixes, adding all glyphs from a measured run before
measuring its individual advances. Each run shares one atlas and one discovery
walk even outside painting; drawn fragments include their own glyphs. Plain
labels preserve their existing overflow drawing of all logical lines; viewport
clipping applies to entries/text views.
Per-view measurement caches retain at most eight entries and invalidate when
the source tree, display text, font metrics or effective font styles change.
Allocation, padding, line height and scrolling are applied when queried.
Disposal and rebinding clear the caches. Call `invalidate-text-geometry` after
changing external state used by an application-defined measurement method.

Line lookup costs logarithmic tree work. Range copies cost logarithmic lookup
plus the requested characters. A small range edit costs logarithmic tree work
plus inserted/removed text and bounded boundary chunks, in addition to view
remapping and history/observer work. Horizontal measurement grows incrementally
in runs of at most 256 characters and caches advances. Repeated queries reuse
those advances; the first query far along an unmeasured line must measure its
prefix. Retained geometry therefore depends on the measured prefixes of cached
lines, not only viewport width. There is no constant-time random horizontal
access or wrapping index.

The compatibility `text` getter lazily materializes and caches a full string.
A full-text setter, custom `validate-slot` text methods and `:change` listeners
still need full strings and can incur O(n) work. Existing validation and
notification ordering remain intact. Prefer range queries and `:edit` observers
for large-buffer applications. Attaching/detaching views preserves the existing
snapshot/validation contract and can also materialize text. Standalone editing
continues to use flat strings, with range records for undo/redo. Its edit storage
still copies the current string; the migration removes full-text history copies.

Try `(lut:start (lut-examples:indexed-text))` after loading `lut/examples`: a
50,000-line shared model with EOF navigation, append operations and indexed
status reporting. Automated checks cover tree balance/sharing, Unicode offsets,
EOF edits, viewport geometry and cache invalidation. Native/platform verification
limits are recorded in the foundation roadmap.


## Standalone history and budget feedback

Standalone entries/text views own the same range-record format as shared models.
Their character budget now counts removed plus inserted text, rather than full
snapshots. Full-text setters find the smallest contiguous difference. A new
content edit clears redo; an identical setter preserves it. `replace-selection`
with identical selected text still collapses the selection, as before.
Programmatic setters still clamp the existing cursor/anchor and do not emit
`:change`; text input/selection replacement and undo/redo emit it as before.

Undo restores the pre-edit cursor and anchor, including selection direction.
Redo restores the selection captured when undo was invoked, even if navigation
changed it after the edit. Repeated undo/redo captures the invoking selection for
the inverse operation, preserving the original snapshot contract. Rejected text
validation leaves content, selection and both history stacks unchanged. Disposing
or rebinding a view clears its standalone history.

Both standalone and shared histories retain a contiguous newest prefix. Older
records evicted by count/total payload limits are silent. If a single record is
too large for a positive character budget and record count is also positive,
the destination stack becomes empty and the history owner emits
`:history-overflow` with a fresh plist:

```lisp
(:operation :edit :stack :undo :characters 13 :limit 8)
```

`:operation` is `:edit`, `:undo` or `:redo`; `:stack` is the destination `:undo`
or `:redo` stack. `:characters` counts removed plus inserted characters and
`:limit` is the budget used for that operation. The edit still succeeds. After
lowering limits, undo/redo may restore text while its inverse record cannot fit;
feedback then identifies that inverse's destination stack. Zero limits mean
intentional disabling and emit no overflow feedback. No-op or rejected content
edits emit no overflow feedback either.

Observe the standalone entry, or the shared buffer (not every attached view):

```lisp
(lut:on owner :history-overflow
  (lambda (owner payload)
    (declare (ignore owner))
    (format t "History record requires ~d characters; budget is ~d.~%"
            (getf payload :characters) (getf payload :limit))))
```

Notifications observe committed text, selection and histories. For standalone
edits feedback runs after the setter commits, before `replace-selection` emits
`:change`; for standalone undo/redo it also precedes `:change`. Shared buffers
emit it after their existing `:edit`/`:change` sequence, under the same reentrant
edit guard. A notification error propagates without rolling back the committed
operation, and can prevent later notifications. Feedback describes the budget
at commit time, even if a prior observer changes the configured limits.
Applications decide how to present it; LUT emits no dialog or global warning.

Try `(lut:start (lut-examples:standalone-history))` for small edits, undo/redo,
and a deliberately oversized insertion with status feedback.


Word/line navigation, repeated-click selection, caret reveal and captured
selection autoscroll are described in [text selection and navigation](text-selection.md).
