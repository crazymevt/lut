# LUT Demo

The interactive feature browser lives in this repository as the `lut/demo` ASDF
system. It has a resizable feature list on the left and **Demo** / **Code** tabs
on the right. Browse controls, views, layouts and reusable foundations, including search,
compact activity feedback, image toggles, and date/time pickers in 12/24-hour modes.

The Demo tab is interactive. The Code tab displays the exact builder form used
for that example, wrapped as a function accepting its containing window. Code is
an editable scratch view: select and copy it with Ctrl/Cmd+C. Edits do not execute
or change the demo and reset when you choose a different feature.

## Run

Install SBCL, Quicklisp and LUT's native raylib dependencies as described in
[the LUT README](../../README.md). From the repository root:

```sh
make lut-demo
```

The existing `make demo` command still opens the GTK adaptation browser.
Alternatively, run `make run` from this directory. No sibling `lut-demo` checkout
or separate ASDF registration is required. The bootstrap explicitly loads this
checkout's `lut.asd`, so an older sibling installation is not used.

The former `../lut-demo` checkout was deleted after verifying this migration,
including preservation of its local source and test edits. If you have another
copy of the old project, do not load its `lut-demo` system alongside `lut/demo`
in the same Lisp image:
both define the `lut-demo` package and its functions, so loading one can
redefine the other's implementation. Use only `lut/demo` for this browser.
If the old system is already loaded, start a fresh Lisp image before loading
the new system.

From a REPL:

```lisp
(ql:quickload '("lut/demo" "lut/raylib"))
(lut-demo:main)
;; Or load just lut/demo and build a tree without native libraries:
(lut-demo:make-app)
```

The left catalog has a vertical scrollbar whenever its rows exceed the viewport.
Drag its thumb or click the track to browse without changing the selected demo.
Wheel scrolling remains available; keyboard selection reveals the chosen row.

Drag the pane divider to resize. Use Tab to move focus, Up/Down to select a
feature, and Left/Right on the tab bar to switch tabs. Long demos and source
scroll with the mouse wheel. Selecting another feature disposes its predecessor
and resets its state, while retaining the current Demo/Code tab. The theme and
UI scale examples change the whole browser and remain in effect across feature
changes. F12 releases the cell-grid example's key capture.

To run a copied builder, load `lut/raylib`, evaluate the displayed lambda, call
it with a `lut:window`, add its returned widget to that window, and call
`lut:start`. The builder forms use public LUT APIs; they do not depend on private
demo helpers.

## Foundation examples

| Foundation | Catalog entries |
| --- | --- |
| Shared actions | Shared commands (two buttons, availability and F6) |
| Phase 1: text and history | Shared text and history; indexed text and selection (20,000 lines) |
| Phase 2: presentation | Document presentation, links and caret suggestions |
| Phase 3: data models | Virtual data and selection (1,000,000 rows); editable model table; keyed tree model |
| Phase 4: platform | UI zoom, context menus with separators and portable path picking |
| Phase 5: composition | Reordering, close vetoes, badges and notebook page transfer |
| Phase 6: measurement | Measured prose and wrapping flow controls |
| Phase 7: wrapped text | Styled document blocks and a bounded growing composer |
| Phase 8: scrolling | Append, pause, reveal and resume follow-end |
| Phase 9: adapters | Launcher capabilities, explicit URI launch, maximize/restore |
| Phase 10: cell grids | Fixed cells, raw key/text capture, F12 release and cell selection/copying |

No example writes files or starts a shell. The path picker reports a path
without reading its contents. Opening a URI or changing native window state
requires clicking its explicit action. The grid is a simulated console surface,
not a terminal emulator. See the [cell-grid guide](../../docs/cell-grid.md) for
Unicode and CCL performance limits and the open rendering follow-up.

## Verification

From the repository root:

```sh
make test-lut-demo   # Headless catalog/source and foundation behavior checks
make smoke-lut-demo  # Render every Demo and Code tab, then close
LUT_DEMO_FRAMES=4 make lut-demo  # Bound the normal launch path
```

From this directory, `make test` and `make smoke` run the same checks. Headless
tests need ASDF and LUT core, without loading raylib or Quicklisp. Native smoke
needs the normal runtime dependencies. Scripts resolve the checkout from their
own paths and can also be invoked with absolute paths from another directory.
`SBCL` selects the SBCL executable for the Make targets.

For CCL, use `ccl --no-init --batch --load` with `scripts/test.lisp`,
`scripts/smoke.lisp` or `scripts/run.lisp`. Shell verification in this workspace
uses `/Users/jessie/.local/bin/quiet-run.sh --` before each command.

Smoke coverage follows the catalog length rather than a fixed example count.
It saves `/tmp/lut-demo-demo.png`, `/tmp/lut-demo-code.png`,
`/tmp/lut-demo-foundations.png` and `/tmp/lut-demo-foundation-code.png` for visual
inspection. Selecting examples during smoke does not invoke external launch or
path-picker actions. Behavioral tests cover commands and teardown, shared undo,
indexed selection, suggestion cleanup, lazy rows, edited/sorted cells, tree
expansion, context menus, path-picker cancellation, zoom, close veto/transfer,
measurement, wrapping, follow-end and grid capture/copying.

## Styled text

Open **Views / Styled text** for an editable Lisp snippet with live demo syntax
colors, bold keywords, italic comments, mixed sizes and an underlined TODO marker.
Test selection, copying, undo/redo and scrolling. Toggle Colors, Line numbers,
Bold, Italic or Mixed sizes independently, or Reset the sample. Comments use
14 pixels, keywords 18, strings 20 and numbers 24; unstyled text uses 16.
The 34-pixel line spacing leaves room for the larger glyphs.
The Code tab contains the complete builder and small lexer. The application
supplies style runs/decorations; LUT supplies the text widget and rendering.
