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
`view-buffer` keeps its existing standalone editing/history behavior.

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
buffer; view-local limits apply only when the view is standalone. Shared history
stores range records: start position, removed text, inserted text and numeric
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
limit intentionally disables retention; no warning is emitted for these limits.

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

This model uses flat strings with bounded range-based history. Small edits no
longer copy the full buffer into history, but editing still rebuilds the flat
string. Indexed storage, large-file viewport geometry, styled spans, word
navigation and richer document presentation remain separate items in the [foundation roadmap](foundation-roadmap.md).
