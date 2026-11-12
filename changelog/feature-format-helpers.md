# feat(export): add the format and write helpers for export-metadata

**Date**: 2026-11-12
**Branch**: feature/format-helpers

## Changes

PR 5 of `plans/impl-export-metadata.md`. Five helpers go into
`R/export-utils.R` and one into `R/export-crosstab.R`. No exported function
calls them yet, so no workbook changes.

- `.fmt_pct(p, decimals, has_rows)` turns a proportion into one percentage
  cell: `-`, `0%`, the floor string (`<0.1%`), the ceiling string (`>99.9%`),
  or the rounded value (`35.6%`). It multiplies by 100 itself. Rounding is
  half to even, and `decimals` is a maximum, so 30.0 prints `30%`.
- `.fmt_variance(rows, variance, decimals, has_rows)` writes `(2.9%)` for
  `"se"` and `(-0.3% – 1.8%)` for `"ci"`, with an en-dash and a hyphen-minus.
  Every number goes through `.fmt_pct()`. It returns `""` when `variance` is
  `NULL` or the cell has no rows.
- `.build_withheld(counts, min_eff_n, banner_var)` returns one row per
  subgroup whose effective N is below `min_eff_n`, and a zero-row tibble when
  none is. It never returns `NULL`. It holds the only `n_eff < min_eff_n` test
  in the package.
- `.format_withheld_lines(withheld, min_eff_n)` writes one line per withheld
  subgroup, for example
  `"Female" (gen) withheld: effective sample size 18.3, below the minimum of 100.`
  It names no raw N.
- `.write_sample_size_rows(wb, sheet, start_row, label_cols, counts, show_ess)`
  writes the two sample-size rows and returns `list(wb = , next_row = )`. A
  zero-row `counts` frame writes the labels and no data cell.
- `.unique_sheet_name(wb, name)` in `R/export-crosstab.R` returns a sheet name
  that does not collide with one in `wb`, comparing without case. It adds
  `_2`, `_3` and so on, and shortens the name so that it never exceeds 31
  characters.

`.fmt_pct()`, `.fmt_variance()`, `.build_withheld()`,
`.format_withheld_lines()` and `.write_sample_size_rows()` have one call-site
file today, `R/export-crosstab.R`, but sit in `R/export-utils.R` because spec
2.1 places them with the shared helpers.

Readings the spec leaves open, each stated in a code comment:

- The wording of a withheld line. Spec 3.14 names what a line holds but gives
  no sentence.
- A suffixed sheet name is shortened to fit 31 characters. Excel rejects a
  longer one.
- An `NA` estimate prints `-`. An `NA` effective N is not withheld.
- The worked example in spec 3.12 shows `(30.0% – 41.3%)`. Spec 3.3 and
  test-spec XH-16 give `(30% – 41.3%)`, and the code follows them.

`air format` rewrites a `"–"` escape as a literal en-dash, which R CMD
check rejects in R code. `.fmt_variance()` builds the character with
`intToUtf8(0x2013L)` for that reason.

The tests are direct calls in a new section 22 of
`tests/testthat/test-export-crosstab.R`: 37 blocks. None of these helpers
takes a design, so the cross-design loop does not apply.

## Files Modified

- `R/export-utils.R` — added `.fmt_pct()`, `.fmt_variance()`,
  `.build_withheld()`, `.format_withheld_lines()` and
  `.write_sample_size_rows()`
- `R/export-crosstab.R` — added `.unique_sheet_name()` below the exported
  function
- `tests/testthat/test-export-crosstab.R` — added section 22, 37 test blocks
- `changelog/feature-format-helpers.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 5 complete
