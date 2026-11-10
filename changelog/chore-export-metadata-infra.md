# chore(pipeline): add the nonprob test design and the two all-NA classes

**Date**: 2026-11-10
**Branch**: chore/export-metadata-infra

## Changes

- `make_all_designs()` returns a fourth design, `nonprob`, built with
  `surveycore::as_survey_nonprob(df, weights = wt)` over the same frame as
  the other three. It carries the same SATA and battery metadata. Every
  cross-design loop in both export test files now runs four designs.
- A new test checks that `make_all_designs()` returns `taylor`,
  `replicate`, `twophase` and `nonprob`, in that order.
- `plans/error-messages.md` gains `surveyreports_error_vars_all_na` and
  `surveyreports_warning_all_na_dropped` (spec 3.17 and 3.18). The other
  six errors and four warnings of the spec were already present.
- `.claude/rules/testing.md` loses the "Gap to close" note under
  Cross-design testing.
- Checked, not changed: `DESCRIPTION` reads `surveycore (>= 1.2.0)` under
  `Imports:` and has no `Remotes:` line. surveycore 1.2.0 is installed and
  exports `get_effective_n()`.
- `air format .` reformats seven files, in a separate commit with no other
  change.

The `nonprob` design has no replicate weights, so each estimate on it
raises `surveycore_warning_nonprob_srs_fallback`. No test fails. A later
test that asserts no warning across all four designs must allow for it.

## Files Modified

- `tests/testthat/helper-test-data.R` — the `nonprob` design.
- `tests/testthat/test-export-topline.R` — the design-count test; one test
  name changes from "all 3 design types" to "all 4 design types".
- `tests/testthat/test-export-crosstab.R` — the same test-name change.
- `plans/error-messages.md` — two rows.
- `.claude/rules/testing.md` — the gap note is removed.
- `data-raw/` (five scripts) and `tests/testthat/test-pool-pvals.R` —
  `air` formatting only.
- `changelog/chore-export-metadata-infra.md` — this file.
