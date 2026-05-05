# feat(export): add shared export utilities, survey datasets, and test data helpers

**Date**: 2026-05-05
**Branch**: feature/export-utils

## Changes

- Add `R/export-utils.R` with all shared internals for export functions:
  `.validate_export_inputs()`, `.compute_eff_n()`, `.compute_total_freq()`,
  `.compute_subgroup_freq()`, `.compute_interaction_freq()`, `.build_freq_frame()`,
  `.build_workbook()`, `.write_suppression_footnote()`
- Add `openxlsx2 (>= 1.0.0)` and `S7` to `Imports`; `tidyselect (>= 1.2.0)` to `Suggests`
- Add `LazyData: true` to DESCRIPTION for correct data loading
- Replace `helper-test-data.R` stub with `make_survey_data()` + `make_all_designs()`
  (taylor, JK1 replicate, and twophase designs with SATA/battery metadata)
- Add four bundled survey datasets: `anes_2024`, `gss_2024`, `pew_jewish_2020`, `ns_wave1`
- Add `R/data.R` with full roxygen documentation for all four datasets
- Add data preparation scripts in `data-raw/` for ANES, GSS, Pew Jewish, and Nationscape
- Add export error and warning class definitions to `plans/error-messages.md`
- Add design spec and implementation plan for `export_topline()` / `export_crosstab()`
- Update `CLAUDE.md` with surveycore dependency note

## Files Modified

- `R/export-utils.R` — new file; all shared internal helpers for export functions
- `R/data.R` — new file; roxygen documentation for all four bundled datasets
- `data/anes_2024.rda` — ANES 2024 Time Series extract (5,521 rows, 19 variables)
- `data/gss_2024.rda` — GSS 2024 extract (3,309 rows, 27 variables)
- `data/pew_jewish_2020.rda` — Pew Jewish Americans 2020 with 100 JK1 replicate weights
- `data/ns_wave1.rda` — Nationscape Wave 1 (July 18, 2019)
- `data-raw/prepare-anes-2024.R` — ANES data preparation script
- `data-raw/prepare-gss-2024.R` — GSS data preparation script
- `data-raw/prepare-pew-jewish-2020.R` — Pew Jewish data preparation script
- `data-raw/prepare-nationscape-phase1.R` — Nationscape Phase 1 preparation script
- `data-raw/prepare-nationscape-helpers.R` — Nationscape shared preparation helpers
- `data-raw/parse-nationscape-codebooks.R` — Nationscape codebook parser
- `man/anes_2024.Rd`, `man/gss_2024.Rd`, `man/ns_wave1.Rd`, `man/pew_jewish_2020.Rd` — generated Rd files
- `tests/testthat/helper-test-data.R` — updated with full `make_all_designs()` implementation
- `DESCRIPTION` — add openxlsx2, S7 to Imports; tidyselect to Suggests; LazyData: true
- `CLAUDE.md` — add surveycore Remotes/Imports dependency note
- `plans/error-messages.md` — new error/warning classes for export_topline() and export_crosstab()
- `plans/2026-05-04-export-topline-crosstab-design.md` — export function design spec
- `.claude/rules/` — code style, testing, github strategy, package conventions
- `.claude/skills/` — commit-and-pr, r-implement, implementation-workflow, spec-workflow skills
