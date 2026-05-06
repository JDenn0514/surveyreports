# feat(export-crosstab): implement export_crosstab() for cross-tabulation workbook export

**Date**: 2026-05-06
**Branch**: feature/export-crosstab

## Changes

- Implement `export_crosstab()` with core pipeline supporting `per_question` and `stacked` layouts
- Add banner spanner rendering with cross-tabulation interactions for single-type designs
- Implement SATA and battery question render helpers
- Refactor: extract `n_cols` and question-title helpers to `R/export-utils.R` to eliminate DRY violations
- Wire suppression, variance, and display toggles into the render pipeline
- Fix banner resolution ordering (moved after validation to enforce correct error sequencing)
- Fix: revert warning→message downgrade in export utilities; fix self-banner snapshot test
- Add full test suite covering error paths, edge cases, and numerical accuracy oracle tests
- Update roxygen documentation, package key functions listing, and mark implementation plan complete

## Files Modified

- `R/export-crosstab.R` — implement `export_crosstab()` and all internal render helpers
- `R/export-utils.R` — extract shared helpers (`n_cols`, question-title) used across export functions
- `R/surveyreports-package.R` — update key functions section to reference `export_crosstab`
- `tests/testthat/test-export-crosstab.R` — full test suite: error paths, edge cases, and oracle accuracy tests
- `tests/testthat/_snaps/export-crosstab.md` — snapshots for user-facing error messages
- `plans/impl-export-topline-crosstab.md` — mark implementation plan complete
- `man/export_crosstab.Rd`, `man/export_topline.Rd`, `man/surveyreports-package.Rd` — generated documentation
- `NAMESPACE` — updated exports
