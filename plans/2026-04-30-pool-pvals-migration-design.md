# Design: Migrate `pool_pvals()` from surveycore to surveyreports

**Date:** 2026-04-30  
**Status:** Approved  
**Scope:** surveyreports only — removal from surveycore is a separate concern

---

## Motivation

`pool_pvals()` is a post-processing utility, not an estimator. It applies a
family-wise multiplicity correction across a list of analysis result tibbles
that each carry a `p_value` column. It belongs in surveyreports because:

1. Reporting is its purpose — correcting p-values across a multi-variable
   analysis family is a reporting step, not an estimation step.
2. It will be called internally by future `report_diffs()`, `report_t_test()`,
   and `report_pairwise()` functions in this package.
3. surveyreports' mission is to automate multi-variable reporting workflows;
   `pool_pvals()` is a direct expression of that mission.

The surveycore version is being removed (it exists only on `develop` and has no
users). This spec covers only the surveyreports side.

---

## Architecture

### New files

| File | Contents |
|------|----------|
| `R/pool-pvals.R` | `pool_pvals()`, `print.survey_pooled_pvals()`, 3 internal helpers |
| `tests/testthat/test-pool-pvals.R` | Full test suite |
| `tests/testthat/_snaps/pool-pvals.md` | Generated snapshots (committed) |

### Updated files

| File | Change |
|------|--------|
| `DESCRIPTION` | Add `dplyr (>= 1.0.0)` and `tibble (>= 3.0.0)` to `Imports` |
| `plans/error-messages.md` | Add 6 error rows and 2 warning rows |

### Internal helpers

The 3 helpers from `surveycore/R/analysis-helpers.R` move to the bottom of
`R/pool-pvals.R`. Per package conventions, helpers live in the same file when
there is one call site, and are promoted to `R/utils.R` only when a second
call site appears. When `report_diffs()` or similar needs
`.validate_pval_adjustment_method()`, promote it to `R/utils.R` then.

Helpers:
- `.is_plain_list(x)` — guards against a bare data frame being passed as `results`
- `.validate_pval_adjustment_method(method, arg_name, call, class, include_received)` — validates against `stats::p.adjust.methods`
- `.validate_list_columns(results, col_names, id_col)` — per-element column presence and id-col collision check

### DESCRIPTION imports

`stats` is a base package and needs no entry. `dplyr` and `tibble` are new:

```
dplyr (>= 1.0.0)
tibble (>= 3.0.0)
```

---

## Implementation

### Source

Copy `surveycore/R/analysis-pool-pvals.R` verbatim into `R/pool-pvals.R`.
Copy the 3 helpers from `surveycore/R/analysis-helpers.R` to the bottom of the
same file. No logic changes.

### Error and warning class renames

All `surveycore_*` prefixes become `surveyreports_*` (8 substitutions):

| Old class | New class |
|-----------|-----------|
| `surveycore_error_pool_pvals_not_list` | `surveyreports_error_pool_pvals_not_list` |
| `surveycore_error_pool_pvals_empty` | `surveyreports_error_pool_pvals_empty` |
| `surveycore_error_pool_pvals_invalid_method` | `surveyreports_error_pool_pvals_invalid_method` |
| `surveycore_error_pool_pvals_missing_pcol` | `surveyreports_error_pool_pvals_missing_pcol` |
| `surveycore_error_pool_pvals_id_col_collision` | `surveyreports_error_pool_pvals_id_col_collision` |
| `surveycore_error_pool_pvals_invalid_pvalues` | `surveyreports_error_pool_pvals_invalid_pvalues` |
| `surveycore_warning_pool_pvals_input_pre_adjusted` | `surveyreports_warning_pool_pvals_input_pre_adjusted` |
| `surveycore_warning_pool_pvals_no_pvalues_available` | `surveyreports_warning_pool_pvals_no_pvalues_available` |

### S3 class

`survey_pooled_pvals` is unchanged — it carries no package prefix.

### Example rewrite

The surveycore example references `gss_2024` (a surveycore dataset) and bare
`as_survey()` / `get_diffs()` calls. Per package conventions, all examples
must be runnable during `R CMD check` with no `\dontrun{}`. The example is
rewritten using a small inline `data.frame` with `surveycore::as_survey()` and
`surveycore::get_diffs()` — surveycore is already in `Imports`.

### Code comment: future `split_output` argument

Add a brief comment near the return value of `pool_pvals()` noting that a
`split_output` argument (which would split the bound result back into a named
list by `id_col` after adjustment) is a natural future addition for the
internal `report_*` pipeline. Users can perform the split themselves with
`split(result, result[[id_col]])` in the meantime.

---

## Testing

### Source

Port the existing surveycore test suite (~495 lines in
`tests/testthat/test-analysis-pool-pvals.R`). Adaptations are mechanical:

- Replace all `surveycore_error_*` / `surveycore_warning_*` class strings with
  `surveyreports_*` equivalents
- Replace bare `as_survey()` / `get_diffs()` calls with
  `surveycore::as_survey()` / `surveycore::get_diffs()`
- Regenerate snapshots (class names appear in error messages, so all snapshot
  text changes)

### Test data

`pool_pvals()` receives a list of result tibbles, not a survey design, so
`make_all_designs()` is not the primary data source. Tests use:

- **Inline tibbles** with a `p_value` column for error paths, structural
  checks, and edge cases
- **surveycore function output** (`get_diffs()`, `get_t_test()`,
  `get_pairwise()`, `get_anova()`, `clean.survey_glm_fit()`) on a small inline
  design for per-upstream-function and numerical accuracy tests

### Test file sections

```
# 1. Happy paths — result tibble structure, S3 class, .meta attribute
# 2. Per-upstream-function happy paths — one test each for get_diffs(),
#    get_t_test(), get_pairwise(), get_anova(), clean.survey_glm_fit();
#    each verifies structure and .meta correctness (method, family_size,
#    n_total, n_na, n_significant_05)
# 3. Multiple inputs — column union ordering, id_col, named vs unnamed list
# 4. strip_within_adj — rename-to-within vs. drop behavior, warning class
# 5. Error paths — not_list, empty, invalid_method, missing_pcol,
#    id_col_collision, invalid_pvalues (dual: expect_error + expect_snapshot)
# 6. Edge cases — all-NA p_value column, single-element list, partially-NA pool
# 7. Numerical accuracy — adjusted values match stats::p.adjust() directly
```

All error classes use the dual assertion pattern:

```r
expect_error(
  pool_pvals(...),
  class = "surveyreports_error_pool_pvals_not_list"
)
expect_snapshot(error = TRUE, pool_pvals(...))
```

---

## plans/error-messages.md additions

### Errors

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_error_pool_pvals_not_list` | `pool_pvals()` | `results` is not a plain list |
| `surveyreports_error_pool_pvals_empty` | `pool_pvals()` | `results` has length 0 |
| `surveyreports_error_pool_pvals_invalid_method` | `pool_pvals()` | `method` not in `stats::p.adjust.methods` |
| `surveyreports_error_pool_pvals_missing_pcol` | `pool_pvals()` | One or more list elements missing `p_col` column |
| `surveyreports_error_pool_pvals_id_col_collision` | `pool_pvals()` | `id_col` name already exists in one or more elements |
| `surveyreports_error_pool_pvals_invalid_pvalues` | `pool_pvals()` | Pooled `p_col` contains values outside `[0, 1]` |

### Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_warning_pool_pvals_input_pre_adjusted` | `pool_pvals()` | One or more elements already contain a `new_col` column |
| `surveyreports_warning_pool_pvals_no_pvalues_available` | `pool_pvals()` | All pooled p-values are `NA` |

---

## Out of scope

- Removing `pool_pvals()` from surveycore (separate PR)
- `split_output` argument — deferred until the internal `report_*` pipeline
  makes the need concrete
- Any changes to `pool_pvals()` logic or behavior
