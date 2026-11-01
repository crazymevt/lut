# Wakeable retained event loop

LUT's default configured desktop event backend keeps raylib/GLFW and the retained renderer.
There is no native-widget rewrite. Stock raylib still uses the compatibility loop.
Only `lut/raylib` loads the scheduler; backend-free editor/model code remains
independent of it.

## Build and select

One-time setup belongs to LUT:

```sh
make event-backend-build
```

LUT's ASDF bootstrap then prefers this backend in every fresh Lisp process;
applications can use their ordinary launch command. No builds or downloads run
at application startup. Set `LUT_EVENT_LOOP=0` for compatibility polling, or use
an explicit `RAYLIB_LISP_LIBRARY_PATH` / `LUT_CEF_RUNTIME` override. A native
library already loaded in the process is never replaced.

Setup reuses a local pinned CEF SDK. Set `CEF_ROOT=PATH` for another SDK;
`CEF_DOWNLOAD=1` explicitly permits its download. `WITHOUT_CEF=1` is available
for GUI-only LUT development, and `WAYLAND=1` selects Linux Wayland. Successful
setup atomically publishes `.event-build/event-backend.sexp`; partial builds
never become the configured default. The low-level raylib builder remains:

```sh
/Users/jessie/.local/bin/quiet-run.sh -- python3 tools/build-event-raylib.py
```

The builder verifies the official raylib 6.2 archive against SHA256
`df7a13129b1bec9e73a6962efff170beba310ee6eab8f94cd000b7316b4db5ee`. It checks
patch contexts exactly, preserves upstream source/licenses in `.event-build`,
and writes immutable installations under `.event-build/versions/`. It prints the
library directory to use as `RAYLIB_LISP_LIBRARY_PATH`. macOS/Linux also receive
a `.event-build/current` convenience link. Windows can use the printed DLL path
without symlink privileges. Linux defaults to X11; `--wayland` selects Wayland.
Do not overwrite a library directory while an app is using it.

ABI version 1 exports `LUTEventBridgeVersion`, `LUTSetManualEvents`,
`LUTWaitEvents`, `LUTWakeEvents`, and `LUTConsumeDamage`. All calls except wake
belong on the native UI thread with a live context. Wait takes seconds: negative
blocks indefinitely, zero polls, positive waits to a deadline. Waiting is inside
raylib's input reset/dispatch boundary; EndDrawing retains swap behavior but
skips its own polling while LUT owns dispatch. Wake is thread-safe, uses a
pending latch plus GLFW's posted event, and is lifetime-gated during teardown.
No foreign worker calls into Lisp. Refresh damage is coalesced for presentation.

## Timers and tick compatibility

```lisp
(lut:schedule-ui 0.5 (lambda () (setf (lut:text label) "Ready")) :owner label)
(let ((timer (lut:schedule-ui 1 #'refresh-state :owner window :interval 1)))
  (lut:cancel-ui-timer timer))
(lut:on window :tick #'observe-controller :interval nil)
```

Timers use monotonic time, execute on the UI thread, coalesce missed repeating
periods, and release owned closures on disposal. Cancellation can be called from
a worker; already executing callbacks may finish. New queue work, an earlier
deadline, cancellation and stop wake native waiting. Native services register a
callback and a function returning seconds-until-work (or NIL). They must publish
an earlier deadline with `wake-ui` or the backend's native wake entry point.
Shutdown clears queued deadlines/services.

Existing `on :tick` subscriptions retain an explicit 30 Hz compatibility cadence.
A positive `:interval` opts into cadence; NIL observes actual controller turns
without adding wakeups. Tick callbacks still run on actual event turns as well.
Do not silently convert essential periodic services into passive observers.
`:context-open` is emitted once after native setup; `:context-close` retains
cleanup semantics. Interactive error pause temporarily restores the binding's
polling policy and re-enables manual dispatch when resumed.

## Painting and remaining active cadences

The controller uses root layout/paint generations plus native size/focus to
skip unchanged retained validation and pointer walks. Expose/resize/damage drive
presentation; no one-second refresh is needed with the bridge. `request-paint`
publishes changed regional keys without changing geometry or whole-widget
render keys; `invalidate-widget` remains the whole-widget invalidation API.
Use `on-ui`/`on-widget` for mutations from a worker. File-backed changes need an
explicit invalidation instead of an idle filesystem scan.

Submenu hover grace uses its own one-shot deadline. Active pointer capture,
drag/selection, dynamic/custom painters and direct drawing retain active
cadence. Finite-frame diagnostics also opt into cadence. The existing caret is
steady; no implicit blink poll was added. Secondary-window IPC still retains a
60 Hz parent fallback and its existing worker polling; this is not a claim of
fully event-driven secondary windows.

CEF uses its supported scheduled message-pump callback and a native C wake pointer.
Callback-only servicing stalled actual browser startup in testing; a 33 ms safety
deadline is retained while browser clients exist, consistent with the upstream
[reference external pump](https://raw.githubusercontent.com/chromiumembedded/cef/master/tests/shared/browser/main_message_loop_external_pump.cc).
It does not force widget traversal or presentation. CEF clients remain serviced
when they do not paint. No live clients means no safety cadence. CEF scheduling,
pump and fallback counters are separate. Build a new runtime directory with
`webview/scripts/build.py --cef-root SDK --runtime-dir NEW_DIR --build-dir BUILD_DIR`
and select it with `LUT_CEF_RUNTIME`; do not replace a mapped runtime.

## Verification

With the printed library path exported, run:

```sh
/Users/jessie/.local/bin/quiet-run.sh -- env LUT_SCHEDULER_NATIVE=1 sbcl --non-interactive --load tests/ui-scheduler.lisp
/Users/jessie/.local/bin/quiet-run.sh -- make test-widget-cache-ui
/Users/jessie/.local/bin/quiet-run.sh -- sbcl --non-interactive --load tests/scheduled-cef.lisp
```

Tests cover deterministic deadlines, ownership/cancellation, coalescing, 100
queue/wait publication races, earlier-deadline wake, sleeping shutdown,
pause/resume, retained parity at multiple scales, multiple windows, and actual
scheduled CEF animation/regional repaint bounds, resize, minimize/restore and
JS/title delivery. CEF tests require the rebuilt runtime. Native checks here ran
only on macOS ARM64. Windows/Linux and full physical keyboard/IME/modal smoke
checks remain pending; GLFW implementation coverage is not native validation.

The Xeon sibling's `docs/IDLE-CPU-RESULTS.md` records controlled real-workspace
before/after CPU, helper CPU separately, counters, provenance, logs and limits.
