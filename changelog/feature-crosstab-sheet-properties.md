# feat(export): fix the crosstab sheet widths, wrapping and freeze pane

**Date**: 2026-11-19
**Branch**: feature/crosstab-sheet-properties

## Changes

PR 15 of `plans/impl-export-metadata.md`. The crosstab drops its `100%` row.
Widths, wrapping, the heading row height and the freeze pane are fixed
values, so a label change moves no column. No formal argument changes, so no
`man/` file moves.

### `R/export-crosstab.R`

- `.render_crosstab_single()`: the `Total` row of `100%` cells is deleted.
  The footer starts right after the last response row. `export_topline()`
  keeps its own `Total` row (spec 4.2).
- New `.write_sheet_columns()`, called once per sheet by `export_crosstab()`:
  - Column A is 44. Each data column is 12, held in one variable
    (`data_width`).
  - Column B is 20 on a per-question battery sheet, and the larger of 20 and
    the data width on a stacked sheet that holds a battery block.
  - Column A wraps from row 1 to the last row written.
  - No auto-fit.
- `export_crosstab()` tracks the widest block, whether a battery is on the
  sheet, and the last row, for each sheet.
- `.render_block_preamble()`: the heading row wraps and is 30 points high. The
  freeze pane splits at the first data row. It is set only for the block at
  `start_row == 1L`, and not under `sample_size_display = "bottom"`.
- `.render_crosstab_battery()`: the `Response` label cells in column B wrap.
  On a stacked sheet, another block's estimate cells in column B do not.

## Readings the spec leaves open

- The column A wrap covers every row from the title to the last row,
  including the base note and the withheld lines.
- The freeze pane is also written under `sample_size_display = "none"`,
  below the heading row. The spec excludes only `"bottom"`.
- Column B on a stacked sheet is the larger of 20 and the data width whenever
  a battery block is on the sheet, as plan task 10 reads.
- Widths are set on columns 1 to the widest block on the sheet only.
- XX-01: surveycore cannot build a one-row design, so the test reuses
  `one_row_design()` from XX-02: a domain that keeps one phase-2 row. The
  topline count is the `N` cell of its `Total` row.
- XN-05 sets 10 in-domain `q1` answers to NA, so the variable's N differs
  from the in-domain row count.

## Tests

- `tests/testthat/test-export-crosstab.R`:
  - Section 30: XH-10, XB-01, XB-02, XB-03, XB-04, XB-11, XB-12, XB-13.
  - Section 31: XX-01, XX-04, the unused factor level case, XX-11, XX-12.
  - Section 32: XN-01 to XN-05, tagged `[numerical]`.
- `tests/testthat/test-export-topline.R`, section 18: the topline still
  writes its `Total` row of `100%` cells.
- Every block loops all four designs.
- Failed first: XH-10, XB-01, XB-03, XB-04, XB-11 and XB-13.

Existing test changed, with the user's approval (2026-11-19): the helper
`column_cells()` read a column down to the `Total` row, which is gone. It now
reads down to the last written row of column A. Four tests use it (XW-02,
XW-04, XW-13, XV-05); no assertion line changed.

No snapshot is new or moved.

Gate runner (`.claude/scripts/run-gates.sh`), 1163 seconds:

- Tests: 0 failures, 0 warnings, 3857 expectations
- R CMD check: 0 errors, 0 warnings, 2 approved notes
- Coverage: 99.84% before, 99.85% after. `R/export-crosstab.R` has no
  uncovered line.
- `document()`, R CMD build and `check_pkgdown()` pass
- `air format --check R tests` passes. The full-tree air gate named only an
  untracked mockup script outside this PR.

## Files Modified

- `R/export-crosstab.R` — the `100%` row removed, widths, wrapping, row
  height, freeze pane
- `tests/testthat/test-export-crosstab.R` — sections 30 to 32, the helper
  change
- `tests/testthat/test-export-topline.R` — section 18
- `changelog/feature-crosstab-sheet-properties.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 15 complete
