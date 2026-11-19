# fix(export): count code 1 as chosen for a labelled SATA item

**Date**: 2026-11-19
**Branch**: fix/sata-chosen-code-1

## Changes

- Fix a select-all-that-apply (SATA) item with value labels that printed 0%
  and N 0. The export counted an item as chosen only where the frame's `value`
  was the string `"1"`. For a labelled item (`1 = Yes, 2 = No`),
  `surveycore::get_freqs()` returns `Yes`, so no row matched. On `ns_wave1`,
  `news_sources_facebook` now prints 61.5 in `export_topline()`.
- Code 1 is chosen, read before value labels are applied. The new helper
  `.extract_sata_chosen()` returns the label whose code is 1. A logical item
  gives `TRUE`. Any other item gives `1`, as before, so an unlabelled 0/1
  item does not change.
- An item with no code 1 (for example `0 = No, 2 = Yes`) keeps the true-zero
  rule: it prints 0 where it has a base. No new warning or error class.
- `.build_freq_frame()` marks the chosen rows in a new logical column,
  `sata_chosen`. `.sata_pct_cell()` and `.sata_n_cell()` read that column, so
  `export_topline()` and `export_crosstab()` use one rule.
- Add the rule to `plans/spec-export-metadata.md` section 3.3.

Tests: 3494 pass, 0 fail. Coverage is 99.85% (99.84% before).
`R CMD check --as-cran`: 0 errors, 0 warnings.

## Files Modified

- `R/export-utils.R` — new `.extract_sata_chosen()` and `.build_sata_chosen()`;
  `.build_freq_frame()` adds `sata_chosen`; the two SATA cell helpers read it
- `R/export-topline.R` — one comment updated
- `R/export-crosstab.R` — one comment updated
- `tests/testthat/test-export-topline.R` — 7 new blocks: labelled share and N
  on all four designs, `ns_wave1`, a logical item, an item with no code 1, a
  collection, and the `sata_chosen` mark
- `tests/testthat/test-export-crosstab.R` — 1 new block: labelled share in
  the Total and banner columns on all four designs
- `plans/spec-export-metadata.md` — section 3.3 states the chosen-value rule
- `changelog/fix-sata-chosen-code-1.md` — new; this file
