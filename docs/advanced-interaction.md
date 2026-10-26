# Advanced interaction and composition

Try `(lut:run (lut-examples:advanced-interaction))` after loading `lut/examples`.
The example includes two notebooks, an optional native peer window, protected
badges, a draggable card, split targets, a scrolling collection of drop surfaces,
and a file-drop surface. These APIs compose widgets; application workspace trees,
file contents, dirty-buffer policies and session persistence stay outside LUT.

## Tab closing and badges

Set `closable-p` on a notebook to show a close affordance at the right of each
tab. Pointer down there calls `request-page-close`; ordinary tabs still select
and drag. Programmatic calls do not require the affordance to be enabled:

```lisp
(lut:on book :page-close-request
  (lambda (book request)
    (declare (ignore book))
    (when (application-refuses-close-p (lut:close-request-page request))
      (setf (lut:close-request-veto-p request) t))))
(lut:request-page-close book page :reason :application)
(setf (lut:tab-badge page) "3")
```

A request exposes its page, reason (`:pointer` or the application's value), and
mutable veto flag. Returning NIL from a callback does **not** veto. LUT emits
`:page-close-request` synchronously before touching the tree. Veto, disposal or
reparenting during that callback makes the request return NIL. A successful
request detaches the page, removes its caption, retains the selected page when
possible, clamps the index otherwise, and emits `:change` then `:page-closed`
with the request. Empty notebooks retain index zero. The application owns the
detached page and may dispose it in `:page-closed`. For asynchronous decisions,
veto now and request again after the application has resolved its policy.

`tab-badge` is an optional string on the page. It appears in the caption and
follows the page on reorder/transfer. Badges carry no built-in dirty semantics.

## Controller-owned keyboard and programmatic cross-window transfers

```lisp
(defparameter controller (lut:make-drag-controller))
(lut:register-drag-window controller primary)
(lut:register-drag-window controller peer)
```

Register the **root windows**, including the root passed to `spawn-window`.
A root can belong to one controller. The controller retains its registered
windows until unregister/disposal; disposing a window unregisters it, and
disposing the controller unregisters all roots. Controllers do not own or
close registered windows. Cancel active drags before tearing down a registration;
unregistration does this automatically, even if the drag currently targets a
peer. Source/target subtree removal also cancels an affected session.

The session remains in `current-drag` of its source window. Peer input is routed
to that session by `dispatch`. `drag-x`/`drag-y` are logical coordinates in the
most recently receiving root, not desktop coordinates. `dispatch-device-event`
converts worker coordinates using that worker's UI scale exactly once. Workers
send input and copied OS paths; widgets, closures and payloads remain in the
controller Lisp image. No widget serialization is involved. Only one session
is armed per controller; starting another cancels the previous one.

`move-page` permits cross-root moves only through the same controller. Pointer
notebook drops additionally retain the existing opt-in `reorderable-p` and
matching non-NIL `tab-group` rules. Captions and badges follow the page; source
selection and focus are repaired, and an existing focused descendant may receive
focus in the destination. Escape, removal, disposal, registration teardown and
commit errors release session references and source capture. Successful drops
still emit the normal enter/over/leave/drop/end lifecycle.

Cross-window transfer is supported through keyboard targeting and programmatic
`move-page` calls. Physical mouse dragging between native windows is currently
unsupported. On platforms that capture dragging to the source window, the peer
may receive no movement or release events. A release outside the source then
uses source-root coordinates and rejects the drop; LUT does not route that
captured event through peer screen rectangles and UI scales.

Receiving-root event routing remains available to integrations that explicitly
supply destination events. The native test injects those events through worker
IPC; it does not establish physical pointer delivery. Physical pointer support
requires capture-aware routing and manual acceptance, including overlapping
windows. In-window pointer dragging continues to work. These transfers remain
independent of OS drag-and-drop interoperability.

## Keyboard dragging and autoscroll

`begin-keyboard-drag source payload` explicitly starts a drag without a pointer
threshold. The application supplies the initiation shortcut or action. Tab and
Shift-Tab cycle accepting surfaces (their center must accept); arrow keys move
24 logical units, Enter/Space commits and Escape cancels. Other keys are consumed
while dragging. `keyboard-drag-to source-window target &optional x y` aims at a
surface center or explicit logical root coordinates; use explicit header
coordinates for notebook transfers. It can target a registered peer window.

`advance-drag window seconds` advances stationary-pointer edge scrolling once
per **source-window** frame. Native primary and worker frame loops call it.
Portable integrations must call it with nonnegative elapsed seconds. The nearest
scrollable ancestor under the pointer scrolls vertically at 300 logical units
per second in a band up to 24 units wide. Scroll containers, list/model views and
notebook headers clamp to their extents; geometry and target hit testing refresh
after movement. Custom views may specialize `drag-autoscroll widget session
seconds`, update offsets, and return true when geometry changes. Existing
pointer-motion notebook header scrolling remains available. This is drag edge
scrolling, independent of text-selection autoscroll.

## Drop zones and pane composition

`drop-zone` is a reusable box with `drop-predicate` and `drop-function` callbacks,
both `(zone session event)`. NIL callbacks reject; a true commit result succeeds.
Ordinary drag feedback and lifecycle events apply. Dispose clears both closures.
Acceptance predicates should be pure; tree changes belong in the commit callback.

`split-drop-zone` accepts widget payloads and composes a `paned` on its
`split-edge` (`:left`, `:right`, `:top`, `:bottom`). `split-drop target incoming
edge :ratio 1/2` offers the same operation directly and returns the new paned.
It preserves the target's position in its parent. Ratio describes the first
pane's fraction. Cycles, detached targets, unrelated roots and direct stack/
notebook page composition are rejected. Move notebook pages through `move-page`
first so captions and selection remain consistent. Empty source panes are not
collapsed; applications decide their own composition policy.

## OS adapter and capabilities

`os-drag-capabilities window` describes incoming/outgoing support and MIME types.
Core-only use reports unsupported. The raylib adapter supports **incoming file
paths only**, for primary and worker windows, using
`application/x-lut-file-path-list`. This private type deliberately represents a
list of decoded path strings, not URI-list text. It does not claim arbitrary
MIME or outgoing drags. OS hover negotiation/feedback is unavailable.

A drop zone can test `(typep (lut:drag-payload session) 'lut:os-drop)` and read
`os-drop-mime` and `os-drop-data`. Nothing opens, reads or writes dropped files.
The adapter copies native paths before unloading the native list, forwards data
through worker IPC, converts coordinates to logical units once and delivers only
to live, enabled input-scope targets. `:drop` is emitted after a successful
commit. The OS owns gesture feedback; internal `:drag-start`/`:drag-end` events
are not fabricated. Session references are cleared even on errors.

Other adapters can use `dispatch-os-drop window mime data x y` with logical root
coordinates and Lisp data. This delivery API does not itself advertise an OS
capability; each backend must report its actual MIME support. Data is transient;
copy what the application needs during the callback. Unknown MIME types are
rejected by application predicates.

## Verification boundaries

`asdf:test-system "lut"` includes focused behavior and cleanup tests.
`lut/gc-tests` checks peer/session/drop-closure collection.
`tests/advanced-native.lisp` exercises rendering and worker IPC. Automated OS
delivery exercises the adapter boundary; a human Finder drag remains a separate
manual check. Injected peer pointer events verify only receiving-root routing and
IPC. Physical cross-window pointer transfer remains an unfinished roadmap item.
Linux/Windows native behavior and arbitrary MIME/outgoing support are not claimed.
