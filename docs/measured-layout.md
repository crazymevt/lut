# Content measurement and flow layout

Load `lut/examples` and try `(lut:run (lut-examples:measured-layout))`.
Resize the window or change its prose: labels request their painted height,
controls wrap into rows, and expanding children share unused space.

These APIs are opt-in. Existing `box`, `grid`, `paned`, notebook and scroll-view
allocation stays unchanged. Put a `measured-box` under a window with
`:content-layout :fill` to allocate from the root's available logical rectangle.
Application breakpoints and layout persistence remain application code.

## Measurement

`(measure widget axis &optional for-size)` returns two nonnegative logical sizes:
minimum and natural, with minimum no greater than natural. Axis is `:horizontal`
or `:vertical`. The optional nonnegative `for-size` is the offered size on the
other axis, bounded by that axis's configured minimum/maximum. Built-ins support height-for-width; width-for-height is not supplied.

```lisp
(lut:measure label :horizontal)       ; minimum and natural width
(lut:measure label :vertical 320)     ; required height at width 320
```

A query never allocates widgets or changes X/Y/WIDTH/HEIGHT. One outer `layout`
call shares a measurement cache with all nested layout and measurement calls.
A standalone `measure` query likewise shares a cache with its recursive queries.
Each `(widget, axis, offered size)` is computed once per pass; the offered size
is normalized to the configured bounds before lookup. Measurement methods must
be pure, and tree/text/style/request inputs must stay stable within that pass.
Apply input changes before starting layout rather than during custom layout.

The cache exists only on the dynamic call stack and is discarded on normal
return or error. Separate layout passes and standalone queries recompute their
results, so changes between passes require no explicit invalidation. This bounds
repeated nested queries; it does not eliminate per-frame traversal, virtualize
content, or retain text measurements across frames. Hidden widgets measure zero
and disposed widgets signal an error. Disabled widgets retain their space.
Containers use active children in tree order.

Plain labels measure their text with the active font metrics. With `:wrap-text t`,
minimum width is the longest whitespace-delimited word plus padding; natural
width is the widest logical line plus padding. Vertical measurement uses the
**same** word-wrapping function as painting and reserves padding plus one line
height per painted line, with additional room if the font size exceeds the
line height. Existing label wrapping collapses spaces/tabs and does
not break an oversized word; explicit newlines are preserved. This is plain,
noninteractive label wrapping, not selectable/editor visual-line reflow.

Buttons measure their unwrapped captions, including vertical padding and depth.
Check/radio/switch indicators reserve extra width. Generic widgets, entries and
text/document views use their initial width/height as natural hints, with zero
intrinsic minimum, until specialized measurement is provided. Allocating them
does not change those hints. A text-view's content does not automatically grow
its request; editor reflow is still a later roadmap item.

When the raylib font backend is loaded, text measurement needs an active native
context, just as `text-width` does. Core-only use has portable approximate font
metrics. Measurement is in logical units; root UI scaling remains separate.

### Requests and constraints

All widgets accept these measured-layout properties:

- `width-request` / `height-request`: optional natural-size requests, independent
  of allocated geometry. NIL uses measured content or initial size hints.
- `min-width` / `min-height`: nonnegative lower bounds, default zero.
- `max-width` / `max-height`: optional upper bounds, NIL means unbounded.
- `hexpand` / `vexpand`: whether to share extra space on that axis, default NIL.

The content minimum and configured lower bound are combined. An explicit maximum
can clip below the intrinsic content minimum; a natural request is clamped to the
resulting bounds. A configured minimum greater than its maximum is rejected
before assignment. Use requests, not repeated SETF WIDTH/HEIGHT, to change a
measured child's natural preference after allocation. These properties do not
change legacy containers into measured layouts.

### Custom widgets

Specialize `measure` with a primary method returning minimum and natural size;
common validation and request/constraint handling wraps the method automatically.
Do not mutate the tree or geometry inside measurement.

```lisp
(defmethod lut:measure ((view custom-chart) axis &optional for-size)
  (declare (ignore for-size))
  (if (eq axis :horizontal) (values 120 400) (values 80 240)))
```

## Measured boxes

`measured-box` has `orientation` and `spacing`. It stacks measured children on
the main axis. Padding comes from the usual style token.

```lisp
(lut:with-ui (lut:measured-box :spacing 8)
  (lut:make-widget 'lut:label :text "Content-sized heading")
  (lut:make-widget 'lut:label :text "Long prose ..."
                   :hexpand t :style '(:wrap-text t))
  (lut:make-widget 'lut:entry :height-request 40 :hexpand t))
```

The main axis starts at natural sizes. A shortage shrinks each child
proportionally toward its minimum. Surplus is shared equally among expanders,
redistributing space when a child reaches its maximum. With no eligible
expanders, space stays unused. Below the combined minimum, children keep their
minima and may overflow; ancestor clipping or application scroll policy applies.

On the cross axis a child uses up to its natural size, bounded by available
space and its minimum/maximum. Cross-axis expansion fills that space up to the
maximum. Vertical boxes choose widths before measuring heights. Horizontal
boxes allocate widths first, then measure each child's height at its width.
Allocation and measurement therefore use the same width-dependent heights.

## Flow boxes

`flow-box` packs children left-to-right using natural widths and wraps onto new
rows. `column-spacing` and `row-spacing` control gaps. A child wider than the
available row shrinks toward its minimum; an unavoidable oversized minimum gets
its own overflowing row. An empty flow container has only its padding; hidden children are excluded
from packing and gaps.

Each row distributes surplus to horizontal expanders subject to maxima. Its
height is the largest measured natural child height at the final widths.
Vertical expanders fill that row height, respecting their maxima; other children
align at the top. Rows do not stretch to consume the container's entire height.

`measure flow :vertical width` and `layout` use the same row packing and final
widths. Nested flow/linear layouts respond to resizing, text/style changes,
visibility changes and child removal between passes. The temporary measurement
cache may reference widgets only while its pass runs; row plans and caches are
not retained by widgets after return or error. Ordinary ownership/disposal rules
apply.

## Limits and verification

This is the G2 foundation. Selectable/editable visual-line wrapping, paragraph
blocks, general scrolling/reveal, URI launching, window-state adapters and a
terminal integration boundary remain separate roadmap work. Existing
scroll-view parents still allocate explicit child heights; embedding measured
content there requires supplying a measured height until scrolling integration
is added.

`tests/measurement.lisp` covers requests, bounds, height-for-width, nested boxes,
flow rows, expansion, resizing, visibility/removal, disposal and hit testing.
Nested-tree counters verify once-per-key computation and stable text-width work
as nesting increases. Cache lifetime tests cover changed inputs, distinct offered
widths, standalone queries and error unwinding.
`tests/measurement-native.lisp` checks actual font measurements, light/dark
rendering at explicit wide/narrow/wide allocations and 100/125/200% scaled
input. A separate macOS OS-window resize attempt intermittently reported double
the requested size (680 after requesting 340); that check did not pass reliably.
Physical/native window resizing remains unverified, as does Linux/Windows native
behavior. Explicit allocation tests do not establish OS window-size semantics.
