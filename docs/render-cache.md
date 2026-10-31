# Render-texture region caching

Load `lut/render-cache` (or `lut/raylib`) to share the native cache across apps.
No application models or widget tree are required. All operations that touch
textures run on the native window's thread, while its graphics context is open.

```lisp
(let ((cache (lut:make-render-cache)))
  (unwind-protect
       (progn
         ;; Before screen drawing, outside a camera, texture target or scissor:
         (lut:update-cached-region cache :sidebar '(0 36 240 600)
           (list model-revision hover-row selected-row theme-revision)
           (lambda ()
             ;; Global logical coordinates; scale and target origin are applied.
             (lut:with-ui-scissor (0 36 240 600)
               (paint-sidebar)))
           :scale zoom :background :black)
         ;; During screen drawing, inside the app's logical screen transform:
         (lut:call-with-render-transform
           (lambda () (lut:draw-cached-region cache :sidebar)) :scale zoom))
    ;; Before closing the native window/context:
    (lut:dispose cache)))
```

In a LUT application, prepare regions before `render-window` and composite them
from custom rendering using the existing root transform; do not add a second
transform around `draw-cached-region`. Keep platform/font resource discovery
and asynchronous model updates outside cached painters. This cache does not
change the frame loop or automatically cache the widget tree.

`update-cached-region` compares immutable `equal` keys, bounds, scale, background
color and framebuffer DPI. It returns a region handle and a repaint boolean.
Apps supply revisions or immutable presentation snapshots; mutable live model
objects are not valid change keys. Include selection, caret, hover, focus, font,
theme and animation phase whenever they affect pixels. Omit hidden regions and
continue polling background services independently of painting.

Targets cover only their region, snapped to framebuffer pixels. Reallocation
on resize/DPI changes releases the old target. Fractional zoom preserves pixel
alignment. `with-ui-scissor` works in both screen and cached-region rendering;
custom adapters can use `render-scissor-box` with their logical scale. Nested
raw scissors need the caller to restore the outer clip; LUT's
`with-drawing-clip` does this for widget renderers.

The default background is transparent (`:blank`). Cached pixels composite with
premultiplied alpha to avoid applying their alpha twice. Opaque backgrounds are
also supported. Drawing returns NIL for absent/invalid regions. A failed paint
invalidates the target and unwinds texture/matrix state so the next update can
retry; it is not displayed in the meantime.

`invalidate-render-cache` forces repaint of one ID (second argument) or all
regions (omitted argument). `render-cache-paint-count` reports successful paints
for an ID or the cache total. `dispose` is idempotent; updates/draws after
disposal signal an error. A cache belongs to one graphics context and must not
be reused across windows or across context teardown/recreation.
