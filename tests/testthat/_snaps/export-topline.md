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

# export_topline() errors when decimals is negative

    Code
      export_topline(d, vars = q1, file_name = out, decimals = -1)
    Condition
      Error in `.validate_export_inputs()`:
      x `decimals` must be a whole number, 0 or more.
      i Got -1.
      v Use a whole number such as "0", "1" or "2".

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

# export_topline() aborts when every vars column is non-substantive (TE-01)

    Code
      export_topline(d, vars = c(q1, q2), file_name = out)
    Condition
      Error in `.apply_role_guard()`:
      x Every column in `vars` has a non-substantive role.
      i Dropped: q1 (free_text) and q2 (paradata).
      v Select a column with a substantive role, or clear the role of a column to keep it.

# export_topline() aborts on an empty domain before the role guard (TE-03)

    Code
      export_topline(d, vars = c(q1, q2), file_name = out)
    Condition
      Error in `.validate_export_inputs()`:
      x `design` has no rows to tabulate.
      i The design has no row inside its domain.
      v Use a domain that keeps at least one row.

