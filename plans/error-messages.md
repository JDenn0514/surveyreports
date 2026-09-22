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
| `surveyreports_error_vars_all_dropped` | `export_topline()`, `export_crosstab()` | Every `vars` column was dropped by the role guard |
| `surveyreports_error_empty_domain` | `export_topline()`, `export_crosstab()` | Domain-filtered design resolves to zero rows |
| `surveyreports_error_invalid_file_name` | `export_topline()`, `export_crosstab()` | `file_name` does not end in `.xlsx` |
| `surveyreports_error_invalid_conf_level` | `export_topline()`, `export_crosstab()` | `conf_level` outside `(0, 1)` |
| `surveyreports_error_invalid_decimals` | `export_topline()`, `export_crosstab()` | `decimals` is not a positive integer |
| `surveyreports_error_invalid_min_eff_n` | `export_crosstab()` | `min_eff_n` is not a length-1, non-missing, finite, non-negative numeric |
| `surveyreports_error_banner_not_found` | `export_crosstab()` | A variable in `banner` does not exist in the design |
| `surveyreports_error_banner_empty_selection` | `export_crosstab()` | Every `banner` column was dropped by the role guard |
| `surveyreports_error_duplicate_value_label` | `export_crosstab()` | A surviving `banner` column carries one value label on 2 or more codes |
| `surveyreports_error_multiple_unlabelled_codes` | `export_crosstab()` | A surviving `banner` column carries 2 or more observed codes with no value label |
| `surveyreports_error_interaction_not_in_banner` | `export_crosstab()` | A variable in `interactions` is not in `banner` |
| `surveyreports_error_interactions_not_list` | `export_crosstab()` | `interactions` is not a list |
| `surveyreports_error_collection_not_supported_for_crosstab` | `export_crosstab()` | `design` is a `survey_collection`; not supported — use `export_topline()` for trend output |
| `surveyreports_error_design_variable_selected` | `export_topline()`, `export_crosstab()` | A variable in `vars` or `banner` is a column the design names (weight, cluster id, strata, FPC, replicate weight, twophase subset) |
| `surveyreports_error_base_notes_invalid` | `export_topline()`, `export_crosstab()` | `base_notes` is not `NULL` and is not a fully named character vector |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_warning_example` | `my_fn()` | Example warning condition |
| `surveyreports_warning_pool_pvals_input_pre_adjusted` | `pool_pvals()` | One or more elements already contain a `new_col` column |
| `surveyreports_warning_pool_pvals_no_pvalues_available` | `pool_pvals()` | All pooled p-values are `NA` |
| `surveyreports_warning_subgroup_withheld` | `export_crosstab()` | One or more subgroups fall below `min_eff_n`; one warning per call, whose bullets are the lines of `.format_withheld_lines()` |
| `surveyreports_warning_banner_all_withheld` | `export_crosstab()` | Every level of one or more banner column groups, or every cell of an interaction, falls below `min_eff_n`; names each affected group |
| `surveyreports_warning_full_sample_below_min` | `export_crosstab()` | The full sample's own effective N is below `min_eff_n`; the workbook is written in full |
| `surveyreports_warning_role_dropped` | `export_topline()`, `export_crosstab()` | One or more columns dropped from `vars` or `banner` for a non-substantive role; one warning per argument, listing every column and its role |
| `surveyreports_warning_unknown_role` | `export_topline()`, `export_crosstab()` | A column's `role` is outside the seven known values, or is not a length-1 character; one warning per call, listing every affected column; the column is kept |
| `surveyreports_warning_missing_variable_label` | `export_topline()`, `export_crosstab()` | A `vars` column or a `banner` column has no variable label; one warning per call, listing every affected column |
