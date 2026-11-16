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
      x Banner variable not found in the design.
      i The tidyselect expression for `banner` failed: Can't select columns that don't exist. x Column `nonexistent_banner` doesn't exist.
      v Use bare column names that exist in the design.

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

# export_crosstab() errors when base_notes is not fully named

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, base_notes = c(
        "unnamed note"))
    Condition
      Error in `.validate_base_notes()`:
      x `base_notes` must be a fully named character vector or "NULL".
      i Got <character> of length 1.
      v Name every element after the variable whose table it annotates.

# export_crosstab() errors when base_notes is not a character vector

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, base_notes = list(
        q1 = "a list, not a character vector"))
    Condition
      Error in `.validate_base_notes()`:
      x `base_notes` must be a fully named character vector or "NULL".
      i Got <list> of length 1.
      v Name every element after the variable whose table it annotates.

# export_crosstab() aborts when every vars column is non-substantive (XE-01)

    Code
      export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)
    Condition
      Error in `.apply_role_guard()`:
      x Every column in `vars` has a non-substantive role.
      i Dropped: q1 (free_text) and q2 (free_text).
      v Select a column with a substantive role, or clear the role of a column to keep it.

# export_crosstab() aborts when every banner column is non-substantive (XE-03)

    Code
      export_crosstab(d, vars = q1, banner = c(gen, reg), file_name = out)
    Condition
      Error in `.apply_role_guard()`:
      x Every column in `banner` has a non-substantive role.
      i Dropped: gen (paradata) and reg (paradata).
      v Select a column with a substantive role, or clear the role of a column to keep it.

# export_crosstab() re-validates interactions against the surviving banner (XE-06)

    Code
      export_crosstab(d, vars = q1, banner = c(gen, reg), file_name = out,
      interactions = list(c("gen", "reg")))
    Condition
      Warning:
      ! Dropped 1 column from `banner` for a non-substantive role.
      i Dropped: reg (paradata).
      Error in `export_crosstab()`:
      x Interaction variable reg not found in `banner`.
      i All variables in each interactions element must also appear in `banner`.
      v Add the missing variable to `banner`, or remove them from `interactions`.

# export_crosstab() aborts on an empty domain (XE-09)

    Code
      export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)
    Condition
      Error in `.validate_export_inputs()`:
      x `design` has no rows to tabulate.
      i The design has no row inside its domain.
      v Use a domain that keeps at least one row.

# export_crosstab() aborts when vars names the design's weight column (XE-12)

    Code
      export_crosstab(d, vars = c(q1, wt), banner = group, file_name = out)
    Condition
      Error in `.reject_design_vars()`:
      x Column wt in `vars` is a design variable, not a question.
      i The design names it in its weights slot.
      v Remove wt from `vars`.

# export_crosstab() aborts when banner names the design's weight column (XE-14)

    Code
      export_crosstab(d, vars = q1, banner = c(group, wt), file_name = out)
    Condition
      Error in `.reject_design_vars()`:
      x Column wt in `banner` is a design variable, not a question.
      i The design names it in its weights slot.
      v Remove wt from `banner`.

# export_crosstab() warns once for a dropped vars column and still writes the file (XV-01)

    Code
      export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)
    Condition
      Warning:
      ! Dropped 1 column from `vars` for a non-substantive role.
      i Dropped: q2 (free_text).

# export_crosstab() warns for a dropped banner column under its own name (XV-02)

    Code
      export_crosstab(d, vars = q1, banner = c(gen, reg), file_name = out)
    Condition
      Warning:
      ! Dropped 1 column from `banner` for a non-substantive role.
      i Dropped: reg (paradata).

# export_crosstab() keeps a column with an unrecognized role and warns (XV-07)

    Code
      export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)
    Condition
      Warning:
      ! `vars` has 1 column with an unrecognized role: q2 (curiosity).
      i Each one is kept as a substantive column. The known roles are "item", "demographic", "treatment", "weight", "identifier", "paradata", and "free_text".

