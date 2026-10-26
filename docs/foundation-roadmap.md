# Reusable toolkit foundation roadmap

This records the remaining building blocks identified while comparing LUT with
Argon. It is an implementation sequence, not a claim of feature parity. Argon's
language tooling, REPL/debugger protocols, Git, databases, projects, assistants
and workspace policies stay outside LUT.

## Delivered

- [x] In-window drag sessions, payloads, acceptance/commit hooks, cancellation,
  lifecycle events and rendering feedback.
- [x] Opt-in notebook reordering and grouped page transfer.
- [x] Tab overflow navigation, selection reveal and drag edge scrolling.
- [x] Independent input modifiers and base keys, preserved through worker IPC.
- [x] Reusable commands, context predicates, shared control/shortcut bindings,
  enumeration and disposal.

See [drag-and-drop](drag-and-drop.md), [commands](commands.md) and
[ownership](lifecycle.md) for the delivered contracts and current limits.

## Phase 1: Shared text and view foundations

- [x] **Shared text buffers — delivered.** Separate text/history from views;
  support range edits, shared undo/redo, revisions, edit notifications and
  read-only policy. Keep each view's cursor, selection and scroll independent.
  Verified edits from either view, position remapping, shared history, validation,
  disposal and collection without retaining destroyed views. Native peer-window
  editing and rendering checks pass; see [text buffers](text-buffers.md).
- [x] **Range-based shared undo/redo history.** Store edit start, removed text,
  inserted text and numeric selection data rather than full-buffer copies.
  Verified multiple small-edit undo/redo steps on a 1 Mi-character buffer larger
  than the default history budget; limits now count changed-text payload.
- [x] **Indexed text and viewport geometry — delivered.** Balanced chunk storage
  replaces flat-string range edits. Shared line/range queries, caret rectangles,
  point hit testing and visible-line iteration drive drawing, navigation and
  wheel extents. Verified AVL balance/sharing, Unicode character offsets, EOF
  edits and geometry/cache invalidation; the 50,000-line example and native
  peer-window regressions pass on macOS. Full-string getters, validation hooks
  and change listeners still materialize snapshots. First horizontal queries
  far into an unmeasured line measure its prefix; repeated queries cache it.
  Linux/Windows checks remain unrun. See [text buffers](text-buffers.md).
- [x] **Standalone history migration and budget feedback — delivered.**
  Standalone entries/text views now retain changed-range records with the same
  cursor/selection and undo/redo behavior as snapshot history. Budgets count
  removed plus inserted text. Owners emit `:history-overflow` for a single
  oversized record with positive limits; zero limits disable retention silently.
  Verified snapshot-oracle comparisons, 1 Mi-character small-edit history,
  validation failures, budget boundaries and the native example on macOS.
  Standalone edit storage remains flat strings. See [text buffers](text-buffers.md).
- [x] **Selection and navigation behavior — delivered.** Portable word/run and
  logical-line navigation/selection, Shift extension, preferred pixel X,
  double/triple-click unit dragging, shared caret reveal and time-based selection
  autoscroll. Drawing and hit testing use the same geometry. Verified read-only
  and independent shared views, stationary-pointer reveal edges, capture/GC
  cleanup and native worker click/timestamp/modifier IPC on macOS. Word rules
  are character runs, not Unicode word breaking or language syntax; logical
  lines remain unwrapped. Linux/Windows checks remain unrun. See
  [text selection](text-selection.md) and `lut-examples:text-selection`.

## Phase 2: Reusable document presentation

- [x] **Styled text runs and decorations — delivered.** Per-view font/color
  spans, backgrounds, selection, underlines, gutter markers and annotations with
  explicit invalidation and edit remapping. Rendering and hit testing share run
  metrics; applications supply syntax/diagnostic data, not LUT.
- [x] **Read-only document view — delivered.** Selectable formatted text,
  application link targets, inline images and hit testing. Programmatic refresh
  remains available. Parsing, routing, navigation/history and rich serialization
  stay in application models/adapters. Text uses unwrapped logical lines and
  explicit line height; this is not an HTML/paragraph layout engine.
- [x] **Anchored suggestion/help surfaces — delivered.** In-window caret/root-
  rectangle anchoring with flip/clamp/reposition, keyboard/pointer candidate
  selection, dismissal and focus/lifetime handling. Acceptance emits original
  application data; candidate ranking and documentation lookup remain external.

See [text presentation](text-presentation.md) and
`lut-examples:document-presentation`. Portable behavior, GC and native light/dark
rendering/interaction checks pass on macOS. Linux/Windows remain unverified.

## Phase 3: Data model and selection foundations

- [x] **Virtualized list model — delivered.** Reusable lazy/vector data models
  and fixed-height viewport contracts, promoted from the demo approach. Views
  request only visible rows, without allocating a widget/string for every row.
- [x] **Selection models — delivered.** Independent single/multiple/range keyed
  selection with shared keyboard/pointer handling and optional multi-view sharing.
- [x] **Sorting/filtering and tree models — delivered.** Stable keyed projections,
  explicit change notifications, tree expansion and retained hidden selection.
  Projection sorting/filtering and tree indexing build metadata eagerly; they
  do not claim lazy database queries or unbounded trees.
- [x] **Table cell presentation/editing — delivered.** Reusable column/cell
  factories, row/column navigation and one active entry editor with application
  setters and commit/cancel events. Database access stays outside LUT.

See [data models](data-models.md) and `lut-examples:data-models`. The opt-in model
views preserve the existing list/tree/table APIs. Portable, GC and native
light/dark rendering/input checks pass on macOS, including a million-row lazy
model. Linux/Windows remain unverified.

## Phase 4: Platform and application integration

- [x] **Native menus — delivered.** Primary macOS AppKit command menus adapt
  labels, enabled state and shortcuts; workers/other platforms retain drawn
  menus. Main and right-click context menus accept noninteractive separators.
- [x] **Native file/folder/save pickers — delivered.** Path-only request handles
  choose native AppKit panels or the portable browser/entry fallback. Existing
  pickers remain available; no file-save or application persistence policies.
- [x] **Coordinated UI scaling — delivered.** Logical UI coordinates share root
  rendering, clipping, font-atlas and input transforms, including worker frames.
  Application zoom/preference persistence stays separate from OS backing DPI.
- [x] **Text/platform capability audit — delivered.** Queryable status and a
  documented strategy for shaping, bidi, IME composition and accessibility.
  These text/accessibility features remain unsupported; audit completion does
  not claim their implementation. Linux/Windows remain unverified.

See [platform integration](platform-integration.md) and
`lut-examples:platform-integration`. Portable behavior, GC, macOS menu updates,
native modal cancellation, 100/125/200% rendering/input and scaled worker checks
pass. Human acceptance in native pickers and Linux/Windows native checks have
not been exercised. Native macOS menus/pickers are primary-context adapters;
secondary workers intentionally use portable menus/pickers.

## Phase 5: Advanced interaction and composition

- [ ] **Tab closing and richer tab presentation.** Close requests, application
  veto hooks and generic badges; dirty-buffer decisions remain application code.
- [ ] **Cross-window drag/transfer.** Explicit controller ownership, coordinates,
  cancellation and cleanup across native workers, without serializing closures.
- [ ] **General autoscroll and keyboard drag operations.** Extend beyond the
  current notebook header edge scrolling.
- [ ] **Reusable split/drop zones.** Compose panes through public drag/drop APIs.
  Do not encode an editor's workspace tree, project layout or session persistence.
- [ ] **OS drag-and-drop.** A separate platform/MIME adapter with explicit
  capabilities; in-process payload support is not OS interoperability.

## Delivery rule

For each item, add the reusable API, focused behavior/lifecycle tests, an example
and API documentation. Promote demo code deliberately; a working demo is not a
supported library contract. Update this file when an item is delivered or its
scope changes. Keep native and manual verification limits visible.
