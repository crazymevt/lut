# Platform integration and UI scaling

Load `lut/examples` and run `(lut:start (lut-examples:platform-integration))`.
The same command data powers a macOS AppKit menu or a drawn menu. File, folder
and save dialogs return paths; the example does not read or write those files.
Application preferences and persistence remain application policy.

## Command menus

```lisp
(let ((open (lut:make-command :open "Open…"
              (lambda (command context) (declare (ignore command))
                (lut:request-path context #'print))
              :shortcut :control-o)))
  (lut:install-command-menu window
    (list (list :label "File" :commands (list open :separator)))))
```

`install-command-menu` returns a `command-menu` owned by the window. One handle
per window is supported; dispose it to replace it. Groups are copied plists with
`:label` strings and `:commands` lists of live commands; `:separator` separates
items in both native and drawn menus (NIL is also accepted). Commands remain
application-owned. `:context` defaults to the window and is passed to command
predicates/actions. Labels, enabled state and shortcut changes are refreshed each
frame and before native menu tracking. `refresh-command-menu` permits explicit
refresh after external state changes. Group definitions remain fixed for the
handle's lifetime.

For dynamic submenus, pass `:submenu` to `make-command` (or set
`command-submenu`). The provider takes `(command context)` and returns a list
of application-owned commands and optional separators. This supports recent-file
and recent-folder lists in both AppKit and drawn menus. Native contents refresh
with the menu snapshot; drawn contents are captured when the group opens.
Keep returned commands alive until the menu is disposed. A drawn submenu opens
beside its parent row, and choosing an action closes the menu chain.

`:native :auto` (default) starts with the drawn bar and upgrades when a primary
macOS GUI context becomes available. `:native nil` always draws. `:native t`
requires an active eligible context and signals `unsupported-capability` if none
exists. `command-menu-backend` reports `:drawn` or `:native`;
`command-menu-bar` returns the fallback widget (hidden while native). The fallback
is an ordinary child of the window, so application layout may place it as needed.
Existing hand-built `menu-bar` and `bind-command` users retain their APIs.

The AppKit adapter owns its `NSMenu`, target and registry entries, preserves the
application menu, and restores the previous main menu on disposal/context close.
Menu callbacks queue command execution on the controller; Lisp errors never
unwind through Objective-C callbacks. Execution rechecks command availability,
root scope, native modal blocking and window visibility/enabled state. Native
shortcuts replace the handle's drawn key bindings, preventing duplicate actions;
unsupported equivalents retain the normalized keyboard binding. Do not separately
bind the same shortcut through another application binding.

Character keys, arrows, Return, Tab, Space and Escape have native equivalents.
Exact modifier plists preserve Shift/Control/Option/Command. Normalized keyword
aliases such as `:control-o` display as Command-O on macOS, consistent with the
poller's common Ctrl/Cmd command aliases. Other normalized aliases remain bound
through LUT instead of inventing a native mapping. AppKit item validation is
manual so LUT's predicate/enabled state remains authoritative.

Secondary workers retain drawn menus: their application objects and callbacks
live in the controller, and no Objective-C pointers or closures cross IPC. Native
Linux/Windows menus are not implemented. These contexts use the drawn fallback.

### Separators in main and context menus

Place `:separator` between commands in a main-menu group's `:commands` list.
For right-click menus, place it between action descriptors:

```lisp
(lut:open-context-menu window target event
  (list (list "First action" (lambda () (print :first)) t)
        :separator
        (list "Second action" (lambda () (print :second)) t)))
```

NIL entries are also accepted as separators in both APIs. Native main menus use
AppKit separator items; drawn menus create noninteractive `menu-separator`
widgets. They reserve their own row height, draw a rule, take no keyboard focus,
and invoke no action when clicked. Separators apply inside a main-menu group
(such as File), not between top-level horizontal menu titles.

## File, folder and save paths

```lisp
(lut:request-path window
  (lambda (path) (when path (format t "Chosen: ~a~%" path)))
  :kind :save :directory (user-homedir-pathname) :filename "untitled.txt")
```

`request-path` accepts `:kind :file`, `:folder` or `:save`, an existing
`:directory`, optional `:filename`, string `:title`, and the same
`:native :auto/t/nil` preference. It returns a `path-request`. Native requests run
synchronously through AppKit's modal loop on the primary GUI thread; the callback
can run before `request-path` returns. Drawn requests return pending and complete
later. Callbacks take one pathname on acceptance or NIL on cancellation.

`:file` requires an existing non-directory file; `:folder` requires an existing
directory. Both return canonical paths. `:save` returns a filename in an existing
directory, without creating it, opening a stream, or writing data. Native panels
may present their usual overwrite confirmation; LUT does not implement file-save,
extension, persistence or security-scoped-bookmark policies. This API selects one
path, not a multi-file collection.

`path-request-state` is `:pending`, `:accepted` or `:cancelled`;
`path-request-result` is the resulting pathname or NIL.
`path-request-dialog` is the active portable dialog, or NIL. Invalid portable
input displays a message inside the dialog, focuses the path field, and leaves
the request pending so the user can correct it. Directory browsing failures use
the same feedback.
`cancel-path-request` cancels a pending
portable request once. Escape, Cancel, or disposal of its dialog also cancel.
Completion removes the dialog and root references and clears the callback before
calling application code. Callback errors propagate after completion.

Window/request disposal cancels silently and clears callbacks/results. A completed
handle is application-owned once removed from the root's pending-resource list;
dispose it when no longer needed. Native requests are modal/synchronous, so
programmatic cancellation of a native panel is not an asynchronous public API.
The existing `choose-file`, `choose-color` and `choose-font` helpers remain
unchanged. Portable path dialogs stay in-window even with the raylib backend.

The native provider uses `NSOpenPanel` for files/folders and `NSSavePanel` for save
paths. Outside the primary macOS GUI context (including workers), `:auto` uses the
portable browser/path entry. Explicit `:native t` does not silently fall back.

## Coordinated UI scaling

`window` accepts `:ui-scale` (positive real, default 1); SETF changes zoom at
runtime. All public widget geometry, layout arguments, text rectangles, scroll
offsets, anchors, hit tests, and ordinary `dispatch` events remain in logical UI
units. Widget style tokens and application width/height values are not multiplied
or rewritten. This avoids cumulative rounding and repeated scaling on relayout.

`ui-to-device` / `device-to-ui` convert coordinates at the native boundary.
`dispatch-device-event` copies and converts one native-coordinate event; the
original is untouched. Native polling performs that same single conversion.
Wheel deltas remain row/step counts. Do not pre-convert an event and then pass it
to `dispatch-device-event`.

The raylib backend applies one root camera zoom, scales scissor rectangles, and
loads font atlases at the requested output size while measuring in logical
units. `begin-ui-scissor` and `with-ui-scissor` take logical coordinates for
custom backend drawing. Like raylib's scissor scopes, nested scopes require the
caller to restore the outer clip afterward. Drawing callbacks inherit logical
camera coordinates. Raw `rl:begin-scissor-mode` remains a native-coordinate API;
application code should use LUT's helper within the UI renderer.

Initial native dimensions are logical root dimensions × UI scale. Runtime zoom
keeps the native window size and changes the available logical viewport. The
frame loop divides reported native dimensions by UI scale before layout. Text
measurement caches are invalidated when the scale changes. Controls, text,
selections, gutters, scrolling, images and popovers share the same transform.

UI zoom is distinct from the OS display backing-pixel/Retina scale, which raylib
handles. LUT does not infer preference values from monitor DPI or persist them.
Each application window has its own UI scale. Detached dialogs inherit their
owner's scale when opened. Worker messages carry physical frames and raw native
input; the controller converts against the current root scale, including after
runtime zoom changes. Worker pixels, logical dimensions and event conversion are
tested together.

## Capability audit and backend strategy

`platform-capabilities window` returns fresh records; `platform-capability window
name` returns one or NIL. Native menu/picker status is context-sensitive:
`:native` in an eligible primary macOS context, otherwise `:portable`. This is a
capability report, not a claim that all operating systems were tested.

| Area | Current behavior | Required strategy before claiming more |
| --- | --- | --- |
| Menus and path pickers | AppKit primary-window adapter; drawn fallback elsewhere | Add/test a platform provider for Linux/Windows; keep the same command/path contracts |
| UI scaling | Logical coordinates with coordinated raylib transforms, clipping, font atlases and worker conversion | Separate per-monitor backing DPI policy from application zoom |
| Unicode glyphs | Partial: supported font glyphs and Common Lisp character indices | Preserve font coverage tests; introduce grapheme-aware editing explicitly |
| Shaping | Unsupported: no shared shaping engine for layout, rendering and hit testing | Integrate shaped glyph runs (e.g. HarfBuzz/CoreText) and cluster-to-model index maps across all three paths |
| Bidi | Unsupported: no Unicode bidirectional layout | Adopt UAX #9 with visual/logical caret and selection mapping before claiming RTL support |
| IME composition | Unsupported: committed character events do not establish preedit/composition support | Add native text-input clients, marked ranges, candidate geometry and composition lifecycle; do not treat key events as IME integration |
| Accessibility | Unsupported: no native accessibility tree or semantic action bridge | Define roles/states/actions and expose them through NSAccessibility/UI Automation/AT-SPI adapters; verify with platform assistive tools |
| Linux/Windows native behavior | Unverified; native menu/picker providers absent | Run the requested port's behavioral/native checks before changing the status |

Relevant primary references: [AppKit menu enabling](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/EnablingMenuItems.html),
[menu key equivalents](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/SettingMenuKeyEquiv.html),
[NSSavePanel modal results](https://developer.apple.com/documentation/appkit/nssavepanel/runmodal()),
[raylib drawing/input reference](https://www.raylib.com/cheatsheet/cheatsheet.html),
[Unicode bidi algorithm](https://www.unicode.org/reports/tr9/), and
[NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient).

## Verification limits

Portable tests cover coordinate conversion, event copying, command updates,
fallback requests/validation/cancellation, ownership and explicit capability
gaps. GC tests retain disposed menu/request handles while checking payload release.
macOS native tests verify menu label/enabled/shortcut/action changes and cleanup,
configure all three actual AppKit panels, and cancel each through its real modal
loop. Native path acceptance by a human was not exercised; portable accepted-path
validation is tested. Rendering tests at 100/125/200% check scissored pixels,
font atlas resolution, text hit testing and button input. Worker checks cover
200%→125% runtime zoom, physical frames and one-time input conversion.

Linux/Windows native tests, shaping, bidi, preedit IME and assistive-technology
integration have not been established by these checks.

Use `(set-command-menu-native menu nil)` to switch an installed menu to its
fully functional drawn backend at runtime. Pass `:auto` to restore platform
selection (or `t` to require native availability). Switching releases the prior
native handle and refreshes shortcuts without replacing application commands.

Drawn command-menu headings are flat, content-sized controls owned by LUT.
Submenu items open on hover as well as activation. Moving between parent items
replaces the open submenu; hovering does not invoke commands. Submenus open to
the left when there is insufficient room at the right edge.

Open drawn menus switch headings on hover. Submenu closing/switching has a
200 ms grace period so diagonal movement can reach the child; entering the child
cancels that pending transition. Returning to an ancestor reuses its existing
submenu and closes only deeper levels.

Command menu popups show right-aligned shortcut hints and restore the previous
control's focus and selection when dismissed. `open-context-menu` action records
accept an optional fifth string (the hint) after the submenu provider; existing
records remain valid. Native Cocoa menus compare effective snapshots before
issuing setters, avoiding repeated FFI calls and string allocation at idle.
Native path-request modal state participates in that comparison.

Submenu providers are resolved again when the child popup opens, so background
model updates are visible even if the parent menu was already open. Availability
is evaluated in that menu's own input scope; unrelated modal dialogs still block
commands. This does not add polling or rebuild closed menus at idle.

`refresh-command-menu` also refreshes an already-visible drawn menu when its
snapshot changes, preserving the open submenu path. Unchanged snapshots retain
the same popup widgets, and a modal dialog above the menu blocks that refresh.
