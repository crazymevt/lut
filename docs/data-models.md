# Data models, selection, and cells

Phase 3 provides opt-in `model-list-view`, `model-tree-view`, and
`model-table-view` classes. Existing `list-view`/`tree-view`/`table-view` APIs
retain their `items`/`nodes`/`rows` behavior. Load `lut/examples` and run
`(lut:start (lut-examples:data-models))` for the combined showcase.

## Model contract and virtualization

A `data-model` supplies `model-count`, `model-item`, `model-key`, and
`model-index`. Indices are zero-based integers; `model-index` returns NIL for an
invisible or missing key. Keys are non-NIL, immutable, unique under EQUAL, and
stable across edits and reorderings. Application items retain identity; LUT does
not copy or own them. Do not mutate a key while it is in a model.

```lisp
(defparameter *rows*
  (lut:make-function-model
    :count 1000000
    :item (lambda (i) (format nil "Row ~d" i))
    :index (lambda (key)
             (when (and (integerp key) (<= 0 key) (< key 1000000)) key))))
(lut:make-widget 'lut:model-list-view :model *rows* :height 300)
```

`make-function-model` accepts a count integer or zero-argument count function,
an index-to-item function, an optional index-to-key function (default IDENTITY),
and an optional key-to-index function. Without the latter, lookup scans keys.
Use index keys only for data whose identity really is its index. Notify the model
after externally changing the dataset. A custom `data-model` subclass can
implement the same generics, and `model-contains-key-p` for hidden-key validity.

`make-vector-model sequence :key item-to-key` copies the sequence, validates
unique keys, and builds an identity index. `replace-model-items` validates a
replacement before committing it. `notify-model-change` publishes external
mutations, increments `model-revision`, and emits `:model-change` with the new
revision. Do not mutate/re-notify the same model from its notification handlers;
queue follow-up work. Changes are committed before observers run; errors propagate
and can prevent later observers. The caller must publish every external change.
Publish item-value changes on the underlying source model so projections can
refresh. Structural tree changes require `replace-tree-roots` to rebuild the
tree index; `notify-model-change` alone does not rebuild structural metadata.

Views use fixed `:row-height` and vertical scrolling. `visible-model-range`
returns a half-open pair including partial rows; `map-visible-model-rows` calls
`(index key item x y width height)` only for that range. A zero-height viewport
visits nothing. `reveal-model-index` scrolls without selecting. No row widgets,
full-dataset row strings, or compatibility `items` list are built. Initial layout
and drawing cost O(visible rows), apart from application callbacks. `:row-label-function`
maps an item to a string on demand. Horizontal flow and variable row heights
remain application layout, as in the older GTK demonstrations.

## Independent selection

`make-selection-model model :mode :single` also accepts `:none` and `:multiple`.
`select-model-index` selects a visible row; `:toggle t` adds/removes that row,
`:extend t` forms a range from the anchor in current visible order, and both
flags add that range. Single selection ignores multi-selection modifiers.
`clear-model-selection` clears keys, focus, and anchor. `selected-keys` returns a
fresh list; key objects keep identity. `selection-focus`, `selection-anchor`, and
`selection-contains-p` query the model. Changes emit `:selection-change` with
copied selected keys. Focus/anchor changes also count as changes.

`handle-selection-event` handles pointer `:down` with a supplied `:index`, or
Up/Down/Home/End without depending on any widget. Shift extends, Ctrl/Cmd toggles.
Views use this same contract, reveal the destination, and relay
`:selection-change`. Several views may share a selection via `:selection`.
Their legacy `value` mirrors the visible focused index; set selection through
the selection API rather than assigning `value`.

Selection stores keys rather than positions. Sorting/reordering retains keys;
deleted keys are pruned. Filtering or collapsing a tree retains hidden keys,
focus, and anchor until the underlying item is deleted. Extending from a hidden
anchor starts a new range. Materializing a range costs O(range length), and
reconciliation costs O(selected keys × model lookup cost).

## Sorting, filtering, and trees

`make-projection-model source :predicate predicate :lessp comparator` builds a
visible source-index vector; predicates/comparators receive application items.
`set-model-query` replaces either callback; omitted callbacks remain, NIL clears
one. Sorting is stable for ties, relative to current source order. A projection
listens for source changes and recomputes its indices, without copying items or
changing their keys. Filtering is O(source rows); sorting is O(n log n), with
O(n) index storage. It deliberately does not claim lazy sorting of millions of
rows. Callbacks must be pure and must not mutate their model.

Explicit query failures leave the old query intact. If a source update makes a
projection callback fail, the projection is disposed so stale indices cannot
address different rows; the error still propagates. Dispose a projection without
disposing its source. Disposing a source disposes its projections/selections.

`make-tree-model roots :key key-function :children children-function` indexes a
finite application tree, checks unique keys across all descendants (including
collapsed nodes), and starts collapsed. Duplicate/cyclic keys signal errors.
`set-tree-expanded model key boolean` rebuilds visible rows;
`tree-expanded-p`, `model-depth`, and `model-branch-p` query expansion and row
geometry. `replace-tree-roots` validates before committing and preserves surviving
keys' expansion. Rebuilding visits O(all nodes), storing O(all nodes) key metadata
and O(visible nodes) row metadata. It creates no child widgets or display strings.
`model-tree-view` uses Left/Right and disclosure-area clicks to collapse/expand.

## Table cells and editing

`model-table-view` accepts a nonempty `:table-columns` list of `make-data-column`
objects. Each column has a unique non-NIL `:id`, `:title`, `:getter (item)`, and
`:formatter (value)` (default PRINC-TO-STRING). An optional
`:cell-factory (item value)` returns a string or a plist with `:text` and optional
`:foreground`/`:background`. `cell-presentation view row column` returns a copied
description. Factories run only for visible cells; columns are equal width and
clipped individually beneath a fixed header. Column definitions are shared
immutable application objects. Column accessors expose title and ID.

Click selects a row and active column. Up/Down/Home/End use the common selection
contract; Left/Right moves `active-column`. Enter/F2 calls `begin-cell-edit` for
the selected row/column. A column with no `:setter` is read-only. An editable
column's `:setter (original-item text)` validates/converts and updates application
data. Database access and persistence belong to the application.

`begin-cell-edit` creates one entry, selects its text, focuses it, and emits
`:cell-edit-start` with `:key`, `:column`, and `:old-value`. An optional
`:editor-factory (view key column value)` must return a live unparented `entry`;
it receives the same Enter/Escape handling as the default editor. `cell-editor`
returns the active entry or NIL. Enter/`commit-cell-edit` calls the setter, closes
the entry, notifies the underlying source (re-sorting/filtering projections), and
emits `:cell-edit-commit` with `:key`, `:column`, `:old-value`, and `:text`. Setter
errors leave the editor open; setters must validate before mutating if rollback is
needed. Observer errors do not roll back application data.

Escape/`cancel-cell-edit` closes without invoking the setter and emits
`:cell-edit-cancel` with `:key`, `:column`, and `:reason`. Model changes, row clicks,
and scrolling cancel an active edit; layout cancels an editor whose full row no
longer fits. Closing restores table focus when focus was in the editor. Sorting
and filtering are explicit model operations, not implicit header-click policy.

## Lifetime and verification

Model/selection notifications use owned connections. A view owns its default
selection and its active editor; it does not own an explicitly supplied selection,
model, columns, or application items. Dispose those when the application no longer
needs them. Models are standalone event sources, not children to add to a layout.
Views bind their model and selection at construction; create a new view to rebind.
Disposal clears callbacks, indices, items, sources, and editor references.
`:model-disposing` visits all active dependents even if an observer signals,
then completes cleanup and propagates the first observer error. Recursive
disposal is idempotent. The
showcase owns and disposes its models alongside its root window.

Portable tests cover bounded row requests, selection modifiers, stable identity,
hidden/deleted selections, tree/query validation, commit/cancel, and ownership.
Native light/dark tests cover rendering and input; GC tests retain disposed model
and view objects while checking payload release. These checks run on macOS;
Linux/Windows remain unverified. Keyboard accessibility and platform APIs remain
the later roadmap phase.
