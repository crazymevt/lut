# Drag-and-drop and notebook tabs

LUT supplies pointer drag sessions within a window, plus keyboard and
programmatic transfers between explicitly registered peer windows. Physical
pointer dragging between native windows is unsupported. Payloads are ordinary
Lisp values and stay in the controller process. This is independent of
an editor, document type or workspace layout.

## Notebook tabs

Opt in with `:reorderable-p t`. Two notebooks can exchange pages when they have
equal, non-NIL `:tab-group` values and belong to the same window. Cross-window
keyboard/programmatic transfers require an explicit drag controller; see
[advanced interaction](advanced-interaction.md). The example below uses
in-window pointer dragging:

```lisp
(lut:with-ui (lut:paned :height 300)
  (lut:with-ui (lut:notebook :reorderable-p t :tab-group :documents
                           :items '("First" "Second"))
    (lut:make-widget 'lut:entry :text "First page")
    (lut:make-widget 'lut:entry :text "Second page"))
  (lut:make-widget 'lut:notebook :reorderable-p t :tab-group :documents))
```

Drag a tab into a header strip. The insertion marker identifies the destination;
an empty notebook accepts a tab in its header too. Escape cancels. Ordinary
clicks and Left/Right page navigation retain their existing behavior. Reordering
and transfer preserve page instances, captions and callbacks, select the moved
page, and leave the source with a valid selection, including when it becomes empty.
A focused descendant stays focused during a programmatic move when it remains a
valid input target.

`(lut:move-page source page target index)` performs the structural operation
without a pointer gesture. `index` is a boundary in the destination's original
page list, from zero through its length. For same-notebook moves it is adjusted
after removal; moving the first of three pages to boundary three puts it last.
Explicit moves do not require pointer opt-in or matching groups. Use this API
rather than directly rearranging `children` and `items` independently.

Both notebooks emit `:pages-changed` with a plist containing `:page`, `:source`,
`:target`, `:old-index` and final `:index`; a same-notebook move emits once.
Selection updates emit `:change` before `:pages-changed`. A source notebook that
becomes empty has `value` zero and no active child.

Run the standalone example with:

```lisp
(ql:quickload "lut/examples")
(lut:start (lut-examples:drag-tabs))
```

## Custom sources and targets

Override `drag-data` to offer a payload on pointer down. Its second value says
whether a drag is offered, so NIL itself can be a payload. Source lookup starts
at the hit widget and walks its ancestors. Moving at least `:drag-threshold`
pixels (default six) starts the session; smaller movements remain ordinary clicks.

```lisp
(defclass card (lut:button) ())
(defclass card-bin (lut:box) ())

(defmethod lut:drag-data ((source card) event)
  (declare (ignore event))
  (values (lut:text source) t))

(defmethod lut:accepts-drop-p ((target card-bin) session event)
  (declare (ignore target event))
  (stringp (lut:drag-payload session)))

(lut:on bin :drop
  (lambda (target session)
    (lut:add-child target
      (lut:make-widget 'lut:label :text (lut:drag-payload session)))))
```

Acceptance lookup walks ancestors from the hit widget. `accepts-drop-p` is a
predicate: do not change the tree from it. Acceptance is rechecked on release.
Override `perform-drop` for a commit that may reject the operation by returning
NIL. Its default returns true; a `:drop` handler can implement simple accepted
drops. Side effects are application-owned and are not rolled back if a callback
signals an error.

`begin-drag` can arm a source explicitly from its pointer-down handler.
`current-drag` returns the pending or active session. Public read-only accessors
are `drag-source`, `drag-payload`, `drag-target`, `drag-state`, `drag-x` and `drag-y`.
Coordinates are relative to the containing window.

## Events, feedback and ownership

Callbacks take `(widget session)`:

- `:drag-start` on the source after crossing the threshold.
- `:drag-enter`, `:drag-over`, `:drag-leave` on accepted targets. Over also runs
  on release; leave runs when the target changes or the session terminates.
- `:drop` after a successful commit, with state `:dropped`.
- `:drag-end` on the source, with state `:dropped`, `:rejected` or `:cancelled`.

A pending session emits no drag lifecycle events when it ends as a click.
An active drag consumes release, preventing accidental source activation.
Escape and `cancel-drag` cancel; removal/disposal of the source, target, payload
widget or notebook page cancels too. Opening a dialog cancels the current drag.
A disabled/hidden source is cancelled on the next input event. Closing the native
context cancels even when the tree is retained for reuse.

Capture and session references are released on completion, including callback
errors. After terminal callbacks, source, target and payload accessors return
NIL; retain application data explicitly if it is needed later. Session state and
coordinates remain inspectable. Terminal callbacks run after the window's
`current-drag` is cleared, so they may start another operation.

The raylib backend paints a target outline, insertion marker for notebook tabs,
and accepted/rejected pointer marker. Override `render-drag-feedback` on your
window class for a custom preview; call the next method to retain default feedback.

See [advanced interaction and composition](advanced-interaction.md) for tab
close requests/badges, controller-owned keyboard/programmatic peer transfers, keyboard dragging,
stationary-pointer content scrolling, reusable split/drop zones, and the
incoming OS file-path adapter. Arbitrary MIME and outgoing OS drags remain
unsupported; workspace/persistence policies remain application code.

## Tab overflow

When tabs no longer fit, the notebook retains readable tab widths, clips the
strip, and shows left/right navigation buttons. The mouse wheel over the header
scrolls the tabs without changing the selected page. Left/Right keyboard page
selection and `select-page` reveal the selected tab automatically; resizing and
caption/page changes clamp the offset and reveal the selection on layout.
Dragging near either edge of the visible strip scrolls toward hidden tabs.
Navigation buttons do not start a drag or select a page.

`scroll-tabs` accepts a pixel delta; `tab-offset` exposes the current pixel offset
and is clamped on layout. `reveal-page` scrolls a given page into view without
selecting it. `tab-at-position` returns the visible page at root coordinates,
excluding navigation controls and the content body.

Styles `:tab-min-width` (96), `:tab-max-width` (220) and `:tab-scroll-step` (96)
control overflow geometry. Long labels are truncated within their tabs. When all
tabs fit they continue to share the available strip width. For a strip too narrow
to expose any tab, resize it or select a page from code/keyboard.

Try `(lut:start (lut-examples:overflow-tabs))` after loading `lut/examples`.
