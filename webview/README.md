# Standalone CEF webview prototype

This optional LUT widget renders Chromium off-screen into the existing raylib
retained compositor. Xeon is unchanged. `lut/webview` loads without CEF or raylib;
`lut/cef` supplies the native implementation and a standalone demo.

## Build and run

Prerequisites: LUT's normal SBCL/Quicklisp/raylib environment, Python 3.12+,
CMake 3.21+, and a C++20 toolchain. Use Xcode command-line tools on macOS,
Visual Studio 2022's **x64 Native Tools** shell on Windows, and GCC/Clang on
Linux. The SDK must match the Lisp process architecture. See the downloaded
SDK's README for its OS minimums and Linux runtime dependencies.

From the LUT checkout:

```sh
python3 webview/scripts/prepare.py
python3 webview/scripts/build.py --download
sbcl --script webview/scripts/run.lisp
```

The script pins CEF `156.0.15+gcf671c0+chromium-156.0.8078.80`, checks the
archive against the official index's SHA-1 recorded in `sdk-lock.json`, builds the C++ wrapper/bridge/helper,
and stages everything under ignored `webview/runtime/`. It preserves CEF's
license and Chromium credits. SDK/cache/build/runtime files are not committed.
You may instead supply an extracted matching SDK:

```sh
python3 webview/scripts/build.py --cef-root /absolute/path/to/cef_binary_...
```

On this workstation run noisy commands through
`/Users/jessie/.local/bin/quiet-run.sh --`, including builds and tests. For example:

```sh
/Users/jessie/.local/bin/quiet-run.sh -- python3 webview/scripts/build.py --download
/Users/jessie/.local/bin/quiet-run.sh -- sbcl --script webview/scripts/run.lisp
```

Start a **fresh Lisp process** for each run. macOS must initialize CEF's
NSApplication subclass before raylib opens any window. The standalone runner
handles initialization on the OS main thread. CEF is initialized/shut down once;
loading `lut/cef` alone does not initialize it.

The demo provides an address field, Back/Forward/Reload, loading/error status,
and a local page with fields, a button and scrollable content. Click the page to
focus it. F12 releases browser focus, then Tab returns to LUT's toolbar.

## Validation

```sh
sbcl --script webview/tests/headless.lisp
```

That runs input-boundary regressions and the existing LUT ASDF test suite.
For a native integration test set `LUT_WEBVIEW_SMOKE=1` and
`LUT_WEBVIEW_FRAMES=600` in the environment, then run the ordinary script.
On POSIX shells:

```sh
LUT_WEBVIEW_SMOKE=1 LUT_WEBVIEW_FRAMES=600 sbcl --script webview/scripts/run.lisp
```

PowerShell:

```powershell
$env:LUT_WEBVIEW_SMOKE='1'
$env:LUT_WEBVIEW_FRAMES='600'
sbcl --script webview/scripts/run.lisp
```

Run `sbcl --script webview/tests/idle-baseline.lisp` for a separate toolkit-only
idle sample with CEF uninitialized.

The native test uses LUT's event dispatcher and a deterministic local page to
check pointer input, Unicode text, Backspace, wheel scrolling, native resize/UI
zoom, navigation/back, stable texture reuse, and orderly close. It also asserts zero dynamic surface paints and no more
than four window presentations during a three-second static-page interval
(the toolkit retains its existing once-per-second compositor repair). A missed stage
fails the run at its frame limit. `LUT_WEBVIEW_SCREENSHOT=/absolute/path.png`
optionally captures the rendered fixture. Host idle CPU is process CPU divided
by wall time during a three-second static-page interval after warm-up; it includes CEF's browser-process
pump but **excludes CEF helper processes**. It is not a total browser CPU metric.
See [cross-platform CI and test downloads](../docs/test-builds.md) for the hosted
checks, macOS VM graphics limitation, Fedora validation and offline bundles.

## Recorded validation (2026-10-31)

On this macOS ARM64 workstation, the pinned SDK builds and the complete native
interaction test passes, including clean shutdown. The headless webview checks
and the existing LUT ASDF suite pass. A warm three-second idle sample measured
6.36% host CPU with CEF and 2.29% for the separate empty-surface toolkit baseline;
the baseline presented three times. The CEF sample asserts no dynamic paints,
no more than four idle presentations, and unchanged browser paint/upload
revisions during the sample. These short local samples are indicative, not a
cross-platform performance guarantee; helper-process CPU is excluded.

Current hosted CI results and Windows/Linux test downloads are available in the
[public repository](https://github.com/crazymevt/lut/actions). See
[CI coverage](../docs/test-builds.md) for the exact tests and platform limits.
macOS x64, Linux ARM64, multi-monitor behavior and native Wayland remain unverified.

## Architecture and boundaries

- `native/bridge.h` is the small C ABI. Calls and borrowed frame/string access
  occur only on the initializing UI thread. Browser creation/close are async.
- The webview explicitly opts into retained caching; its paint revision is
  the cache key. Custom-renderer defaults must not make it dynamic.
- CEF callbacks compare/copy BGRA dirty rectangles into a bounded RGBA surface.
  Identical pixel callbacks do not advance the paint revision or trigger uploads. Lisp
  uploads the current surface once per changed revision. Clean frames retain
  their texture and do not invalidate LUT's layout or paint caches.
- Each changed browser frame currently uploads the **whole** texture. Dirty
  rectangle GPU uploads and accelerated shared textures are future work.
- CEF's main loop is serviced by LUT's existing tick; there is no extra polling
  thread. Idle toolkit cadence is roughly 30 Hz. Message pumping does not force
  repainting. Geometry/focus/visibility native changes are sent on changes.
- All CEF rendering methods belong to LUT's optional backend. Applications create
  widgets and handle events; they do not install draw callbacks.
- `src/input.lisp` makes the existing focus predicate generic and adds a default
  no-op embedded-input boundary. It runs after modal/anchored/drag routing, before
  ordinary command/key dispatch. Hidden/inactive pages cannot receive input.
- Closing queues browser handles until `OnBeforeClose`, releases textures while
  GL is alive, then shuts CEF down after all browser references have gone away.
- Chromium initialization can replace POSIX signal handlers. The bridge restores
  the host's synchronous trap handlers afterward so SBCL's allocation/GC traps
  continue to work. CEF helpers retain their own normal initialization.

## Prototype limits

This is a development prototype, **not a production browser**. The native build
explicitly disables the Chromium sandbox. Use the included local fixtures and
trusted development pages. Production integration needs sandbox/packaging work,
security-update policy and signed/notarized macOS application/helper bundles.

Windows x64, macOS ARM64/x64 and Linux x64/ARM64 SDK targets are selected by the
build script. Actual support is conditional on matching SDK/runtime dependencies
and native runtime testing. Linux X11/XWayland and native Wayland must be tested
separately; OSR does not by itself establish Wayland support.

IME/preedit, native accessibility, browser popup surfaces (including HTML select
menus), new-window requests, context menus, file dialogs/download policy,
permission prompts, OS drag/drop and full held-key/native scan-code semantics
are not implemented. New-window requests and context menus are suppressed;
popup paint surfaces are not composited. Keyboard forwarding sends down/up pairs
and UTF-16 character events, rather than preserving native key transitions.
Clipboard shortcuts and international keyboard layouts need per-platform QA.

The prototype supports one standalone primary-window session; LUT's separate
secondary-window workers are not integrated. CEF uses a development cache under
`webview/runtime/cache/`; application profile/cache policy belongs in a later
integration. Frames are limited to 8192×8192 physical pixels. DPI changes and
monitor transitions require further multi-monitor QA.

The Windows download defaults to bundled Mesa software OpenGL. It includes an
optional hardware OpenGL launcher. Runtime packaging omits upstream docs/theme
examples, checks archive path lengths, and uses short compiled-cache paths.
Failed window initialization skips native window cleanup to preserve the
original graphics error instead of risking a secondary native crash.
