# Verification record — task revision 6

Host: macOS ARM64. Implementations: SBCL 2.6.9 and upstream Clozure Common Lisp
1.13 ARM64 prerelease (v1.13-459-g690ff7ea). Commands run from the checkout using
`/Users/jessie/.local/bin/quiet-run.sh --` as the command prefix.

| Script | SBCL command after wrapper | CCL command after wrapper | Result |
| --- | --- | --- | --- |
| Portable suites/docs | `sbcl --script tests/portable.lisp` | `ccl --no-init --batch --load tests/portable.lisp` | Both passed: core, review regressions, widgets, lifecycle, 108 demo behavioral tests, ordinary GC tests, demo GC, 165-entry docset with no problems. |
| All GTK native entries | `sbcl --script tests/gtk-smoke.lisp` | `ccl --no-init --batch --load tests/gtk-smoke.lisp` | All 108 rendered/start/stop checks passed on both implementations. |
| Native models/resources | `sbcl --script tests/demo-native.lisp` | `ccl --no-init --batch --load tests/demo-native.lisp` | Both passed: real FFmpeg decoding, native audio start/pause/resume, frame/audio-file deletion, repeated shader reload, bounded resource wrappers, context teardown. Test audio volume is zero. |

The same SBCL/CCL invocation patterns also passed for:

- `tests/smoke.lisp`: seven local example/gallery windows.
- `tests/backend.lisp`: REPL queue, live class migration and per-class rendering.
- `tests/text.lisp`: Unicode glyphs, whole-string metrics and horizontal scrolling.
- `tests/cache.lisp`: font/texture eviction, owned callbacks and loop cleanup.
- `tests/windows.lisp`: normalized drag-out, worker IPC, custom drawing, styling,
  callback response and controller shutdown while a worker starts.
- `tests/review-native.lisp`: primary global cleanup, unchanged-frame suppression,
  changed-frame/resize invalidation and previous-pixel-buffer release.

Weak reachability checks collected all 300 disposed-widget fixtures, all 300
unreferenced detached callback cycles, and all 1,711 widget instances created and
disposed across the 108 demos. These checks do not prove arbitrary user code is
leak-free; application globals and unowned subscriptions can intentionally retain
objects. See lifecycle.md for the ownership contract.

Screenshot inspection covered markup, decimal/right text tabs, the world-map path
walk and composite message rows. It caught clipped row actions, which were fixed
by allocating sufficient row height. Native font warnings for codepoints outside
Noto Sans coverage are a documented limitation, not a claim of complete glyph
coverage.

Linux and Windows execution was not run, per user deferral. Physical pointer
interaction for the drag-out UX and hardware multitouch/trackpad behavior were
not manually checked. Automated normalized-input/IPC tests are not a substitute
for those checks. Nor do passing tests imply exact GTK/Pango/GSK feature parity;
see gtk-demo.md for material adaptation differences.

Changes are in `src/`, `examples/gtk-demo.lisp`, `examples/gtk/`, demo/font assets,
`lui.asd`, `tests/`, `tools/`, `docs/` (including the generated docset), and README.
The repository began with all project files untracked; no commit was created.
