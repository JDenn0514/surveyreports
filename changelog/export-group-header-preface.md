# fix(freqs): head SATA/battery blocks with the shared question preface

**Date**: 2026-07-08
**Branch**: fix/export-group-header-preface

## Changes

- Fix SATA and battery export blocks being headed by the first member's
  `variable_label` (its item/option text) instead of the group's shared
  question text, in both `export_topline()` and `export_crosstab()`
- Carry `question_preface` through `.build_freq_frame()`'s frame via the
  existing `classify_question_type()` join (both standard and collection
  paths)
- Add `.group_header_text()` internal helper: prefers the group's shared
  `question_preface`, falls back to the first member's `question_text`
  when no preface exists; all four sata/battery renderers use it
- Single-variable blocks keep `variable_label` as their header (regression
  tests added for singles carrying both a label and a preface)
- Add header-cell tests for SATA and battery blocks in both exporters
  across all three design types

## Files Modified

- `R/export-utils.R` — carry `question_preface` in the freq frame joins; add `.group_header_text()` helper
- `R/export-topline.R` — sata and battery renderers head blocks via `.group_header_text()`
- `R/export-crosstab.R` — sata and battery renderers head blocks via `.group_header_text()`
- `tests/testthat/test-export-topline.R` — header-cell tests for sata/battery blocks, singles regression, helper fallback test
- `tests/testthat/test-export-crosstab.R` — header-cell tests for sata/battery blocks, singles regression
