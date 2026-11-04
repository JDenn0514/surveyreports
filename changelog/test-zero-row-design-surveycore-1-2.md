# test(export): remove zero-row design tests for surveycore 1.2.0

**Date**: 2026-11-04
**Branch**: test/zero-row-design-surveycore-1-2

## Changes

- Remove four tests that built a zero-row design. surveycore 1.2.0 (on CRAN
  since 2026-11-03) rejects zero-row `@data` in its S7 validator, so these
  tests errored before they reached `export_topline()` or
  `export_crosstab()`.
- Remove the two snapshot blocks that belonged to the removed tests.
- Mark the abort branch of check 4 in `.validate_export_inputs()` with
  `# nocov` markers and a `Defensive:` comment. The check stays, because
  DESCRIPTION still allows surveycore < 1.2.0. The condition, the message, and
  the class do not change.
- Update the `surveyreports_error_empty_domain` row in
  `plans/error-messages.md`. It now says that the check is defensive, and that
  an empty `filter()` domain keeps every row and does not raise this class.

No exported function, argument, output column, or number changes.

## Files Modified

- `R/export-utils.R` — added `# nocov` markers and a `Defensive:` comment to
  check 4 of `.validate_export_inputs()`; comment lines only
- `tests/testthat/test-export-crosstab.R` — removed "export_crosstab() errors
  when domain has zero rows" and "export_crosstab() errors with empty-domain
  design"
- `tests/testthat/test-export-topline.R` — removed "export_topline() errors
  with empty_domain for a zero-row design" and "export_topline() errors when
  domain has zero rows"
- `tests/testthat/_snaps/export-crosstab.md` — removed the snapshot block for
  the removed zero-row test
- `tests/testthat/_snaps/export-topline.md` — removed the snapshot block for
  the removed zero-row test
- `plans/error-messages.md` — rewrote the Condition cell of the
  `surveyreports_error_empty_domain` row
- `changelog/test-zero-row-design-surveycore-1-2.md` — new; this file
