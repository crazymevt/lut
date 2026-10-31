# Reusable document presentation

LUT renders application-supplied presentation data. It does not identify code,
parse markup, tokenize languages, fetch documentation, rank completions or open
link targets. Code and prose can use the same presentation model.

Load `lut/examples` and try `(lut:start (lut-examples:document-presentation))`.
The example supplies static formatting and candidate data and handles link and
acceptance events itself. Its insertion action replaces the current selection;
it is not a language completion engine.

## Styled runs and decorations

`styled-text-view` extends the existing editable `text-view`, including shared
buffers, range history, independent viewports and selection. Presentation is
per-view, so peers can use different formatting on the same buffer.

```lisp
(lut:set-text-presentation view
  :runs '((:start 0 :end 5 :style (:font-size 20 :foreground :blue))
          (:start 6 :end 10 :style (:foreground :darkgreen)))
  :decorations '((:start 6 :end 10 :kind :underline :color :orange)
                 (:start 0 :end 5 :kind :gutter :text "1")
                 (:start 10 :end 10 :kind :annotation :text "note")))
(setf (lut:gutter-width view) 32)
```

Ranges are half-open Common Lisp character offsets, not bytes, glyphs or syntax
tokens. Each collection is sorted on commit. Runs are disjoint and accept
`:font`, `:font-size`, `:foreground`, `:background`, `:bold` and `:italic`;
other style keys are rejected. The raylib backend synthesizes bold/italic
emphasis; an explicit `:font` file can supply a designed face. Font spacing
belongs to the view and stays uniform. Existing theme color representations apply.

The interactive `lut/demo` browser's **Views / Styled text** example supplies
live editable runs with independently switchable colors, bold, italic and
14/18/20/24-pixel sizes. Line spacing is set to 34 pixels to accommodate the
largest glyphs; run font sizes do not change the view's fixed line height.

Decorations may overlap. Their `:kind` is `:underline`, `:background`, `:gutter`
or `:annotation`, with optional `:color` and `:text`. Empty ranges are permitted
for point annotations/markers. Gutters reserve `gutter-width` pixels and render
application text on affected lines; annotations draw text at the range's start.
They do not add document characters or alter line height. Set a zero gutter width
to hide its markers. Backgrounds draw behind selection/text; underlines and
annotations overlay text. Selected text uses the theme's `:on-accent` foreground
while retaining its font. Images retain their pixels over selection backgrounds.

Supplied collections replace existing ones; omitted collections remain. Use NIL
to clear a collection. `set-text-presentation` validates every supplied record
before committing any of them. It copies records, strings and style/color lists;
opaque application payloads retain identity. Treat supplied sources/fonts as
immutable and replace records through the API. `text-runs`, `text-decorations`,
`document-links` and `document-images` return copies, preserving opaque payload
identity. `text-style-at` returns overrides at a position, including a link's
default accent foreground.

### Invalidation and edits

`text-presentation-revision` is independent of the buffer content revision.
Explicit setters, gutter changes and `invalidate-text-presentation` invalidate
measurements and emit `:presentation-change` with the new revision. Call explicit
invalidation after external font state changes, including changes to a run's font
file. Ordinary inherited base font/style changes are also part of geometry keys.
Allocation and scroll offsets are applied at query time.

Text edits remap records before existing content notifications. Ranges entirely
before an edit stay put; ranges after it shift. Intersected ranges are discarded,
so new content does not silently inherit stale syntax/diagnostic/link meaning.
An insertion strictly inside a range discards it. At a range's start, insertion
shifts the range; at its end, insertion leaves it unchanged. Point decorations
have right affinity. Applications can use buffer edit notifications to recompute
presentation from their own parsers/data.

Automatic remapping increments the presentation revision quietly: it does not
emit a second presentation event during a content transaction. It occurs before
shared `:edit`/`:change` and standalone editing notifications. Explicit
programmatic standalone TEXT setters retain their existing no-`:change` contract.
Text undo/redo does not keep a separate presentation history; applications
resupply derived styling. Attaching a new buffer clears presentation; detaching preserves the formatted
snapshot. Disposal releases records and opaque targets, including on error paths.

Run lookup uses binary searches and measurement proceeds in bounded character
runs using the active run font. Decoration queries use a sorted prefix interval
index to skip completed intervals; long overlapping intervals can still require
scanning candidates. Setting/remapping collections costs O(number of records).
The first horizontal query far into a line retains the existing prefix-measurement
cost. This is not a syntax tree, shaping engine or rich paragraph layout engine.

## Read-only documents, links and images

`document-view` is always read-only for interactive editing. It supports the same
selection, navigation, copy and viewport behavior. Programmatic TEXT refresh is
permitted; setting `read-only-p` to NIL is rejected. Standalone documents default
to zero history retention for refreshes; shared buffers keep their own history
policy. Text uses unwrapped logical
lines and one configured `:line-height`. Configure it to accommodate all fonts
and images; there is no automatic paragraph reflow or variable-height row index.

Setting TEXT uses a minimal text diff and preserves presentation outside the
changed span, including links and images in a shared prefix or suffix. When
replacing a document, follow the TEXT update with `set-text-presentation` for all
collections, passing NIL for any that should be cleared. Otherwise an old link
target or image source can remain attached to text shared with the new document.

```lisp
(let ((view (lut:make-widget 'lut:document-view
              :text (format nil "Open help~%~c An image" (code-char #xfffc))
              :style '(:line-height 32))))
  (lut:set-text-presentation view
    :links '((:start 0 :end 9 :target :help))
    :images '((:position 10 :source "examples/assets/demo.png"
               :width 30 :height 26 :alt "Demo image")))
  view)
```

Links are disjoint `(:start :end :target)` records. They receive an accent
foreground and underline by default; a run can override their foreground.
A collapsed single pointer click emits `:link` with the original target, including
an image covered by a link. Drag/double-click selection does not activate it.
Applications decide whether a target means navigation, an action or a URL; LUT
does not open it. Keyboard link traversal is application policy for now.

Images are disjoint `(:position :source :width :height :alt)` records. Each
occupies one existing U+FFFC object-replacement character. Sources are file paths;
dimensions are positive logical pixels, and height must fit the configured line
height when records are set. Images are centered vertically in their line and
use the normal backend texture cache/sweep. They are not separate child widgets.
Selection indices count the object as one character, and plain-text copy retains
U+FFFC; applications can use image metadata for richer serialization.

`document-hit-test` takes root pixels and returns two values: `:image`/`:link`
and a copied record, `:text` and a character position, or NIL outside visible
content. Image hits use the actual image rectangle; link hits use their text
cells. Image records take precedence in hit results, while link activation still
works for an image covered by a link.

## Anchored suggestions and help

`anchored-surface` is a nonmodal in-window popover accepting ordinary children.
`suggestion-surface` provides a candidate list using `items`, `value` and an
`item-label-function`. Labels are pure string-producing function designators;
items remain application objects. A valid application-supplied `value` is
preserved when shown; otherwise the first candidate is selected. These surfaces
do not fetch/filter/rank data.

```lisp
(let ((surface (lut:make-widget 'lut:suggestion-surface
                 :width 280 :height 160 :items '("alpha" "beta"))))
  (lut:on surface :accept
    (lambda (surface candidate)
      (declare (ignore surface))
      (lut:replace-selection entry candidate)) :owner entry)
  (lut:show-anchored-surface entry surface))
```

Showing retains the owner's focus and follows an entry's caret. For other
widgets it anchors to the widget bounds. Optional `:rectangle '(x y w h)` supplies
a fixed root-coordinate rectangle; re-show to update a supplied rectangle.
Each layout/render frame follows the owner's current geometry, flips above when
space favors it, and clamps inside the window. Preferred dimensions survive a
temporary window shrink. Surfaces do not create native windows or cross workers;
they work inside each controller-rendered window.

Unmodified Up/Down/Home/End select candidates while focus is on the owner or
inside the surface; Enter calls `accept-suggestion` in that scope. Modified keys
and keys focused on unrelated widgets continue normally. An empty list lets
these keys through, including Enter for a text-view newline. Escape
dismisses the top surface. Pointer rows and wheel scrolling are supported.
Acceptance dismisses first, then emits `:accept` with the original item. LUT
does not insert text or execute a candidate. Typing continues to the owner while
suggestions are open. An empty list has no selection and cannot accept.

Help content can take focus, select/copy text and remain open. Dismissal restores
owner focus if focus was inside the surface. `dismiss-on-blur-p` defaults T;
focus outside the owner/surface dismisses it. Outside pointer down dismisses and
continues to the underlying control. Modal/context surfaces dismiss existing
anchors, and Escape is consumed before reaching an underlying dialog.

`dismiss-anchored-surface` is idempotent, clears owner/input-scope/pointer
references, and emits `:dismiss` once per explicit dismissal with a reason keyword.
Disposal clears a shown surface quietly under the usual disposed-widget event
suppression rule.
Its content/items remain available for reuse. Owner detachment dismisses;
owner/root disposal disposes shown surfaces and their contents. A reusable
surface that is detached between shows is application-owned: dispose it when
retaining it is no longer useful. Disposal releases candidates, formatters,
owned connections and opaque document payloads even when an observer signals.
Use `on ... :owner ...` for callbacks capturing a widget.

Notifications run on the GUI/controller thread. Observer errors propagate after
the committed update/dismissal and can prevent later notifications, including
acceptance if a dismissal observer fails. Application parsing, browsing history,
URL routing, completion selection policy and documentation lookup remain outside
LUT.

Portable tests cover geometry, immutable data boundaries, edit remapping,
transaction failures, links/images, candidate identity, positioning/focus, modal
scope and disposal errors. GC tests retain roots/surfaces while checking opaque
payloads and disposed owners are collected. Native light/dark checks exercise
mixed-font metrics, image/link hit testing, all presentation layers and popup
interaction on macOS. Linux/Windows and shaping/bidi/IME/accessibility have not
been established by these checks.

For character wrapping, variable-height headings, paragraph spacing and block
images beyond the base line height, use the opt-in
[wrapped document view](wrapped-text.md).
