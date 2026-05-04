# Design: `export_topline()` and `export_crosstab()`

**Date:** 2026-05-04
**Status:** Approved
**Scope:** Two new exported functions for producing styled Excel workbooks from survey design objects

---

## Overview

`export_topline()` and `export_crosstab()` are publication-quality frequency
export functions. They call `surveycore::get_freqs()` across multiple variables,
assemble results into a long tidy frame, and render styled `.xlsx` workbooks via
`openxlsx2`.

Three question types are supported: single-response, SATA (select-all-that-apply),
and battery/grid. Question type is detected automatically from
`surveycore::classify_question_type()` — no user-facing argument needed.

---

## Function Signatures

### `export_topline()`

```r
export_topline(
  design,
  vars,
  file_name,
  pub_type      = c("external", "internal", "none"),
  variance      = NULL,
  conf_level    = 0.95,
  show_n        = TRUE,
  show_eff_n    = FALSE,
  decimals      = 1
)
```

| Argument | Type | Description |
|---|---|---|
| `design` | `survey_base` or `survey_collection` | Survey design. `survey_collection` produces trend (wave) columns. |
| `vars` | tidy-select | Variables to tabulate. |
| `file_name` | chr scalar | Output path. Must end in `.xlsx`. |
| `pub_type` | chr scalar | Suppression level. `"external"` suppresses small cells; `"internal"` shows all; `"none"` skips suppression logic. Default `"external"`. |
| `variance` | chr scalar or `NULL` | Passed directly to `get_freqs()`. `NULL` shows no variance columns. Default `NULL`. |
| `conf_level` | dbl scalar | Passed directly to `get_freqs()`. Default `0.95`. |
| `show_n` | lgl | Show unweighted N. Default `TRUE`. |
| `show_eff_n` | lgl | Show effective N (Kish approximation). Default `FALSE`. |
| `decimals` | int scalar | Decimal places for percentages. Default `1`. |

### `export_crosstab()`

```r
export_crosstab(
  design,
  vars,
  banner,
  file_name,
  layout        = c("per_question", "stacked"),
  interactions  = NULL,
  pub_type      = c("external", "internal", "none"),
  variance      = NULL,
  conf_level    = 0.95,
  show_n        = TRUE,
  show_eff_n    = FALSE,
  decimals      = 1
)
```

Additional arguments beyond the shared set:

| Argument | Type | Description |
|---|---|---|
| `banner` | tidy-select | Subgroup variables. Required. Each variable produces an independent set of columns (marginal, not joint). |
| `layout` | chr scalar | `"per_question"` (default): one table per variable. `"stacked"`: all variables in one table with question text as merged left column. |
| `interactions` | list or `NULL` | Each element is a character vector of 2+ variable names; all must be in `banner`. Produces one interaction spanner group per element. Default `NULL`. |

---

## Architecture

### New files

| File | Contents |
|---|---|
| `R/export-topline.R` | `export_topline()`, `.render_topline_single()`, `.render_topline_sata()`, `.render_topline_battery()` |
| `R/export-crosstab.R` | `export_crosstab()`, `.render_crosstab_single()`, `.render_crosstab_sata()`, `.render_crosstab_battery()` |
| `R/export-utils.R` | `.build_freq_frame()`, `.compute_total_freq()`, `.compute_subgroup_freq()`, `.compute_interaction_freq()`, `.build_workbook()`, `.compute_eff_n()` |
| `tests/testthat/test-export-topline.R` | Full test suite for `export_topline()` |
| `tests/testthat/test-export-crosstab.R` | Full test suite for `export_crosstab()` |

### Updated files

| File | Change |
|---|---|
| `DESCRIPTION` | Add `openxlsx2 (>= 1.0.0)` and `tidyselect (>= 1.2.0)` to `Imports`; `surveycore` stays in `Suggests` (not on CRAN) |
| `plans/error-messages.md` | Add 8 error rows and 2 warning rows |

### surveycore dependency

`surveycore` is in `Suggests`, not `Imports` (not yet on CRAN). Both
`export_topline()` and `export_crosstab()` call it via `rlang::check_installed("surveycore")`
at the top of the function body, which aborts with a clear install message if
the package is absent. Tests that call surveycore functions use
`skip_if_not_installed("surveycore")` at the block level.

### Helper placement rationale

`.build_freq_frame()` and its sub-helpers are used by both export functions, so
they live in `R/export-utils.R` rather than either function's file. This is a
domain-scoped extension of the "promote to `R/utils.R` when used in 2+ files"
rule — if any helper later gains a call site outside the export domain, promote
it to `R/utils.R` at that point.

---

## Data Flow

```
export_topline() / export_crosstab()
  │
  ├─ 1. Validate inputs
  ├─ 2. Resolve NSE → character vectors
  ├─ 3. classify_question_type(design, vars_resolved) → var_type + group_id per var
  │
  ▼
.build_freq_frame()
  ├─ .compute_total_freq()           ← all vars
  ├─ .compute_subgroup_freq()        ← each var × banner var (crosstab only)
  └─ .compute_interaction_freq()     ← each var × interaction group (crosstab only)
  │
  ▼
Long flat tibble (one row per var × subgroup × response value)
  │
  ▼
.render_topline() / .render_crosstab()
  ├─ .render_*_single()
  ├─ .render_*_sata()
  └─ .render_*_battery()
  │
  ▼
openxlsx2 workbook → wb_save(wb, file_name)
```

### Long frame schema

| Column | Type | Description |
|---|---|---|
| `variable` | chr | Variable name |
| `var_type` | chr | `"single"` \| `"sata"` \| `"battery"` |
| `group_id` | int | From `classify_question_type()$group`; groups battery/SATA items; `NA` for single |
| `question_text` | chr | `variable_label` or `question_preface` from `.meta`; falls back to variable name (with warning) |
| `subgroup_type` | chr | `"total"` \| `"banner"` \| `"interaction"` \| `"wave"` |
| `subgroup_var` | chr | Banner variable name; `NA` for total |
| `subgroup_label` | chr | Spanner header text |
| `subgroup_value` | chr | Level value (e.g. `"Republican"`); `NA` for total |
| `value` | chr | Response category; raw value if `value_labels` absent |
| `pct` | dbl | Weighted proportion (from `get_freqs()`) |
| `n` | int | Unweighted count |
| `se` / `ci_low` / `ci_high` | dbl | Present when `variance` non-`NULL`; column set depends on `variance` value |
| `eff_n` | dbl | Present when `show_eff_n = TRUE`; Kish approximation |

### `survey_collection` handling

`survey_collection` inputs dispatch to a separate computation path that iterates
over `@surveys` (named list of designs). Each wave produces rows tagged with
`subgroup_type = "wave"` and `subgroup_label = wave_name` (from
`names(@surveys)`). The renderer handles wave columns identically to banner
columns; spanner labels use the wave names. Raw N for each wave appears in the
column header (e.g. `"Mar 2026 (n=1,203)"`).

`@if_missing_var` behavior on the collection governs missing-variable handling
across waves — surveycore handles it, no interception needed.

---

## Suppression

Suppression is governed by the team's subgroup sample size SOP
(`analysis-sops/subgroup_sample_size/sop_subgroup_sample_size.md`), which
defines three tiers based on effective N (Kish approximation: DEFF ≈ 1 + CV²(w))
and raw N.

### Thresholds by `pub_type`

| Tier | Condition | `"external"` | `"internal"` | `"none"` |
|---|---|---|---|---|
| F.4c | eff_n ≥ 100 AND raw N ≥ 100 | Show proportions | Show proportions | Show proportions |
| F.4b | eff_n 50–99 AND raw N ≥ 100 | **Suppress** | Show proportions | Show proportions |
| F.4a | eff_n < 50 OR raw N < 100 | **Suppress** | **Suppress** | Show proportions |

### Suppression behavior

Suppressed subgroups are **dropped entirely** from the output — no blank cells.
A footnote is written at the bottom of each affected table in the workbook
naming the dropped subgroups and the reason:

> *"Something else" (race_ethnicity) not shown: eff_n = 47, below the
> threshold of 100 for external publication. Consider combining with another
> category.*

The R-side warning `surveyreports_warning_subgroup_suppressed` also fires once
per call, listing all suppressed subgroups, so the analyst is informed during
their workflow regardless of whether they inspect the workbook.

### Implementation

Suppression is evaluated **before** the `get_freqs()` loop. `.compute_eff_n()`
runs once per banner level; suppressed levels are excluded from all subsequent
computation. `.build_freq_frame()` returns a named list:

```r
list(
  frame      = <long tidy tibble>,   # only non-suppressed subgroups
  suppressed = <tibble>              # subgroup_var, subgroup_value, eff_n,
                                     # raw_n, threshold, pub_type
)
```

The renderer reads `suppressed` to write footnotes; if the tibble is empty, no
footnote is added.

---

## Rendering Details

### var_type dispatch

`classify_question_type(design, vars_resolved)` is called once per function
call, before the frame is built. Its output — a tibble with columns `variable`,
`type`, `question_preface`, and `group` — drives:

- Which render helper is called per variable (or group of variables, for SATA/battery)
- How variables with the same `group_id` are batched together into one table block

### Self-banner handling (crosstab only)

When a variable appears in both `vars` and `banner`, computing that variable's
own breakdown by itself produces a degenerate circular result. For the row where
`variable == banner_var`, that banner column is silently dropped per variable.
No warning is emitted. Other variables' rows retain the full banner structure.

### Metadata fallbacks

| Metadata | Source | Fallback |
|---|---|---|
| `question_text` | `meta(result)$x[[var]]$variable_label` or `question_preface` | Variable name; `surveyreports_warning_missing_variable_label` fired once per call listing all affected variables |
| Response category labels | `meta(result)$x[[var]]$value_labels` | Raw data values; no warning |

---

## Error and Warning Classes

### New errors

| Class | Thrown by | Condition |
|---|---|---|
| `surveyreports_error_not_survey_object` | both | `design` is not `survey_base` or `survey_collection` |
| `surveyreports_error_var_not_found` | both | A variable in `vars` does not exist in the design |
| `surveyreports_error_invalid_file_name` | both | `file_name` does not end in `.xlsx` |
| `surveyreports_error_invalid_conf_level` | both | `conf_level` outside `(0, 1)` |
| `surveyreports_error_invalid_decimals` | both | `decimals` is not a positive integer |
| `surveyreports_error_banner_not_found` | `export_crosstab()` | A variable in `banner` does not exist in the design |
| `surveyreports_error_interaction_not_in_banner` | `export_crosstab()` | A variable in `interactions` is not in `banner` |
| `surveyreports_error_interactions_not_list` | `export_crosstab()` | `interactions` is not a list |

### New warnings

| Class | Thrown by | Condition |
|---|---|---|
| `surveyreports_warning_subgroup_suppressed` | both | One or more subgroups dropped under `pub_type = "external"` or `"internal"`; single warning listing all suppressed subgroups and their eff_n |
| `surveyreports_warning_missing_variable_label` | both | `variable_label` is `NULL` for one or more vars; single warning listing all affected variables |

---

## Testing

### Files

| Test file | Covers |
|---|---|
| `tests/testthat/test-export-topline.R` | `R/export-topline.R` + shared helpers in `R/export-utils.R` |
| `tests/testthat/test-export-crosstab.R` | `R/export-crosstab.R` + shared helpers in `R/export-utils.R` |

All tests use `withr::local_tempdir()` for output paths. Workbook assertions
read back cells with `openxlsx2` after the call. Numerical accuracy tests
compare `.build_freq_frame()` output directly against `surveycore::get_freqs()`
and are guarded with `skip_if_not_installed("surveycore")` at the block level.

### `test-export-topline.R` sections

```
# 1. Happy paths — file created for all 3 design types
# 2. survey_collection — wave columns present in workbook
# 3. var_type dispatch — single / SATA / battery render without error
# 4. variance options — "ci", "se", NULL produce correct frame columns
# 5. show_n / show_eff_n — columns present/absent as expected
# 6. pub_type suppression — subgroup_suppressed warning fires; suppressed columns absent; footnote present in workbook
# 7. Missing metadata — missing_variable_label warning fires; variable name used
# 8. Error paths — all 5 error classes, dual pattern (expect_error + expect_snapshot)
# 9. Edge cases — all-NA variable, single-value variable
# 10. Numerical accuracy — .build_freq_frame() totals match get_freqs() per variable
```

### `test-export-crosstab.R` sections

```
# 1. Happy paths — file created for all 3 design types
# 2. layout = "per_question" vs "stacked" — workbook structure differs
# 3. banner — subgroup columns present; spanner labels correct
# 4. interactions — interaction spanner groups present
# 5. vars/banner overlap — self-banner silently dropped; no error, no warning
# 6. var_type dispatch — single / SATA / battery render without error
# 7. variance options
# 8. show_n / show_eff_n toggles
# 9. pub_type suppression — suppressed columns absent; footnote present; warning fires
# 10. Missing metadata — missing_variable_label warning fires
# 11. Error paths — all 8 error classes, dual pattern (expect_error + expect_snapshot)
# 12. Edge cases — all-NA variable, single-value variable, single-row data
# 13. Numerical accuracy — .build_freq_frame() subgroup values match get_freqs(design, var, group = banner_var)
```
