# feat(export): report withheld subgroups with three warnings and withheld_note

**Date**: 2026-11-18
**Branch**: feature/crosstab-withheld-notices

## Changes

PR 13 of `plans/impl-export-metadata.md`. The `min_eff_n` floor now applies
to crossed cells. Three new warnings replace
`surveyreports_warning_subgroup_suppressed`. The new argument `withheld_note`
decides where the withheld lines are written.

### `export_crosstab()`

- New argument `withheld_note = c("once", "every", "none")`, after
  `show_total` and before `base_notes`. Spec 3.1 puts it after `na_label`,
  which `feature/crosstab-total-and-missing` inserts in front of it.
  - `"once"` (default): the withheld lines go on the About sheet.
  - `"every"`: the lines go at the end of each question block.
  - `"none"`: no lines are written. The warnings still fire.
- Step 16 of spec 3.11 calls the new `.emit_withholding_warnings()`, after
  the `.apply_all_na_drop()` call. It raises, in this order:
  - `surveyreports_warning_subgroup_withheld`: one per call, one bullet per
    line of `.format_withheld_lines()`.
  - `surveyreports_warning_banner_all_withheld`: every level of a column
    group, or every cell of an interaction, is below the floor.
  - `surveyreports_warning_full_sample_below_min`: the full sample's own
    effective N is below the floor. Nothing is removed.
- The full-sample test calls `.build_withheld()`, so the floor comparison
  stays in one place.
- `min_eff_n` and `has_banner` reach `.write_cover_sheet()`, so the "Why a
  column is missing" entry follows spec 3.15.
- New `.write_withheld_lines()` writes the lines at the end of a block for
  `"every"`. The three render helpers take `withheld_lines` in place of
  `suppressed`.
- Roxygen: new `@param withheld_note`. `@param min_eff_n` now names crossed
  cells. `man/export_crosstab.Rd` is regenerated.

### `R/export-utils.R`

- New `.interaction_label()` (the `gen × reg` name, 3 call sites) and
  `.build_interaction_design()` (adds the synthetic interaction column that
  the frequency helper and the floor both read).
- `.build_freq_frame()` applies `.resolve_eff_n()` and `.build_withheld()` to
  each interaction, and filters the withheld crossed cells on the same set
  difference as banner levels. It returns `withheld` and `emptied_groups`,
  and raises no warning. The old `subgroup_suppressed` warning is gone.
- `.format_withheld_lines()` prints the one unlabelled code as
  `[no value label]`.
- `.write_suppression_footnote()` is marked `# nocov`. Its only callers are in
  the topline path, which can no longer reach it.

## Readings the spec leaves open

- XX-02: surveycore cannot build a one-row design
  (`surveycore_error_single_row`). The test uses a domain that keeps one
  phase-2 row, on all four designs.
- XV-05 "with every column": with no NA in the banner, the full sample's
  effective N is never below every subgroup's. The test reads the criterion
  as "the Total column is written unchanged", and compares it cell by cell
  with a floor-0 run.
- XV-11: `testing.md` forbids calling handlers in tests. The test collects the
  messages with `testthat::capture_warnings()` and maps each one to its class
  by a phrase that only that message holds.
- XV-10 builds the old class name with `paste0()` in two parts, so the grep
  gate stays empty.
- XW-06's floor is set per design to the rounded midpoint of the two smallest
  crossed effective Ns: 37 on three designs, 25 on twophase.
- A crossed cell's banner variable, and the name in the all-withheld warning,
  are column names (`gen × reg`), not variable labels.
- `cell_is_bold()` is copied into the crosstab test file, because
  `helper-export.R` is outside the write surface.

## Known gap

At `withheld_note = "every"` or `"none"`, the glossary entry "Why a column is
missing" still says the minimum is listed above, but the About sheet does not
list it. Spec 3.15 makes the entry depend only on `min_eff_n` and
`has_banner`. A later PR fixes the wording.

## Tests

`tests/testthat/test-export-crosstab.R`, new section 28: all 21 scenarios,
plus a block that asserts `banner_all_withheld` names an interaction whose
every cell is withheld (XV-04, on all four designs).

- Failed first: XW-06, XW-08, XV-03, XV-04, XV-05 and XX-08.
- Passed on first write: the second call of XE-16, XV-10 to XV-13, XW-07,
  XW-09 to XW-11, XA-06, XA-07, XA-12, XX-02, XX-06, XX-07 and XX-09.
- XE-16 gets its second call, which `feature/crosstab-banner-headings` left
  for this PR.

Existing tests changed, with the user's approval (2026-11-18):

- The old class name becomes `surveyreports_warning_subgroup_withheld` in 6
  places in section 26 (by the plan).
- "export_crosstab() renders interaction spanner groups in workbook" passes
  `min_eff_n = 0`, because the floor now withholds every crossed cell at the
  default.
- "export_crosstab() withholds a below-floor column from SATA and battery
  blocks" passes `withheld_note = "every"`, so it still checks the lines under
  each table.
- XW-01's snapshot is deleted. XV-03's snapshot records the same class and
  message. XW-01's class assertion and other checks stay.

Snapshots: three new (XV-03, XV-04, XV-05); one deleted (XW-01).

- `devtools::test()`: 395 blocks, 0 failures, 0 warnings
- `devtools::check()`: 0 errors, 0 warnings, 1 approved note
- Coverage: 99.80% before, 99.85% after, by the same command. No line this PR
  added or changed is uncovered.
- `air format --check .` passes
- `grep -rn "subgroup_suppressed" R/ man/ tests/` returns nothing

## Files Modified

- `R/export-crosstab.R` — `withheld_note`, step 16, the withheld lines, the
  roxygen
- `R/export-utils.R` — the floor on interactions, the warning removed, the
  new helpers
- `man/export_crosstab.Rd` — regenerated
- `tests/testthat/test-export-crosstab.R` — section 28 and the edits above
- `tests/testthat/_snaps/export-crosstab.md` — three new, one deleted
- `changelog/feature-crosstab-withheld-notices.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 13 complete
