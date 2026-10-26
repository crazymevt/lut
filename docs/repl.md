# Develop from the main REPL

## Keep the objects

The builder returns an ordinary CLOS object tree. Store it before calling
`start`; the library does not rebuild it on each frame. `lui:*window*` also
holds the most recently started active root and is cleared on loop teardown. Use your own variable when several roots
exist. `find-widget` looks up an application-supplied `:id` with `equal`.

Wrap mutations in `on-ui` when the editor REPL runs on another thread. This
captures lexical variables and queues the closure on the controller thread.
The macro returns the closure immediately, not the eventual body result.
Callbacks can mutate directly because they already run on that thread.

```lisp
(defparameter *app* (lui:with-ui (lui:window :width 640 :height 480)
                     (lui:make-widget 'lui:entry :id :name :text "Hello")))
(lui:start *app*)
(lui:on-ui (setf (lui:text (lui:find-widget *app* :name)) "Updated"))
```

## Redefine a widget class

Use `defwidget` for class/slot documentation and validated accessors. Slot
specifications are `(name initform type documentation)`. Avoid names inherited
from the CL package (such as COUNT) unless your application package shadows them.

```lisp
(lui:defwidget counter-label (lui:label) "Live counter label."
  ((tally 0 (integer 0 *) "Number of updates.")))
(defvar *counter* (lui:make-widget 'counter-label :text "Counter"))
(lui:on-ui (lui:add-child *app* *counter*))
```

Now evaluate this definition on the GUI thread. It keeps the original instance
and adds a slot using standard CLOS lazy instance updating:

```lisp
(lui:on-ui
  (eval '(lui:defwidget counter-label (lui:label) "Counter with a live badge."
           ((tally 0 (integer 0 *) "Number of updates.")
            (badge "new" string "Badge text added during development.")))))
```

Existing `*counter*` receives BADGE's initform when CLOS updates the instance.
An application can define `update-instance-for-redefined-class :after` when
removed/added slots require a migration beyond their initforms. Removed accessors
should no longer be called; redefining a class does not promise to migrate a
completely different application model automatically.

## Redefine behavior and rendering

All controls use per-class `render` methods. The shared around method applies
clipping, focus decoration and active-child traversal, so a subclass only draws
its own content. `call-next-method` reuses its superclass rendering.

```lisp
(defmethod lui:render ((w counter-label))
  (setf (lui:text w) (format nil "~a: ~d" (badge w) (tally w)))
  (call-next-method))
(defun update-counter (widget payload)
  (declare (ignore widget payload))
  (incf (tally *counter*)))
(lui:on-ui (lui:on *app* :tick 'update-counter))
```

A symbol callback is resolved through its current function definition. Redefining
`update-counter` changes the running app. Callback registrations are additive:
re-evaluating `on` registers again, so register once and redefine the function.
Anonymous closures remain the original closures until explicitly replaced by
application code or a rebuilt tree.

## Reload source files

```lisp
(lui:on-ui (asdf:load-system "my-application" :force t))
```

Define builders, callbacks and classes at top level. A source reload does not
call your builder or replace the existing tree automatically. Preserve live
state and update children explicitly, or stop and start a new builder result.
Reloading LUI itself resets its default palette variables; roots retaining old
palette lists keep them until their THEME is reassigned.

## Errors and validation

Interactive raylib runs pause on errors. Inspect `rl:*last-error*`, fix/redefine
the function, and call `(rl:resume)` or press F5. Bounded test runs signal errors
instead. Queued edits do not execute while the error screen is paused. A failing
queue job is not retried (it may already have side effects); later jobs remain
queued in order for recovery.

Every `defwidget` setter checks its declared type before assignment and invokes
`validate-slot`. Specialized methods enforce cross-slot invariants. Numeric
controls require `minimum <= value <= maximum`, including during live edits.
For a range change, expand the bound, move the value, then contract the other
bound in a valid order. Invalid assignments signal and retain the previous value.
Geometry allocations remain valid non-negative extents.

## More than one native window

Secondary widget trees and all application code remain in this REPL.
Root title changes also synchronize to native title bars. Application style
sources propagate later theme and selector changes to detached roots. The
controller renders them to offscreen textures, compares rendered pixels and encodes only changed frames as in-memory PNGs,
and sends them to a small native window worker. The worker forwards normalized
input; callbacks run in the controller. Thus redefined custom widget methods and
custom drawing closures work in detached windows without serializing Lisp code.

`on-window`/`evaluate-in-window` are explicit advanced worker-evaluation tools,
for native window operations such as `(rl:set-window-title "Updated title")`.
They do not capture lexical variables from this process. Ordinary app edits and
source reloads belong in `on-ui` in the original REPL.

The primary loop services IPC. While it is paused, workers keep their last frame
and handle OS events, but application callbacks wait. Keep the primary running to service secondary input. `stop` closes remaining
workers automatically and clears library-owned references. Use `close-window`
for an individual remote handle. Dialog response callbacks should call `dismiss-dialog` on the
dialog itself; that closes its current modal owner or detached native host. Worker startup uses `*worker-command*` and this checkout's ASDF
system; deployment needs an appropriate executable/registry setup.

On macOS the OS main thread owns native GUI operations. SBCL uses the binding's
main-thread runner. LUI adds a CCL bridge because CCL's listener process is a
different thread; invoking Cocoa directly there causes a native trace trap.

See [object ownership and disposal](lifecycle.md) for owned callbacks, cancellable
work, subtree destruction, and the difference between temporary stop and disposal.
