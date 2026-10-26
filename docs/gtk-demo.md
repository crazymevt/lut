# GTK demo suite

The registry covers all 108 C demo entry points in GTK 4.20.2. These are portable
LUT adaptations: each builds a working widget tree and has a named behavioral
test. They share models and drawing utilities instead of copying GTK internals.
They are not exact replicas of GTK, Pango, GSK, GIO or OS integration.

```lisp
(ql:quickload '("lut/raylib" "lut/gtk-demo"))
(lut:start (lut-gtk-demo:browser))
;; Or choose a builder directly:
(defparameter *example* (lut-gtk-demo:demo "constraints_interactive"))
(lut:start *example*)
(lut-gtk-demo:demo-names) ; sorted list of all 108 names
```

The fuzzy-search browser opens selections as native secondary windows while the
controller remains active. Every demo is placed in a scrollable viewport so
controls below the current window height remain reachable. Edits to builders
affect the next instance; re-evaluated CLOS methods affect existing instances.
See [REPL development](repl.md) for threading, callback replacement and reloads.

## Coverage and checks

[Coverage](../examples/gtk-demo-coverage.md) gives each source entry's implemented
behavior. It is generated from `*demos*`, not maintained by hand. A registry entry
holds name, description, factory and behavioral test. `test-demos` requires the
exact 108-name upstream manifest, checks the coverage file, builds each tree,
allocates it, exercises its behavior and disposes it even on a failed assertion.

```lisp
(asdf:test-system "lut/gtk-demo-tests")
;; After intentionally changing descriptions/entries:
(lut-gtk-demo::write-coverage)
```

Headless behavioral tests exercise normalized input, model changes, numerical
invariants, error handling and ownership. Native smoke checks render every demo;
they do not prove every visual detail or hardware gesture. `tests/demo-native.lisp`
loads a real media fixture, renders decoded frames, checks cleanup and repeatedly
recompiles shaders. `lut/gtk-demo-gc-tests` checks that disposed widgets from every
demo become unreachable, including callback cycles.

## Applications, dialogs and editing

`application_demo` provides New/Open/Save, dirty status, menu actions and Ctrl+N,
Ctrl+O, Ctrl+S. File operations use the path field and ordinary Lisp streams.
`assistant` validates required input, records preferences, presents confirmation,
then runs progress with cancellation. `builder` consumes an allowlisted data tree;
it never evaluates supplied Lisp. `shortcuts` displays grouped help;
`shortcut_triggers` recognizes chords and an ordered G G sequence with timeout.

`dialog` edits two fields with Apply/Cancel, retaining only committed values.
Drag the dialog title inside its root or past the root edge to detach it. Response
callbacks locate the current host, so detachment preserves their behavior.
`expander` exposes an editable detailed error report. `errorstates` styles invalid
input and gates confirmation. `infobar` has independent informational/warning/error
responses. `read_more` and `revealer` expose collapsed content; `sidebar` selects
stack pages. `stack` retains independent page state and animates slide positions.

`entry_undo` and `textundo` preserve text and selection snapshots, support undo/
redo and branching edits, and expose enable/disable. Undo is bounded by both
snapshot count and character budget; disposal clears both histories.
`entry_completion` filters case-insensitive prefixes, including non-ASCII words.
`password_entry` masks display text, supports reveal and prevents copying hidden
text through keyboard/context actions. CapsLock indication tracks received key
presses; it does not query the initial OS toggle state. `tagged_entry` creates
and disposes removable tag controls. `textview` shares edits between two views;
`textscroll` follows an appended log with a manual-scroll mode.

`combobox` demonstrates icon labels, hierarchical choices and free input.
`spinbutton` parses hexadecimal input and formats numeric time/month models.
`scale` supports fractional ranges and mark snapping. `tabs` is the upstream
text-tab-stop example, with left/decimal/right alignment, not a notebook alias.

## Data models and lists

`list_store` maintains mutable bug rows, completion and sorting. `editable_cells`
edits actual selected model cells and adds/removes rows. `tree_store` groups
holiday contacts; settings demos traverse/edit hierarchical and flattened data.
`filtermodel` computes derived/searchable rows. `listbox` uses composite message
widgets with timestamps and favorite actions; filtering and sorting dispose old
row trees before rebuilding. `flowbox` reflows hundreds of color tiles.

The virtual model creates only viewport display strings. Color/Unicode/weather/
word demos retain model functions rather than millions of widget instances.
`listview_colors` supports 16M RGB values and selection modes; `listview_ucd`
provides codepoint jumping. Weather is deterministic sample data, not a network
forecast. Clock offsets are examples, not a timezone/DST database. Word lists can
be loaded from a local dictionary. File browsers navigate the real filesystem;
editable icons support rename/reorder/add/delete. The application launcher opens
LUT demos rather than invoking arbitrary OS desktop applications.

`iconscroll` measures bounded virtual scrolling. These examples do not reproduce
GTK's full GListModel, sorting/filter signal protocol, accessibility or OS launch
registry.

## Layout and appearance

The four constraint examples use Classowary. Simple constraints maintain total
width, minimum widths and a spacer. Interactive constraints update the width
ratio while dragging. The VFL example accepts its documented equal-width
production, `H:|-[button1(==button2)]-12-[button2]-|`; it is not a general VFL
parser. Builder constraints accept `(:gap 12 :ratio 1)`, with gap 0..200 and ratio
0.2..5. Invalid input leaves the prior layout intact.

`fixed` projects rotating cube faces; `fixed2` controls rotation/scale. Custom
layout examples interpolate grid/circle positions and place icons on an
arrow-rotated sphere. `panes` has nested draggable dividers and collapse/equalize.
`sizegroup` shares label widths. Overlay examples position actions or decorative
labels independently of an editable document. Transparency uses a shader to blur
image regions behind translucent overlays.

`themes` previews inherited light/dark palettes and local overrides.
`theming_style_classes` uses CLOS subclasses as semantic style selectors, with
hover/pressed/disabled states. `css_basics` edits validated LUT token data, not
CSS. The other CSS examples reproduce accordion, shadow, orbiting image,
background and blend behaviors through portable drawing operations and GLSL.

## Drawing, paths and text

Painting canvases record pointer strokes and expose brush/ink/clear controls.
Games implement playable Minesweeper, a legally shuffled sliding puzzle, and peg
solitaire with move validation, reset and undo where applicable. The sliding
puzzle uses numbered tiles rather than GTK's image-tile presentation.

Graphics examples include interacting gear geometry, projected GL-area geometry,
editable fragment shaders, moving fish, image orbiting/scaling/filtering, busy
indicators and frame benchmarks. These use raylib's renderer rather than GSK;
`glarea` and gears demonstrate projected geometry, not GTK's original GL scene.

Path demos parse and flatten M/L/H/V/C/S/Q/T/Z commands (relative or absolute),
including implicit repetitions and smooth-curve reflection. They draw/edit paths,
animate markers, detect sweep intersections, place text along paths and test maze
corridor distance. Arc commands and the complete GSK path/stroke API are not
implemented. Walk/sweep use the original complex CC0 world-map data, not a stand-in
rectangle. Text-on-path positions glyphs by sample distance; it does not shape
whole runs along a curve.

Markup uses XMLS with a restricted formatting vocabulary: `b`, `i`, `u`, `s`,
`big`, `small`, and `span` with `foreground`/`size`. Colors accept the names listed
in `markup-color` or #RRGGBB; size is 8..96 pixels. Malformed/unsupported markup
keeps the previous formatted view. Bold/italic faces are bundled Noto Sans fonts.
Gradient masks use actual glyph alpha. Rotated text uses native transforms.

Font rendering controls font file, raster size, spacing and texture filtering.
The font explorer reads actual GSUB/GPOS feature tags and fvar axis ranges from
OpenType files. It reports that feature application, variation instancing,
Cairo hinting modes, shaping, bidi and IME are unavailable in the current raylib
text backend. Unsupported font glyphs fall back according to raylib; supplying a
font with the needed coverage is the application's responsibility. This is a
material difference from Pango, not simulated OpenType support.

## Media and printing

Paintables share one owned CLOS drawing model at several display sizes. Animated,
symbolic, emblem and media-stream variants add invalidation/time, theme colors,
composition and seeking/pause. Video loading requires `ffmpeg` on PATH. Click
Load after setting a path. The loader caps decoding at 600 frames (10 fps, at most
60 seconds) and 640-pixel width. Audio, when present, is decoded to PCM and played
through raylib with seeking, volume and pause synchronization. Clips without
sound remain valid. Longer/large videos need a streaming decoder backend; decoding
currently blocks during Load. The fixtures are generated test patterns, not GTK's
licensed media assets. Video frame directories and audio streams are owned and
released on replacement/disposal; native streams close before deleting files.

Printing previews wrapped pages (78 characters × 48 lines) and exports selected
pages through CL-PDF. First/last page must be within the computed document range.
The example uses standard PDF Courier and accepts Latin-1; unsupported characters
produce an explicit error. It exports a PDF rather than invoking an OS print
spooler/dialog. Unicode embedding, printer discovery and native printing remain
backend work.

Clipboard text uses the OS clipboard. Image/file paths and colors use a validated
`LUT-TRANSFER-1` text envelope for portable interchange; this is not native image
or file MIME clipboard integration. The demo also drags typed data inside its
canvas. The DND demo moves/recolors/rotates objects and shares context menus;
OS cross-application drag-and-drop is not implemented. Cursor choices apply to the
appropriate native worker. Gestures accept raylib touch events plus pointer/
keyboard equivalents; desktop trackpads may expose fewer events than GTK.

The launcher's search field accepts ordered abbreviations: `cbx` finds
`combobox`, and `lvfb` finds `listview_filebrowser`. Matching ignores case,
spaces, underscores and hyphens. Exact, prefix and substring matches rank ahead
of looser subsequences; compact matches rank higher. The best result is selected
automatically, and Enter opens it. Clearing the field restores the alphabetical
list. No matches clears the selection and shows a message.
