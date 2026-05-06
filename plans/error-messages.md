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
| `surveyreports_error_not_survey_object` | `export_topline()`, `export_crosstab()` | `design` is not `survey_base` or `survey_collection` |
| `surveyreports_error_var_not_found` | `export_topline()`, `export_crosstab()` | A variable in `vars` does not exist in the design |
| `surveyreports_error_vars_empty_selection` | `export_topline()`, `export_crosstab()` | `vars` tidyselect resolves to zero columns |
| `surveyreports_error_empty_domain` | `export_topline()`, `export_crosstab()` | Domain-filtered design resolves to zero rows |
| `surveyreports_error_invalid_file_name` | `export_topline()`, `export_crosstab()` | `file_name` does not end in `.xlsx` |
| `surveyreports_error_invalid_conf_level` | `export_topline()`, `export_crosstab()` | `conf_level` outside `(0, 1)` |
| `surveyreports_error_invalid_decimals` | `export_topline()`, `export_crosstab()` | `decimals` is not a positive integer |
| `surveyreports_error_banner_not_found` | `export_crosstab()` | A variable in `banner` does not exist in the design |
| `surveyreports_error_interaction_not_in_banner` | `export_crosstab()` | A variable in `interactions` is not in `banner` |
| `surveyreports_error_interactions_not_list` | `export_crosstab()` | `interactions` is not a list |
| `surveyreports_error_collection_not_supported_for_crosstab` | `export_crosstab()` | `design` is a `survey_collection`; not supported — use `export_topline()` for trend output |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_warning_example` | `my_fn()` | Example warning condition |
| `surveyreports_warning_pool_pvals_input_pre_adjusted` | `pool_pvals()` | One or more elements already contain a `new_col` column |
| `surveyreports_warning_pool_pvals_no_pvalues_available` | `pool_pvals()` | All pooled p-values are `NA` |
| `surveyreports_warning_subgroup_suppressed` | `export_crosstab()` | One or more subgroups dropped under `pub_type = "external"` or `"internal"`; single warning listing all suppressed subgroups and their eff_n |
| `surveyreports_message_missing_variable_label` | `export_topline()`, `export_crosstab()` | `variable_label` is `NULL` for one or more vars; informational message listing all affected variables (downgraded from warning — not user-actionable at call time) |
