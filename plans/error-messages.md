# Error and Warning Classes

All `cli_abort()` and `cli_warn()` calls must use a class from this table.

## Errors

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_error_not_data_frame` | `my_fn()` | `data` is not a data.frame |
| `surveyreports_error_pool_pvals_not_list` | `pool_pvals()` | `results` is not a plain list |
| `surveyreports_error_pool_pvals_empty` | `pool_pvals()` | `results` has length 0 |
| `surveyreports_error_pool_pvals_invalid_method` | `pool_pvals()` | `method` not in `stats::p.adjust.methods` |
| `surveyreports_error_pool_pvals_missing_pcol` | `pool_pvals()` | One or more list elements missing `p_col` column |
| `surveyreports_error_pool_pvals_id_col_collision` | `pool_pvals()` | `id_col` name already exists in one or more elements |
| `surveyreports_error_pool_pvals_invalid_pvalues` | `pool_pvals()` | Pooled `p_col` contains values outside `[0, 1]` |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_warning_example` | `my_fn()` | Example warning condition |
| `surveyreports_warning_pool_pvals_input_pre_adjusted` | `pool_pvals()` | One or more elements already contain a `new_col` column |
| `surveyreports_warning_pool_pvals_no_pvalues_available` | `pool_pvals()` | All pooled p-values are `NA` |
