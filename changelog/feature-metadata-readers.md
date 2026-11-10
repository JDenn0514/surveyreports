# feat(export): add the five design readers for export-metadata

**Date**: 2026-11-10
**Branch**: feature/metadata-readers

## Changes

PR 2 of `plans/impl-export-metadata.md`. Five internal helpers go into
`R/export-utils.R`. Each one reads a design and returns a value. None of them
classifies, warns, or drops. No exported function calls them yet, so no
workbook changes.

- `.resolve_eff_n(design, group_var = NULL, na.rm = TRUE)` returns a tibble
  of `level`, `n` and `n_eff` from `surveycore::get_effective_n()`. With no
  group it returns one row. On a `survey_collection` it returns one row per
  member, keyed by the wave name. With a group it returns one row per observed
  level, labelled as `get_freqs()` labels it. It muffles
  `surveycore_warning_small_cell`. `.build_freq_frame()` reads it in
  `feature/effective-n-rewiring`.
- `.has_domain(design)` returns `TRUE` when `@data` holds
  `surveycore::SURVEYCORE_DOMAIN_COL`. A domain that selects every row still
  counts.
- `.banner_levels_labelled(design, col)` returns a banner column with codes
  replaced by value labels. A factor comes back unchanged, with its level
  order. An unlabelled code becomes `NA`, as it does in `get_freqs()`.
- `.banner_heading(design, col)` returns the variable label of a banner
  column, or the column name with `fell_back = TRUE`.
- `.unanimous_across(entries)` returns the keys whose value is the same, and
  not missing, in every member.

The tests are direct calls in a new section 19 of
`tests/testthat/test-export-crosstab.R`. They cover all four design types.
The numbers are checked against `surveycore::get_effective_n()`: `n` exactly,
and `n_eff` at `1e-8`.

## Files Modified

- `R/export-utils.R` — added the five helpers
- `tests/testthat/test-export-crosstab.R` — added section 19, 22 test blocks
- `changelog/feature-metadata-readers.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 2 complete
