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
`lut.asd`, `tests/`, `tools/`, `docs/` (including the generated docset), and README.
The repository began with all project files untracked; no commit was created.

## LUT rename and Quicklisp registration — task revision 1

The checkout moved from `/Users/jessie/projects/lisp/lui` to
`/Users/jessie/projects/lisp/lut`. Systems/packages, worker bootstrap paths,
examples, documentation and generated docset identity were renamed. No LUI
compatibility system/package is provided.

Quicklisp now has `~/quicklisp/local-projects/lut` as a symlink to the checkout;
`ql:register-local-projects` refreshed its `system-index.txt`. Fresh SBCL and CCL
processes started from `/tmp` loaded LUT through Quicklisp without manually
loading its ASD. The source directory resolved to the new checkout. CCL also
constructed/disposed the browser and confirmed the old package was absent.

All shell checks used `/Users/jessie/.local/bin/quiet-run.sh --`:

- `sbcl --script tests/portable.lisp` and
  `ccl --no-init --batch --load tests/portable.lisp`: passed the core, review,
  widget/lifecycle, 108 demo, GC and 165-entry generated-docset checks.
- Both invocation forms passed `tests/smoke.lisp`, `tests/backend.lisp`,
  `tests/windows.lisp` and `tests/review-native.lisp`: native startup, live reload,
  renamed worker bootstrap/IPC, shutdown and global/frame cleanup passed.
- Regenerated coverage/docset files; `git diff --check` passed. No stale old name
  remains in executable sources, tests, generated docs or ASDF definitions.

The full 108-window native sweep and codec tests recorded above were not repeated
for this naming-only change; focused native/worker checks cover its path/package
risks. Linux/Windows execution remains deferred. No external docset reader/schema
change was required, and no commit was created.

## Phase 7: Wrapped text and rich document blocks

All commands use `/Users/jessie/.local/bin/quiet-run.sh --`.

- `sbcl --script tests/portable.lisp` and
  `ccl --no-init --batch --load tests/portable.lisp`: portable suites, 108 demo
  behaviors, GC checks and regenerated API docset pass. New tests cover visual
  geometry round trips, empty/trailing lines, editing and history, Home/End and
  vertical movement, independent shared-buffer widths, bounded measurement,
  resize, cache invalidation/disposal, paragraph/heading/image metrics, read-only
  policy, image hit testing and captured-selection autoscroll.
- `sbcl --script tests/wrapped-text-native.lisp` and
  `ccl --no-init --batch --load tests/wrapped-text-native.lisp`: macOS native font
  metrics/rendering, block image hit testing, explicit wide/narrow/wide reflow,
  measurement/allocation agreement, selection painting and injected pointer input
  at 100/125/200% scale pass. Captures are written under `/tmp/lut-wrapped-*.png`;
  the 100% narrow rendering was visually inspected.
- `sbcl --script tests/presentation-native.lisp` and
  `sbcl --script tests/text-selection-native.lisp`: existing unwrapped presentation
  and selection native regressions pass.

These checks use explicit allocations and injected input. Physical OS resizing,
manual typing/dragging, Linux and Windows are not verified by this phase. Whole
wrapped-document reflow is not an incremental large-document performance claim.

### Phase 7 review: Font-discovery work bounds (F1, F2)

`tests/font-discovery-native.lisp` instruments a 65,536-character wrapped
read-only document alongside nine labels. On SBCL and CCL, unchanged native
frames perform no additional wrapped-text scans and exactly one window glyph
discovery per layout/render pass. Repeated text measurement in one pass also
performs one discovery. Explicit width changes reuse the glyph set; text edits
and presentation changes each rebuild it once. Removing the view refreshes the
next window glyph set, and disposal releases the view cache.

The test runs through the required quiet wrapper with `sbcl --script` and
`ccl --no-init --batch --load`. Wrapped-text native rendering/input tests,
portable suites and generated-docset validation are rerun on both implementations.
Streaming still rebuilds rows on each append; its potentially quadratic cumulative
cost is explicit in [wrapped text](wrapped-text.md). Append-only row reuse is
future work, rather than a performance claim of this phase.

### Phase 7 review: Distinct-character glyph merging (F3)

Window glyph discovery now deduplicates all sources in an `eql` hash table and
sorts the unique keys once. Merging cached wrapped-view sets no longer performs
a linear list membership search for each code point. The font-discovery regression
also covers 4,096 distinct CJK characters across overlapping wrapped views and
ordinary labels, verifies the exact sorted unique union over four discovery
passes, and checks that the cached view set is neither rescanned nor modified.
This discovery-only case does not depend on CJK glyph coverage in the loaded font.

### Phase 7 review: Font-lookup work bounds (F4)

Normal font lookups and measured runs now share a glyph-set object with `eql`
hash membership. Already-covered strings examine only their own characters.
Missing glyphs form a sorted extension cached for the pass. Font keys contain
the glyph-set object rather than a large code list. Fresh discovery sets are
canonicalized against retained atlases using a full-content signature with an
exact comparison on signature matches; this also reuses atlases across passes
without trusting hash collisions. Glyph-set ownership follows the existing
font cache and its resource sweep, with pass-only memo tables discarded afterward.

The font-discovery native regression exercises a 4,191-code base (including
4,096 CJK characters) over three fresh passes with repeated lookups, native
text measurements and measured runs. Counters require only two membership-set
builds and two atlases, at most 1,000 probes for the short requested strings,
and exactly one base/extension signature traversal per pass. It also verifies
that missing-glyph extensions leave the base set unchanged and atlas identity
survives fresh discovery lists. These checks run on SBCL and CCL; native cache
and indexed-text regressions cover resource eviction and bounded run discovery.

## Phase 8: General scrolling and reveal

All shell checks use `/Users/jessie/.local/bin/quiet-run.sh --`.

- `tests/portable.lisp`, run with `sbcl --script` and
  `ccl --no-init --batch --load`: portable suites, GC, all 108 demo behaviors and
  generated API docset validation pass. New scrolling tests cover geometry,
  clamping, inside-out nested child/range reveal, horizontal unwrapped text,
  wrapped boundaries/newlines/EOF, selection preservation, variable-height image
  blocks, following distance, pause/restore, growth/shrink, resize, model disposal,
  and unsupported/disposed views.
- `tests/scrolling-native.lisp` on SBCL and CCL: light/dark rendering and native
  font metrics, append/follow/pause/search/restore, nested match visibility,
  explicit wide/narrow reflow and injected button input at 100/125/200% scale
  pass. A subsequent actual render/frame preserves following without moving the
  caret. Captures are `/tmp/lut-scroll-{search,tail}-{light,dark}-*.png`; the 100%
  light search and dark end captures were visually inspected.
- Existing wrapped-text, font-discovery, presentation, and resource-cache native
  regressions pass. These include the earlier glyph lookup work bounds.

These are explicit allocation and injected-input checks, not manual typing,
physical OS resizing, wheel/scrollbar acceptance or Linux/Windows verification.
Following deliberately does not change the documented whole-document streaming
reflow cost. Applications choose when to suspend or resume it.

### Phase 8 review: Bounded unwrapped reveal (F1)

Horizontal reveal now uses the target rectangle, page width and current offset,
without querying document-wide text extent. Explicit horizontal extent queries
and `scroll-to` keep their exact full-document clamping behavior. The same
bounded path is used when revealing through an unwrapped text ancestor.

The portable scrolling regression uses 512 lines of 4,096 characters (about
2 MiB). It counts measured characters and horizontal extent queries: cold near-left
matches measure at most 256 characters, a match at column 2,048 measures at most
2,304, repeated matches reuse cached advances, and caller-supplied rectangles
measure no text. All reveal requests perform zero full horizontal extent queries;
selection/cursor and expected offsets are checked. Cost remains proportional to
affected line prefixes through the range endpoints, including chunk rounding.

## Phase 9: Native application adapters

All commands use `/Users/jessie/.local/bin/quiet-run.sh --`.

- `tests/portable.lisp` on SBCL (`--script`) and CCL
  (`--no-init --batch --load`): core suites, 108 demo behaviors, GC and generated
  API-doc validation pass. New adapter tests verify literal URI/path argv,
  copied capabilities, disabled/missing launchers, invalid targets, process and
  nonzero-exit failures, a real printf helper, normal-size isolation from layout,
  native operation routing and validation. No browsers or user files are opened.
- The macOS native test also invokes the actual `open --` error route with a
  guaranteed nonexistent target and checks its nonzero-exit diagnostic; no
  external application is opened.
- `tests/application-native.lisp` on both implementations: actual macOS primary
  and worker maximize/restore, changing normal size while maximized, matching
  restored OS content allocations, and normal-size independence from explicit
  layout pass at 100/125/200%. Worker observations/generations traverse real IPC;
  deterministic packet tests additionally reject stale/malformed state reports.
- Existing `tests/windows.lisp` verifies window/modal IPC and cleanup. Existing
  scrolling native checks guard the phase-8 behavior after startup/IPC changes.

Manual window-manager buttons, actual external default-app launches, and
Linux/Windows execution are not verified. Launching is tested at the argv/process
boundary. Native transitions are asynchronous; normal capture skips transition
frames, then reflects OS-reported sizes/constraints. Persistent settings remain
application-owned.

### Phase 9 review: Legacy pre-open sizing (F1)

Before any normal size is saved or configured, `normal-window-size` falls back
to current `width`/`height`, matching legacy native startup behavior. Once saved,
normal size remains independent of layout allocations. Portable tests cover
pre-open setters, the unsaved layout fallback, and explicit size configuration
followed by a different layout allocation. Native tests construct primary and
worker windows at smaller sizes, update both dimensions with legacy setters
before opening, and verify actual OS/IPC opening dimensions at 100/125/200%
on SBCL and CCL, then retain maximize/restore isolation checks.


## Phase 10 cell grids and key capture

Run the following commands from the checkout, each prefixed with
`/Users/jessie/.local/bin/quiet-run.sh --`:

| Command | Result |
| --- | --- |
| `sbcl --script tests/portable.lisp` | Passed core suites including cell-grid/key-capture behavior, 108 demo checks, ordinary/demo GC and API doc generation. |
| `ccl --no-init --batch --load tests/portable.lisp` | Same portable suites passed. |
| `sbcl --script tests/cell-grid-native.lisp` | Passed primary/worker drawing and normalized key IPC, simulated example, glyph/ancestor clipping pixel checks at 100/200% scale. |
| `ccl --no-init --batch --load tests/cell-grid-native.lisp` | Same native checks passed. |
| `sbcl --script tests/windows.lisp` | Existing native window/dialog IPC, modal input and shutdown checks passed. |
| `sbcl --script tests/commands-native.lisp` | Existing worker command availability, shortcut/context forwarding and teardown passed. |
| `sbcl --script tests/backend.lisp` | Existing REPL queue, live class migration and rendering redefinition passed. |

Full-redraw measurements after two warmup frames, using an 82-by-25 grid with
mixed colours, synthetic bold/underline and Unicode glyphs:

| Implementation | Scale | Primary mean | Worker mean |
| --- | --- | --- | --- |
| SBCL | 100% | 1.275 ms | 1.210 ms |
| SBCL | 200% | 1.395 ms | 1.535 ms |
| CCL | 100% | 12.528 ms | 11.799 ms |
| CCL | 200% | 13.781 ms | 13.148 ms |

The largest primary sample was 36.560 ms on CCL. These bounded macOS timings
measure the grid render call, excluding GPU completion, worker encoding/readback
and transport; they are not end-to-end throughput guarantees. Per-cell GPU
scissor changes were replaced with atlas-quad cropping and separate background
and glyph passes. No retained backing texture/damage cache was added. CCL's
12–14 ms averages use most of a 16.7 ms frame budget at 60 fps, and its peaks
exceed that budget before GPU completion, transport and other UI work. These
results justify an open performance follow-up for a CCL draw-path improvement
or a backing texture cache, with larger/multiple-grid measurements. They do not
establish acceptable interactive CCL performance for terminal-sized grids.

Physical keyboard/pointer UX and Linux/Windows execution remain unverified.

## In-repository interactive feature browser

`lut/demo` now lives in `examples/lut-demo`, with no dependency on the former
sibling checkout. The migration includes that checkout's local catalog and test
edits. After rechecking the complete legacy file inventory, source/test changes
and passing headless/native demo checks, the original checkout was deleted at
the user's request.
The catalog has 36 entries: 22 original examples and 14 foundation examples,
with executable matching source in every Code tab.

Commands below run from the LUT root with
`/Users/jessie/.local/bin/quiet-run.sh --` as the prefix:

| Command | Result |
| --- | --- |
| `make test-lut-demo` | Passed catalog/source evaluation, keyboard selection, resize/reveal, disposal and focused foundation behavior checks. |
| `make -C examples/lut-demo test` | Same headless checks passed from the nested directory. |
| `ccl --no-init --batch --load examples/lut-demo/scripts/test.lisp` | Same headless checks passed on CCL. |
| `make smoke-lut-demo` | Passed native Demo/Code rendering of all 36 entries over 216 frames on SBCL. |
| `ccl --no-init --batch --load examples/lut-demo/scripts/smoke.lisp` | Same 216-frame native smoke passed on CCL. |
| `LUT_DEMO_FRAMES=4 make lut-demo` | Normal Make launch opened and closed successfully. |
| `LUT_DEMO_FRAMES=4 make demo` | Existing GTK launcher still opened and closed successfully. |
| `sbcl --script tests/portable.lisp` | Passed core, GTK, the newly integrated lut/demo suite, GC checks and API generation. |

An absolute invocation of `examples/lut-demo/scripts/test.lisp` from `/tmp`
also passed, checking bootstrap independence from the working directory.
Native smoke saves original and foundation Demo/Code screenshots under `/tmp`;
the foundation grid and source screenshots were visually inspected. Selection
reveal covers the longer catalog without forcing wheel scrolling back to the
selected row at unchanged viewport sizes. Smoke selection does not launch URIs
or open path pickers; headless behavior checks cancel the portable picker.
Physical pointer/keyboard UX and Linux/Windows execution remain unverified.

## Catalog and plain-list scrollbars

Plain list views now share the vertical track/thumb handling used by scroll
containers. The demo catalog exposes a scrollbar on overflow, reserves its
strip from row painting, and preserves selection during dragging/track clicks.
Layout clamps offsets when the viewport or item count changes. Specialized
tree/table/model views retain their existing geometry and behavior.

With `/Users/jessie/.local/bin/quiet-run.sh --` as the command prefix:

- `make test-lut-demo` passed catalog dragging, track clicks, outside release,
  selection/source preservation and wheel scrolling alongside all demo checks.
- `ccl --no-init --batch --load tests/portable.lisp` and
  `sbcl --script tests/portable.lisp` passed, including plain-list geometry,
  shrinking content, nested parent scrollbar capture, core/demo/GC suites and
  API generation.
- `sbcl --script tests/list-scrollbar-native.lisp` and the corresponding
  `ccl --no-init --batch --load tests/list-scrollbar-native.lisp` passed thumb/
  track pixel checks, device-scaled dragging, selection preservation and hiding
  after content fits, in both themes at 100/125/200% scale.
- `make smoke-lut-demo` passed all 36 Demo/Code pairs over 216 native frames;
  its foundation screenshot was inspected for the visible catalog thumb.
- `sbcl --script tests/scrolling-native.lisp` passed existing container scrolling,
  nested reveal and follow-end regressions at 100/125/200% in both themes.

Physical pointer UX and Linux/Windows execution remain unverified.

Dropdown regression follow-up: closed dropdowns are excluded from plain-list
scrollbar eligibility. A new dispatch regression failed before the fix, then
passed on SBCL and CCL as part of `tests/portable.lisp`: clicking the arrow/right
edge opens dropdowns with both 4 and 20 options without scrollbar capture. The
20-option popup remains scrollable, and thumb dragging neither selects an
option nor closes the popup. `make test-lut-demo` and `make smoke-lut-demo` also
passed after the fix. This is a targeted eligibility change; catalog and popup
selection-list subclasses keep their scrollbar support.

## Configurable newest-record history and synchronous launch errors

Recorded 2026-10-26 on macOS ARM64, SBCL 2.6.9 and CCL 1.13 ARM64 prerelease,
on branch `feat/migration-foundations`. This work changes LUT; Argon's settings
and production GUI were not changed.

`history-retain-newest-p` defaults NIL on shared buffers and standalone entries/
text views. With T and both limits positive, each destination history stack may
retain its newest oversized record alone, including undo/redo inverses. Record
count and character budgets remain configurable. Zero limits still disable
retention, ordinary older records still evict, and overflow feedback keeps its
existing payload and timing. Raising a range budget is not equivalent to
preserving an application's snapshot-history policy.

`start :wait t` now signals primary controller/render/cleanup errors on the
caller after native teardown, even without a frame bound. The same condition
object crosses the main-thread bridge. CCL explicitly carries the synchronous
policy to its initial process. Asynchronous starts, direct interactive `run`,
worker-handle routing and application ownership of widget trees are preserved.

All noisy commands used the local quiet wrapper required by the session:

- `sbcl --script tests/portable.lisp` and
  `ccl --no-init --batch --load tests/portable.lisp`: passed core behavior,
  history/selection/presentation, all 108 demo behaviors, the demo browser,
  GC checks and regenerated/validated 427-entry API docset. New history checks
  cover shared/standalone entry/text views, peer undo/redo selections, opt-in
  oversized retention, unchanged overflow feedback, no-op edits, read-only and
  validation failures, configurable larger budgets/counts, policy changes and
  zero limits. GC additionally verifies 25 disposed views are collected while
  their buffer keeps an oversized history record.
- `sbcl --script tests/start-errors.lisp` and
  `ccl --no-init --batch --load tests/start-errors.lisp`: passed native unbounded
  tick errors, final-frame render errors, cleanup errors, cross-thread condition
  identity, closed native contexts/controller state and successful relaunch.
  Injected runner/worker contracts also verify return values, asynchronous error
  recording and immediate secondary-window handles even with WAIT T.
- `sbcl --script tests/windows.lisp` and
  `ccl --no-init --batch --load tests/windows.lisp`: passed native worker IPC,
  modal/modeless behavior, live objects, nested dialogs and teardown regressions.
- In the unchanged Argon checkout, `make test-lut-probe`: passed all seven groups
  and 72 assertions against LUT's unchanged default history policy.
- `git diff --check`: passed. Generated docset index changes include renumbering
  caused by the new exported accessor.

The first new history test had an incorrect originating-view redo-caret
expectation; it was corrected to the existing invoking-peer selection contract.
The first CCL native error run failed because the policy binding did not cross
its initial-process bridge. The implementation was fixed and both native and
portable suites rerun successfully; neither failure is treated as passing evidence.

Linux/Windows native execution, physical input, full 108-window native rendering
and packaging were not run for these history/launcher changes. No cell-grid or
terminal feature expansion is included, and Argon must opt into the new policy
when its editor adapter is ready.
