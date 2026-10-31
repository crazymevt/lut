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
| `:background`, `:foreground`, `:surface`, `:accent`, `:on-accent` | Raylib palette keyword, RGBA integer, or RGB/RGBA byte list |
| `:wrap-text` | Boolean; opt-in word wrapping for labels, within padded width; long individual words remain clipped |
| `:font` | Existing TrueType/OpenType pathname/string, or NIL for bundled Noto Sans |
| `:font-size` | Positive real pixel size; atlas generation rounds to integer |
| `:font-spacing` | Non-negative real additional glyph spacing |
| `:line-height` | Positive real; multiline row/selection/caret extent |
| `:row-height` | Positive real; list/table rows and wheel increments |
| `:padding` | Non-negative real; content and text inset |
| `:title-height` | Positive real; dialog title and notebook tab strip |
| `:border-width` | Non-negative real; zero hides borders |
| `:border-radius` | Real in 0..1, raylib rounded-rectangle proportion, limited by `:max-border-radius` |
| `:max-border-radius` | Non-negative real pixel corner-radius cap; default 8 |
| `:border-color`, `:focus-color` | Border and focus decoration colors |
| `:hover-color`, `:pressed-color`, `:disabled-color` | Default interactive surface colors; a state-specific `:surface` overrides them |
| `:button-depth` | Non-negative pixel elevation for buttons and toggles, default 0 for flat surfaces; positive values opt into elevation |
| `:button-shadow`, `:button-highlight` | Button depth-edge and raised top-highlight colors |
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

## Rounded controls and layout

Use `:style '(:border-radius 1 :max-border-radius 24)` on a button up to
48px tall for pill-shaped corners, or
`:border-radius 0` for square corners. The value is proportional to the shorter
side, capped by `:max-border-radius` in pixels. Surfaces, borders, focus outlines,
and rounded indicators share this cap so tall controls keep restrained corners.
Lists and tables paint a surface and border, with inset selection highlights and
vertically centered text; selected text uses `:on-accent`.

Layout containers arrange children; they do not paint a background or border
by default. A box accepts `:orientation :horizontal` and `:spacing 12`; a grid
accepts `:columns 3` and `:spacing 12`. Both resolve `:style '(:padding 16)`.
Stacks select a child with `value`, and paned containers use `orientation` and
`value` for the split. Width and height are widget properties, not style keys.
There is no CSS flexbox, automatic responsive sizing, or decorative card surface
on layout containers; a custom render method can add that surface.

Labels can opt into `:style '(:wrap-text t)`. Allocate enough height for the
expected lines: wrapping does not automatically resize a widget. Editable text
and button captions retain their existing explicit-newline behavior.

The default palette uses neutral surfaces, subtle borders, 16-pixel text,
rounded corners and flat buttons with hover/pressed feedback. Checkboxes,
radios and switches draw their indicators without framing the entire row.
Progress bars use a slim rounded track. Text and picker focus remains clearly
visible without covering values or action icons.

Set `:button-depth` to a positive value to opt into raised buttons: these show
a lower shadow edge at rest and an upper inset edge when pressed, with the
caption following the face. Elevation stays inside widget bounds and does not
change layout or hit testing. Disabled buttons remain flat.

In the GTK demo launcher, open `combobox` for the dropdown option selector
(the first control), or `application_demo` for application action menus.

Dropdown selectors use a button face, a divider, and a geometric chevron that
points up while the option popup is open. Their indicator space is reserved so
long selected values cannot cover the chevron. The `combobox` demo uses plain
color names that the bundled font covers.

Editable combo boxes retain a text entry area and have a separately clickable
chevron segment. Click that segment or press Down to open suggestions; choosing
one replaces the text and emits the usual text change. Clicks in the text area
continue to position the cursor and allow custom values. Both selector types
share the divider/chevron renderer; long closed dropdown values use `...`.

On a font-atlas cache miss, LUT probes font coverage and builds the final atlas
from supported codepoints only. The probe's expected missing-glyph diagnostic
is suppressed; other native diagnostics remain visible. Missing characters
still render with the font's fallback glyph: automatic fallback-font selection
is not implemented. Native windows already use raylib's warning log level.

Opening either selector focuses its popup list immediately. Up/Down move the
highlight without changing the owner; Enter commits the highlighted option.
Escape cancels the preview. Selection and cancellation return focus to the
owner, so no Tab step is needed to continue keyboard use.

List and table hover feedback applies to the individual row under the pointer,
using `:hover-color` (or `:pressed-color` while pressed). The list surface stays
neutral. Selected rows retain `:accent` and `:on-accent`; hovering does not change
selection or commit a popup option. Hover clears on leaving or empty space and
tracks scrolled content; table headers are excluded from row hover.
