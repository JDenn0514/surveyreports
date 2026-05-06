# feat(export-topline): implement export_topline() with single, SATA, and battery support

**Date**: 2026-05-06
**Branch**: feature/export-topline

## Changes

- Implement `export_topline()` producing a styled `.xlsx` workbook from a survey design object
- Add render helpers for single-answer, SATA (select-all-that-apply), and battery question types via auto-detection with `surveycore::classify_question_type()`
- Add `survey_collection` wave-column support — wave columns are written as separate sheets
- Wire variance estimation, display toggles (`show_n`, `show_unweighted_n`, `show_se`, `show_ci`), and missing-label warning
- Add full test suite: happy paths across all three design types, error paths for all typed error classes, edge cases (all-NA variable, single-row data, single-value variable, empty domain), and numerical accuracy oracle tests comparing against `surveycore::get_freqs()`
- Update implementation plan to mark PR 2 complete

## Files Modified

- `R/export-topline.R` — new file; `export_topline()` and internal render helpers (`.render_single()`, `.render_sata()`, `.render_battery()`)
- `R/export-utils.R` — minor updates; coverage now complete via `export_topline()` tests
- `R/surveyreports-package.R` — add `export_topline` to package-level docs
- `tests/testthat/test-export-topline.R` — full test suite including cross-design, edge cases, and numerical accuracy
- `tests/testthat/_snaps/export-topline.md` — snapshots for all user-facing error messages
- `man/export_topline.Rd` — generated Rd file
- `man/surveyreports-package.Rd` — updated package Rd
- `NAMESPACE` — export `export_topline`
- `plans/impl-export-topline-crosstab.md` — mark PR 2 complete
