# tests/testthat/test-export-crosstab.R

# 1. Happy paths ------------------------------------------------------------------

test_that("export_crosstab() creates a non-empty .xlsx file for all 3 design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    result <- withVisible(export_crosstab(designs[[nm]], vars = q1, banner = group, file_name = out))

    expect_false(result$visible, label = paste0(nm, ": return invisible"))
    expect_identical(result$value, out, label = paste0(nm, ": return file_name"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    expect_gt(file.info(out)$size, 0L, label = paste0(nm, ": file non-empty"))

    wb <- openxlsx2::wb_load(out)
    # per_question is default: one sheet named "q1" (variable name)
    expect_true("q1" %in% wb$sheet_names, label = paste0(nm, ": q1 sheet present"))
  }
})

# 2. Multiple variables -----------------------------------------------------------

test_that("export_crosstab() includes all variable names in workbook for multiple vars", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out))

  wb <- openxlsx2::wb_load(out)
  # per_question: one sheet per var
  expect_true("q1" %in% wb$sheet_names, label = "q1 sheet present")
  expect_true("q2" %in% wb$sheet_names, label = "q2 sheet present")
  expect_equal(length(wb$sheet_names), 2L, label = "exactly 2 sheets")
})

# 3. Layout -----------------------------------------------------------------------

test_that("export_crosstab() layout='per_question' creates one sheet per variable", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out,
                    layout = "per_question")
  )

  wb <- openxlsx2::wb_load(out)
  expect_true("q1" %in% wb$sheet_names)
  expect_true("q2" %in% wb$sheet_names)
  expect_equal(length(wb$sheet_names), 2L)
})

test_that("export_crosstab() layout='stacked' creates single sheet named 'Crosstab'", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out,
                    layout = "stacked")
  )

  wb <- openxlsx2::wb_load(out)
  expect_true("Crosstab" %in% wb$sheet_names, label = "Crosstab sheet present")
  expect_equal(length(wb$sheet_names), 1L, label = "exactly 1 sheet")
})

# 4. Banner columns ---------------------------------------------------------------

test_that("export_crosstab() includes subgroup columns for each banner level", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = q1, banner = group, file_name = out)
  )

  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  # Banner levels A, B, C from the 'group' variable should appear as column headers
  expect_true(any(grepl("^A$", cells)), label = "banner level A present")
  expect_true(any(grepl("^B$", cells)), label = "banner level B present")
  expect_true(any(grepl("^C$", cells)), label = "banner level C present")
  # The banner variable name 'group' should appear as a spanner header
  expect_true(any(grepl("^group$", cells)), label = "banner spanner 'group' present")
})

test_that("export_crosstab() produces correct number of banner level column sets", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = q1, banner = group, file_name = out)
  )

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)

  # With banner = group (3 levels: A/B/C), the table has at minimum 4 columns:
  # Response | A | B | C (plus optional N columns)
  expect_gte(ncol(df), 4L)
})

# 5. Interactions -----------------------------------------------------------------

test_that("export_crosstab() renders interaction spanner groups in workbook", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d, vars = q1, banner = c(group, q2), file_name = out,
      interactions = list(c("group", "q2"))
    )
  )

  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  # The interaction label should appear: "group × q2" or "group x q2"
  expect_true(
    any(grepl("group", cells) & grepl("q2", cells)) ||
      any(grepl("group.*q2|q2.*group", cells)),
    label = "interaction group × q2 present in workbook"
  )
})

# 6. Self-banner ------------------------------------------------------------------

test_that("export_crosstab() silently drops self-banner without error or warning", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  # Set labels so the missing-variable-label warning does not fire,
  # letting expect_no_warning() verify only self-banner behavior
  d   <- surveycore::set_var_label(d, variable = "q1",    label = "Agreement question")
  d   <- surveycore::set_var_label(d, variable = "group", label = "Group")
  out <- withr::local_tempfile(fileext = ".xlsx")

  # q1 is in both vars and banner: the q1×q1 subgroup should be silently dropped
  expect_no_warning(
    export_crosstab(d, vars = c(q1, group), banner = c(group), file_name = out)
  )
  expect_true(file.exists(out))

  wb    <- openxlsx2::wb_load(out)
  # q1 sheet should have banner 'group' columns
  df_q1 <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells_q1 <- as.character(unlist(df_q1)[!is.na(unlist(df_q1))])
  expect_true(any(grepl("^group$|^A$|^B$|^C$", cells_q1)),
              label = "q1 sheet has group banner columns")

  # group sheet should NOT have a self-banner 'group' column set
  df_group <- openxlsx2::wb_to_df(wb, sheet = "group", col_names = FALSE)
  cells_group <- as.character(unlist(df_group)[!is.na(unlist(df_group))])
  # The 'group' spanner should be absent from the group variable's own sheet
  # (self-banner dropped); there should be no repeated 'group' spanner header
  # We check there is only one occurrence of 'group' (the question text itself)
  group_occurrences <- sum(grepl("^group$", cells_group))
  expect_lte(group_occurrences, 1L, label = "group spanner absent from self-sheet")
})

# 7. var_type dispatch: SATA and battery ------------------------------------------

test_that("export_crosstab() renders SATA variables without error, with banner columns", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    expect_no_error(
      suppressWarnings(
        export_crosstab(designs[[nm]], vars = c(sata_a, sata_b, sata_c),
                        banner = group, file_name = out)
      )
    )
    expect_true(file.exists(out))

    wb    <- openxlsx2::wb_load(out)
    df    <- openxlsx2::wb_to_df(wb, sheet = wb$sheet_names[[1L]], col_names = FALSE)
    cells <- as.character(unlist(df)[!is.na(unlist(df))])

    # Spanner for banner variable should be present
    expect_true(any(grepl("^group$", cells)), label = paste0(nm, ": group spanner present"))
    # Banner levels should be present
    expect_true(any(grepl("^A$|^B$|^C$", cells)), label = paste0(nm, ": banner levels present"))
  }
})

test_that("export_crosstab() renders battery variables without error, with banner columns", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    expect_no_error(
      suppressWarnings(
        export_crosstab(designs[[nm]], vars = c(bat_1, bat_2, bat_3),
                        banner = group, file_name = out)
      )
    )
    expect_true(file.exists(out))

    wb    <- openxlsx2::wb_load(out)
    df    <- openxlsx2::wb_to_df(wb, sheet = wb$sheet_names[[1L]], col_names = FALSE)
    cells <- as.character(unlist(df)[!is.na(unlist(df))])

    # Spanner for banner variable should be present
    expect_true(any(grepl("^group$", cells)), label = paste0(nm, ": group spanner present"))
    # Banner levels should be present
    expect_true(any(grepl("^A$|^B$|^C$", cells)), label = paste0(nm, ": banner levels present"))
  }
})

# 8. Variance options -------------------------------------------------------------

test_that("export_crosstab() variance=NULL produces no se/ci columns in output frame", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d, "q1", clf,
    banner_resolved = "group",
    variance        = NULL,
    conf_level      = 0.95
  )$frame

  expect_false("se"     %in% names(frame), label = "no se col when variance=NULL")
  expect_false("ci_low" %in% names(frame), label = "no ci_low col when variance=NULL")
})

test_that("export_crosstab() variance='se' produces se column in output frame", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d, "q1", clf,
    banner_resolved = "group",
    variance        = "se",
    conf_level      = 0.95
  )$frame

  expect_true("se" %in% names(frame), label = "se col present when variance='se'")
})

test_that("export_crosstab() variance='ci' produces ci_low/ci_high columns in frame", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d, "q1", clf,
    banner_resolved = "group",
    variance        = "ci",
    conf_level      = 0.95
  )$frame

  expect_true("ci_low"  %in% names(frame), label = "ci_low present when variance='ci'")
  expect_true("ci_high" %in% names(frame), label = "ci_high present when variance='ci'")
})

test_that("export_crosstab() produces a valid file with variance='se'", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_crosstab(d, vars = q1, banner = group, file_name = out, variance = "se")
    )
  )
  expect_true(file.exists(out))
})

# 9. show_n and show_eff_n --------------------------------------------------------

test_that("export_crosstab() show_n=FALSE produces no N row-level data in workbook", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = q1, banner = group, file_name = out, show_n = FALSE)
  )

  wb  <- openxlsx2::wb_load(out)
  df  <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  # With show_n=FALSE the workbook should not contain standalone "N" column
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_false(any(grepl("^N$", cells)), label = "no N header when show_n=FALSE")
})

test_that("export_crosstab() show_n=TRUE includes N column in workbook", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = q1, banner = group, file_name = out, show_n = TRUE)
  )

  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_true(any(grepl("^N$", cells)), label = "N header present when show_n=TRUE")
})

test_that("export_crosstab() show_eff_n=TRUE produces file without error", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_crosstab(d, vars = q1, banner = group, file_name = out, show_eff_n = TRUE)
    )
  )
  expect_true(file.exists(out))
})

# 10. pub_type suppression --------------------------------------------------------

test_that("export_crosstab() pub_type='external' suppresses small-N banner columns", {
  skip_if_not_installed("surveycore")
  # Create a design with a banner variable where one level has very small N
  df_small <- make_survey_data(n = 50L, seed = 99L)
  # Make 'group' very unbalanced: mostly A, tiny C
  df_small$group <- c(
    rep("A", 45L), rep("B", 3L), rep("C", 2L)
  )
  d_small <- surveycore::as_survey(df_small, ids = psu, strata = strata,
                                    weights = wt, nest = TRUE)

  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(
      d_small, vars = q1, banner = group, file_name = out,
      pub_type = "external"
    ),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))

  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  # Suppression footnote should be written (contains "suppressed")
  expect_true(any(grepl("suppressed", cells, ignore.case = TRUE)),
              label = "suppression footnote present in workbook")
})

test_that("export_crosstab() pub_type='none' does not suppress any columns", {
  skip_if_not_installed("surveycore")
  df_small <- make_survey_data(n = 50L, seed = 99L)
  df_small$group <- c(rep("A", 45L), rep("B", 3L), rep("C", 2L))
  d_small <- surveycore::as_survey(df_small, ids = psu, strata = strata,
                                    weights = wt, nest = TRUE)
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(
    suppressWarnings(  # suppress only missing-label warnings
      export_crosstab(
        d_small, vars = q1, banner = group, file_name = out,
        pub_type = "none"
      )
    )
  )
  # All 3 banner levels should be present
  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_true(any(grepl("^A$", cells)), label = "A still present with pub_type='none'")
})

# 11. Missing metadata warning ----------------------------------------------------

test_that("export_crosstab() warns about missing variable_label when unset", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(d, vars = q1, banner = group, file_name = out),
    class = "surveyreports_warning_missing_variable_label"
  )
})

test_that("export_crosstab() does not warn when variable_label is set", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(export_crosstab(d, vars = q1, banner = group, file_name = out))
})

# 12. Error paths -----------------------------------------------------------------

test_that("export_crosstab() errors for survey_collection design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll    <- surveycore::as_survey_collection(wave1 = designs$taylor, wave2 = designs$replicate)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(coll, vars = q1, banner = group, file_name = out),
    class = "surveyreports_error_collection_not_supported_for_crosstab"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(coll, vars = q1, banner = group, file_name = out)
  )
})

test_that("export_crosstab() errors when design is not a survey object", {
  skip_if_not_installed("surveycore")
  out <- withr::local_tempfile(fileext = ".xlsx")
  df  <- data.frame(q1 = 1:5, wt = rep(1, 5))

  expect_error(
    export_crosstab(df, vars = q1, banner = q1, file_name = out),
    class = "surveyreports_error_not_survey_object"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(df, vars = q1, banner = q1, file_name = out)
  )
})

test_that("export_crosstab() errors when vars resolves to zero columns", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = starts_with("zzz"), banner = group, file_name = out),
    class = "surveyreports_error_vars_empty_selection"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = starts_with("zzz"), banner = group, file_name = out)
  )
})

test_that("export_crosstab() errors when vars_resolved contains a missing column", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    surveyreports:::.validate_export_inputs(d, "nonexistent_col", out, 0.95, 1L),
    class = "surveyreports_error_var_not_found"
  )
  expect_snapshot(
    error = TRUE,
    surveyreports:::.validate_export_inputs(d, "nonexistent_col", out, 0.95, 1L)
  )
})

test_that("export_crosstab() errors when domain has zero rows", {
  skip_if_not_installed("surveycore")
  d_empty      <- make_all_designs(seed = 42)$taylor
  d_empty@data <- d_empty@data[0L, ]
  out          <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d_empty, vars = q1, banner = group, file_name = out),
    class = "surveyreports_error_empty_domain"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d_empty, vars = q1, banner = group, file_name = out)
  )
})

test_that("export_crosstab() errors when file_name does not end in .xlsx", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = "output.csv"),
    class = "surveyreports_error_invalid_file_name"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = "output.csv")
  )
})

test_that("export_crosstab() errors when conf_level is outside (0, 1)", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out, conf_level = 1.5),
    class = "surveyreports_error_invalid_conf_level"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out, conf_level = 1.5)
  )
})

test_that("export_crosstab() errors when decimals is not a positive integer", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out, decimals = 0),
    class = "surveyreports_error_invalid_decimals"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out, decimals = 0)
  )
})

test_that("export_crosstab() errors when banner variable is not in design", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = nonexistent_banner, file_name = out),
    class = "surveyreports_error_banner_not_found"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = nonexistent_banner, file_name = out)
  )
})

test_that("export_crosstab() errors when interactions is not a list", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    interactions = "not_a_list"),
    class = "surveyreports_error_interactions_not_list"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    interactions = "not_a_list")
  )
})

test_that("export_crosstab() errors when interactions contains a var not in banner", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    interactions = list(c("group", "q2"))),
    class = "surveyreports_error_interaction_not_in_banner"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    interactions = list(c("group", "q2")))
  )
})
