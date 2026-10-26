# Wrapped text and rich document blocks

Use `wrapped-text-view` for editable character-wrapped text and
`wrapped-document-view` for read-only documents. Existing `text-view`,
`styled-text-view` and `document-view` retain their unwrapped behavior.

```lisp
(lut:make-widget 'lut:wrapped-text-view
  :text "Type here" :hexpand t :max-height 150)
```

Place the composer in a `measured-box` to allocate its height for the available
width. It grows to `max-height`, then uses its vertical viewport. A plain box
still uses explicit size hints. Measuring never changes allocated geometry.

Visual rows preserve every character, including whitespace; this first wrapping
policy breaks at character boundaries, including long words. Newlines retain
empty paragraphs and a trailing empty row. At a soft boundary the insertion
position normally belongs to the following row (downstream affinity). End retains
the caret on the preceding row until another cursor assignment. Home/End use visual
row bounds; Up/Down retain the horizontal navigation goal. Word selection and
`select-line` continue using logical text boundaries. Selection, shared buffers,
undo/redo, pointer selection, autoscroll and read-only policy use existing APIs.
Horizontal scrolling is disabled for wrapped views. A glyph wider than the
viewport is clipped; its character remains addressable.

For documents, use `set-text-presentation` with existing `:runs`, `:links` and
`:images`. A heading is a font-size run. Row height is at least the base
`line-height` and every run's font size. `paragraph-spacing` adds pixels after
logical paragraphs; it does not separate soft continuation rows. An image
record occupies its U+FFFC replacement character, forces a separate row, and
can exceed the base line height. Its explicit dimensions control its row size;
images wider than the viewport are clipped. Applications supply image sources,
text, formatting and link targets, and decide how to handle `:link`.
Markdown parsing and document models stay outside LUT.

Rows cache insertion advances for the current buffer, width, presentation and
font metrics. Edits, resize and presentation/style changes rebuild them.
`invalidate-text-geometry` handles external custom font/measurement changes.
Disposal clears the cache. Reflow currently visits the whole document and stores
one advance per character; it is not incremental layout for huge documents.
Streaming appends rebuild all rows on each chunk, so cumulative layout work can
be quadratic in the final reply length. Applications should batch streaming
updates for now; append-only row reuse remains future work alongside follow-end.
Glyph discovery separately caches each wrapped view's code-point set by text root
and presentation revision. Unchanged documents are not rescanned each frame;
window glyph sets are shared within each layout/render pass. Disposal releases
the retained glyph cache.
No shaping, bidi, grapheme-aware movement, IME or accessibility support is added.

Run `lut-examples:wrapped-text` to try resizing a document and a growing composer.
