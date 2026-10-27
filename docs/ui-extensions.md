# Application UI extension APIs

These APIs keep interaction mechanics in LUT while applications retain commands,
models, constraints and icon artwork.

## Pointer capture and resize handles

`capture-pointer widget` routes pointer move/up events to a live widget in the
current input scope. `pointer-captured-p` queries ownership; `release-pointer`
releases only that widget's capture. Detachment, disposal and modal changes
cancel capture through the normal lifecycle.

A `resize-handle` takes `:resize-axis :horizontal` (east/west cursor) or
`:vertical` (north/south). It emits `:resize-start` and `:resize-end` with the
pointer event, and `:resize` with `(:x x :y y :dx dx :dy dy)` in logical root
coordinates. The application applies size constraints and updates its layout.

## Notebook actions

Set `(page-action book page)` to a `make-notebook-action` value. It takes:

- `:label`: tooltip/default caption.
- `:function`: callback `(book page)`, invoked on a completed enabled click.
- `:draw-function`: optional backend painter `(book page action rectangle)`.
- `:width`: positive logical width, default 26.
- `:enabled-p`: boolean, default true.

LUT reserves caption space, clips painting to the strip, handles canceled clicks,
blocks tab dragging from the action, and manages tooltips. An action belongs to
its page, survives tab transfer and is released when the page is disposed.
`tab-rectangle`, `tab-action-rectangle`, and `tab-strip-rectangle` return logical
root rectangles. An offscreen tab's rectangle is not a hit-test result;
`tab-at-position` excludes clipped areas and navigation arrows.

## Lists and text adapters

Basic `list-view` emits `:change` for selection and `:activate` for Enter or a
completed click on a valid row. Arrow navigation does not activate a row.
`row-at-position` and `input-hit-test` expose viewport-aware queries.

Externally managed text views can call `handle-text-pointer-event` for standard
selection handling, `text-selection-active-p` for active drags, and
`suppress-cursor-reveal` after explicit scrolling. `anchor`, `scroll-viewport`,
`text-word-point-position` and `visible-line-fragment` are supported adapter APIs.

Horizontal extents are cached by immutable text root and font/metric state.
Resize and paint-only presentation changes reuse measurements. Text, font,
metric-affecting runs and image geometry invalidate them.

## Rendering styles and clipping

`:focus-outline-p` defaults to true; false suppresses the focus ring without
changing keyboard focus. `:caret-height` is `:line` (default) or `:font`.
`text-caret-rectangle` returns painting geometry without changing selection rows.

For overlay dialogs, `:backdrop-color` and `:shadow-color` default to nil.
`:shadow-spread` defaults to 18 and `:shadow-offset` to 6. Explicit colors enable
the corresponding effect; native dialog windows do not paint owner backdrops.

In the raylib backend, `with-drawing-clip (x y width height)` intersects the
current logical clip and restores it on normal or exceptional exit.
`current-drawing-clip` returns a copy; custom drawing need not access `*clip*`.

## Verification

Run `(asdf:test-system "lut")` for the core interaction/cache contracts, and
`sbcl --script tests/ui-extensions-native.lisp` for focus-preserving rendering and
nested/error clipping. Argon's shell and native editor suites exercise the
application adapters, Markdown eye, divider constraints and document selection.

## Repeated pointer clicks

`pointer-click-count` shares the text selection click rules with custom controls
and lists. Pass a `:down` event and the previous opaque state; it returns the
click count and the next state. Supply a stable `:target` such as a model row key
(targets compare with `equal`). Clicks repeat within 0.5 seconds and a radius of
5 logical pixels. Explicit `event-click-count` values take priority. Events
without timestamps return no retained state.

The default `:cycle 3` counts single/double/triple clicks; use `:cycle 2` for
single/double activation. Keep the state per control and reset it to `nil` on
scrolling, keyboard navigation, or an invalid target.

```lisp
(multiple-value-bind (count next-state)
    (lut:pointer-click-count event click-state :target row-key :cycle 2)
  (setf click-state next-state)
  (when (= count 2) (open-row row-key)))
```

## Custom root layout

Box stacking is a primary layout method. To replace stacking in a custom
window or box, specialize the primary method, set the widget's x, y, width
and height (clamping sizes to zero), place its children at their final bounds,
and return the widget. Do not call the next primary method when replacing
stacking. Keep a custom window's content-layout at its default :box; :fill
requests an additional fill pass. Existing :around methods still provide measurement/font contexts;
:after methods can continue extending the normal stacking behavior.
