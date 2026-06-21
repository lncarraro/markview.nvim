; Table width measurement must follow rendered display width, not raw Markdown width.
;
; Open this fixture with `wrap` enabled. The first table has deliberately long
; link destinations whose raw source width is much larger than the rendered
; labels. It should be judged by the rendered labels and decorations.

## Concealed links

| Document | Description |
| --- | --- |
| [`product.md`](https://example.com/a/very/long/path/that/must/not/count/toward/the/rendered/table/width/product.md) | Product vision |
| [`architecture.md`](https://example.com/a/very/long/path/that/must/not/count/toward/the/rendered/table/width/architecture.md) | Architecture overview |

## Inline decorations and display width

| Kind | Value |
| --- | --- |
| Inline code | `parser-sidecar extract-java` |
| Nested link/code | [`code`](https://example.com/a/very/long/destination/hidden/by/the/renderer) |
| Wide Unicode | 日本語 🚀 |
| Combining text | café |

## Disabled-renderer check

When hyperlinks or inline codes are disabled in the Markview configuration,
the corresponding Markdown delimiters and destinations remain visible. Width
measurement must therefore use the full raw syntax for that disabled renderer.

## Overflow behavior

With `markdown.tables.overflow = "horizontal"` and window-local `wrap` enabled,
the concealed-links table must render at its natural width, switch only that
window to `nowrap`, and remain horizontally scrollable. Disabling or clearing
Markview preview must restore the original `wrap` value.

With `markdown.tables.overflow = "raw"`, the same genuinely overflowing table
must remain raw Markdown and must not change the window-local `wrap` value.

When Tree-sitter does not emit `markdown_inline` nodes for link content inside a
table cell, the table renderer must display the same decorated representation it
used for width measurement. The raw link destination must not remain visible,
and every row separator must stay at the same screen column while scrolling.
Cells already covered by the normal inline renderer must not receive a duplicate
table-level decoration.

Projected horizontal rows must use overlay virtual text rather than concealing
the complete source line. Normal-mode cursor movement must continue to traverse
the underlying Markdown columns instead of appearing permanently at the end of
the projected table. Moving left or right must not change table alignment.
