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
- [ ] **Selection and navigation behavior — next.** Word/line navigation and selection,
  double/triple click, caret reveal and autoscroll during selection. Use the
  same geometry for drawing and hit testing.

## Phase 2: Reusable document presentation

- [ ] **Styled text runs and decorations.** Font/color spans, underlines,
  selection, gutters and annotations with explicit invalidation. Applications
  supply syntax/diagnostic data; LUT does not supply a language server or parser.
- [ ] **Read-only document view.** Selectable formatted text, links, embedded
  images and hit testing. Navigation/history and markup parsing should remain
  separable models/adapters, not an Argon documentation tab.
- [ ] **Anchored suggestion/help surfaces.** Reusable caret/rectangle-anchored
  popovers with keyboard selection and dismissal. Completion candidates and
  parameter/documentation lookup remain application data.

## Phase 3: Data model and selection foundations

- [ ] **Virtualized list model.** Extract reusable model/viewport contracts from
  demo-only implementations; avoid allocating one widget/string per row.
- [ ] **Selection models.** Single/multiple/range selection with keyboard and
  pointer behavior independent of a particular list/tree/table.
- [ ] **Sorting/filtering and tree models.** Stable identity and explicit change
  notifications; preserve valid selection through model changes.
- [ ] **Table cell presentation/editing.** Reusable column/cell factories,
  navigation and edit commit/cancel hooks. Database access stays outside LUT.

## Phase 4: Platform and application integration

- [ ] **Native menus.** Adapt command labels, enabled state and shortcuts to
  platform menus; preserve the existing drawn menu fallback.
- [ ] **Native file/folder/save pickers.** Keep a portable picker contract and
  existing fallback; return paths without embedding file-save policies.
- [ ] **Coordinated UI scaling.** Scale layout, fonts, hit testing and scroll
  geometry together. Application preference persistence remains external.
- [ ] **Text/platform capability audit.** Track shaping, bidi, IME and accessibility
  gaps explicitly. Choose backend strategies before claiming support. Verify
  Linux/Windows when requested; current macOS checks do not establish those ports.

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
