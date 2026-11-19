# feat(export): replace the N column with sample-size rows in export_crosstab()

**Date**: 2026-11-19
**Branch**: feature/crosstab-label-cols-and-sizes

## Changes

PR 14 of `plans/impl-export-metadata.md`. Two sample-size rows replace the
per-response `N` column. The three render routes share one block preamble and
one block footer.

### Breaking: arguments removed and added

- `show_n` and `show_eff_n` are removed from `export_crosstab()`. A call that
  passes either one, or `pub_type`, gets R's unused-argument error (spec 5.1).
  `show_eff_n` had no effect since `feature/effective-n-rewiring`.
- New `sample_size_display = c("top", "bottom", "none")` and `show_ess = TRUE`
  sit after `conf_level` and before `decimals` (spec 3.1).
  - `"top"` (default): an `Unweighted sample size` row and an
    `Effective sample size` row sit under the heading row.
  - `"bottom"`: both rows go below the estimates, before any withheld line.
  - `"none"`: no sample-size rows.
  - `show_ess = FALSE` removes only the effective-sample-size row.
- Both rows are italic and one point smaller than the base font. A battery
  block leaves its second label column blank in these rows.
- The counts are per data column and ignore the tabulated variable. The Total
  column takes the full sample's counts.

### `R/export-crosstab.R`

- `export_crosstab()`: the two layout loops and their six route calls are now
  one loop with one call; a `switch()` picks the route. The loop builds the
  column groups and the counts for each block.
- `.write_crosstab_headers()`: `label_col1` becomes `label_cols`, a vector of
  headings. Spanners start at column `length(label_cols) + 1`. Single blocks
  pass `Response`, SATA blocks `Item`, battery blocks `Item` and `Response`.
- New `.render_block_preamble()`: the title, the base note, the spanner row,
  the heading row, and the sample-size rows at `"top"`. It returns the first
  data row.
- New `.render_block_footer()`: the sample-size rows at `"bottom"`, then the
  withheld lines. It returns the next free row. `.write_withheld_lines()` is
  deleted; its loop moved here.
- New `.block_counts()`: one counts row per data column, in write order.
- `.build_col_groups()` takes `show_total` and puts the Total group first.
  Before, each route did this itself; the output does not change.
- `.count_render_cols()` takes the number of label columns.
- The three routes write no `N` column and take the same arguments.

### `R/export-utils.R`

- `.build_freq_frame()` also returns `group_counts`, the counts it already
  looks up for each banner column and interaction, so no count is looked up
  twice.
- `.write_sample_size_rows()` sets the italic, one-point-smaller font.
- `.sata_n_cell()` is unchanged; `export_topline()` still uses it.

## Readings the spec leaves open

- The preamble has no `legend` argument yet. PR 17 adds the legend row.
- The routes pass the two sample-size arguments through `...`, because the
  acceptance grep forbids the routes from naming `sample_size_display`.
- The `100%` Total row stays until PR 15. Under `"bottom"`, the sample-size
  rows go after it.
- XS-09 compares against surveycore: the sum of `get_freqs()$n` is less than
  the count cell, and the count cell equals the in-scope rows.

## Accepted grep exceptions (user, 2026-11-19)

- `grep "show_n\|show_eff_n"` on the test file finds 2 lines. Both are in
  XE-07, which passes the old arguments to show that they now give an error.
- `grep write_crosstab_headers` finds 2 lines, not 4: the definition and the
  call in `.render_block_preamble()`. Spec 2.2 and 3.16 have the preamble make
  the call.

## Tests

`tests/testthat/test-export-crosstab.R`:

- Section 9, "show_n and show_eff_n", is deleted (3 blocks). Its banner points
  to section 29.
- New section 29: XD-01, XS-01 to XS-10 and XE-07, on all four designs.
- Failed first: XS-01 and XE-07. XD-01 passed on first write, because the
  battery route already wrote its own `Item` and `Response` headings.

Existing tests changed, with the user's approval (2026-11-19). All four read
the `N` column or passed `show_n`:

- "show_total shifts the N column one position right" becomes "show_total
  puts the Total column in front of the banner columns", and checks the
  heading order.
- "battery N column follows the banner columns" becomes "battery banner
  columns follow the Total column, with no N column".
- "prints 0 for an asked-but-never-selected SATA option" loses its check of
  the old `N` cell.
- "withholds a below-floor column from SATA and battery blocks" loses its
  `show_n` loop, and checks that no heading reads `N`.

No snapshot is new or moved.

Gate runner (`.claude/scripts/run-gates.sh`), 861 seconds:

- Tests: 0 failures, 0 warnings, 3396 expectations
- R CMD check: 0 errors, 0 warnings, 2 approved notes
- Coverage: 99.85% before, 99.84% after. `R/export-crosstab.R` is at 100%.
  The one uncovered line, `R/export-utils.R:85`, is old.
- `air format --check .`, R CMD build and `check_pkgdown()` pass
- The `document()` gate reports drift because `man/export_crosstab.Rd` is not
  yet committed. A second `document()` run left the Rd and `NAMESPACE`
  unchanged, byte for byte.

## Files Modified

- `R/export-crosstab.R` — the arguments, the roxygen, the shared preamble and
  footer, the single route loop
- `R/export-utils.R` — `group_counts`, the sample-size font
- `man/export_crosstab.Rd` — regenerated
- `tests/testthat/test-export-crosstab.R` — section 9 deleted, section 29, the
  edits above
- `changelog/feature-crosstab-label-cols-and-sizes.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 14 complete
