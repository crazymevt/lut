# Default widget caching and render-texture regions

Native LUT windows now retain their pixels by default. Widgets invalidate
paint generations when visible properties change; only overlapping 256-by-256
logical tiles are repainted. Final layout bounds are compared separately, so
intermediate box/fill allocations do not dirty unchanged frames. Layout is
scheduled by widget changes or native size/scale changes, rather than performed
on every frame. Changed tiles patch one retained window image; unchanged windows
skip drawing and buffer swaps. A one-second compositor refresh is retained because
raylib exposes no portable damage/expose event.

This is invalidation-driven layout/painting with a lightweight native input
pump, not an indefinitely blocking OS event loop. Idle iterations yield with
`sleep` and pump input about every 33 ms while idle so queued REPL work, timers, worker
messages and animations remain responsive. Native blocking event-waiting is not
enabled: the current raylib binding has no connected cross-thread wake API for
those sources. Animating/dynamic content presents at the normal cadence.

```lisp
(lut:on-ui
  (setf (lut:text label) "Updated") ; automatic invalidation
  (lut:invalidate-widget custom-view)) ; externally owned visible state
(lut:window-cache-statistics window)
;; :ENABLED-P T :TILES ... :REPAINTS ... :DYNAMIC-PAINTS ...
;; :LAST-REPAINTS ... :MEMORY-BYTES ...
```

`invalidate-widget` invalidates a widget's painted region. Use `:descendants t`
for inherited/external changes affecting its subtree. `request-layout` schedules
layout after custom measurement/geometry changes; normal setters and invalidation
do this automatically. Ordinary `defwidget`
setters, shared text edits, presentation/model revisions, selection, hover,
focus, scrolling, image-file timestamps and cell-grid mutations are tracked.
Assign styles/themes through their setters. If you mutate a list, array or
application model in place, publish its normal model notification or invalidate
the affected widget explicitly. Unchanged tiles reuse pixels; moving, hiding,
removing and disposing widgets also clears their previous regions.

`cache-mode` accepts:

- `:auto` (default): retain built-in rendering, including subclasses that only
  inherit it. Activity indicators, drawing callbacks, custom widget classes with render methods and
  custom notebook action painters redraw automatically.
- `:retained`: opt a custom renderer into retention. Call `invalidate-widget`
  when its external state changes, or specialize `widget-render-key` to return
  an immutable `equal` key combining `call-next-method` with your data revision.
- `:dynamic`: redraw the widget subtree every frame. Dynamic subtrees are
  captured once per frame, then reused by overlapping tiles, so callbacks do
  not execute multiple times merely because they cross tile boundaries.

Root `cache-enabled-p` defaults to T; NIL restores direct rendering. Existing
custom paint methods keep running under `:auto`; opt them into retention once
they publish their dependencies. Returned custom keys must remain immutable.
Direct calls to `render-window` for application-owned offscreen targets retain
the direct path; default cache preparation happens before the native window
and worker-frame drawing passes, outside cameras/targets/scissors.

Each native context owns its cache. Resized/removed tiles and dynamic surfaces
release their targets; worker closure and native context teardown release the
remaining targets. The extra full-window composite avoids per-tile texture/blend
transitions while idle. Translucent root backgrounds use direct rendering rather
than opaque dirty-frame patching. Cache keys use numeric widget identities, not widget
references. `:memory-bytes` counts RGBA color texture bytes, excluding driver
and depth-buffer overhead. Workers skip readback/PNG work when retained frames
are unchanged, while input and metadata round trips continue.

The cache preserves paint order, clipping, fractional scaling and overlays.
Opaque controls have exact direct/cached pixel parity in the native checks;
extra transparent dynamic surfaces can differ by one 8-bit color level because
of premultiplication/rounding in the intermediate target.

Run `tests/widget-cache-native.lisp` for reuse, regional invalidation, selection,
styles, movement/removal, transparency and callback-frequency checks at
100/125/200%. `tests/widget-cache-performance.lisp` compares direct/cached CPU
time and asserts zero idle tile repaints, zero extra layout passes and only
low-frequency buffer presentation in the actual demo. On this local macOS/SBCL
run, the idle button demo measured about 8.1 ms CPU/frame direct and 0.85 ms
cached; styled text measured 11.9 ms direct and 0.90 ms cached. These are
100-frame local samples, not cross-platform performance guarantees. The input
pump and dirty-state checks still contribute to those costs.

## Explicit region cache API

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
and asynchronous model updates outside explicit cached painters. This low-level
API remains available independently of the default native widget cache.

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

Retained windows share font-file timestamp checks per frame and reuse unchanged
default-style snapshots. Bounded warm caches retain up to 32 cold font atlases
and 128 cold image textures across idle frames; currently used resources survive
the trim. Direct-render windows retain the existing per-frame disposal policy.
Atlas keys include file timestamps, so replacing a font still refreshes it.
Idle-only polling defaults to 30 Hz; active/dynamic painting uses normal cadence.
