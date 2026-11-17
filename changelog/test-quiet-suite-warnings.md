# test(export): quiet the warnings in the test suite

**Date**: 2026-11-16
**Branch**: test/quiet-suite-warnings

## Changes

`devtools::test()` gave 659 warnings and now gives 0. No warning that a test
is about was touched: every `expect_warning()` and `expect_no_warning()` still
sees what it saw before. No assertion changed, no snapshot moved, and each
file passes the same number of expectations as before.

| File | Warnings before | Warnings after | Passed before | Passed after |
|---|---|---|---|---|
| `test-export-crosstab.R` | 458 | 0 | 1361 | 1361 |
| `test-export-topline.R` | 195 | 0 | 495 | 495 |
| `test-pool-pvals.R` | 6 | 0 | 122 | 122 |
| `test-package.R` | 0 | 0 | 1 | 1 |
| Total | 659 | 0 | 1979 | 1979 |

The warnings came from five sources:

- 622 `surveycore_warning_nonprob_srs_fallback` (442 crosstab, 180 topline).
  surveycore 1.2.0 raises it on every estimate from a `survey_nonprob` design
  that has no bootstrap replicate weights. The fixture's nonprob design has
  none, so every cross-design loop raised it.
- 18 missing-variable-label warnings (9 crosstab, 9 topline) from blocks that
  do not test that warning.
- 10 `file.remove()` warnings (5 crosstab, 5 topline): a loop removed its
  temp file on the first pass, before the file existed.
- 3 setup warnings from surveycore: a single stratum, a single-level banner,
  and an all-NA SATA item. Each one is the input the block sets up, not the
  thing it tests.
- 6 surveycore warnings in `test-pool-pvals.R` from the 6-row dataset that
  feeds `get_diffs()` and `get_t_test()`.

## How each source was fixed

- New file `tests/testthat/helper-export.R`. It holds `quiet_nonprob()`, which
  muffles the nonprob fallback class and no other, plus `topline_quiet()` and
  `crosstab_quiet()`, which wrap the export functions in it.
  `crosstab_quiet()` moved here from section 25 of `test-export-crosstab.R`.
- The blocks that raised the nonprob warning now call `topline_quiet()` or
  `crosstab_quiet()`. A call inside `expect_snapshot()` or `expect_error()`
  was left alone. `battery_col_a()` and one `get_freqs()` reference call take
  the same wrapper.
- The fix is in the tests, not in the fixture. Bootstrap replicate weights on
  the nonprob design would stop the warning, but they move every nonprob test
  from the calibration SE path to the replicate path and add columns to the
  design. The package code does not muffle the warning.
- Label warnings: a block that does not test labels now passes its design
  through `cover_design()`, or sets the `q1` label inline as the
  `pub_type = "none"` block already did. The block that tests the
  variable-name fallback keeps the unlabelled design and muffles
  `surveyreports_warning_missing_variable_label` by class.
- `file.remove(out)` at the top of a loop is now `unlink(out)`, which is
  silent when the file does not exist.
- The single-stratum, single-level and all-NA warnings are muffled by class
  (`surveycore_warning_single_stratum`, `surveycore_warning_single_level`,
  `surveycore_warning_all_na_freqs`) around the one call that raises each.
- `test-pool-pvals.R`: the `get_diffs()` and `get_t_test()` setup calls take
  `suppressWarnings()`, as the `get_pairwise()` block next to them does.

`about_sheet()`, `about_glossary()` and `cover_design()` were defined in both
export test files. They are now in `helper-export.R` once. `cover_design()`
takes the crosstab version, which also labels `group`. Every topline call
passes a design that has `group`, so the topline tests see no difference.

## Notes

- The gate in `plans/test-spec-export-metadata.md` (the warning count drops
  from 88 to 8 or fewer) can now be met: the count is 0.
- A new warning in the suite is now a real signal. A test that adds a
  nonprob loop should call `topline_quiet()` or `crosstab_quiet()`.
