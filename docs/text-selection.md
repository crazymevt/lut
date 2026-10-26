# Text selection and navigation

`entry` and `text-view` support character, word and logical-line selection,
keyboard extension and pointer drag selection. Shared views keep independent
cursor, anchor and scroll state, including read-only views. Navigation/selection
does not edit text, increment revisions or add undo history.

## Word and line APIs

`text-word-range` accepts a string, label/view or text buffer and a character
position (including EOF), returning start and exclusive end. It groups runs of:

- Common Lisp alphanumeric characters and underscore.
- Space, tab, newline, return and page characters.
- Other punctuation characters.

At EOF it uses the preceding character; empty text returns `0, 0`. Positions
count Common Lisp characters. This is a portable run rule, not Unicode word
breaking, grapheme segmentation, language tokenization or shaping. Scanning
visits adjacent leaf strings directly, with O(log chunks + scanned characters)
work and O(tree height) traversal space; it does not flatten a shared buffer.
Complete long runs remain selectable without a fixed scan cap. A full-run scan
is linear in that run's length, rather than an indexed lookup per character.
Raw-string line/word queries construct a temporary index.

`select-word` selects a display run; `select-line` selects a logical display line,
including its terminating newline. Both accept a view and optional position,
defaulting to its cursor. The anchor is placed at the start, the caret at the
end, and the caret is revealed. A final empty line has an empty selection.
Display overrides, such as password masks, should preserve character indices.
Word selection on a mask uses the mask's runs; raw `text-word-range` queries
use model text.

```lisp
(lut:select-word view 8)
(lut:select-line view)
(multiple-value-bind (start end) (lut:text-word-range buffer 8)
  (lut:text-range buffer start end))
```

## Keyboard movement

`move-text-cursor` takes a view and one movement:
`:left`, `:right`, `:word-left`, `:word-right`, `:line-start`, `:line-end`,
`:document-start`, `:document-end`, `:up` or `:down`. `:extend t` preserves the
anchor; otherwise selection collapses to the resulting position. Left/right and
word-left/right collapse an existing selection to its corresponding edge before
any further movement. Line/document movement goes directly to that boundary.
Word-left skips preceding whitespace and moves to the preceding run's start.
Word-right passes the current run and following whitespace to the next run.

Vertical movement uses the same pixel measurements as drawing/hit testing and
preserves a preferred horizontal pixel X across short lines. Other movement or
explicit cursor assignment resets this preference. Buffer edits also reset it.
Logical lines are unwrapped; there is no visual-row/wrapping navigation index.

| Input | Movement |
| --- | --- |
| Left/Right | One character, or collapse selection |
| Ctrl/Alt + Left/Right | Word/run movement |
| Home/End | Logical line start/end, excluding newline |
| Ctrl/Super + Home/End | Document start/end |
| Super + Left/Right | Logical line start/end |
| Up/Down | Adjacent logical line at preferred pixel X |
| Super + Up/Down | Document start/end |
| Shift with any movement | Extend selection from the existing anchor |

Base keys and modifiers stay independent through native worker IPC. The native
backend still reserves its existing editing aliases (copy, paste, undo, etc.).
This is LUT's portable mapping; it does not query OS text-navigation preferences.

## Repeated clicks and unit dragging

Single click places the caret; Shift-click extends from the current anchor.
Double click selects a run, including whitespace/punctuation runs. Triple click
selects the logical line including its newline. Dragging after a double/triple
click extends in whole runs/lines and preserves direction when crossing back
before the initial unit. Shift-click always uses character extension.

Native pointer events include `event-timestamp`, monotonic seconds. Consecutive
downs on the same view within 0.5 seconds and 5 pixels infer counts 1, 2, 3,
then start again at 1. Significant drag motion, other controls, keyboard input,
text edits and lifecycle changes reset repetition. These are portable thresholds,
not platform-configured click preferences.

Synthetic events default to single clicks. Supply `:timestamp` for inference or
`:click-count 2` / `3` to force a unit selection. `event-timestamp` and
`event-click-count` survive worker IPC. A stationary mouse-up/move preserves the
selected unit even when caret reveal scrolled the viewport after pointer down.

```lisp
(lut:dispatch root (lut:make-event :kind :down :x 24 :y 40 :click-count 2))
(lut:dispatch root (lut:make-event :kind :up :x 24 :y 40))
```

## Reveal, autoscroll and lifetime

`reveal-text-cursor` adjusts a view's own offsets to include its caret rectangle,
using padding, allocation and styled caret width. It does not change selection.
`:vertical nil` preserves vertical scrolling while revealing horizontally.
Keyboard movement and word/line APIs reveal immediately; rendering reveals after
ordinary cursor/content changes and maintains horizontal reveal on resize.
Wheel scrolling is preserved when the caret has not moved. Active pointer
selection uses its own bounded scroll steps instead of jumping to an outside
pointer's logical position.

While a selection is captured, dragging beyond a content edge scrolls that
view horizontally and, for `text-view`, vertically. The core stores the last
pointer position; `advance-text-selection` takes the root and elapsed seconds
and continues scrolling while that pointer is stationary. Native main and
controller-rendered peer frames call it automatically. Other backends should
call it once per frame after input. Speed increases with edge distance, up to
800 pixels/second; each step uses at most 0.1 seconds. Zero time does not scroll.
Vertical scrolling clamps to document extent; horizontal scrolling stops at a
measured line end without requiring a full long-line width scan. Drawing and
endpoint hit testing share the same geometry and scroll offsets.

`cancel-text-selection` releases selection capture without clearing its range;
`:forget-clicks t` also discards repeated-click metadata. It is safe to call more
than once and does not cancel an independent drag-and-drop session. Release,
keyboard/context input, another pointer down, focus transfer, modal blocking,
detachment, disposal, rebinding and standalone/originating-view content edits
stop an active gesture. Shared-buffer edits originating elsewhere (including
model-only appends to a log) preserve peer capture. The initial anchor/unit
bounds and current cursor/anchor remap through the edit with the buffer's usual
right-affinity rule; pointer coordinates and scroll offsets remain independent.
This also applies to read-only peers and overlapping edits. Click repetition and
preferred navigation X reset when content changes. Hidden or disabled captures
cancel on the next input/frame check. Native focus loss
also cancels capture. Read-only policy permits navigation and selection.
Selection and click metadata are released when views are detached or disposed;
GC tests retain the root/model while checking disposed views can be collected.

Try `(lut:start (lut-examples:text-selection))` after loading `lut/examples`.
The left pane is editable and the right pane is read-only; both share a buffer
while keeping independent selection and viewport state. Tests cover portable
behavior, proportional metrics, stationary-pointer edge cases and native
worker click/timestamp/modifier transport on macOS. Linux/Windows interaction
has not been verified.
