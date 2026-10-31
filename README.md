# LUT — Lisp User Toolkit

A retained-mode Common Lisp GUI library with CLOS widgets, portable core logic,
and a raylib backend. Applications build widget trees and register callbacks;
the library handles layout, painting, input, focus and window processes.

The GTK 4.20.2 suite has 108 runnable portable adaptations, each with a behavioral
test. [Generated coverage](examples/gtk-demo-coverage.md) is checked against the
registry. [Demo usage and differences](docs/gtk-demo.md) describes controls,
optional media dependencies and backend limits; this is not exact GTK feature or
rendering parity. See [acceptance status](docs/status.md).

## Install and run

For Quicklisp, link the checkout into its local projects and refresh the index:

```sh
ln -s /path/to/lut ~/quicklisp/local-projects/lut
```

```lisp
(ql:register-local-projects)
```

This machine is registered as `~/quicklisp/local-projects/lut` pointing to
`/Users/jessie/projects/lisp/lut`. The ASDF system and public package are both
`lut`; application helpers use `lut-examples` and `lut-gtk-demo`. After upgrading
from LUI, start a fresh Lisp session to avoid stale packages and cached old paths.
The existing local `raylib` and `docset` projects must also be registered. Raylib requires its native library and a C compiler; follow
that binding's installation instructions. Quicklisp supplies CFFI, Alexandria,
Bordeaux Threads and CL-BASE64. The demo system additionally uses portable
Classowary (constraint solving), XMLS (markup) and CL-PDF/parser (printing).
Video loading uses an optional `ffmpeg` executable on PATH. Noto Sans regular,
bold and italic faces are bundled under the SIL OFL.

Run the searchable demo launcher from this checkout with `make demo` (SBCL and
Quicklisp must be installed). Override `SBCL` to select its executable. For an
automatically closing smoke run, use `LUT_DEMO_FRAMES=4 make demo`.

For the interactive controls and foundation browser with matching **Demo** and
**Code** tabs, run `make lut-demo`. Its source lives under
[`examples/lut-demo`](examples/lut-demo/README.md) as the `lut/demo` ASDF system.
It includes shared text/history, presentation, data models, platform integration,
composition, responsive layouts, wrapping, scrolling, adapters and cell grids.
Use `make test-lut-demo` for headless checks or `make smoke-lut-demo` to render
all examples and Code tabs. `LUT_DEMO_FRAMES=4 make lut-demo` bounds a normal run.

```lisp
(ql:quickload "lut/examples")
(defparameter *app* (lut-examples:gallery))
(lut:start *app*)
```

Use `(lut:start *app* :wait t)` for a synchronous primary launch. Controller and
rendering errors are signaled on the caller after native cleanup, including for
unbounded runs. Asynchronous starts keep interactive pause/runner error handling.
Starting a secondary window returns its worker handle immediately even with
`:wait t`; that flag does not wait for a worker's lifetime. See
[the REPL workflow](docs/repl.md).

The example builders `hello-world`, `todo`, `editor`, `drawing`, `clock`, and
`adwaita` return trees. These are small adaptations of the six local GTK4
examples, not full replicas. `gallery` demonstrates the basic controls.

```lisp
(ql:quickload '("lut/raylib" "lut/gtk-demo"))
(lut-gtk-demo:demo-names)
(lut:start (lut-gtk-demo:demo "stack"))
```

## REPL workflow

Keep the actual widget tree in a variable. Use `on-ui` for mutations from an
editor REPL; its closures execute FIFO on the GUI/controller thread.

```lisp
(lut:on-ui
  (setf (lut:theme *app*) lut:*dark-theme*)
  (lut:add-child *app* (lut:make-widget 'lut:entry :id :name :text "Added live")))
(lut:on-ui (setf (lut:text (lut:find-widget *app* :name)) "Changed live"))
```

Re-evaluate named functions, CLOS methods and `defwidget` forms. Existing CLOS
instances acquire added slots through normal class redefinition. Setter type
checks and `validate-slot` invariants also apply to REPL edits. See the
[worked class-redefinition example](docs/repl.md), including source reloads,
callback registration and error recovery.

## Native windows and dialogs

With the raylib backend running, `show-dialog` opens dialogs directly in a
separate OS window. Dialogs queued before `run` open when the loop starts,
without first appearing inside the main window. The OS title bar handles moving
the window. Popovers, context menus and tooltips remain in-window overlays.
Dialogs are modal by default: owner input is blocked and clicking the owner
returns focus to its active dialog. Modal windows use the OS topmost flag while a LUT window is focused, so
they stay above the owner even when cross-process focus requests are ignored.
Switching to another application clears that flag; returning to LUT restores it.
The owner remains blocked until its modal closes.
Use `:modal-p nil` for a modeless dialog.
Nested dialogs block their immediate owner and redirect focus to the deepest modal.
`spawn-window` opens an independent root; `start` during the primary loop opens
a worker as well.
The backend-free core retains overlays for non-native use and headless tests.

Use `dismiss-dialog` in dialog response callbacks so they also close a native
native host. App styles and selectors inherit across roots through `style-source`.

Each native worker owns one raylib context. The original Lisp retains all widget
objects, callback closures and rendering methods; it renders secondary windows
offscreen and transfers PNG frames over private process pipes. Input returns to
the original objects. This supports live custom drawing without copying closures
or classes between processes. PNG readback/compression is a performance cost;
this backend is not intended for high-frame-rate multiwindow animation.

```lisp
(defvar *second*)
(lut:on-ui
  (setf *second* (lut:spawn-window
    (lut:with-ui (lut:window :text "Second" :width 400 :height 240)
      (lut:make-widget 'lut:button :text "Another native window")))))
(lut:close-window *second*)
```

The primary controller loop services secondary input and render updates. Workers continue handling OS movement/close events while the
parent is paused, displaying their latest frame. Stopping the primary loop closes secondary workers and releases their registry
references. Workers launch the local Lisp executable through
`*worker-command*`; override it for deployed applications or other runtimes.

Search fields, busy spinners and image toggle buttons are documented in
[extra controls](docs/extra-controls.md) and demonstrated in the interactive browser.

## Widgets and styles

The library includes labels, buttons, toggles, switches, radio groups, entries,
multiline text, sliders, numeric steppers, progress, lists, dropdowns, editable
combos, expandable trees, sortable tables/columns, boxes, grids, split panes,
stacks, tabs, headers, menus, popovers, tooltips, expanders, images and portable
file/color/font choosers. These are initial implementations; they do not provide
all GTK/JavaFX features such as virtualized data models or editable table cells.

Root themes inherit through the tree. Local overrides, state overrides and
ordered root class selectors control colors, fonts, metrics, borders and radii.
See [styling](docs/styling.md) and the [programming guide](docs/guide.md).
Text uses a loaded font with the tree's Unicode codepoints and whole-string
measurement/drawing. Font coverage limits still apply. Complex shaping, bidi,
font-pair kerning and IME are not implemented by raylib's text renderer.

## Object lifetime

Use `remove-child` to detach for reuse, or `dispose` / `remove-child :dispose t`
to destroy a subtree. Owned callbacks (`on ... :owner widget`) and owned queued
work (`on-widget`) are removed automatically on disposal. Closed worker handles
release their widget roots, and native caches evict unused resources after a
frame. See [ownership and cleanup](docs/lifecycle.md), including GC tests.

## Documentation and tests

```lisp
(asdf:test-system "lut")
(asdf:test-system "lut/gtk-demo-tests")
(ql:quickload "lut/gc-tests")
(asdf:test-system "lut/gc-tests")
(ql:quickload "lut/docs")
(lut-docs:generate)
```

The generated `docs/docset/` is the shared Cadre/spec-browser Lisp-data format,
not a Dash SQLite docset. It includes inherited initargs, types/defaults,
function/macro signatures, argument contracts, examples and event payloads.
Generation rejects missing exported-function contracts and unreadable examples.

Native checks are in `tests/smoke.lisp`, `tests/gtk-smoke.lisp`,
`tests/backend.lisp`, `tests/windows.lisp`, `tests/text.lisp`, `tests/cache.lisp`,
`tests/review-native.lisp`, and `tests/demo-native.lisp`.
`tests/portable.lisp` runs all headless, GC and docset checks, including
`lut/gtk-demo-gc-tests`.
Run them as load scripts from this checkout in SBCL or CCL. Use the project's
required quiet command wrapper for shell invocations.

`sbcl --script tests/start-errors.lisp` checks synchronous launch failures,
native cleanup, caller-thread propagation, asynchronous handling and worker
routing. For CCL use `ccl --no-init --batch --load tests/start-errors.lisp`.

## Verified platforms

Core behavior and native windows run on macOS/ARM64 under SBCL and the upstream
CCL 1.13 ARM64 prerelease. The backend bridges both implementations onto the OS
main thread. Linux and Windows runtime verification is deferred by user direction;
no claim is made that those native paths have passed.

## Drag-and-drop

Reusable in-window drag sessions and opt-in notebook tab reordering/transfer are
available. See [drag-and-drop](docs/drag-and-drop.md) for extension hooks, lifecycle
and the `lut-examples:drag-tabs` example.

## Shared commands

Commands share actions, labels, availability and shortcuts across buttons/menu
buttons. See [commands](docs/commands.md) and `lut-examples:command-actions`.

## Foundation roadmap

The [foundation roadmap](docs/foundation-roadmap.md) records delivered components,
remaining toolkit work and the boundary with application-specific behavior.

## Shared text models

`text-buffer` shares text/history across independent entry/text views. See
[shared text buffers and indexed geometry](docs/text-buffers.md),
`lut-examples:shared-text` and the 50,000-line `lut-examples:indexed-text`.
`lut-examples:standalone-history` demonstrates range undo/redo and oversized-record feedback.
History record count and character budget are configurable. Set
`:history-retain-newest-p t` on the shared buffer or standalone view to preserve
the newest oversized record; defaults and zero-limit disabling are unchanged.
See [text selection and navigation](docs/text-selection.md) and `lut-examples:text-selection`
for word/line selection, caret reveal and selection autoscroll.
Phase 2 presentation APIs and the `lut-examples:document-presentation` showcase are
documented in [text presentation](docs/text-presentation.md).
Phase 3 keyed data models, virtual views, selection, trees and editable cells are
documented in [data models](docs/data-models.md); try `lut-examples:data-models`.
Phase 4 menus (including separators), native/portable path pickers, UI scaling
and capability limits are documented in [platform integration](docs/platform-integration.md).
Try `lut-examples:platform-integration`.

Phase 5 close requests/badges, keyboard/programmatic peer transfers, keyboard dragging,
drag autoscroll, split/drop zones and incoming OS file paths are documented in
[advanced interaction](docs/advanced-interaction.md).
Try `lut-examples:advanced-interaction`. Arbitrary MIME and outgoing OS drags
remain unsupported. Physical cross-window pointer transfer is unfinished;
Finder drag acceptance and Linux/Windows native behavior remain unverified.

Content measurement, minimum/natural size requests, measured boxes and wrapping
control rows are available as opt-in APIs. See [measured layout](docs/measured-layout.md)
and `lut-examples:measured-layout`. Selectable/editor reflow remains pending.

## Wrapped editors and documents

`wrapped-text-view` shares visual rows across editing, painting, selection and
scrolling. `wrapped-document-view` adds paragraph spacing and variable-height
headings/images. See [wrapped text](docs/wrapped-text.md) and
`lut-examples:wrapped-text` for a bounded growing composer.

## Scrolling and reveal

Query content/page/offset with `scroll-geometry`, clamp with `scroll-to`, and
reveal nested children or text ranges with `reveal-widget` / `reveal-text-range`.
Applications explicitly enable or pause `set-follow-end`. See
[scrolling and reveal](docs/scrolling.md) and `lut-examples:scrolling`.

## Application adapters

Explicit `launch-uri` / `launch-file` actions use a discovered or configured
argv launcher with availability/error reporting. `window-state` and
`set-window-state` query/request native maximize/restore; `normal-window-size`
preserves normal logical dimensions separately from allocated geometry,
including worker windows. See [application adapters](docs/application-adapters.md)
and `lut-examples:application-adapters`.

Phase 10 provides focused key capture, a fixed-cell text surface and cell selection.
See [cell grids and key capture](docs/cell-grid.md) and `lut-examples:cell-grid-demo`
for console-style presentation without an emulator or PTY.

Application authors can use the [public UI extension APIs](docs/ui-extensions.md)
for pointer capture, resize handles, notebook actions, list activation, clipping,
and text/caret styling.

## Render-texture regions

Native windows use retained region caching by default: widget changes dirty only
the overlapping tiles. Custom views can call `invalidate-widget` or supply a
`widget-render-key`; `cache-mode :dynamic` preserves continuous drawing, and
root `cache-enabled-p` disables caching. The standalone `lut/render-cache` API
also provides native region caching without requiring a LUT widget tree. It is also loaded by `lut/raylib`. See
[the cache API and lifecycle example](docs/render-cache.md).
Run `make test-render-cache-ui` for native reuse, clipping, HiDPI, fractional zoom,
transparency, explicit invalidation and error-retry checks.

## Embedding tables in another frontend

`lut/data-renderer` provides the same virtual data-table painter used by
`lut/raylib`, with a borrowed host font and no window-controller dependency.
See [the host embedding API](docs/table-embedding.md). Run
`make test-data-renderer-ui` for standalone native checks.

## Experimental CEF webview

The optional standalone Chromium widget lives under [`webview/`](webview/README.md).
It has its own pinned SDK build, CFFI bridge, native helpers and smoke tests;
normal LUT systems do not load or distribute CEF. See its README for platform
validation status and development-only limitations.
