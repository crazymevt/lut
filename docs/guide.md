# Programming guide

## Composition and ownership

Construct widgets with `make-widget` (a thin `make-instance` wrapper) or `with-ui`.
The macro takes a class and initargs, followed by child expressions. Each child
has one parent; `add-child` reparents and rejects cycles. `remove-child` clears
focus if necessary. Do not assign `parent`/`children` directly.

```lisp
(lut:with-ui (lut:window :text "Counter" :width 500 :height 320)
  (lut:make-widget 'lut:label :text "Welcome")
  (lut:with-ui (lut:box :orientation :horizontal :height 50)
    (lut:make-widget 'lut:button :text "One")
    (lut:make-widget 'lut:button :text "Two")))
```

Boxes stack vertically or horizontally with `spacing` and inherited `:padding`.
Vertical children fill available width; their height is their preferred height.
Horizontal children keep preferred width. Uniform grids, split panes, stacks
and notebooks provide additional layouts; there is no flex negotiation.
Containers clip descendants. Scroll views scroll vertically with the mouse wheel.

## Styles

Set the root window's `theme` to `*light-theme*` or `*dark-theme*`, or supply a
property list. See [styling](styling.md) for all tokens, state styles and root
class selectors. Basic tokens include `:background`, `:foreground`, `:surface`,
`:accent`, `:font-size`, and `:padding`. Colors use raylib's keyword/list conventions;
RGBA byte lists work for both themes. Font size and padding are positive pixel
numbers. Override tokens with any widget's `:style` plist. Resolution searches
local styles and ancestors before the root theme. Changing a token affects the
next frame. Use a copied plist when modifying shared themes.

## Events and input

`(on widget :activate (lambda (widget payload) ...))` registers activation.
`:change` receives the new text, number, boolean, or selected row index.
`:context` receives the right-click event, and root `:tick` receives elapsed
seconds. Handlers execute in registration order. Entries get a reusable context menu automatically. `open-context-menu` also
accepts shared (caption callback enabled-p) actions; it positions at the pointer
and dismisses on outside click or Escape.

Tab/Shift-Tab traverse enabled visible interactive descendants. Space/Enter
activate buttons. Entries support arrows, Home/End, Shift selection, pointer drag
selection, Backspace/Delete and Ctrl/Cmd+A/C/X/V. Text views accept newlines.
The renderer loads a real font with explicit codepoints and measures/draws full
strings. Text viewports track the caret and support wheel scrolling in multiline
controls. Complex shaping, pair kerning, bidi, IME and undo are unfinished.
Bundled Noto Sans covers Latin, Greek and Cyrillic; use the :font style for other
font coverage.

Sliders support click position, arrow keys and wheel increments. List views have
selection and wheel scrolling. Progress bars share numeric bounds but are
read-only. Selection is zero-based. Prefer updating text with `select-all` and
`replace-selection`; assigning shorter text directly clamps the existing selection to valid indices.

`dispatch` accepts normalized `make-event` objects independently of raylib, so
custom backends and tests can drive the same behavior. Kinds are `:down`, `:move`,
`:up`, `:wheel`, `:key`, `:text`, and `:context`. Coordinates are logical pixels.
Wheel delta is in notches. Dialogs block input to the underlying tree; Escape
closes the top modal dialog. Drag titles/empty surfaces to move dialogs.
Crossing the root bounds detaches into a native worker window. See the
[REPL and window workflow](repl.md).

## Extending

Subclass `widget` or a concrete control. Define methods on `layout` and `render`;
call the backend's drawing API only in the latter. `drawing-area` offers a
`:draw-function` callback for simpler custom drawing. `defwidget` records class
metadata for documentation; slot specifications are `(name default type doc)`.
The core and normalized event model can be loaded without native libraries.

## Vertical tabs

`vertical-notebook` owns a left-hand tab strip and lays out its selected child
to the right. It uses the same `items`, `value`, `active-children`, `select-page`
and `:change` conventions as stacks/notebooks:

```lisp
(let ((book (lut:make-widget 'lut:vertical-notebook
              :items '("Appearance" "Editor") :tab-strip-width 144
              :reorderable-p nil :style '(:row-height 36 :padding 16))))
  (lut:add-child book (lut:make-widget 'lut:box))
  (lut:add-child book (lut:make-widget 'lut:box))
  (lut:add-child window book))
```

Click a tab, or focus the widget and use Up/Down/Home/End. Tab moves focus into
the selected page; hidden pages do not participate in input. `tab-strip-width`
is clamped to the allocated width, and styled padding separates strip and page.
Hover highlights only the tab under the pointer; empty strip space stays unchanged.
The selected row remains highlighted during keyboard navigation without an outer
focus ring. Long captions are ellipsized. Overflowing strips scroll with the wheel;
selection reveals its tab. `tab-offset` is a vertical logical-pixel offset.
`tab-at-position` accepts vertical notebooks too.

Reordering defaults to disabled. With `:reorderable-p t`, dragging a tab onto
another tab changes the page/title order, preserves the selected page identity,
and emits `:change` with the selected index, then `:reorder` with
`(from-index to-index)`. Static tab groups such as settings should explicitly
use `:reorderable-p nil`. This widget supports local reordering; horizontal
notebook close buttons and cross-notebook tab transfers remain separate APIs.

Closable notebook tabs draw a geometric X, independent of the caption font's
glyph coverage. The mark occupies the existing close-button hit region.

### Resize mouse cursors

The native backend resolves `window-pointer-cursor` after pointer input each frame,
using logical coordinates (including UI zoom). Built-in `paned` splitters show
`:resize-ew` or `:resize-ns` over their drag region and throughout a captured drag.
Hidden, disabled, disposed, and modal-blocked targets do not supply cursors.
Custom resizable panels or handles can specialize
`(pointer-cursor widget x y &key captured-p)` to return a raylib cursor keyword
inside their resize region, or `nil` elsewhere. During capture, return the gesture's
cursor even outside that region. Unhandled targets restore `:default` automatically.
