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

- [x] **Tab closing and richer tab presentation — delivered.** Vetoable close
  requests detach pages without imposing disposal/dirty-buffer policy. Generic
  string badges follow pages through transfer; close affordances share header
  geometry with pointer hit testing.
- [ ] **Cross-window drag/transfer — partially delivered.** Keyboard and
  programmatic transfers use explicit controller registration, source-owned
  sessions and receiving-root logical coordinates without serializing widgets or
  closures. Removal, disposal and worker teardown release references. Physical
  pointer transfer remains pending: source-window mouse capture is not routed
  to peer screen rectangles, so registration alone does not enable it.
- [x] **General autoscroll and keyboard drag operations — delivered.** Frame-based
  edge scrolling for scroll/list/model views and notebook headers; explicit
  keyboard initiation, target cycling/aiming, movement, commit and cancellation.
- [x] **Reusable split/drop zones — delivered.** Predicate/commit surfaces and
  side-based paned composition through public drag/drop APIs. Workspace trees,
  empty-pane collapse and persistence remain application policy.
- [x] **OS drag-and-drop adapter — delivered with limited scope.** Separate
  capability query and MIME delivery boundary; raylib supplies incoming file
  paths (including worker IPC). Arbitrary MIME, outgoing drags and OS hover
  negotiation remain unsupported; in-process payloads do not imply OS support.

See [advanced interaction](advanced-interaction.md) and
`lut-examples:advanced-interaction`. Portable behavior, closure/peer/session GC,
light/dark native rendering, 200% injected peer-event transfer, keyboard return,
OS path IPC and worker teardown pass on macOS. OS allocation/Unicode decoding
and cleanup are tested at the adapter boundary. Injected peer events verify
routing and IPC, not physical cross-window pointer delivery. Physical pointer
transfer is unsupported pending capture-aware routing and manual acceptance.
Physical Finder drops and Linux/Windows native behavior remain unverified.

## Phase 6: Content measurement and responsive layout (G2)

- [x] **Content measurement and constraints — first slice delivered.** Public minimum/natural size
  queries, height-for-width measurement, independent size requests and expansion
  constraints. Keep allocated geometry separate from content requests and retain
  existing explicit-size layouts for compatibility.
- [x] **Measured boxes and flow layout — delivered.** Opt-in containers that allocate measured
  children and wrap controls into rows. Application breakpoints and saved panel
  layouts stay outside LUT.

See [measured layout](measured-layout.md) and `lut-examples:measured-layout`.
The delivered measurement covers basic labels/buttons, measured/flow containers
and explicit fallback hints for other widgets; editor/document reflow remains
Phase 7 work. Portable behavior and native font/render/input checks at explicit
wide/narrow/wide allocations and 100/125/200% scale pass. A separate macOS OS-window
resize check intermittently reported 680 after requesting 340 and remains
unresolved; these checks do not establish native window-size semantics.
Linux/Windows native behavior remains unverified.

## Phase 7: Wrapped text and rich document blocks (G1, G3)

- [x] **Selectable/editable wrapped text (G1) — delivered.** Shared visual-line geometry for
  rendering, hit testing, cursor navigation, selection and scrolling. Support
  composers that grow to a configured height limit using Phase 6 measurement.
  Paint-only label wrapping is not completion of this item.
- [x] **Variable-height document blocks (G3) — delivered.** Paragraph spacing, heading metrics
  and block images whose size is independent of a global line height. Keep
  Markdown parsing, link routing and document models in applications.

See [wrapped text](wrapped-text.md) and `lut-examples:wrapped-text`. Character
wrapping preserves whitespace; shaping, bidi and IME remain unsupported.
Portable suites and macOS native font/render/injected-input checks pass on SBCL
and CCL at explicit wide/narrow/wide allocations and 100/125/200% scale. Physical
OS resizing and Linux/Windows native behavior remain unverified; see
[verification](verification.md).

## Phase 8: General scrolling and reveal (G4)

- [x] **Public scrolling geometry — delivered.** Query content extent/page size and reveal
  child rectangles or text ranges after layout, including nested containers.
- [x] **Optional follow-end behavior — delivered.** Preserve a requested end relationship as
  streaming content grows; applications decide when to follow, suspend it for
  search or user scrolling, and restore it. Do not bake chat policy into LUT.

See [scrolling and reveal](scrolling.md) and `lut-examples:scrolling`. The public
operations use allocated logical coordinates and are immediate after layout.
Following is explicit application policy. Whole-document wrapped reflow remains
the Phase 7 implementation; this phase does not claim incremental appends.
Portable and macOS native font/render/injected-input checks pass on SBCL and CCL
at explicit wide/narrow allocations and 100/125/200% scale. Physical OS resizing,
manual interaction, and Linux/Windows native behavior remain unverified.

## Phase 9: Native application adapters (G6, G7)

- [ ] **Default-application launching (G6).** Opt-in URI/file launching with native
  adapters, portable fallback and explicit availability/error reporting. The
  application decides which targets to launch; document links continue emitting
  application targets without opening them automatically.
- [ ] **Native window state (G7).** Query and set maximized/restored state and
  preserve normal window size separately from allocated content geometry,
  including worker IPC. Settings persistence stays application-owned.

## Phase 10: Terminal integration boundary (G5)

- [ ] **Terminal extension or native host adapter.** Define how an application
  embeds a terminal alongside LUT widgets, including focus, input, clipping,
  resizing and disposal. Choose an explicit supported backend boundary rather
  than treating a drawing area as a native-widget host. PTY/shell/process policy
  stays outside toolkit core.

The G1–G7 references come from the Agent Duet UI review. Text shaping, bidi, IME
composition and accessibility remain separate unsupported capabilities recorded
in Phase 4; these phases do not implicitly implement them.

## Delivery rule

For each item, add the reusable API, focused behavior/lifecycle tests, an example
and API documentation. Promote demo code deliberately; a working demo is not a
supported library contract. Update this file when an item is delivered or its
scope changes. Keep native and manual verification limits visible.
