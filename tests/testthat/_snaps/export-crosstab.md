# export_crosstab() errors for survey_collection design

    Code
      export_crosstab(coll, vars = q1, banner = group, file_name = out)
    Condition
      Error in `export_crosstab()`:
      x `design` must be a single survey design, not a collection.
      i Got class <surveycore::survey_collection/S7_object>.
      v Use `export_topline()` for wave-comparison (trend) output.

# export_crosstab() errors when design is not a survey object

    Code
      export_crosstab(df, vars = q1, banner = q1, file_name = out)
    Condition
      Error in `export_crosstab()`:
      x `design` must be a survey design object.
      i Got class <data.frame>.
      v Use `surveycore::as_survey()` to create a design object.

# export_crosstab() errors when vars resolves to zero columns

    Code
      export_crosstab(d, vars = starts_with("zzz"), banner = group, file_name = out)
    Condition
      Error in `.validate_export_inputs()`:
      x `vars` did not select any columns.
      i The tidyselect expression resolved to an empty set.
      v Use bare column names or a tidyselect helper that matches existing columns.

# export_crosstab() errors when vars_resolved contains a missing column

    Code
      surveyreports:::.validate_export_inputs(d, "nonexistent_col", out, 0.95, 1L)
    Condition
      Error in `surveyreports:::.validate_export_inputs()`:
      x 1 variable not found in the design: nonexistent_col.
      i Check for typos or use `names()` on the design data.
      v Remove or rename the missing variable before calling this function.

# export_crosstab() errors when domain has zero rows

    Code
      export_crosstab(d_empty, vars = q1, banner = group, file_name = out)
    Condition
      Error in `.validate_export_inputs()`:
      x The design contains zero rows.
      i No data is available to compute frequencies.
      v Supply a design with at least one observation.

# export_crosstab() errors when file_name does not end in .xlsx

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = "output.csv")
    Condition
      Error in `.validate_export_inputs()`:
      x `file_name` must end in ".xlsx".
      i Got "output.csv".
      v Change the file extension to ".xlsx".

# export_crosstab() errors when conf_level is outside (0, 1)

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, conf_level = 1.5)
    Condition
      Error in `.validate_export_inputs()`:
      x `conf_level` must be a single numeric value in (0, 1).
      i Got 1.5.
      v Use a value such as "0.95" for a 95% confidence interval.

# export_crosstab() errors when decimals is not a positive integer

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, decimals = 0)
    Condition
      Error in `.validate_export_inputs()`:
      x `decimals` must be a positive integer scalar.
      i Got 0.
      v Use a whole number such as "1" or "2".

# export_crosstab() errors when banner variable is not in design

    Code
      export_crosstab(d, vars = q1, banner = nonexistent_banner, file_name = out)
    Condition
      Error in `value[[3L]]()`:
      x 1 banner variable not found in the design: nonexistent_banner.
      i Check for typos or use `names()` on the design data.
      v Remove or rename the missing banner variable before calling this function.

# export_crosstab() errors when interactions is not a list

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, interactions = "not_a_list")
    Condition
      Error in `export_crosstab()`:
      x `interactions` must be a list or "NULL".
      i Got class <character>.
      v Pass a list of character vectors, each naming 2+ variables from `banner`.

# export_crosstab() errors when interactions contains a var not in banner

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, interactions = list(
        c("group", "q2")))
    Condition
      Error in `export_crosstab()`:
      x Interaction variable q2 not found in `banner`.
      i All variables in each interactions element must also appear in `banner`.
      v Add the missing variable to `banner`, or remove them from `interactions`.

