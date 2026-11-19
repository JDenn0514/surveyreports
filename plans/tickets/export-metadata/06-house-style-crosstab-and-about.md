# 06: House style B1 on the crosstab sheets and the About sheet

**What to build:** Every crosstab question sheet, under both layouts, and
the `"About"` sheet of both export functions take house style B1. The base
font is Calibri 11 and gridlines are hidden. Each block has a navy title
band, filled spanner and heading rows, zebra stripes, a grey box, a navy
rule at the left edge of each column group, and the interval on a smaller
grey second line. The merged rows (title, notes, legend, spanner, withheld
lines) get a height that follows their text. The pane also freezes the label
columns. No cell value, row, column, sheet name or argument changes.

**Blocked by:** 05 (The Total column, missing data and the block row order).
It is the last change to the block shape, so the style is applied to the
final rows once.

**Status:** ready-for-agent

**Branch:** `feature/house-style`

## Spec

Spec v0.29.0: 3.14, 3.16, 3.21.1, 3.21.2, 3.21.3, 3.21.5, 3.21.6, 3.21.7,
VIII, 8.1. Context: the decision entries "House style B1" and "Spec gaps
settled from the decision page" (extra 1).

## Scenarios

- Own: XY-01 to XY-24 (24 ids), and TY-10 (the About sheet of a
  collection).
- Rewrite to their house-style clause: XB-03, XB-10, XB-11, XB-12, XB-13.
- Must still pass unchanged: XB-04, XB-09, XS-02, XA-12.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)`, labelled with the design name. `TY-10`
      runs on the two-wave collection.
- [ ] `.build_house_style()`, `.build_row_height()` and
      `.write_block_style()` are in `R/export-utils.R`, and
      `ls("package:surveyreports", all.names = TRUE)` exposes none of them.
- [ ] The colour grep of spec VIII returns lines inside
      `.build_house_style()` only.
- [ ] The style-call grep of spec VIII returns nothing for
      `R/export-crosstab.R`. Ticket 07 clears `R/export-topline.R`.
- [ ] `grep -rn "wb_set_grid_lines" R/` returns nothing.
- [ ] `devtools::document()` leaves `NAMESPACE` and `man/` unchanged, and
      no snapshot moved.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/feature-house-style.md` exists.

## Notes

- Register one complete cell style per distinct cell record and set it
  with `openxlsx2::wb_set_cell_style()`. Do not layer `wb_add_font()`,
  `wb_add_fill()` and `wb_add_border()`: the result depends on their order
  over ranges that overlap.
- Section 5 of `plans/mockups/build-mockups.R` (`xf_id()`,
  `finish_sheet()`, `style_table()`, `new_workbook()`) is a working example
  on openxlsx2 1.28. Take the mechanism, not the values. Its row heights
  follow the withdrawn v0.28.0 rule (every row sized), so do not copy them.
- `.render_block_preamble()` and `.render_block_footer()` return the
  block's layout record beside `wb` and `next_row`. Each route adds its
  rows, columns, groups and stripe numbers, then calls
  `.write_block_style()` once, after the footer.
- `.render_block_preamble()` gains `freeze_cols`. `export_crosstab()`
  passes it per sheet from `classify_out`: 2 on a battery sheet and on a
  stacked sheet with any battery, 1 otherwise.
- The 30-point heading and estimate rows and the wrap that tickets 04 and
  earlier set move into `.write_block_style()`. No other row stores a
  height.
- Add `grid_lines = FALSE` to the About sheet in `.build_workbook()` and to
  every `wb_add_worksheet()` call in `R/export-crosstab.R`.
- `tests/testthat/helper-house-style.R` holds the readers and
  `expected_height()`, written from spec 3.21.6, never from `R/`. Check it
  against hand counts: 21, 18, 19 and 34.
- The merged test "writes the About sheet with no merged cell and two
  stored widths" asserts column B at 12. Rewrite it to 90.
