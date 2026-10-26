# Acceptance and review status

The project remains unfinished against the complete requested scope. This file
distinguishes verified improvements from full upstream or platform parity.

| Finding | Change / remaining work |
| --- | --- |
| F1 | 108/108 registry entries now have runnable adaptations and individual behavioral tests. Native smoke checks cover every entry. Older controls have been expanded; see the generated coverage and demo guide for implemented behavior and explicit differences. Exact upstream parity is not claimed. |
| F2 | Native worker-process windows and direct native dialog creation implemented. The parent retains all objects, callbacks and rendering; workers display in-memory PNG frames and forward input. Automated native IPC, custom drawing and callback round trips pass. Dialogs open directly in OS windows; popovers and menus remain overlays. The primary controller services input; teardown closes remaining workers. |
| F3 | Implemented initial widget coverage. Added dropdown/combo, spin, radio/toggle/switch, tabs, menus/popovers/tooltips, tree/table/columns, grid/paned/stack/header, choosers, image and expander classes with initial behaviors. The demo suite now includes virtual list models up to 16M items, hierarchical settings and editable table cells. This is not full GTK/JavaFX parity. |
| F4 | Shared entry editing context menu, pointer placement, outside click/Escape dismissal and action routing implemented; core regressions pass. |
| F5 | Root class/state rules, local state styles, inherited disabled state, font/border/radius and styled row/line/caret/padding metrics implemented. The demos use validated style data instead of CSS; constraint demos use portable Classowary. |
| F6 | Generated API includes inherited initargs/defaults/types, every exported function/macro contract and example, plus activate/change/tick/context payloads. Generator fails for missing contracts or unreadable examples. Added REPL and styling guides. |
| F7 | Implemented, with the accepted raylib limitations. Bundled OFL Noto Sans; explicit Unicode codepoint loading, whole-string MeasureTextEx/DrawTextEx, selection/caret metrics and horizontal/vertical text viewports implemented. Complex shaping, bidi, pair kerning and IME remain limitations of the raylib text path. |
| F8 | Fractional and zero-width range normalization fixed and regression tested. |
| F9 | Per-class render methods, retained-instance DEFWIDGET redefinition/migration, named callback redefinition, queued ASDF reloads and source workflow documented and tested. Worker rendering also stays in the parent, so custom REPL-only classes/closures work there. |
| F10 | Installed upstream CCL ARM64 prerelease and verified core plus native windows, with a CCL macOS main-thread bridge. Linux/Windows runtime checks deferred by explicit user direction. |
| F11 | Generated setter type checks and extensible VALIDATE-SLOT invariants reject invalid live edits before assignment. Numeric ranges, cursor bounds, theme/state metrics and color chooser channels validated. |

## Remaining acceptance gaps

- Continue upstream feature parity beyond the runnable 108-demo adaptations; especially complete OpenType shaping and broader VFL/path syntax (see gtk-demo.md).
- Bring the six local example adaptations to feature parity (for example analog clock and richer editor).
- Expand widget behavior, data models and application text editing.
- Manually check pointer input, drag-out UX and platform integration.
- Verify Linux and Windows when requested; these paths are not asserted to pass.
- Review deployment packaging and large-window transfer performance: unchanged frames now skip compression/transfer, but GPU readback and comparison still occur.

Native smoke checks exercise startup/render/shutdown. The IPC check additionally
verifies original custom drawing closures, parent state updates and callback
routing through the worker pipe. Normalized-event tests cover interactions;
they do not substitute for all manual desktop input checks.

## Object lifetime direction

Added idempotent subtree disposal, explicit callback disconnection, owned event
bindings and owned cancellable UI jobs. Removal clears focus/capture/drag and
recognizes overlays. Closed native windows clear global registry and handle
references; loop teardown closes remaining workers and cancels pending work.
Native caches evict stale/unused fonts and textures after frame drawing. Weak
reachability tests cover 300 disposed widgets and 300 detached callback cycles.
See [lifecycle](lifecycle.md) for the ownership contract and native checks.

## Follow-up cleanup review

F12–F14 are implemented: primary disposal clears both global roots, registry
lookups take the registry lock, and unchanged remote pixels skip PNG/base64
encoding. The native regression checks disposal and change/resize invalidation.
The previous pixel buffer is cleared when its remote handle closes.

The coverage table (F15) is generated from the registry and checked byte-for-byte
before the suite runs; the registry must match the pinned 108-name manifest.
