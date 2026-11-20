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

# export_crosstab() errors when decimals is negative

    Code
      export_crosstab(d, vars = q1, banner = group, file_name = out, decimals = -1)
    Condition
      Error in `.validate_export_inputs()`:
      x `decimals` must be a whole number, 0 or more.
      i Got -1.
      v Use a whole number such as "0", "1" or "2".

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
      interactions = list(c("gen", "reg")), min_eff_n = 0)
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
      export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out,
      min_eff_n = 0)
    Condition
      Warning:
      ! Dropped 1 column from `vars` for a non-substantive role.
      i Dropped: q2 (free_text).

# export_crosstab() warns for a dropped banner column under its own name (XV-02)

    Code
      export_crosstab(d, vars = q1, banner = c(gen, reg), file_name = out, min_eff_n = 0)
    Condition
      Warning:
      ! Dropped 1 column from `banner` for a non-substantive role.
      i Dropped: reg (paradata).

# export_crosstab() keeps a column with an unrecognized role and warns (XV-07)

    Code
      export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out,
      min_eff_n = 0)
    Condition
      Warning:
      ! `vars` has 1 column with an unrecognized role: q2 (curiosity).
      i Each one is kept as a substantive column. The known roles are "item", "demographic", "treatment", "weight", "identifier", "paradata", and "free_text".

# export_crosstab() rejects an invalid min_eff_n before writing (XE-11)

    Code
      export_crosstab(d, vars = q1, banner = gen, file_name = out, min_eff_n = -5)
    Condition
      Error in `export_crosstab()`:
      x `min_eff_n` must be a single finite number at or above 0.
      i Got -5.
      v Use a single number at or above 0, such as the default 100.

# export_crosstab() names an unlabelled banner column in the missing-label warning (XV-06)

    Code
      export_crosstab(d, vars = q1, banner = nolab, file_name = out, min_eff_n = 0)
    Condition
      Warning:
      ! Variable nolab has no variable_label.
      i Column name used as banner heading.

# export_crosstab() rejects a banner value label on two codes (XE-04)

    Code
      export_crosstab(d, vars = q1, banner = gen, file_name = out)
    Condition
      Error in `export_crosstab()`:
      x Banner column gen uses one value label for 2 or more codes.
      i Repeated label: "Female".
      v Use `surveycore::set_val_labels()` to give each code its own label.

# export_crosstab() rejects a banner with two unlabelled codes (XE-05)

    Code
      export_crosstab(d, vars = q1, banner = gen, file_name = out)
    Condition
      Error in `export_crosstab()`:
      x Banner column gen has 2 observed codes with no value label.
      i Codes with no label: 2 and 3.
      v Use `surveycore::set_val_labels()` to label these codes, so at most one is left without a label.

# export_crosstab() names every dropped all-NA variable in one warning (XV-14)

    Code
      export_crosstab(d, vars = c(q1, all_na_var, q2, all_na_2), banner = group,
      file_name = out, min_eff_n = 0)
    Condition
      Warning:
      ! Variables q1, q2, and group have no variable_label.
      i Variable name used as question text.
      i Column name used as banner heading.
      Warning:
      ! Dropped 2 variables with no non-missing value: all_na_var and all_na_2.
      i The check reads the rows the design tabulates: the rows inside the domain on a domain-restricted design, and every wave of a collection.

# export_crosstab() aborts when every variable is all-NA (XE-16)

    Code
      export_crosstab(d, vars = c(all_na_var, all_na_2), banner = gen, file_name = out,
      min_eff_n = 0)
    Condition
      Error in `export_crosstab()`:
      x No variable in `vars` has a non-missing value.
      i All-NA variables: all_na_var and all_na_2.
      v Select at least one variable with data in `vars`.

# export_crosstab() warns once per call for withheld subgroups (XV-03)

    Code
      export_crosstab(add_gen_fixture(designs$taylor), vars = q1, banner = gen,
      file_name = out, min_eff_n = gen_floor)
    Condition
      Warning:
      ! 1 subgroup is below `min_eff_n` and is withheld.
      * "Female" (gen) withheld: effective sample size 18.1, below the minimum of 50.
      i Each withheld subgroup has no column in any table.

# export_crosstab() warns when every level of a banner is withheld (XV-04)

    Code
      export_crosstab(d, vars = q1, banner = gen, file_name = out, min_eff_n = floor_n)
    Condition
      Warning:
      ! 2 subgroups are below `min_eff_n` and are withheld.
      * "Male" (gen) withheld: effective sample size 166.9, below the minimum of 176.
      * "Female" (gen) withheld: effective sample size 18.1, below the minimum of 176.
      i Each withheld subgroup has no column in any table.
      Warning:
      ! Every subgroup of 1 column group is below `min_eff_n`: gen.
      i The tables are written without that column group.

# export_crosstab() warns when the full sample is below the floor (XV-05)

    Code
      export_crosstab(d, vars = q1, banner = gen, file_name = out, min_eff_n = ceiling(
        full_oracle(d)) + 1)
    Condition
      Warning:
      ! 2 subgroups are below `min_eff_n` and are withheld.
      * "Male" (gen) withheld: effective sample size 166.9, below the minimum of 186.
      * "Female" (gen) withheld: effective sample size 18.1, below the minimum of 186.
      i Each withheld subgroup has no column in any table.
      Warning:
      ! Every subgroup of 1 column group is below `min_eff_n`: gen.
      i The tables are written without that column group.
      Warning:
      ! The effective sample size of the full sample, 185.0, is below `min_eff_n` (186).
      i The full sample is not a subgroup, so its column is still written.

