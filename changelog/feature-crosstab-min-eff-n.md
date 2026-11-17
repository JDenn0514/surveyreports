# feat(export): replace pub_type with min_eff_n in export_crosstab()

**Date**: 2026-11-16
**Branch**: feature/crosstab-min-eff-n

## Changes

PR 11 of `plans/impl-export-metadata.md`. One floor on the effective N
replaces the three `pub_type` modes. A banner level below the floor loses its
heading, its cells and its share of the spanner.

- `export_crosstab()` takes `min_eff_n = 100` in the place of `pub_type`,
  right after `interactions` (spec 3.1). `@param min_eff_n` gives the range,
  the default, the equal-to-floor case, and `0` to show every level.
  `man/export_crosstab.Rd` is regenerated.
- New `.validate_min_eff_n()`, below the exported function, runs at step 8 of
  spec 3.11. It aborts with `surveyreports_error_invalid_min_eff_n` unless the
  value is a length-1, finite, numeric value at or above 0. Spec 3.11 and 3.17
  say "in `.validate_export_inputs()`", but that helper runs at step 4, so
  plan task 9 is not followed literally.
- `.build_freq_frame()` takes `min_eff_n` in the place of `pub_type`. Per
  banner column it calls `.resolve_eff_n()`, then `.build_withheld()`, and
  keeps `setdiff(counts$level, withheld$level)`. The frame is filtered to the
  kept levels. The old raw-N loop and the holding change from
  `feature/effective-n-rewiring` are gone. `.build_withheld()` holds the only
  `n_eff <` comparison in `R/`.
- `.empty_suppressed()` loses its `pub_type` column. `threshold` is now
  numeric, and the footnote formats it with `format()`, so a fractional floor
  no longer breaks `sprintf("%d")`.
- The step comments in `export_crosstab()` now match spec 3.11. The surveycore
  install check is unnumbered, and step 8 is added. Step 12 (banner labels)
  belongs to a later PR.
- `surveyreports_warning_subgroup_suppressed` still fires inside
  `.build_freq_frame()`. PR 13 moves and renames it.

## Readings the spec leaves open

- **A floor of 50, not 100, in XW-01, XW-02, XW-03, XW-12 and the SATA and
  battery block.** On the twophase design, phase 2 keeps 107 of the 180 Male
  rows, with an effective N of 99.2. At 100, Male is withheld too, so XW-02
  and XW-03 cannot hold. At 50, every design withholds Female (effective N
  18.1 or less) and keeps Male (99.2 or more). The user chose this over a
  change to the shared test data (decided 2026-11-17).
- XW-05 sets the floor per design to the midpoint of the raw N and the
  effective N, from the oracle.
- The `min_eff_n` error reads "Error in `export_crosstab()`". Its "i" bullet
  is "Got {.val}", as for `conf_level`.
- Section 10 keeps its banner as "Suppression: N/A", so sections 11 to 25 keep
  their numbers.

## Test-spec change

`plans/test-spec-export-metadata.md` gets a fixture caution for the floor on
twophase, and the rows that later PRs own move off the floor of 100:

- XW-01, XR-01, XA-12, XV-03 and XX-08 use `min_eff_n = 50`.
- XA-06, which needs every subgroup kept, uses `min_eff_n = 10`.
- XH-14 and the second call of XE-16 keep the floor of 100. Their assertions
  hold when `Male` is withheld too, and XE-16 tests the default itself.

Plan task 17 for PR 11 now says 50.

## Tests

`tests/testthat/test-export-crosstab.R`:

- Section 10, "pub_type suppression", is deleted: five blocks, no snapshots.
- New section 26: XE-11, XW-01, XW-02, XW-03, XW-04, XW-05, XW-12 and XW-13,
  plus a block that withholds a column from SATA and battery blocks under both
  `show_n` values. That block restores the coverage of the SATA and battery
  footnote lines that section 10 held. Every block except XE-11 loops all
  four designs.
- XE-11 and XW-01 failed first. With `<=` in `.build_withheld()`, XW-13 fails
  on all four designs.
- At the default floor of 100, the `group` levels (effective N near 62) are
  withheld. `min_eff_n = 0` is added to every call with a `banner` in the
  blocks that then failed or warned: 59 calls, plus the `battery_col_a()`
  helper.
- Two new snapshots: XE-11 and XW-01. Four snapshots moved (XE-06, XV-01,
  XV-02, XV-07): only the echoed call gained `min_eff_n = 0`, and the recorded
  conditions are unchanged.

Results:

- `devtools::test()`: 350 blocks, 0 failures, 0 warnings
- `devtools::check()`: 0 errors, 0 warnings, 1 approved note
- Coverage: 99.58% before, 99.68% after, by the same command. No line this PR
  added or changed is uncovered.
- `air format --check .` passes.
- `grep -rn "pub_type"` finds nothing in `R/`, `man/` or the crosstab test
  file.

## Files Modified

- `R/export-crosstab.R` — the signature, roxygen, step 8 and
  `.validate_min_eff_n()`
- `R/export-utils.R` — the withholding step in `.build_freq_frame()`,
  `.empty_suppressed()` and the footnote format
- `man/export_crosstab.Rd` — regenerated
- `tests/testthat/test-export-crosstab.R` — section 10 deleted, section 26,
  `min_eff_n = 0` in existing calls
- `tests/testthat/_snaps/export-crosstab.md` — two new, four moved
- `changelog/feature-crosstab-min-eff-n.md` — new; this file
- `plans/test-spec-export-metadata.md` — the twophase floor caution and six
  rows
- `plans/impl-export-metadata.md` — marked PR 11 complete; task 17
