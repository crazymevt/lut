# Cell grids and focused key capture

`cell-grid` is a presentation widget for console-style applications. It contains
no terminal emulator, escape parser, PTY, shell, session manager or scrollback.
Applications update cells on the UI thread. `lut-examples:cell-grid-demo` shows a
simulated terminal grid without starting a process.

## Geometry and cells

After layout, `grid-columns` and `grid-rows` report the complete cells fitting
inside the allocated widget. The grid starts empty before its first layout.
`grid-cell-metrics` returns logical width and height (defaults 10 and 20).
`set-grid-cell-metrics` changes both atomically after validating positive values,
then resizes storage. Layout emits `:grid-resize` with `(columns rows)` only when
the dimensions change. Overlapping cells survive resize; new cells are blank and
selection clears. A zero-sized grid is supported. Resize callbacks run after the
new storage is installed; they may fill cells but should not recursively resize.

```lisp
(lut:layout grid 0 0 800 480)
(lut:set-grid-cell grid 0 0 #\A
  :foreground '(240 220 120 255) :background '(20 23 30 255)
  :bold t :underline t)
```

`set-grid-cell` takes zero-based column and row, a non-control character and
optional RGBA byte lists. `grid-cell` returns a copied plist, or NIL for an
untouched blank cell. Mutating supplied colours or returned records does not
change the grid. Invalid coordinates signal errors before mutation.

`grid-point-cell` maps root logical coordinates to column and row. Outside the
complete cell rectangle it returns NIL,NIL; `:clamp t` clamps to the nearest cell.
Empty grids always return NIL,NIL. UI scale does not change logical cell metrics.

The raylib backend redraws the whole grid, clipping glyphs to their individual
cells and the ancestor clip. Bold is a second draw offset by one logical unit;
underline is a one-unit rule. Choose metrics appropriate for the font and size.
One cell holds one Lisp character: wide-character spans, combining clusters,
shaping, bidi and terminal cursor semantics are not provided. Storage and redraw
cost are proportional to allocated rows times columns. There is no damage cache.

## Selection and copying

Pointer drag selects inclusive cells in row-major order. Alt-drag selects a
rectangle. Dragging outside clamps to the grid; this does not scroll a separate
application scrollback model. `select-grid-cells` takes two column,row endpoints
and optional `:rectangular t`, accepting reversed endpoints. `clear-grid-selection`
clears selection. `grid-selected-text` joins selected rows with newlines,
preserving spaces without adding a final newline. `copy-grid-selection` writes
that string through `clipboard-text`. Ctrl/Cmd+C copies when keys are not captured;
captured input belongs to the application's handler instead.

## Key capture

```lisp
(lut:on grid :raw-key
  (lambda (widget event)
    (declare (ignore widget))
    ;; EVENT is normalized; use EVENT-BASE-KEY and independent modifier fields.
    (format t "Key ~s control=~s~%"
      (lut:event-base-key event) (lut:event-control-p event))))
(lut:on grid :raw-text
  (lambda (widget event)
    (declare (ignore widget))
    (format t "Text ~s~%" (lut:event-text event))))
(lut:focus root grid)
(lut:capture-keys grid :release-key :f12
  :passthrough '((:key :s :super t)))
```

Capture is opt-in on any focusable widget. It emits `:raw-key` and `:raw-text`
with normalized event objects, before window `:key` handlers and command
shortcuts, and consumes those events. It does not bypass modal blockers, active
popup handling or drag handling. The mandatory release shortcut (default F12)
clears capture and consumes its own event. `release-keys` clears it explicitly;
`keys-captured-p` queries the configuration. Focus movement, detachment and
disposal clear capture. An invisible/disabled/inactive widget cannot capture.

`:passthrough` lists shortcut specs using the same syntax as command shortcuts.
Matching keys take normal dispatch, allowing application commands to stay active;
they are not also emitted as raw events. A keyword matches the normalized key;
a `(:key ... :control ... :alt ... :super ... :shift ...)` plist matches the base
key and exact modifiers. Text events contain committed characters, not IME
composition. Captured Ctrl+C may arrive as normalized `:copy` with base key `:c`.
Tab and Escape were already consumable in a focused widget's `handle-event`
before default traversal/dismissal; capture adds precedence over window handlers.
Without capture, the grid emits text events as `:text-input`.

## Verification and measurement

`tests/cell-grid.lisp` exercises geometry, copied records, selection, resize,
input precedence and lifecycle behavior as part of `asdf:test-system "lut"`.
`tests/cell-grid-native.lisp` exercises native primary/worker rendering and logs
full-grid draw times at 100% and 200% scale after font warmup. These timings
measure CPU submission for the grid, not GPU completion or worker transport.
On macOS/SBCL the measured 82-by-25 grid averaged approximately 1.2–1.6 ms in
primary and worker draw paths at both scales after warmup; CCL averaged
approximately 12–14 ms (with primary-window maxima near 37 ms). Per-cell scissor
changes were the initial bottleneck; cropped atlas quads and separate background
and glyph passes removed that bottleneck. CCL's average consumes most of the
16.7 ms budget for a 60 fps frame, and its peaks exceed that budget before GPU
completion, worker transport or the rest of the UI. Two grids or a larger grid
would put further pressure on that budget. Functional checks passing on CCL do
not establish acceptable interactive performance for terminal-sized grids.

A [Phase 10 performance follow-up](foundation-roadmap.md#phase-10-terminal-capable-primitives-g5)
remains open: profile and improve CCL's per-cell draw path or introduce a cached
backing texture with explicit invalidation and disposal. Remeasure primary and
worker windows, including larger and multiple grids, before claiming adequate
frame-budget headroom. No backing texture cache is implemented yet.

SBCL and CCL pass the native script, including worker key IPC and
pixel assertions for glyph/ancestor clipping. Physical keyboard/pointer UX and
Linux/Windows execution remain unverified. These are bounded measurements, not
a throughput guarantee for larger grids or worker frame transfer.
