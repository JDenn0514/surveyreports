# feat(export): add the About cover sheet to every workbook

**Date**: 2026-11-12
**Branch**: feature/cover-sheet

## Changes

PR 6 of `plans/impl-export-metadata.md`. Every workbook from
`export_topline()` and `export_crosstab()` now has a sheet named `About` as
sheet 1, and the file opens on it.

- `.build_workbook(design, withheld = NULL, min_eff_n = NULL,
  has_banner = FALSE, string_cells = FALSE, variance = NULL)` takes the
  signature of spec 2.3. It adds the `About` sheet before any question sheet.
- New `.write_cover_sheet(wb, design, withheld, min_eff_n, has_banner,
  string_cells, variance)` writes the sheet under a `Key` / `Value` header:
  - the survey metadata block, one row per set key in surveycore's key order;
  - a `Restricted to` row (`75 of 200 rows`) when `.has_domain()` is TRUE;
  - on a collection, one block per wave in `@surveys` order, with a heading
    for a wave that has no keys;
  - the withheld block, with a `None` row for a zero-row frame and no block
    for `NULL`;
  - the glossary: five terms, three conditions. No sixth term is added under
    `variance = "se"`, per the issue-66 decision in spec 3.15.
  The sheet has no merged cell. Columns A and B have stored widths.
- `export_topline()` passes `design` and `variance`. `export_crosstab()`
  passes `design`, `has_banner = TRUE`, `string_cells = FALSE`, `variance`
  and `withheld = NULL`.
- `export_crosstab()` gives each per-question sheet its name through
  `.unique_sheet_name()`. A variable named `About` gets the sheet `About_2`,
  and two variables that share their first 31 characters get two sheets.

Readings the spec leaves open, each stated in a code comment:

- The key labels (`Survey`, `Dataset`, `Vendor`, `Field start`, `Field end`,
  `Field period`). Spec v0.27 does not give them. They come from the earlier
  topline and crosstab spec.
- A single design's survey block has no heading row. The `Key` / `Value`
  header heads it.
- On a collection, each wave block gets its own domain row.
- The withheld block is a `Minimum effective sample size` row, then one
  `Not shown` row per subgroup.
- Column A is 44 wide and column B is 12, the widths of spec 3.16.

## `decimals` reaches the cover sheet

Spec 3.15 says the `Percentages` glossary entry is written at the precision
`decimals` sets, so its examples match the cells. The seven-argument
signature in spec 2.2 had no `decimals`. Decided 2026-11-13:

- `.write_cover_sheet()` and `.build_workbook()` take `decimals`, and both
  export functions pass their own. Spec 2.2 and 2.3 record the change.
- The two example strings (`<0.1%` and `>99.9%` at `decimals = 1`) come from
  the same helper that `.fmt_pct()` uses, so the entry and the cells agree.
  At `decimals = 0` the entry reads `<1%` and `>99%`.

No caller sets `string_cells = TRUE` yet, so no workbook shows the entry
until `feature/crosstab-percent-cells`.

## Tests

- `tests/testthat/test-export-crosstab.R`, new section 23: XA-01 to XA-04,
  XA-08 to XA-11 and XA-13, plus a no-merged-cell and column-width test and
  six direct `.write_cover_sheet()` tests for paths no export function
  reaches yet. Four more blocks test `.fmt_pct_limits()` and the
  `Percentages` entry at `decimals` 0, 1 and 2.
- `tests/testthat/test-export-topline.R`, new section 13: TP-06, TP-06a,
  TP-07, TC-05, TC-06 and TC-07.
- Five existing crosstab tests count one more sheet, or read sheet 2 in
  place of sheet 1, because `About` is now sheet 1.

Both test files define their own `about_sheet()`, `about_glossary()` and
`cover_design()`. They belong in a `helper-*.R` file, which is outside this
PR's write surface.

## Files Modified

- `R/export-utils.R` — new `.write_cover_sheet()`; new `.build_workbook()`
  signature; new `.fmt_pct_limits()`, which `.fmt_pct()` now calls
- `plans/spec-export-metadata.md` — `decimals` added to the two signatures
  in 2.2 and 2.3
- `R/export-topline.R` — new `.build_workbook()` call
- `R/export-crosstab.R` — new `.build_workbook()` call; sheet names through
  `.unique_sheet_name()`
- `tests/testthat/test-export-crosstab.R` — section 23; five tests adjusted
- `tests/testthat/test-export-topline.R` — section 13
- `changelog/feature-cover-sheet.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 6 complete
