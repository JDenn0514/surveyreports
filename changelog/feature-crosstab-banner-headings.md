# feat(export): label banner headings and drop all-NA variables

**Date**: 2026-11-17
**Branch**: feature/crosstab-banner-headings

## Changes

PR 12 of `plans/impl-export-metadata.md`. A banner spanner reads `Gender`, not
`gen`. A crossed heading reads `Male × North`, not `1 × 1`. Both export
functions drop a variable with no non-missing value. No formal argument
changes, so no `man/` file moves.

### Banner headings and labels (`export_crosstab()`)

- Step 12 of spec 3.11 calls the new `.validate_banner_labels()` on the
  surviving banner columns. A value label on 2 or more codes aborts with
  `surveyreports_error_duplicate_value_label`. Two or more observed codes with
  no value label abort with `surveyreports_error_multiple_unlabelled_codes`.
- One `.banner_heading()` call per surviving banner column gives the spanner
  text. `.build_col_groups()` takes the headings, so a spanner reads the
  variable label, and an interaction spanner reads `Gender × Region`. The
  frame key stays the column names, and a sheet tab keeps the variable name.
- `.compute_interaction_freq()` runs `.banner_levels_labelled()` on each
  column before `interaction()`, so a crossed heading reads value labels and a
  factor keeps its level order.
- One `surveyreports_warning_missing_variable_label` per call names the `vars`
  columns and the banner columns together (spec 3.18). It is raised after
  `.build_freq_frame()` and before the all-NA drop. `.build_freq_frame()`
  gains `emit_label_warning = TRUE`, and `export_crosstab()` passes `FALSE`.
  `.emit_missing_label_warning(frame)` keeps its signature. A second "i"
  bullet, "Column name used as banner heading.", appears only when a banner
  column is named.

### The all-NA drop (both functions)

- New `.apply_all_na_drop(frame, vars, classify_out, call)` in
  `R/export-utils.R` runs at step 15 of spec 3.11 in `export_crosstab()` and
  step 9 in `export_topline()`. A variable with no `"total"` row in the frame
  is dropped. One `surveyreports_warning_all_na_dropped` names every dropped
  variable in input order. A SATA or battery item is dropped alone; a group
  with no surviving item is dropped.
- When no variable survives, it aborts with `surveyreports_error_vars_all_na`
  and raises no warning first.
- The three frequency helpers muffle `surveycore_warning_all_na_freqs` by
  class, beside `surveycore_warning_small_cell`. No other class is muffled.
- The collection path of `.build_freq_frame()` takes the question text from
  the first wave frame with rows, and returns no pooled row when no wave has
  rows. Before, a variable with no value in wave 1 aborted with "subscript out
  of bounds" (TC-09, TC-10).
- The three `nrow(frame) == 0L` early returns in each of
  `R/export-crosstab.R` and `R/export-topline.R` are deleted. The diff of
  `R/export-topline.R` holds only the drop call and those deletions.

## Readings the spec leaves open

- The banner label check counts codes in every row of `@data`, not only rows
  in the domain or in phase 2.
- The all-NA warning's "i" bullet is one fixed sentence about domain and wave
  scope, because `.apply_all_na_drop()` does not receive the design.
- XX-14's second call sets `bat_2` all-NA as well, and asserts that `bat_1`
  comes before `bat_2`.
- `nolab`, `lik` and the TC-09 `q3` column use repeating values instead of
  `sample()`, so the results do not depend on the seed.
- `set_all_na()` and `fresh_path()` are defined in both test files, because
  `helper-export.R` is outside the write surface.

## Tests

- `tests/testthat/test-export-crosstab.R`, new section 27, and
  `tests/testthat/test-export-topline.R`, new section 17: all 22 scenarios,
  plus a block that sends an all-NA variable through an interaction (XV-15
  pattern), which covers the muffle in `.compute_interaction_freq()`.
- Failed first: XH-01, XH-04, XE-04, XE-05, XX-03 (both functions), XV-14,
  TW-03, XE-16, TE-05, XV-15, TW-04, TC-09 and TC-10. The others passed on
  first write, after the code they depend on had landed.
- XE-16 has its first call only. Its second call, at the default floor, lands
  in `feature/crosstab-withheld-notices`.
- XM-11 now asserts that the spanner reads `Gender`.

Existing tests changed, with the user's approval (2026-11-17):

- Deleted, by plan task 34: "export_crosstab() handles all-NA variable without
  crashing" and "export_topline() handles all-NA variable without crashing".
- Deleted: the topline blocks "handles all-NA SATA variable without crashing"
  and "handles all-NA battery variable without crashing". Spec 3.17 now makes
  both calls abort. XX-15 covers the case.
- 16 crosstab blocks label the banner column (`group = "Group"`, or
  `banner_one = "Banner"`) in their first `set_var_label()` call, because the
  missing-label warning now covers banner columns. No assertion changed.
- "export_topline() leaves a never-asked SATA item blank, not 0" suppresses
  `surveyreports_warning_all_na_dropped` in place of the surveycore class.

Five new snapshots: XV-06, XE-04, XE-05, XV-14 and XE-16. No existing snapshot
moved.

- `devtools::test()`: 0 failures, 0 warnings
- `devtools::check()`: 0 errors, 0 warnings, 1 approved note
- Coverage: 99.68% before (clean `develop`), 99.80% after; no line this PR
  added or changed is uncovered
- `air format --check .` passes
- `grep -rn "nrow(frame) == 0L" R/` and the task 34 grep return nothing

## Files Modified

- `R/export-crosstab.R` — label checks, banner headings, the combined
  missing-label warning, the drop call, deleted early returns
- `R/export-utils.R` — `.apply_all_na_drop()`, the muffle, interaction
  labels, the collection fix, the missing-label helpers
- `R/export-topline.R` — the drop call and three deleted early returns
- `tests/testthat/test-export-crosstab.R` — section 27 and the edits above
- `tests/testthat/test-export-topline.R` — section 17 and the edits above
- `tests/testthat/_snaps/export-crosstab.md` — five new snapshots
- `changelog/feature-crosstab-banner-headings.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 12 complete
