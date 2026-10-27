# Scrolling geometry, reveal and following

After layout, `(scroll-geometry view &optional axis)` returns three values:
content extent, viewport page size and current offset, in logical pixels. The
axis defaults to `:vertical`. Supported views are vertical `scroll-view`,
`text-view` (including wrapped/document views), and legacy/model lists, trees
and tables. Text views additionally support `:horizontal`; wrapped text has no
horizontal scrolling. Unsupported views/axes and disposed views signal errors.
Queries do not mutate offsets. Direct legacy offset setters can leave an offset
out of range until layout/clamping; use `scroll-to` for immediate clamping.

Plain `list-view` widgets (including the demo catalog) and `scroll-view`
containers draw a vertical scrollbar when their content exceeds the viewport.
Drag the thumb or click the track; the gesture captures until release, including
outside the window, and does not select a list row. Plain list rows are clipped
before the scrollbar strip. Layout clamps plain-list offsets after content or
viewport changes, and the scrollbar hides when content fits. Specialized tree,
table and virtual model views retain their existing rendering/input behavior.
Closed dropdowns are excluded: their arrow opens a popup, whose selection list
can independently show a scrollbar when its options overflow.

`(scroll-to view offset :axis :vertical)` clamps to
`0..max(0, extent-page)` and immediately updates child geometry where needed.
Scroll containers retain their existing explicit child sizes. To grow a measured
child inside one, the application must allocate its measured content height.
Text pages exclude padding/gutters; table pages exclude the fixed header.
Scroll-container extent/page includes padding, matching its existing scrollbar.
Unwrapped horizontal extent queries explicitly measure all lines; avoid polling
that expensive query every frame. Explicit horizontal `scroll-to` also queries
that full extent to clamp exactly. Reveal operations avoid that query: they use
the supplied rectangle as their horizontal bound. Wrapped extents reuse the
visual-row cache.

`(reveal-rectangle view x y width height)` reveals a rectangle expressed in that
view's content coordinates. Content coordinate zero maps to the viewport's
leading edge at offset zero. It scrolls only this view. An oversized rectangle
aligns its leading edge. Vertical requests and wrapped horizontal requests clamp
to their scroll range. Unwrapped horizontal reveal clamps only at zero and trusts
the supplied rectangle, avoiding a document-wide width query. A rectangle beyond
actual text can therefore scroll beyond it; use explicit horizontal `scroll-to`
when exact document-wide clamping is required. Supplying a rectangle performs no
unwrapped text measurement.

`(reveal-widget child &key x y width height)` instead accepts a rectangle local
to the child's allocation, defaulting to its entire allocation, and visits
scrolling ancestors from inside out. Child positions are recomputed after inner
scroll containers relayout. Use it only for visible, allocated widgets.
Unwrapped text ancestors use the same target-local horizontal bound, avoiding
full-document extent queries there too.

`(reveal-text-range view start end)` reveals a half-open display-character range
using the shared visual/logical row geometry. Equal endpoints reveal an insertion
position, including EOF. It scrolls the text viewport, then propagates the visible
portion through nested ancestors. Neither reveal API moves the cursor, changes
selection, or focuses a widget. Oversized ranges align their leading edge, and
unsupported axes or smaller ancestor allocations can prevent full visibility.
These operations are immediate: call after layout, or call again after a resize.
For unwrapped text, range reveal measures only the affected logical lines up to
the range endpoints (in bounded chunks, reusing cached advances), not unrelated
lines or the full remaining suffix. Chunk rounding may measure up to 255
characters beyond an endpoint. Its cost can still grow with a far-right
endpoint or a range spanning many lines. Wrapped range reveal uses the existing
whole-document row cache/reflow described in [wrapped text](wrapped-text.md).
With raylib loaded, font measurement requires an active native context.

```lisp
;; In a UI callback, after layout:
(lut:set-follow-end transcript nil)
(lut:reveal-text-range transcript match-start match-end)
(lut:set-follow-end transcript t) ; resume at the end
```

`set-follow-end` enables an explicit vertical end relationship; `:distance 12`
requests a position twelve pixels before the maximum offset. It applies
immediately and after layout, including growth, shrink and width-dependent text
reflow. `follow-end-distance` returns the requested distance, or `nil` when
following is disabled. A short document clamps at zero but retains the request
for later growth. Suspension leaves the current offset unchanged. Disposal
clears the request; no timers, callbacks or target references are retained.

Applications decide when to enable, suspend and restore following. LUT does not
automatically suspend on wheel input, search or selection, and an explicit scroll
while following is enabled will be followed by a return to the requested end
relationship on the next layout. Suspend first for persistent browsing. Range
reveal does not disable following. Following maintains the viewport without
moving the caret to EOF. It does not change the whole-document streaming reflow
cost recorded in [wrapped text](wrapped-text.md); batching remains useful.

Run `lut-examples:scrolling` to append messages, pause, resume, and reveal an
initial match inside nested scrolling viewports. Following starts when the
application's Follow end button is pressed.
