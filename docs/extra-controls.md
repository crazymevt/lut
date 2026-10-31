# Search, activity and icon toggles

`search-control` inherits `entry`, including text selection, history, shared
buffers and read-only behavior. `:search-hint` displays a hint when empty.
Listen to `:change` for live filtering and `:search` for explicit submission
(Enter or the search button); both receive the current string. Escape or the
clear button clears editable text through the normal undoable edit path, then
emits `:cancel` with the empty string. Programmatic `setf text` remains silent.
Read-only controls can submit but cannot clear. The two buttons participate in
keyboard focus traversal. Filtering and search execution belong to the app.

`activity-indicator` is a noninteractive busy spinner. Set
`activity-running-p` to NIL to hide it, or T to animate it. It uses the normal
render loop, including worker windows, with no timers or callbacks to release.
Its default allocation is 24 by 24 logical pixels. The smooth animated ring
stays at most 20 logical pixels across even in a stretched container; palette
and scaling are inherited.

`icon-toggle-button` inherits `toggle-button`: boolean `value`, click/Space/Enter
activation, `:change` with the new value and `:activate`. Set `:icon-source` to
an image file pathname. It uses the backend's shared texture cache and fits the
image inside the padding while preserving its aspect ratio. NIL draws the
centered `text` fallback. Use `:tooltip-text` to describe an icon-only action.
Disabled controls reject input and tint the image with the disabled color.

The interactive demo has Search, Activity indicator and Icon toggle examples
under Controls. These widgets do not add native accessibility support.

## Date and time pickers

`date-picker` uses `:calendar-date '(year month day)`, defaulting to the current
local date when the widget is created. Dates follow the Gregorian calendar with years 1–9999, including century leap
rules. `time-picker` uses `:clock-time '(hour minute second)`, default `(0 0 0)`,
in 24-hour local wall-clock notation. Set `:time-format :12-hour` for a 12-hour
display with AM/PM, or `:24-hour` (the default). Stored values and change events
always use hours 0–23. It performs no timezone or daylight-saving conversion.
Both accessors copy lists on read/write, reject invalid values before mutation,
and remain silent on programmatic assignment. User edits emit `:change` with a
copied three-element list, only when the value changes.

Use Left/Right to select a field (`picker-field`, indices 0–2). Time fields can
also be selected by clicking. Clicking the date field opens its calendar;
the +/- controls step the selected field without opening it.
Type digits to replace the selected field, Up/Down or the mouse wheel to adjust,
or click +/- to step it. Date month/year changes clamp the day, so moving from
January 31 to February selects its final valid day. Day stepping crosses month
and year boundaries, stopping at years 1 and 9999. Time fields wrap independently
(hour 23 to 0, minute/second 59 to 0) without carrying to another field. A field's
digit buffer resets on field navigation, stepping or Escape, or after its full
width (four year digits, two for other fields). Invalid intermediate digits do
not change the value. Disabled pickers reject input.

For a date, clicking anywhere except +/- opens a Monday-first calendar.
Enter/Space also opens it.
The calendar is a single panel with flat day cells, a selected-date highlight,
and icon-only month navigation. Use the month header arrows to browse. Arrow
keys move keyboard focus by a day/week, including across months; Enter/Space
chooses the focused day. Clicking a day chooses it directly. Browsing leaves the value unchanged until selection. Escape or an
outside click cancels. The popup closes and restores eligible owner focus;
disposing the picker also closes its popup. It stays within available root
bounds where space permits. Calendar labels and numeric formats are fixed;
locale formatting, date ranges and native OS pickers are not provided.

```lisp
(lut:make-widget 'lut:date-picker :calendar-date '(2026 10 31) :width 340)
(lut:make-widget 'lut:time-picker :clock-time '(14 30 0) :width 280)
```

In 12-hour mode, AM/PM is a fourth keyboard field. Click it or use Up/Down or
+/- while it is selected to toggle the period; typing A or P also sets the
period. Typing an hour 1–12 preserves the current period. Switching
`time-format` changes presentation without emitting a value-change event.

Search is drawn as one field with inset icon actions and a shared external
keyboard focus ring. Text, caret and selection stay within its text viewport.
Date/time fields retain a neutral surface on hover; only individual action
icons have hover feedback. Their keyboard focus ring sits outside the border.
Mouse actions commit on release in the same region; dragging away cancels.

```lisp
(lut:make-widget 'lut:date-picker) ; current local date
(lut:make-widget 'lut:time-picker :clock-time '(14 30 0) :time-format :12-hour)
```

Run `tests/polished-controls-native.lisp` for light/dark rendering at 100% and
200%, external focus-ring pixels, stable picker hover and bounded spinner
animation. `tests/portable.lisp` includes mouse-release, scaled action targets,
current-date defaults, AM/PM editing and long search/caret checks.

`spin-button` uses the same vector +/- icons and inset action feedback as the
pickers. Only the two edge actions react to hover/press; the field background
stays neutral. A click commits on release over the same icon, and dragging away
cancels it. Clicking the value area only focuses the control. Keyboard arrows
and wheel stepping retain their existing numeric bounds and step behavior.
