# feat(export): run the selection guards in export_topline()

**Date**: 2026-11-16
**Branch**: feature/topline-guards

## Changes

PR 9 of `plans/impl-export-metadata.md`. `export_topline()` now checks the
`vars` selection in the order of spec 3.11:

- Step 3: `.validate_export_inputs()`, which holds the empty-domain check.
- Step 5 (new): `.reject_design_vars()`. A design column in `vars`, such as
  the weight column, aborts with
  `surveyreports_error_design_variable_selected`, and no file is written.
- Step 6 (new): `.apply_role_guard()`. A column whose role is `weight`,
  `identifier`, `paradata` or `free_text` is dropped with one
  `surveyreports_warning_role_dropped`. An unknown role keeps the column
  with one `surveyreports_warning_unknown_role`. When nothing survives, the
  call aborts with `surveyreports_error_vars_all_dropped`. The survivors
  replace `vars`, so no later step sees a dropped column.
- `classify_question_type()` now takes `tidyselect::all_of()`. The bare
  vector raised a tidyselect deprecation warning. The test suite's warning
  count fell from 806 to 760.

## The empty-domain check (decided 2026-11-16)

Spec 3.11 says an empty domain aborts before the role guard, and test-spec
TE-03 asserts it. The code checked only for zero rows, which surveycore
1.2.0 no longer allows, and `plans/error-messages.md` said an empty
`filter()` domain did not raise the class. No PR in the plan added the
check. The user chose to add it here:

- `.validate_export_inputs()` aborts with
  `surveyreports_error_empty_domain` when the design has a domain and no
  row is inside it. An `NA` in the domain column counts as outside. The
  zero-row branch stays. The `# nocov` markers are gone.
- On a collection, every member is checked, and the message names the first
  member with no row to tabulate. Before, only the first member was checked.
- The message is reworded, because the old text ("zero rows") was false for
  an empty domain.
- `.validate_export_inputs()` is shared, so `export_crosstab()` aborts on an
  empty domain from this PR on. `feature/crosstab-guards` adds its guard
  calls after this check.
- Row 21 of `plans/error-messages.md` now describes this.

Before this PR, an empty domain wrote a workbook of empty tables with two
surveycore warnings.

## Readings the spec leaves open

- TP-12: the "tiny subgroup" is a `q1` answer on two rows inside phase 2.
- TP-13: a SATA block's "own shape" is the preface, `Item`, then one row per
  option, under `%` and `N` headings with no `Response` heading.
- TE-02 is a new block. Renaming the existing plain-data-frame block would
  rename its snapshot.

## Tests

`tests/testthat/test-export-topline.R`, new section 16: TP-05, TP-08 to
TP-13, TC-01 to TC-04, TE-01 to TE-04, TW-01 and TW-02, and a block for an
empty wave in a collection. TP-05, TE-04 and TE-03 failed first. Two new
snapshots: TE-01 and TE-03. TW-01 and TE-04 assert the class alone; their
snapshots land in `feature/crosstab-guards` (XV-01, XE-12). No existing test
or snapshot changed.

## Files Modified

- `R/export-topline.R` — the two guard calls and `all_of()`
- `R/export-utils.R` — the empty-domain check in `.validate_export_inputs()`
- `tests/testthat/test-export-topline.R` — section 16
- `tests/testthat/_snaps/export-topline.md` — the TE-01 and TE-03 snapshots
- `plans/error-messages.md` — row 21
- `changelog/feature-topline-guards.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 9 complete
