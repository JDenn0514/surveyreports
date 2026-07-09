# export_topline() errors when design is not a survey object

    Code
      export_topline(df, vars = q1, file_name = out)
    Condition
      Error in `export_topline()`:
      x `design` must be a survey design object.
      i Got class <data.frame>.
      v Use `surveycore::as_survey()` to create a design object.

# export_topline() errors when vars resolves to zero columns

    Code
      export_topline(d, vars = starts_with("zzz"), file_name = out)
    Condition
      Error in `.validate_export_inputs()`:
      x `vars` did not select any columns.
      i The tidyselect expression resolved to an empty set.
      v Use bare column names or a tidyselect helper that matches existing columns.

# export_topline() errors when vars_resolved contains a missing column

    Code
      surveyreports:::.validate_export_inputs(d, "nonexistent_col", out, 0.95, 1L)
    Condition
      Error in `surveyreports:::.validate_export_inputs()`:
      x 1 variable not found in the design: nonexistent_col.
      i Check for typos or use `names()` on the design data.
      v Remove or rename the missing variable before calling this function.

# export_topline() errors when domain has zero rows

    Code
      export_topline(d_empty, vars = q1, file_name = out)
    Condition
      Error in `.validate_export_inputs()`:
      x The design contains zero rows.
      i No data is available to compute frequencies.
      v Supply a design with at least one observation.

# export_topline() errors when file_name does not end in .xlsx

    Code
      export_topline(d, vars = q1, file_name = "output.csv")
    Condition
      Error in `.validate_export_inputs()`:
      x `file_name` must end in ".xlsx".
      i Got "output.csv".
      v Change the file extension to ".xlsx".

# export_topline() errors when conf_level is outside (0, 1)

    Code
      export_topline(d, vars = q1, file_name = out, conf_level = 1.5)
    Condition
      Error in `.validate_export_inputs()`:
      x `conf_level` must be a single numeric value in (0, 1).
      i Got 1.5.
      v Use a value such as "0.95" for a 95% confidence interval.

# export_topline() errors when decimals is not a positive integer

    Code
      export_topline(d, vars = q1, file_name = out, decimals = 0)
    Condition
      Error in `.validate_export_inputs()`:
      x `decimals` must be a positive integer scalar.
      i Got 0.
      v Use a whole number such as "1" or "2".

# export_topline() errors when base_notes is not fully named

    Code
      export_topline(d, vars = q1, file_name = out, base_notes = c("unnamed note"))
    Condition
      Error in `.validate_base_notes()`:
      x `base_notes` must be a fully named character vector or "NULL".
      i Got <character> of length 1.
      v Name every element after the variable whose table it annotates.

# export_topline() errors when base_notes is not a character vector

    Code
      export_topline(d, vars = q1, file_name = out, base_notes = 1L:3L)
    Condition
      Error in `.validate_base_notes()`:
      x `base_notes` must be a fully named character vector or "NULL".
      i Got <integer> of length 3.
      v Name every element after the variable whose table it annotates.

