# feat(export): run the selection guards in export_crosstab()

**Date**: 2026-11-16
**Branch**: feature/crosstab-guards

## Changes

PR 10 of `plans/impl-export-metadata.md`. This PR closes Part A.
`export_crosstab()` now checks `vars` and `banner` in the order of spec 3.11:

- Step 7: the list-shape check on `interactions` stays inline. The membership
  check moves into a new helper, `.validate_interactions_in_banner()`, below
  the exported function. Its message text is unchanged, and its existing
  snapshot did not move.
- Step 9 (new): `.reject_design_vars()` on `vars`, then on `banner`. A design
  column aborts with `surveyreports_error_design_variable_selected`, and the
  message names the argument.
- Step 10 (new): `.apply_role_guard()` on `vars`, then on `banner`. When
  nothing survives, `vars` aborts with `surveyreports_error_vars_all_dropped`
  and `banner` aborts with `surveyreports_error_banner_empty_selection`.
- Step 11 (new): `.validate_interactions_in_banner()` runs again, against the
  surviving banner. An interaction that names a dropped banner column aborts
  with `surveyreports_error_interaction_not_in_banner`.
- Step 13: `classify_question_type()` takes `tidyselect::all_of()`.

Steps 8 (`min_eff_n`) and 12 (banner label checks) belong to later PRs, so the
step comments skip them.

The unknown-role warning still fires once per argument. A call with an unknown
role in both `vars` and `banner` gives two warnings, where spec 3.17 says one
per call. No scenario in this PR covers that case.

## Readings the spec leaves open

- XM-11: banner headings are not wired yet, so a spanner shows the column
  name. The test accepts the name or the label, and asserts that the sheet is
  identical to the same call with only the surviving banner column.
- XE-06 and XE-09 take the dual pattern, as the test-spec says, although each
  class already had a snapshot. The XE-06 snapshot also pins the order: the
  role warning, then the error.
- XE-03 drops both columns of `banner = c(gen, reg)`.
- Snapshots run on the taylor design only. The XE-12 message differs on
  twophase (`phase1$weights`).
- XM-17 cannot fail against the old code: tidyselect 1.2.1 raises the
  bare-vector deprecation from the global environment, not from package code.
  The block is a guard. It sets `lifecycle_verbosity = "warning"` itself.

## The warning-count gate

The test-spec profile gate asks for the warning count to drop from 88 to 8 or
fewer, on the premise that the `all_of()` fix removes 80 deprecation
warnings. The premise does not hold on the current dependencies:

- The suite raises no tidyselect deprecation warning, before or after this PR.
- `test-export-crosstab.R` gives about 458 warnings on a repeat run, down from
  470. Of those, 442 are `surveycore_warning_nonprob_srs_fallback` from
  existing blocks. The rest are 9 missing-label warnings, 5 `file.remove()`
  warnings on a temp file that does not exist yet, and 2 grouping warnings.
- The new section adds 0 warnings. Its calls go through `crosstab_quiet()`,
  which muffles only the nonprob fallback warning.

## Tests

`tests/testthat/test-export-crosstab.R`, new section 25: XM-06, XM-08 to
XM-17, XE-01, XE-02, XE-03, XE-06, XE-08, XE-09, XE-10, XE-12 to XE-15, XV-01,
XV-02, XV-07 to XV-09 and XX-10. New helpers in the section: `guard_design()`,
`data_sheets()`, `add_gen_reg()`, `sheet_rows()` and `crosstab_quiet()`.

21 blocks failed first against the old code. XM-10, XM-16, XE-08, XE-09,
XE-10 and XX-10 passed first: they are regression rows or rows that keep a
column. XM-17 is the guard above.

Nine new snapshots: XE-01, XE-03, XE-06, XE-09, XE-12, XE-14, XV-01, XV-02 and
XV-07. XE-12 and XV-01 are the snapshots that topline TE-04 and TW-01 left to
this PR. No existing test or snapshot changed.

- `devtools::test()`: 346 blocks, 0 failures
- `devtools::check()`: 0 errors, 0 warnings, 1 approved note
- Coverage: 99.78%; no new line is uncovered
- `air format .` changed nothing.

## Files Modified

- `R/export-crosstab.R` — the guard calls, the interactions helper and
  `all_of()`
- `tests/testthat/test-export-crosstab.R` — section 25
- `tests/testthat/_snaps/export-crosstab.md` — nine new snapshots
- `changelog/feature-crosstab-guards.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 10 complete
