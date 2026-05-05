# Design: `export_topline()` and `export_crosstab()`

**Date:** 2026-05-04
**Version:** 1.2 (Stage 4 pass 2 resolved 2026-05-04)
**Status:** Approved — methodology-locked and code-quality-reviewed
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
| `variance` | chr scalar or `NULL` | Passed directly to `get_freqs()`. `NULL` shows no variance columns. Default `NULL`. |
| `conf_level` | dbl scalar | Passed directly to `get_freqs()`. Default `0.95`. |
| `show_n` | lgl | Show unweighted N. Default `TRUE`. |
| `show_eff_n` | lgl | Show effective N (Kish approximation). Default `FALSE`. |
| `decimals` | int scalar | Decimal places for percentages. Default `1`. |

**`@return`:** `invisible(file_name)` — the output file path, returned invisibly.
Consistent with `readr::write_csv()`. Allows piping and easy path-based testing.

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

**`@return`:** `invisible(file_name)` — the output file path, returned invisibly.
Consistent with `readr::write_csv()`. Allows piping and easy path-based testing.

**`design` restriction:** `export_crosstab()` accepts `survey_base` only. A
`survey_collection` input throws
`surveyreports_error_collection_not_supported_for_crosstab` immediately, before
`.validate_export_inputs()` is called. Use `export_topline()` for
wave-comparison (trend) output.

---

## Architecture

### New files

| File | Contents |
|---|---|
| `R/export-topline.R` | `export_topline()`, `.render_topline_single()`, `.render_topline_sata()`, `.render_topline_battery()` |
| `R/export-crosstab.R` | `export_crosstab()`, `.render_crosstab_single()`, `.render_crosstab_sata()`, `.render_crosstab_battery()` |
| `R/export-utils.R` | `.validate_export_inputs()`, `.build_freq_frame()`, `.compute_total_freq()`, `.compute_subgroup_freq()`, `.compute_interaction_freq()`, `.build_workbook()`, `.compute_eff_n()` |
| `tests/testthat/test-export-topline.R` | Full test suite for `export_topline()` |
| `tests/testthat/test-export-crosstab.R` | Full test suite for `export_crosstab()` |

### Updated files

| File | Change |
|---|---|
| `DESCRIPTION` | Add `openxlsx2 (>= 1.0.0)` and `tidyselect (>= 1.2.0)` to `Imports`; `surveycore` stays in `Suggests` (not on CRAN) |
| `plans/error-messages.md` | Add 10 error rows and 2 warning rows (done in Stage 4 resolve) |

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
.build_workbook()                          ← initialises empty wb object
  │
  ▼
.render_topline() / .render_crosstab()     ← each call adds one sheet to wb (side-effect)
  ├─ .render_*_single()
  ├─ .render_*_sata()
  └─ .render_*_battery()
  │
  ▼
wb_save(wb, file_name)                     ← parent calls after all render calls finish
  │
  ▼
invisible(file_name)                       ← returned to caller (consistent with readr::write_csv())
```

### Long frame schema

| Column | Type | Description |
|---|---|---|
| `variable` | chr | Variable name |
| `var_type` | chr | `"single"` \| `"sata"` \| `"battery"` |
| `group_id` | int | From `classify_question_type()$group`; groups battery/SATA items; `NA` for single |
| `question_text` | chr | `variable_label` or `question_preface` from `.meta`; falls back to variable name (with warning) |
| `var_label` | chr | Per-item label used as row label in render helpers. For single-response vars: same as `question_text`. For SATA/battery: `variable_label` of each sub-item (distinct from `question_text`, which is the group preface). Falls back to variable name. |
| `subgroup_type` | chr | `"total"` \| `"banner"` \| `"interaction"` \| `"wave"` |
| `subgroup_var` | chr | Banner variable name; `NA` for total |
| `subgroup_label` | chr | Spanner header text |
| `subgroup_value` | chr | Level value (e.g. `"Republican"`); `NA` for total |
| `value` | chr | Response category; raw value if `value_labels` absent |
| `pct` | dbl | Weighted proportion (from `get_freqs()`); scale `[0, 1]` |
| `n` | int | Unweighted count |
| `se` / `ci_low` / `ci_high` | dbl | Present when `variance` non-`NULL`; column set depends on `variance` value |
| `eff_n` | dbl | Present when `show_eff_n = TRUE`; Kish approximation |

### Helper signatures

**`.validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)`**
— shared validation called as the first step in both `export_topline()` and
`export_crosstab()`. Checks (in order): `design` is `survey_base` or
`survey_collection`, `vars_resolved` is non-empty (errors
`surveyreports_error_vars_empty_selection` if zero-length), all names in
`vars_resolved` exist in `design@data` (errors `surveyreports_error_var_not_found`),
the domain has at least one row (errors `surveyreports_error_empty_domain`),
`file_name` ends in `.xlsx` (`surveyreports_error_invalid_file_name`), `conf_level`
is in `(0, 1)` (`surveyreports_error_invalid_conf_level`), and `decimals` is a
positive integer scalar (`surveyreports_error_invalid_decimals`). Returns
`invisible(TRUE)` on success. The design-type check uses
`S7::S7_inherits(design, surveycore::survey_base) || S7::S7_inherits(design, surveycore::survey_collection)`.
Because `export_crosstab()` rejects `survey_collection` before calling this
helper, the `survey_collection` branch applies only to `export_topline()`.

**`.compute_total_freq(design, var, ...)`** — calls `surveycore::get_freqs(design, !!sym(var), ...)` and tags the result with `subgroup_type = "total"`, `subgroup_var = NA`, `subgroup_value = NA`.

**`.compute_subgroup_freq(design, var, banner_var, ...)`** — calls `surveycore::get_freqs(design, !!sym(var), group = !!sym(banner_var), ...)` for each level of `banner_var` and tags results with `subgroup_type = "banner"`, `subgroup_var = banner_var`.

**`.compute_interaction_freq(design, var, banner_vars, ...)`** — calls `surveycore::get_freqs(design, !!sym(var), group = interaction(!!!syms(banner_vars), sep = " × "), ...)`, producing one column per unique combination of the interacted banner variable levels. Tags results with `subgroup_type = "interaction"`, `subgroup_var = paste(banner_vars, collapse = " × ")`.

**`.compute_eff_n(design, col, level)`** → scalar `dbl`. Filters `design@data` to
rows where `col == level`, then computes the Kish design effect:
`DEFF = n × Σwi² / (Σwi)²`, where `wi` are the weight values and `n` is the
filtered row count. Returns `eff_n = n / DEFF`. Called once per banner level
before any `get_freqs()` loop; suppressed levels are excluded from all subsequent
computation.

### `survey_collection` handling

`survey_collection` inputs dispatch to a separate computation path that iterates
over `@surveys` (named list of designs). Each wave produces rows tagged with
`subgroup_type = "wave"` and `subgroup_label = wave_name` (from
`names(@surveys)`). The renderer handles wave columns identically to banner
columns; spanner labels use the wave names. Raw N for each wave appears in the
column header (e.g. `"Mar 2026 (n=1,203)"`).

`@if_missing_var` behavior on the collection governs missing-variable handling
across waves — surveycore handles it, no interception needed.

**Column layout:** the rendered output includes a `"Total"` column first (pooled
across all waves, computed as a single `get_freqs()` call on the full collection),
followed by one column per named wave in `@surveys` in list order. Wave column
headers show the wave name and raw N (e.g., `"Mar 2026 (n=1,203)"`). When a
variable is missing in a wave (per `@if_missing_var`), that wave's column is
represented as an empty cell with `"n/a"` in the column header rather than being
omitted entirely, so column positions remain stable across variables.

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

If all subgroups for a variable are suppressed, the variable still appears in the
workbook with the total column only; a footnote at the bottom of that variable's
block lists all dropped subgroups and their eff_n values.

---

## Rendering Details

### Sheet structure

**Topline:** all variables are written to a single worksheet named `"Topline"`.

**Crosstab `layout = "per_question"`:** one worksheet per variable, named by the
variable name (truncated to Excel's 31-character sheet name limit if needed).

**Crosstab `layout = "stacked"`:** all variables are written to a single worksheet
named `"Crosstab"`, separated by blank rows between variable blocks.

Variable blocks are written in the order of `vars_resolved` (the order variables
appear in the `vars` argument after tidyselect resolution). Sheet order in
`per_question` layout follows the same order.

Each render helper adds its output to the `wb` object via side-effect (writing to
the appropriate sheet/offset); it does not create or return a workbook.

### Render helper output format

Each render helper writes a self-contained block to its target sheet starting at the
current row offset. The parent advances the offset after each block (for stacked
layout) or uses a new sheet (for `per_question`). Before writing, the renderer
multiplies `pct` by 100 and rounds to `decimals` decimal places to produce the
display string (e.g., `pct = 0.312` → `"31.2%"`).

**`single`** — one row per response category.
Row 1: question text merged across all columns (bold). Row 2: column headers
(`"Response"`, `"%"`, and optionally `"N"`, `"Eff N"` for topline; banner level
labels for crosstab). Rows 3+: one row per response category with label and
percent. Final row: `"Total"` with `100%` as a sum-check.

**`sata` (Select All That Apply)** — one row per item.
Row 1: question preface merged across all columns (bold). Row 2: column headers
(`"Item"`, `"%"`, optionally `"N"` — same column layout as single). Rows 3+: one
row per item. No total row (percentages do not sum to 100%).

**`battery`** — one row per sub-item; scale categories are columns.
Row 1: battery preface merged across all columns (bold). Row 2: column headers
(`"Item"`, then one column per response category of the scale, plus an optional
`"N"` column; for crosstab, banner spanner groups repeat across the scale columns).
Rows 3+: one row per sub-item. No total row.

For crosstab, banner spanner headers appear above the column headers row (Row 2)
as an additional header row, grouping each set of banner-level columns under the
banner variable name.

### var_type dispatch

`classify_question_type(design, vars_resolved)` is called once per function
call, before the frame is built. Its output — a tibble with columns `variable`,
`type`, `question_preface`, and `group` — drives:

- Which render helper is called per variable (or group of variables, for SATA/battery)
- How variables with the same `group_id` are batched together into one table block

**Render dispatch algorithm:** After building the long frame, the parent
function splits the classify output into groups by `group_id`, treating each
`NA` group_id (single-response variables) as its own singleton group. It
iterates over groups in the order they appear in `vars_resolved`, skipping any
`group_id` already rendered (tracked via a `groups_done` set). For each group,
it filters the long frame to `frame[frame$variable %in% group_vars, ]` and
dispatches to the appropriate render helper: `.render_*_single()` for
singletons, `.render_*_battery()` or `.render_*_sata()` for multi-item groups.
Render helpers receive the filtered long frame subset, not a character vector
of variable names.

### Self-banner handling (crosstab only)

When a variable appears in both `vars` and `banner`, computing that variable's
own breakdown by itself produces a degenerate circular result. For the row where
`variable == banner_var`, that banner column is silently dropped per variable.
No warning is emitted. Other variables' rows retain the full banner structure.
The drop is applied in `.build_freq_frame()`: `.compute_subgroup_freq(var, banner_var)`
is not called when `var == banner_var`.

### Single-level banner (crosstab only)

When a banner variable has only one unique level in the data (e.g., `region` in a
single-region dataset), `export_crosstab()` produces one subgroup column for that
banner variable. This is valid output — no warning is emitted — though the
subgroup column will be identical to the total. Tested as an edge case in
`test-export-crosstab.R`.

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
| `surveyreports_error_vars_empty_selection` | both | `vars` tidyselect resolves to zero columns (e.g., `starts_with("nonexistent_prefix")`) |
| `surveyreports_error_empty_domain` | both | Domain-filtered design resolves to zero rows |
| `surveyreports_error_invalid_file_name` | both | `file_name` does not end in `.xlsx` |
| `surveyreports_error_invalid_conf_level` | both | `conf_level` outside `(0, 1)` |
| `surveyreports_error_invalid_decimals` | both | `decimals` is not a positive integer |
| `surveyreports_error_banner_not_found` | `export_crosstab()` | A variable in `banner` does not exist in the design |
| `surveyreports_error_interaction_not_in_banner` | `export_crosstab()` | A variable in `interactions` is not in `banner` |
| `surveyreports_error_interactions_not_list` | `export_crosstab()` | `interactions` is not a list |
| `surveyreports_error_collection_not_supported_for_crosstab` | `export_crosstab()` | `design` is a `survey_collection`; not supported — use `export_topline()` for trend output |

### New warnings

| Class | Thrown by | Condition |
|---|---|---|
| `surveyreports_warning_subgroup_suppressed` | `export_crosstab()` | One or more subgroups dropped under `pub_type = "external"` or `"internal"`; single warning listing all suppressed subgroups and their eff_n |
| `surveyreports_warning_missing_variable_label` | both | `variable_label` is `NULL` for one or more vars; single warning listing all affected variables |

---

## Testing

### Files

| Test file | Covers |
|---|---|
| `tests/testthat/test-export-topline.R` | `R/export-topline.R` + shared helpers in `R/export-utils.R` |
| `tests/testthat/test-export-crosstab.R` | `R/export-crosstab.R` + shared helpers in `R/export-utils.R` |

All tests use `withr::local_tempdir()` for output paths. Cross-design tests use
`make_all_designs(seed = N)` (from `tests/testthat/helper-test-data.R`) for all
three design types (Taylor, replicate, twophase). Workbook assertions read back
cells with `openxlsx2` after the call. Numerical accuracy tests compare
`.build_freq_frame()` output directly against `surveycore::get_freqs()` and are
guarded with `skip_if_not_installed("surveycore")` at the block level.

### `test-export-topline.R` sections

```
# 1. Happy paths — file created for all 3 design types
# 2. Multiple variables — c(q1, q2, q3) produces output for all 3 vars; all variable names present in workbook
# 3. survey_collection — wave columns present in workbook
# 4. var_type dispatch — single / SATA / battery render without error
# 5. variance options — "ci", "se", NULL produce correct frame columns
# 6. show_n / show_eff_n — columns present/absent as expected
# 7. Missing metadata — missing_variable_label warning fires; variable name used
# 8. Error paths — all 7 error classes, dual pattern (expect_error + expect_snapshot)
#    Classes: not_survey_object, var_not_found, vars_empty_selection, empty_domain,
#    invalid_file_name, invalid_conf_level, invalid_decimals
# 9. Edge cases — all-NA variable, single-value variable, single-row data, empty domain (errors with surveyreports_error_empty_domain)
# 10. Numerical accuracy — .build_freq_frame() totals match get_freqs() per variable
```

### `test-export-crosstab.R` sections

```
# 1. Happy paths — file created for all 3 design types
# 2. Multiple variables — c(q1, q2, q3) produces output for all 3 vars; correct sheet count or all names present in workbook
# 3. layout = "per_question" vs "stacked" — workbook structure differs
# 4. banner — subgroup columns present; spanner labels correct
# 5. interactions — interaction spanner groups present
# 6. vars/banner overlap — self-banner silently dropped; no error, no warning
# 7. var_type dispatch — single / SATA / battery render without error
# 8. variance options
# 9. show_n / show_eff_n toggles
# 10. pub_type suppression — suppressed columns absent; footnote present; warning fires
# 11. Missing metadata — missing_variable_label warning fires
# 12. Error paths — all 11 error classes, dual pattern (expect_error + expect_snapshot)
#     Classes: not_survey_object, var_not_found, vars_empty_selection, empty_domain,
#     invalid_file_name, invalid_conf_level, invalid_decimals,
#     banner_not_found, interaction_not_in_banner, interactions_not_list,
#     collection_not_supported_for_crosstab
# 13. Edge cases — all-NA variable, single-value variable, single-row data, empty domain (errors with surveyreports_error_empty_domain), single-level banner (allowed silently)
# 14. Numerical accuracy — .build_freq_frame() subgroup values match get_freqs(design, var, group = banner_var)
```
