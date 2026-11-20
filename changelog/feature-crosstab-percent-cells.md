# feat(export): write each crosstab percentage cell as a string

**Date**: 2026-11-19
**Branch**: feature/crosstab-percent-cells

## Changes

Ticket 03 of `plans/tickets/export-metadata/README.md` (PR 16 of
`plans/impl-export-metadata.md`). Every estimate cell that
`export_crosstab()` writes is now text in one of five forms: a rounded
percentage such as `41.2%`, `0%`, the floor string (`<0.1%` at one decimal),
the ceiling string (`>99.9%`), or `-`. The rule is the same in
single-response, SATA and battery blocks (spec 3.3).

`decimals = 0` is now allowed in both export functions, as spec 3.2 says.
This touches `export_topline()`: a call at `decimals = 0` used to abort and
now writes whole-number percentages. The user approved this change on
2026-11-19.

### `R/export-crosstab.R`

- New `.fmt_pct_cell(col_rows, own, decimals)`, below the exported function.
  It reads the whole banner column of the variable (gap 17):
  - When any row of the variable in that column has n > 0 and the cell's
    own row is absent or has n = 0, it passes `p = 0` to `.fmt_pct()`, so
    the cell reads `0%`.
  - When no row in the column has n > 0, the cell reads `-`.
  - Otherwise it passes the `get_freqs()` proportion to `.fmt_pct()`
    unchanged.
- The single-response, SATA and battery routes call it. The two inline
  `round(pct * 100, decimals)` conversions are gone.
- The SATA route reads the chosen row from the frame's `sata_chosen` column
  and no longer calls `.sata_pct_cell()`. That helper is unchanged and still
  serves `export_topline()`.
- `grep -rn "\* 100" R/` returns four lines, as spec VIII expects.
- `@param decimals` reads "A whole number, 0 or more".

### `R/export-utils.R`

- `.validate_export_inputs()`: `decimals` must be a finite whole number of 0
  or more. The class stays `surveyreports_error_invalid_decimals`. The
  message now reads "`decimals` must be a whole number, 0 or more."

### `R/export-topline.R`

- `@param decimals` only. No cell and no render code changed.

### `plans/error-messages.md`

- The `surveyreports_error_invalid_decimals` row describes the new rule.

## Readings the spec leaves open

- A cell whose own row has n > 0 and an `NA` proportion still reads `-`,
  because `.fmt_pct()` reads `NA` as no estimate. No fixture produces it.
- The XC-04 to XC-05b fixture is a 10,000-row taylor design with unit
  weights and 3 `Rare` rows, not the 200-row `rare` fixture. One row in 200
  is 0.5%, which is above the `<0.1%` threshold. The test-spec allows the
  fixture to be adjusted.
- The `Percentages` glossary entry stays absent until ticket 05 passes
  `string_cells = TRUE`, as the ticket says.

## Tests

- `tests/testthat/test-export-crosstab.R`, section 33: XC-01 to XC-08, with
  XC-05a, XC-05b, XC-06a and XC-07a.
  - XC-01, XC-02 and XC-03 loop all four designs over three blocks: `q1`, a
    SATA block whose `sata_a` is labelled 1 = Yes, 2 = No, and the battery.
  - The expected strings come from `surveycore::get_freqs()` and `round()`,
    not from `.fmt_pct()`. Each test checks every estimate cell of the
    block, and checks that it checked rows times columns of them.
  - XC-01 also reads the XML type of each estimate cell: none is a number.
  - Failed first: every XC row. XC-03, XC-05 and XC-05b also failed on the
    `decimals = 0` validator.
- `tests/testthat/test-export-topline.R`: a new `[numerical]` block. At
  `decimals = 0`, on all four designs, the topline writes whole-number
  percentages equal to `round(pct * 100, 0)` from `get_freqs()`.
- Both files: a class-only block for `decimals = 1.5`.

Existing tests changed:

- Both `decimals` error tests (crosstab and topline) used `decimals = 0`,
  which is now valid. They use `decimals = -1` and are renamed "errors when
  decimals is negative". Their two snapshots move. The user approved both.
- "Total column values match the full-sample distribution" and "SATA tables
  gain the Total column by default" read the Total cell as a number. They
  now compare the string `paste0(round(pct * 100, 1), "%")`.
- "prints 0 for an asked-but-never-selected SATA option" expected the
  number 0. It now expects `0%` in all four columns, and its title says
  `0%`.
- "leaves never-asked banner subgroups blank in SATA tables" expected a
  blank cell and the number 0. Spec 3.3 (gap 17) gives `-` for never asked
  and `0%` for asked and chosen by nobody. Renamed "writes - for never-asked
  banner subgroups in SATA tables".
- "prints the code-1 share for a labelled SATA item" read its cells as
  numbers. It now compares the strings built from the oracle.

No other snapshot moved. No `export_topline()` snapshot moved apart from the
approved `decimals` error.

Gate runner (`.claude/scripts/run-gates.sh`), all gates PASS:

- Tests: 0 failures, 0 warnings, 0 skips, 5253 expectations
- Coverage: 99.85%. The one uncovered line in a changed file,
  `R/export-utils.R:85`, is the zero-row branch of the domain check, which
  this branch does not touch.
- R CMD check: 0 errors, 0 warnings, 3 notes. Two are the approved notes
  (CRAN incoming feasibility; no visible binding for `n`, `pct`, `value`).
  The third names a hidden `.git`: in a git worktree `.git` is a file, and
  the build keeps it. A build from the main checkout does not show it.
- `document()` (no drift), R CMD build and `check_pkgdown()` pass
- `air format --check` passes

## Files Modified

- `R/export-crosstab.R` — the string cells, `.fmt_pct_cell()`,
  `@param decimals`
- `R/export-utils.R` — the `decimals` validator
- `R/export-topline.R` — `@param decimals`
- `man/export_crosstab.Rd`, `man/export_topline.Rd` — regenerated
- `plans/error-messages.md` — the `invalid_decimals` row
- `tests/testthat/test-export-crosstab.R` — section 33, five changed tests,
  the `decimals` error tests
- `tests/testthat/test-export-topline.R` — the `decimals = 0` block, the
  `decimals` error tests
- `tests/testthat/_snaps/export-crosstab.md`,
  `tests/testthat/_snaps/export-topline.md` — the two `decimals` error
  snapshots
- `changelog/feature-crosstab-percent-cells.md` — new; this file
