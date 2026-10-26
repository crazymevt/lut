# Ownership, disposal and memory

Lisp garbage collection reclaims unreachable widget cycles. LUI does not maintain
a global registry of ordinary widgets. A child points at its parent, and the
parent owns its children. Once a detached subtree has no outside references,
its parent/child/callback cycles are collectible without explicit destruction.

Use explicit disposal to stop activity and release native or external bindings
promptly, especially for controls subscribed to a longer-lived event source.

## Detach versus destroy

```lisp
(lui:remove-child container child)             ; detach for reuse
(lui:add-child another-container child)        ; adopt the same live object
(lui:remove-child another-container child :dispose t) ; destroy its subtree
(lui:dispose dialog)                           ; idempotent destruction
```

Removal clears focus, pointer capture and drag state referencing the subtree.
It also recognizes window overlays, so there is no dangling overlay reference.
It preserves callbacks and data for reuse. Disposing recursively detaches and
clears children/overlays, standard model data, drawing closures, event connections,
focus/capture and owned queued work. Disposed widgets cannot be adopted or
rebound. `disposed-p` is managed by `dispose`; changing it cannot revive a tree.

Closing an in-window dialog detaches it for reuse; call `dispose` if retaining
a dialog object but no longer needing its contents. Unreferenced detached
dialogs are garbage-collected normally.

## Callback ownership

An active callback is a real reference. If a long-lived root callback captures
a transient control, make the control its owner:

```lisp
(lui:on window :tick
  (lambda (window dt)
    (declare (ignore window dt))
    (update-preview preview))
  :owner preview)
(lui:dispose preview) ; removes the root callback and clears its closure
```

`on` still returns the callback as its first value. Its second value is a
connection handle. `disconnect` removes both source and owner bookkeeping and
clears the handle's source/owner/callback references. `off` removes matching
bindings from a source:

```lisp
(defvar *binding*)
(setf *binding* (nth-value 1 (lui:on button :activate 'clicked)))
(lui:disconnect *binding*)
(lui:off button :activate) ; all activate bindings
(lui:off button)           ; all bindings
```

Disconnecting during emission prevents later invocation of that connection in
the same emission. Disposing a source removes all of its bindings; disposing
an owner removes bindings registered on other sources. No global connection
registry keeps inactive widgets alive.

## Queued work

A queued closure can also retain a control. Use an owner for work that should
be discarded when the control disappears:

```lisp
(lui:on-widget preview (refresh-preview preview))
;; Equivalent:
(lui:enqueue-ui (lambda () (refresh-preview preview)) :owner preview)
```

The second return value of `enqueue-ui`, `on-ui`, or `on-widget` is a cancellable
job handle. `cancel-ui` also accepts the queued function object. Cancellation
clears pending function/owner references. Work already executing finishes normally.
Disposal cancels owned work, including later jobs in the current drain batch.
Unowned `on-ui` work remains deliberate work until run/cancelled; portable Lisp
cannot infer which objects a user closure captures. Use ownership for transient
controls. Loop teardown cancels remaining jobs so they do not accidentally run
in a subsequent application session.

## Native windows and resources

Worker-window closure defaults to disposing its root. After closure, LUI removes
the global registry entry and clears the handle's root, process, reader, forms
and render-target references. The handle may be retained for status inspection
without retaining the old widget tree. To preserve a tree you own for reuse,
close it with `:dispose nil` and keep your own reference to the tree.

The primary loop closes all workers at teardown, releases their offscreen
render targets and clears `lui:*window*` and the pending work queue. The primary
tree itself remains reusable if the application retains it. Use `dispose` for
a complete application teardown rather than a temporary REPL stop. Raylib's
last-error diagnostic is cleared when the loop ends.

Font and image caches are marked during rendering. Stale font-atlas versions
and unused image textures are unloaded after the frame's draw batch has flushed.
Changing font sizes, changing image sources or removing controls does not leave
an unbounded history of native resources. Workers retain only their latest
frame texture and unload it at exit. Remaining resources are unloaded before
the native context closes.

## Custom widget resources

Subclass disposal methods can release application-owned resources. The generic
around method makes disposal idempotent and runs structural cleanup even if a
custom method signals. Perform disposal on the GUI thread when the application
is running.

```lisp
(defmethod lui:dispose :after ((w my-image-control))
  (when (owned-texture w)
    (rl:unload-texture (owned-texture w))
    (setf (owned-texture w) nil)))
(lui:on-ui (lui:dispose control))
```

LUI cannot release application globals, REPL history, debugger frames or unowned
external subscriptions, or explicit references in another live widget
(such as a style provider) for the application. Those are genuine outside references.
A Lisp allocator may also keep heap pages reserved after collection; process RSS
alone does not establish a widget leak.

## Verification

`asdf:test-system "lui"` checks structural cleanup and connection behavior.
`lui/gc-tests` uses the portable Trivial Garbage library to check weak-pointer
reachability of 300 disposed controls with owned connections/jobs and 300 detached
callback cycles. Native `tests/cache.lisp` verifies cache bounds and eviction;
`tests/windows.lisp` verifies closed workers no longer retain root/process/reader
references or global registry entries. These checks run under SBCL and CCL.

## Demo model and media ownership

Demo windows own their model objects and native resources. Disposal clears the
model and resource lists. Native context-close releases shaders and sound streams
before the raylib context closes. Recompilation replaces and disposes the prior
shader resource instead of accumulating wrappers. Video replacement stops the old
sound stream before deleting its frame/audio directory (important on Windows).
The log demo retains at most 1000 lines and disables undo history.

Remote handles retain only one previous raw pixel frame for exact change
comparison; close clears that buffer and its dimensions. Unchanged frames still
forward input and worker operations but skip PNG/base64 encoding and transfer.
GPU readback/comparison still happens; animated large windows remain expensive.

`lui/gtk-demo-gc-tests` builds and disposes every demo and verifies that all widget
instances become unreachable. `tests/demo-native.lisp` verifies actual decoded
media cleanup and repeated shader reloads, in addition to the ordinary cache and
worker cleanup tests. External references held by a user REPL variable remain
intentional roots; LUI cannot collect objects the application still retains.
