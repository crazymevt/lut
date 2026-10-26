# Themes, state styles and root selectors

Every widget has a `style` property list and a `state-style` property list.
A window adds `theme` and ordered `style-rules`. Values are resolved at rendering
and layout time, so edits take effect on subsequent frames.

Resolution order is local state/base, ancestor state/base overrides, matching
root class/state rules (last match wins), root theme, built-in defaults. Explicit
NIL is an override. State priority is inherited disabled, pressed, hover, focus,
normal. A root class selector matches subclasses as well.

```lisp
(lut:on-ui
  (setf (lut:theme *app*) lut:*dark-theme*
        (lut:style-rules *app*)
        '((:class lut:button :style (:border-radius 0.4 :border-width 2))
          (:class lut:button :state :hover :style (:surface (60 95 130 255)))
          (:class lut:entry :state :focus :style (:border-color :skyblue)))))
(lut:on-ui
  (setf (lut:state-style (lut:find-widget *app* :name))
        '(:focus (:foreground :yellow) :disabled (:foreground :gray))))
```

| Token | Valid values / meaning |
| --- | --- |
| `:background`, `:foreground`, `:surface`, `:accent` | Raylib palette keyword, RGBA integer, or RGB/RGBA byte list |
| `:font` | Existing TrueType/OpenType pathname/string, or NIL for bundled Noto Sans |
| `:font-size` | Positive real pixel size; atlas generation rounds to integer |
| `:font-spacing` | Non-negative real additional glyph spacing |
| `:line-height` | Positive real; multiline row/selection/caret extent |
| `:row-height` | Positive real; list/table rows and wheel increments |
| `:padding` | Non-negative real; content and text inset |
| `:title-height` | Positive real; dialog title and notebook tab strip |
| `:border-width` | Non-negative real; zero hides borders |
| `:border-radius` | Real in 0..1, raylib rounded-rectangle proportion |
| `:border-color`, `:focus-color` | Border and focus decoration colors |
| `:hover-color`, `:pressed-color`, `:disabled-color` | Default interactive surface colors; a state-specific `:surface` overrides them |
| `:caret-width` | Non-negative real pixel width |

Style metric assignments are validated. A malformed property list or invalid
known metric signals an error. Color keywords are interpreted by the raylib
binding; `(rl:color-keywords)` enumerates its palette. Unknown style keys are
allowed for custom widget methods. They have no effect on built-in controls.

Copy shared theme lists before modifying them destructively. Reassigning a
window theme switches its entire inherited palette. Assigning a control style
overrides only the supplied keys. State styles are token plists keyed by
`:normal`, `:hover`, `:pressed`, `:disabled`, or `:focus`.

These are typed Lisp style tokens rather than a CSS parser. Layout currently
provides boxes, uniform grids, split panes and stacks; it does not implement GTK
CSS sizing rules or a JavaFX constraint engine.

## Across native windows

A secondary root's `style-source` points to the application window supplying
styles and selectors. Its default theme inherits from that source; explicitly
supplying `:theme` when constructing the secondary window keeps that override.
Detached dialogs inherit from their original root. Later light/dark switches,
class-rule edits and root style overrides therefore reach detached controls too.
`style-source` chains reject cycles.

```lisp
(lut:on-ui
  (setf (lut:theme *app*) lut:*dark-theme*)) ; includes inheriting detached roots
```

Set a secondary root's theme to NIL to resume inheritance. Give it a palette to
fix that window's palette independently. Local control styles continue to win.
