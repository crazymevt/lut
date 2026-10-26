# Drag-and-drop and notebook tabs

LUT supplies drag sessions and drop targets within one window. Payloads are
ordinary Lisp values and stay in the controller process. This is independent of
an editor, document type or workspace layout.

## Notebook tabs

Opt in with `:reorderable-p t`. Two notebooks can exchange pages when they have
equal, non-NIL `:tab-group` values and belong to the same window:

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

This first implementation does not supply cross-native-window transfers,
OS/MIME drag-and-drop, keyboard drag operations, automatic edge scrolling,
tab overflow/close controls, or docking. Applications may build split/drop-zone
policies using custom targets without adding workspace rules to LUT.
