# tests/testthat/test-export-crosstab.R

# 1. Happy paths ------------------------------------------------------------------

test_that("export_crosstab() creates a non-empty .xlsx file for all 4 design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    unlink(out)
    result <- withVisible(crosstab_quiet(
      cover_design(designs[[nm]]),
      vars = q1,
      banner = group,
      file_name = out,
      min_eff_n = 0
    ))

    expect_false(result$visible, label = paste0(nm, ": return invisible"))
    expect_identical(
      result$value,
      out,
      label = paste0(nm, ": return file_name")
    )
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    expect_gt(file.info(out)$size, 0L, label = paste0(nm, ": file non-empty"))

    wb <- openxlsx2::wb_load(out)
    # per_question is default: one sheet named "q1" (variable name)
    expect_true(
      "q1" %in% wb$sheet_names,
      label = paste0(nm, ": q1 sheet present")
    )
  }
})

# 2. Multiple variables -----------------------------------------------------------

test_that("export_crosstab() includes all variable names in workbook for multiple vars", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_crosstab(
    d,
    vars = c(q1, q2),
    banner = group,
    file_name = out
  ))

  wb <- openxlsx2::wb_load(out)
  # per_question: one sheet per var
  expect_true("q1" %in% wb$sheet_names, label = "q1 sheet present")
  expect_true("q2" %in% wb$sheet_names, label = "q2 sheet present")
  # The About cover sheet comes first, then one sheet per variable.
  expect_equal(length(wb$sheet_names), 3L, label = "About plus 2 sheets")
})

# 3. Layout -----------------------------------------------------------------------

test_that("export_crosstab() layout='per_question' creates one sheet per variable", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = c(q1, q2),
      banner = group,
      file_name = out,
      layout = "per_question"
    )
  )

  wb <- openxlsx2::wb_load(out)
  expect_true("q1" %in% wb$sheet_names)
  expect_true("q2" %in% wb$sheet_names)
  # The About cover sheet comes first, then one sheet per variable.
  expect_equal(length(wb$sheet_names), 3L)
})

test_that("export_crosstab() layout='stacked' creates single sheet named 'Crosstab'", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = c(q1, q2),
      banner = group,
      file_name = out,
      layout = "stacked"
    )
  )

  wb <- openxlsx2::wb_load(out)
  expect_true("Crosstab" %in% wb$sheet_names, label = "Crosstab sheet present")
  # The About cover sheet, then the one stacked sheet.
  expect_equal(length(wb$sheet_names), 2L, label = "About plus 1 sheet")
})

test_that("export_crosstab() stacked layout renders SATA variables", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = c(sata_a, sata_b, sata_c),
      banner = q2,
      file_name = out,
      layout = "stacked"
    )
  )

  expect_true(file.exists(out))
  wb <- openxlsx2::wb_load(out)
  expect_true("Crosstab" %in% wb$sheet_names)
})

test_that("export_crosstab() stacked layout renders battery variables", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = c(bat_1, bat_2, bat_3),
      banner = q2,
      file_name = out,
      layout = "stacked"
    )
  )

  expect_true(file.exists(out))
  wb <- openxlsx2::wb_load(out)
  expect_true("Crosstab" %in% wb$sheet_names)
})

# 4. Banner columns ---------------------------------------------------------------

test_that("export_crosstab() includes subgroup columns for each banner level", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      min_eff_n = 0
    )
  )

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  # Banner levels A, B, C from the 'group' variable should appear as column headers
  expect_true(any(grepl("^A$", cells)), label = "banner level A present")
  expect_true(any(grepl("^B$", cells)), label = "banner level B present")
  expect_true(any(grepl("^C$", cells)), label = "banner level C present")
  # The banner variable name 'group' should appear as a spanner header
  expect_true(
    any(grepl("^group$", cells)),
    label = "banner spanner 'group' present"
  )
})

test_that("export_crosstab() produces correct number of banner level column sets", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      min_eff_n = 0
    )
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
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = q1,
      banner = c(group, q2),
      file_name = out,
      interactions = list(c("group", "q2")),
      min_eff_n = 0
    )
  )

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
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
  d <- make_all_designs(seed = 42)$taylor
  # Set labels so the missing-variable-label warning does not fire,
  # letting expect_no_warning() verify only self-banner behavior
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  d <- surveycore::set_var_label(d, variable = "group", label = "Group")
  out <- withr::local_tempfile(fileext = ".xlsx")

  # q1 is in both vars and banner: the q1×q1 subgroup should be silently dropped
  expect_no_warning(
    export_crosstab(
      d,
      vars = c(q1, group),
      banner = c(group),
      file_name = out,
      min_eff_n = 0
    )
  )
  expect_true(file.exists(out))

  wb <- openxlsx2::wb_load(out)
  # q1 sheet should have banner 'group' columns
  df_q1 <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells_q1 <- as.character(unlist(df_q1)[!is.na(unlist(df_q1))])
  expect_true(
    any(grepl("^group$|^A$|^B$|^C$", cells_q1)),
    label = "q1 sheet has group banner columns"
  )

  # group sheet should NOT have a self-banner 'group' column set
  df_group <- openxlsx2::wb_to_df(wb, sheet = "group", col_names = FALSE)
  cells_group <- as.character(unlist(df_group)[!is.na(unlist(df_group))])
  # The 'group' spanner should be absent from the group variable's own sheet
  # (self-banner dropped); there should be no repeated 'group' spanner header
  # We check there is only one occurrence of 'group' (the question text itself)
  group_occurrences <- sum(grepl("^group$", cells_group))
  expect_lte(
    group_occurrences,
    1L,
    label = "group spanner absent from self-sheet"
  )
})

# 7. var_type dispatch: SATA and battery ------------------------------------------

test_that("export_crosstab() renders SATA variables without error, with banner columns", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    unlink(out)
    expect_no_error(
      suppressWarnings(
        export_crosstab(
          designs[[nm]],
          vars = c(sata_a, sata_b, sata_c),
          banner = group,
          file_name = out,
          min_eff_n = 0
        )
      )
    )
    expect_true(file.exists(out))

    wb <- openxlsx2::wb_load(out)
    # Sheet 1 is the About cover sheet; the question sheet is sheet 2.
    df <- openxlsx2::wb_to_df(
      wb,
      sheet = wb$sheet_names[[2L]],
      col_names = FALSE
    )
    cells <- as.character(unlist(df)[!is.na(unlist(df))])

    # Spanner for banner variable should be present
    expect_true(
      any(grepl("^group$", cells)),
      label = paste0(nm, ": group spanner present")
    )
    # Banner levels should be present
    expect_true(
      any(grepl("^A$|^B$|^C$", cells)),
      label = paste0(nm, ": banner levels present")
    )
  }
})

test_that("export_crosstab() renders battery variables without error, with banner columns", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    unlink(out)
    expect_no_error(
      suppressWarnings(
        export_crosstab(
          designs[[nm]],
          vars = c(bat_1, bat_2, bat_3),
          banner = group,
          file_name = out,
          min_eff_n = 0
        )
      )
    )
    expect_true(file.exists(out))

    wb <- openxlsx2::wb_load(out)
    # Sheet 1 is the About cover sheet; the question sheet is sheet 2.
    df <- openxlsx2::wb_to_df(
      wb,
      sheet = wb$sheet_names[[2L]],
      col_names = FALSE
    )
    cells <- as.character(unlist(df)[!is.na(unlist(df))])

    # Spanner for banner variable should be present
    expect_true(
      any(grepl("^group$", cells)),
      label = paste0(nm, ": group spanner present")
    )
    # Banner levels should be present
    expect_true(
      any(grepl("^A$|^B$|^C$", cells)),
      label = paste0(nm, ": banner levels present")
    )
  }
})

test_that("export_crosstab() heads a SATA block with the shared question preface", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    # Labelled items: variable_label holds the item text, preface the question
    d <- surveycore::set_var_label(
      designs[[nm]],
      variable = c("sata_a", "sata_b", "sata_c"),
      label = c("Option A", "Option B", "Option C")
    )
    unlink(out)
    suppressWarnings(
      export_crosstab(
        d,
        vars = c(sata_a, sata_b, sata_c),
        banner = group,
        file_name = out
      )
    )

    wb <- openxlsx2::wb_load(out)
    df <- openxlsx2::wb_to_df(wb, sheet = "sata_a", col_names = FALSE)

    expect_identical(
      as.character(df[1L, 1L]),
      "Which of the following apply to you?",
      label = paste0(nm, ": SATA header cell is the question preface")
    )
    expect_true(
      all(c("Option A", "Option B", "Option C") %in% as.character(df[[1L]])),
      label = paste0(nm, ": item labels remain the row labels")
    )
  }
})

test_that("export_crosstab() heads a battery block with the shared question preface", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- surveycore::set_var_label(
      designs[[nm]],
      variable = c("bat_1", "bat_2", "bat_3"),
      label = c("Item one", "Item two", "Item three")
    )
    unlink(out)
    suppressWarnings(
      export_crosstab(
        d,
        vars = c(bat_1, bat_2, bat_3),
        banner = group,
        file_name = out
      )
    )

    wb <- openxlsx2::wb_load(out)
    df <- openxlsx2::wb_to_df(wb, sheet = "bat_1", col_names = FALSE)

    expect_identical(
      as.character(df[1L, 1L]),
      "Please rate the following items:",
      label = paste0(nm, ": battery header cell is the question preface")
    )
  }
})

test_that("export_crosstab() heads a single block with variable_label even when a preface is set", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  d <- surveycore::set_question_preface(
    d,
    variable = "q1",
    preface = "Intro text"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)

  expect_identical(as.character(df[1L, 1L]), "Agreement question")
})

# 8. Variance options -------------------------------------------------------------

test_that("export_crosstab() variance=NULL produces no se/ci columns in output frame", {
  skip_if_not_installed("surveycore")
  d <- cover_design(make_all_designs(seed = 42)$taylor)
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d,
    "q1",
    clf,
    banner_resolved = "group",
    variance = NULL,
    conf_level = 0.95
  )$frame

  expect_false("se" %in% names(frame), label = "no se col when variance=NULL")
  expect_false(
    "ci_low" %in% names(frame),
    label = "no ci_low col when variance=NULL"
  )
})

test_that("export_crosstab() variance='se' produces se column in output frame", {
  skip_if_not_installed("surveycore")
  d <- cover_design(make_all_designs(seed = 42)$taylor)
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d,
    "q1",
    clf,
    banner_resolved = "group",
    variance = "se",
    conf_level = 0.95
  )$frame

  expect_true(
    "se" %in% names(frame),
    label = "se col present when variance='se'"
  )
})

test_that("export_crosstab() variance='ci' produces ci_low/ci_high columns in frame", {
  skip_if_not_installed("surveycore")
  d <- cover_design(make_all_designs(seed = 42)$taylor)
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d,
    "q1",
    clf,
    banner_resolved = "group",
    variance = "ci",
    conf_level = 0.95
  )$frame

  expect_true(
    "ci_low" %in% names(frame),
    label = "ci_low present when variance='ci'"
  )
  expect_true(
    "ci_high" %in% names(frame),
    label = "ci_high present when variance='ci'"
  )
})

test_that("export_crosstab() produces a valid file with variance='se'", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_crosstab(
        d,
        vars = q1,
        banner = group,
        file_name = out,
        variance = "se"
      )
    )
  )
  expect_true(file.exists(out))
})

# 9. The count-column arguments: removed --------------------------------------
# The N column and its two arguments are removed (spec 5.1). Section 29 covers
# what replaces them: XS-05 for show_ess, XS-08 for the removed N column, and
# XE-07 for a call that still passes either argument.

# 10. Suppression: N/A ---------------------------------------------------------
# The argument with two suppression modes is removed (spec 3.5), so neither
# mode is left to test. Section 26 tests min_eff_n, the one floor that
# replaces it.

# 11. Missing metadata warning ----------------------------------------------------

test_that("export_crosstab() warns about missing variable_label when unset", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      min_eff_n = 0
    ),
    class = "surveyreports_warning_missing_variable_label"
  )
})

test_that("export_crosstab() does not warn when variable_label is set", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out,
    min_eff_n = 0
  ))
})

# 12. Error paths -----------------------------------------------------------------

test_that("export_crosstab() errors for survey_collection design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    wave1 = designs$taylor,
    wave2 = designs$replicate
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

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
  df <- data.frame(q1 = 1:5, wt = rep(1, 5))

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
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = starts_with("zzz"),
      banner = group,
      file_name = out
    ),
    class = "surveyreports_error_vars_empty_selection"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = starts_with("zzz"),
      banner = group,
      file_name = out
    )
  )
})

test_that("export_crosstab() errors when vars_resolved contains a missing column", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    surveyreports:::.validate_export_inputs(
      d,
      "nonexistent_col",
      out,
      0.95,
      1L
    ),
    class = "surveyreports_error_var_not_found"
  )
  expect_snapshot(
    error = TRUE,
    surveyreports:::.validate_export_inputs(d, "nonexistent_col", out, 0.95, 1L)
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
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      conf_level = 1.5
    ),
    class = "surveyreports_error_invalid_conf_level"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      conf_level = 1.5
    )
  )
})

test_that("export_crosstab() errors when decimals is negative", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      decimals = -1
    ),
    class = "surveyreports_error_invalid_decimals"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      decimals = -1
    )
  )
})

# The class alone: the block above snapshots its message.
test_that("export_crosstab() errors when decimals is not a whole number", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      decimals = 1.5
    ),
    class = "surveyreports_error_invalid_decimals"
  )
})

test_that("export_crosstab() errors when banner variable is not in design", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
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
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      interactions = "not_a_list"
    ),
    class = "surveyreports_error_interactions_not_list"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      interactions = "not_a_list"
    )
  )
})

test_that("export_crosstab() errors when interactions contains a var not in banner", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      interactions = list(c("group", "q2"))
    ),
    class = "surveyreports_error_interaction_not_in_banner"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      interactions = list(c("group", "q2"))
    )
  )
})

# 13. Edge cases ------------------------------------------------------------------

test_that("export_crosstab() handles single-value variable without crashing", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$single_val <- "Only"
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = single_val, banner = group, file_name = out)
  )

  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)
})

test_that("export_crosstab() handles very small design (2 rows) without crashing", {
  skip_if_not_installed("surveycore")
  # surveycore requires >= 2 rows; use a minimal valid design
  df_small <- make_survey_data(seed = 42)[1L:2L, ]
  df_small$strata <- 1L
  df_small$psu <- 1L:2L
  # One stratum is the setup of this test, so its warning is not under test.
  d_small <- suppressWarnings(
    surveycore::as_survey(
      df_small,
      ids = psu,
      strata = strata,
      weights = wt,
      nest = TRUE
    ),
    classes = "surveycore_warning_single_stratum"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d_small, vars = q1, banner = group, file_name = out)
  )

  expect_true(file.exists(out))
})

test_that("export_crosstab() handles single-level banner without error", {
  skip_if_not_installed("surveycore")
  df_one_banner <- make_survey_data(seed = 42)
  df_one_banner$banner_one <- "X"
  d_one_banner <- surveycore::as_survey(
    df_one_banner,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )
  d_one_banner <- surveycore::set_var_label(
    d_one_banner,
    variable = c("q1", "banner_one"),
    label = c("Agreement question", "Banner")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  # surveycore warns that banner_one has one level. That level is the setup of
  # this test, so its warning is not under test.
  expect_no_error(
    suppressWarnings(
      export_crosstab(
        d_one_banner,
        vars = q1,
        banner = banner_one,
        file_name = out
      ),
      classes = "surveycore_warning_single_level"
    )
  )
  expect_true(file.exists(out))

  wb <- openxlsx2::wb_load(out)
  expect_true("q1" %in% wb$sheet_names)
})

# 14. Numerical accuracy ----------------------------------------------------------

test_that(".build_freq_frame() pct matches surveycore::get_freqs() prop for banner subgroups", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- suppressWarnings(
    surveyreports:::.build_freq_frame(
      d,
      "q1",
      clf,
      banner_resolved = "group",
      variance = "se",
      conf_level = 0.95
    )
  )$frame

  banner_rows <- frame[frame$subgroup_type == "banner", ]

  oracle <- suppressWarnings(
    surveycore::get_freqs(
      d,
      !!rlang::sym("q1"),
      group = !!rlang::sym("group"),
      variance = "se"
    )
  )
  # oracle columns: group, q1, pct, se, n
  # Align by (group level, response value)
  for (grp in unique(oracle$group)) {
    for (val in unique(oracle$q1)) {
      oracle_pct <- oracle$pct[oracle$group == grp & oracle$q1 == val]
      frame_pct <- banner_rows$pct[
        banner_rows$subgroup_value == grp & banner_rows$value == val
      ]
      if (length(oracle_pct) == 0L || length(frame_pct) == 0L) {
        next
      }
      expect_equal(
        frame_pct,
        oracle_pct,
        tolerance = 1e-10,
        label = paste0("pct for group=", grp, ", value=", val)
      )
    }
  }
})

test_that(".build_freq_frame() se matches surveycore::get_freqs() se for banner subgroups", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- suppressWarnings(
    surveyreports:::.build_freq_frame(
      d,
      "q1",
      clf,
      banner_resolved = "group",
      variance = "se",
      conf_level = 0.95
    )
  )$frame

  banner_rows <- frame[frame$subgroup_type == "banner", ]

  oracle <- suppressWarnings(
    surveycore::get_freqs(
      d,
      !!rlang::sym("q1"),
      group = !!rlang::sym("group"),
      variance = "se"
    )
  )
  # oracle columns: group, q1, pct, se, n
  for (grp in unique(oracle$group)) {
    for (val in unique(oracle$q1)) {
      oracle_se <- oracle$se[oracle$group == grp & oracle$q1 == val]
      frame_se <- banner_rows$se[
        banner_rows$subgroup_value == grp & banner_rows$value == val
      ]
      if (length(oracle_se) == 0L || length(frame_se) == 0L) {
        next
      }
      expect_equal(
        frame_se,
        oracle_se,
        tolerance = 1e-8,
        label = paste0("se for group=", grp, ", value=", val)
      )
    }
  }
})

# 15. show_total ------------------------------------------------------------------

test_that("export_crosstab() renders a Total column before the banner columns by default", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  # Layout: row 1 title, row 2 spanner, row 3 header
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[[1L]], "Response")
  expect_identical(
    header[[2L]],
    "Total",
    label = "Total header before banner levels"
  )
  expect_identical(header[3L:5L], c("A", "B", "C"))
  # Spanner row carries the synthetic Total group label too
  expect_identical(as.character(df[2L, 2L]), "Total")
})

test_that("export_crosstab() Total column values match the full-sample distribution", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  ref <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (i in seq_len(nrow(ref))) {
    val <- as.character(ref[[1L]][[i]])
    row_idx <- which(as.character(df[[1L]]) == val)
    row_idx <- row_idx[row_idx > 3L][[1L]]
    # The cell is a string (spec 3.3), built here from the oracle.
    expect_identical(
      as.character(df[row_idx, 2L]),
      paste0(round(ref$pct[[i]] * 100, 1L), "%"),
      label = paste0("Total column for value '", val, "'")
    )
  }
})

test_that("export_crosstab() show_total=FALSE restores the banner-only layout", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out,
    show_total = FALSE,
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[[1L]], "Response")
  expect_identical(
    header[[2L]],
    "A",
    label = "first banner level directly after label col"
  )
  expect_false(
    "Total" %in% header,
    label = "no Total header when show_total=FALSE"
  )
})

test_that("export_crosstab() show_total puts the Total column in front of the banner columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out_with <- withr::local_tempfile(fileext = ".xlsx")
  out_without <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out_with,
    min_eff_n = 0
  )
  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out_without,
    show_total = FALSE,
    min_eff_n = 0
  )

  hdr_with <- as.character(unlist(
    openxlsx2::wb_to_df(out_with, sheet = "q1", col_names = FALSE)[3L, ]
  ))
  hdr_without <- as.character(unlist(
    openxlsx2::wb_to_df(out_without, sheet = "q1", col_names = FALSE)[3L, ]
  ))

  # 1 label, then Total, then the 3 banner levels; without Total, the levels
  # start in column 2
  expect_identical(hdr_with[2:5], c("Total", "A", "B", "C"))
  expect_identical(hdr_without[2:4], c("A", "B", "C"))
})

test_that("export_crosstab() SATA tables gain the Total column by default", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c", "group"),
    label = c("Option A", "Option B", "Option C", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c),
    banner = group,
    file_name = out,
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[1L:2L], c("Item", "Total"))

  # Total value for sata_a equals its full-sample share of value 1
  ref <- suppressWarnings(surveycore::get_freqs(d, sata_a))
  ref_pct <- ref$pct[as.character(ref[[1L]]) == "1"]
  row_a <- which(as.character(df[[1L]]) == "Option A")[[1L]]
  # The cell is a string (spec 3.3), built here from the oracle.
  expect_identical(
    as.character(df[row_a, 2L]),
    paste0(round(ref_pct * 100, 1L), "%")
  )
})

# 16. base_notes ------------------------------------------------------------------

test_that("export_crosstab() writes an italic base row under the title and shifts the table", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out,
    base_notes = c(q1 = "Base: All respondents (n=200)"),
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  expect_identical(as.character(df[2L, 1L]), "Base: All respondents (n=200)")
  # Table shifted down one row: header now at row 4
  expect_identical(as.character(df[4L, 1L]), "Response")
})

test_that("export_crosstab() writes no base row when base_notes is NULL", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "group"),
    label = c("Agreement question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  expect_identical(as.character(df[3L, 1L]), "Response")
  expect_false(any(grepl("^Base:", as.character(df[[1L]])), na.rm = TRUE))
})

test_that("export_crosstab() writes base rows only for variables with an entry", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("q1", "q2", "group"),
    label = c("Agreement question", "Yes/no question", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(q1, q2),
    banner = group,
    file_name = out,
    base_notes = c(q1 = "Base: only q1 has a note"),
    min_eff_n = 0
  )

  df_q1 <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  df_q2 <- openxlsx2::wb_to_df(out, sheet = "q2", col_names = FALSE)
  expect_identical(as.character(df_q1[2L, 1L]), "Base: only q1 has a note")
  expect_false(any(grepl("^Base:", as.character(df_q2[[1L]])), na.rm = TRUE))
})

test_that("export_crosstab() keys sata and battery base notes by the group's first member", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c(
      "sata_a",
      "sata_b",
      "sata_c",
      "bat_1",
      "bat_2",
      "bat_3",
      "group"
    ),
    label = c(
      "Option A",
      "Option B",
      "Option C",
      "Item 1",
      "Item 2",
      "Item 3",
      "Group"
    )
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
    banner = group,
    file_name = out,
    base_notes = c(sata_a = "Base: sata group", bat_1 = "Base: battery group"),
    min_eff_n = 0
  )

  df_sata <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  df_bat <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
  expect_identical(as.character(df_sata[2L, 1L]), "Base: sata group")
  expect_identical(as.character(df_bat[2L, 1L]), "Base: battery group")
})

test_that("export_crosstab() errors when base_notes is not fully named", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      base_notes = c("unnamed note")
    ),
    class = "surveyreports_error_base_notes_invalid"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      base_notes = c("unnamed note")
    )
  )
})

test_that("export_crosstab() errors when base_notes is not a character vector", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      base_notes = list(q1 = "a list, not a character vector")
    ),
    class = "surveyreports_error_base_notes_invalid"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      base_notes = list(q1 = "a list, not a character vector")
    )
  )
})

test_that("export_crosstab() errors when base_notes is partially named", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      base_notes = c(q1 = "named", "unnamed")
    ),
    class = "surveyreports_error_base_notes_invalid"
  )
})

# 17. Two-column battery layout ---------------------------------------------------

test_that("export_crosstab() battery tables use Item and Response label columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("bat_1", "bat_2", "bat_3", "group"),
    label = c("Item one", "Item two", "Item three", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(bat_1, bat_2, bat_3),
    banner = group,
    file_name = out,
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[1L:3L], c("Item", "Response", "Total"))

  # Item label written once per item block, not repeated per scale value
  expect_identical(
    sum(as.character(df[[1L]]) == "Item one", na.rm = TRUE),
    1L
  )
  # Scale values live in the Response column
  expect_true(all(c("1", "2", "3", "4", "5") %in% as.character(df[[2L]])))
  # No flattened "item (value)" labels remain
  expect_false(
    any(grepl("^Item one \\(", as.character(df[[1L]])), na.rm = TRUE)
  )
})

test_that("export_crosstab() battery banner columns follow the Total column, with no N column", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("bat_1", "bat_2", "bat_3", "group"),
    label = c("Item one", "Item two", "Item three", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(bat_1, bat_2, bat_3),
    banner = group,
    file_name = out,
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  # Item | Response | Total | A | B | C
  expect_identical(header[3:6], c("Total", "A", "B", "C"))
  expect_false("N" %in% header)
})

# 18. True-zero SATA cells --------------------------------------------------------

test_that("export_crosstab() prints 0% for an asked-but-never-selected SATA option", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  # sata_b: asked of everyone, selected by no one
  d@data$sata_b <- 0L
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c", "group"),
    label = c("Option A", "Option B", "Option C", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c),
    banner = group,
    file_name = out,
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  row_b <- which(as.character(df[[1L]]) == "Option B")[[1L]]
  # Total, A, B, C cells all print 0% (spec 3.3)
  expect_identical(
    as.character(unlist(df[row_b, 2:5])),
    rep("0%", 4L)
  )
})

test_that("export_crosstab() writes - for never-asked banner subgroups in SATA tables", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  # Gate the whole block away from group C: never asked there
  asked <- d@data$group != "C"
  d@data$sata_a <- ifelse(asked, d@data$sata_a, NA_integer_)
  d@data$sata_b <- ifelse(asked, 0L, NA_integer_) # asked, never selected
  d@data$sata_c <- ifelse(asked, d@data$sata_c, NA_integer_)
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c", "group"),
    label = c("Option A", "Option B", "Option C", "Group")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c),
    banner = group,
    file_name = out,
    min_eff_n = 0
  )

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  # Header: Item | Total | A | B | C
  row_a <- which(as.character(df[[1L]]) == "Option A")[[1L]]
  row_b <- which(as.character(df[[1L]]) == "Option B")[[1L]]

  # Asked subgroups have a percentage; the never-asked C column reads `-`
  # (spec 3.3, gap 17)
  expect_match(
    as.character(df[row_a, 3L]),
    "^[0-9]+(\\.[0-9]+)?%$",
    label = "asked subgroup A has a percentage"
  )
  expect_identical(
    as.character(df[row_a, 5L]),
    "-",
    label = "never-asked subgroup C reads -"
  )
  # A true zero prints 0% in asked subgroups and - in C
  expect_identical(as.character(df[row_b, 3L]), "0%")
  expect_identical(
    as.character(df[row_b, 5L]),
    "-",
    label = "zero row reads - where never asked"
  )
})

test_that("export_crosstab() prints the code-1 share for a labelled SATA item", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    unlink(out)
    # sata_a coded 1 = Yes, 2 = No: the chosen value is code 1, "Yes"
    d <- designs[[nm]]
    d@data$sata_a <- ifelse(d@data$sata_a == 1L, 1, 2)
    d@metadata@value_labels[["sata_a"]] <- c(Yes = 1, No = 2)
    d <- surveycore::set_sata(d, variable = c("sata_a", "sata_b", "sata_c"))
    d <- surveycore::set_var_label(
      d,
      variable = c("sata_a", "sata_b", "sata_c", "group"),
      label = c("Option A", "Option B", "Option C", "Group")
    )

    crosstab_quiet(
      d,
      vars = c(sata_a, sata_b, sata_c),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
    col_1 <- as.character(df[[1L]])
    row_a <- which(col_1 == "Option A")
    expect_identical(length(row_a), 1L, label = paste0(nm, ": item row"))
    header <- as.character(unlist(df[which(col_1 == "Item")[[1L]], ]))

    # The cells are strings (spec 3.3), built here from the oracle.
    ref_total <- quiet_nonprob(surveycore::get_freqs(d, sata_a))
    expect_identical(
      as.character(df[row_a, match("Total", header)]),
      paste0(
        round(100 * ref_total$pct[as.character(ref_total[[1L]]) == "Yes"], 1L),
        "%"
      ),
      label = paste0(nm, ": Total cell")
    )

    # The reference call is not the subject: twophase raises the small-cell
    # warning here, as the Total-column SATA block's reference call can.
    ref_group <- suppressWarnings(
      surveycore::get_freqs(d, sata_a, group = group),
      classes = c(
        "surveycore_warning_small_cell",
        "surveycore_warning_nonprob_srs_fallback"
      )
    )
    for (lvl in c("A", "B", "C")) {
      ref_pct <- ref_group$pct[
        as.character(ref_group$group) == lvl &
          as.character(ref_group$sata_a) == "Yes"
      ]
      expect_identical(
        as.character(df[row_a, match(lvl, header)]),
        paste0(round(100 * ref_pct, 1L), "%"),
        label = paste0(nm, ": cell for ", lvl)
      )
    }
  }
})

# 19. Metadata readers: unwired helpers ---------------------------------------
# These five helpers have no caller yet, so the coverage floor has no indirect
# path to them. Later PRs wire them into export_crosstab() and
# export_topline(). Until then they are tested directly.

# Adds a labelled numeric banner `gen` (codes 1 and 2, some NA) to a design.
add_labelled_banner <- function(d) {
  n <- nrow(d@data)
  d@data$gen <- rep(c(1, 2, NA, 2, 1), length.out = n)
  surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))
}

test_that(".unanimous_across() keeps a key that agrees across every member", {
  entries <- list(
    c(q1 = "Adults", q2 = "Voters"),
    c(q1 = "Adults", q2 = "Voters"),
    c(q1 = "Adults", q2 = "Voters")
  )

  result <- surveyreports:::.unanimous_across(entries)

  expect_identical(result, c(q1 = "Adults", q2 = "Voters"))
})

test_that(".unanimous_across() omits a key that disagrees in one member", {
  entries <- list(
    c(q1 = "Adults", q2 = "Voters"),
    c(q1 = "Adults", q2 = "Parents")
  )

  result <- surveyreports:::.unanimous_across(entries)

  expect_identical(result, c(q1 = "Adults"))
})

test_that(".unanimous_across() omits a key that is missing in one member", {
  entries <- list(
    c(q1 = "Adults", q2 = "Voters"),
    c(q2 = "Voters"),
    c(q1 = "Adults", q2 = "Voters")
  )

  result <- surveyreports:::.unanimous_across(entries)

  expect_identical(result, c(q2 = "Voters"))
})

test_that(".unanimous_across() omits a key whose value is NA", {
  entries <- list(
    c(q1 = NA_character_, q2 = "Voters"),
    c(q1 = NA_character_, q2 = "Voters")
  )

  result <- surveyreports:::.unanimous_across(entries)

  expect_identical(result, c(q2 = "Voters"))
})

test_that(".unanimous_across() returns an empty named vector when nothing agrees", {
  empty <- structure(character(0), names = character(0))

  expect_identical(surveyreports:::.unanimous_across(list()), empty)
  expect_identical(
    surveyreports:::.unanimous_across(list(c(q1 = "a"), character(0))),
    empty
  )
  expect_identical(
    surveyreports:::.unanimous_across(list(character(0), c(q1 = "a"))),
    empty
  )
  expect_identical(
    surveyreports:::.unanimous_across(list(c(q1 = "a"), c(q1 = "b"))),
    empty
  )
})

test_that(".has_domain() is FALSE on every design without a domain column", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    result <- surveyreports:::.has_domain(designs[[nm]])
    expect_identical(result, FALSE, label = paste0(nm, ": no domain"))
  }
})

test_that(".has_domain() is TRUE on every design with a domain column", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$group == "A"
    expect_identical(
      surveyreports:::.has_domain(d),
      TRUE,
      label = paste0(nm, ": restricted domain")
    )
  }
})

test_that(".has_domain() is TRUE when the domain selects every row", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- TRUE

  expect_identical(surveyreports:::.has_domain(d), TRUE)
})

test_that(".resolve_eff_n() returns one row with no group, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    result <- surveyreports:::.resolve_eff_n(d)
    ref <- surveycore::get_effective_n(d)

    expect_s3_class(result, "tbl_df")
    expect_identical(names(result), c("level", "n", "n_eff"))
    expect_identical(nrow(result), 1L, label = paste0(nm, ": one row"))
    expect_identical(result$level, NA_character_, label = paste0(nm, ": level"))
    expect_identical(result$n, as.integer(ref$n), label = paste0(nm, ": n"))
    expect_true(is.double(result$n_eff), label = paste0(nm, ": n_eff type"))
    expect_equal(
      result$n_eff,
      ref$n_eff,
      tolerance = 1e-8,
      label = paste0(nm, ": n_eff")
    )
  }
})

test_that(".resolve_eff_n() returns one row per observed level, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    result <- surveyreports:::.resolve_eff_n(d, group_var = "group")
    ref <- surveycore::get_effective_n(d, group = group)
    freqs <- suppressWarnings(surveycore::get_freqs(d, q1, group = group))

    expect_identical(names(result), c("level", "n", "n_eff"))
    expect_true(is.character(result$level), label = paste0(nm, ": level type"))
    expect_identical(
      sort(result$level),
      sort(unique(as.character(freqs$group))),
      label = paste0(nm, ": levels match get_freqs()")
    )
    expect_identical(result$n, as.integer(ref$n), label = paste0(nm, ": n"))
    expect_equal(
      result$n_eff,
      ref$n_eff,
      tolerance = 1e-8,
      label = paste0(nm, ": n_eff")
    )
  }
})

test_that(".resolve_eff_n() returns label levels for a labelled banner", {
  skip_if_not_installed("surveycore")
  d <- add_labelled_banner(make_all_designs(seed = 42)$taylor)

  result <- surveyreports:::.resolve_eff_n(d, group_var = "gen")
  freqs <- suppressWarnings(surveycore::get_freqs(d, q1, group = gen))

  expect_identical(result$level, c("Male", "Female"))
  expect_identical(result$level, unique(as.character(freqs$gen)))
})

test_that(".resolve_eff_n() counts the in-domain rows on a restricted design", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$group == "A"

  result <- surveyreports:::.resolve_eff_n(d)

  expect_identical(result$n, sum(d@data$group == "A"))
  expect_lt(result$n_eff, result$n)
})

test_that(".resolve_eff_n() passes na.rm to get_effective_n()", {
  skip_if_not_installed("surveycore")
  d <- add_labelled_banner(make_all_designs(seed = 42)$taylor)

  kept <- surveyreports:::.resolve_eff_n(d, group_var = "gen", na.rm = FALSE)
  dropped <- surveyreports:::.resolve_eff_n(d, group_var = "gen", na.rm = TRUE)
  ref <- surveycore::get_effective_n(d, group = gen, na.rm = FALSE)

  expect_identical(kept$level, as.character(ref$gen))
  expect_identical(kept$n, as.integer(ref$n))
  expect_true(anyNA(kept$level))
  expect_false(anyNA(dropped$level))
})

test_that(".resolve_eff_n() returns one row per member of a survey_collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = designs$taylor,
    w2 = designs$twophase
  )

  result <- surveyreports:::.resolve_eff_n(coll)
  ref <- surveycore::get_effective_n(coll)

  expect_identical(names(result), c("level", "n", "n_eff"))
  expect_identical(result$level, c("w1", "w2"))
  expect_identical(result$n, as.integer(ref$n))
  expect_equal(result$n_eff, ref$n_eff, tolerance = 1e-8)
})

test_that(".resolve_eff_n() muffles surveycore's small-cell warning", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$tiny <- c(rep("x", 3L), rep("y", nrow(d@data) - 3L))

  expect_no_warning(
    result <- surveyreports:::.resolve_eff_n(d, group_var = "tiny")
  )
  expect_identical(result$level, c("x", "y"))
})

test_that(".banner_levels_labelled() keeps a factor and its level order", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    n <- nrow(d@data)
    d@data$lik <- factor(
      rep(c("Low", "High", NA, "Medium"), length.out = n),
      levels = c("Low", "Medium", "High")
    )

    result <- surveyreports:::.banner_levels_labelled(d, "lik")

    expect_true(is.factor(result), label = paste0(nm, ": factor"))
    expect_identical(length(result), n, label = paste0(nm, ": length"))
    expect_identical(
      levels(result),
      c("Low", "Medium", "High"),
      label = paste0(nm, ": level order")
    )
    expect_identical(
      is.na(result),
      is.na(d@data$lik),
      label = paste0(nm, ": NA kept")
    )
  }
})

test_that(".banner_levels_labelled() translates codes to value labels", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_labelled_banner(designs[[nm]])
    codes <- as.vector(d@data$gen)

    result <- surveyreports:::.banner_levels_labelled(d, "gen")

    expect_true(is.factor(result), label = paste0(nm, ": factor"))
    expect_identical(
      levels(result),
      c("Male", "Female"),
      label = paste0(nm, ": levels in code order")
    )
    expect_identical(length(result), nrow(d@data), label = paste0(nm, ": len"))
    expect_identical(
      as.character(result[!is.na(codes) & codes == 1]),
      rep("Male", sum(codes == 1, na.rm = TRUE)),
      label = paste0(nm, ": code 1")
    )
    expect_identical(
      as.character(result[!is.na(codes) & codes == 2]),
      rep("Female", sum(codes == 2, na.rm = TRUE)),
      label = paste0(nm, ": code 2")
    )
    expect_identical(is.na(result), is.na(codes), label = paste0(nm, ": NA"))
  }
})

test_that(".banner_levels_labelled() orders the levels by code, not by label or row", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    # The first row holds code 3, and the labels are given out of code order,
    # so neither the row order nor the label order is the code order.
    d@data$pid3 <- rep(c(3, 2, 1), length.out = nrow(d@data))
    d <- surveycore::set_val_labels(
      d,
      pid3 = c(Republican = 2, Independent = 3, Democrat = 1)
    )

    result <- surveyreports:::.banner_levels_labelled(d, "pid3")

    expect_true(is.factor(result), label = paste0(nm, ": factor"))
    expect_identical(
      levels(result),
      c("Democrat", "Republican", "Independent"),
      label = paste0(nm, ": code order")
    )
    expect_identical(
      as.character(result),
      c("Democrat", "Republican", "Independent")[d@data$pid3],
      label = paste0(nm, ": per-row values")
    )
  }
})

test_that(".banner_levels_labelled() keeps a duplicate label once, at its lowest code", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    d@data$gen <- rep(c(3, 1, 2), length.out = nrow(d@data))
    d <- surveycore::set_val_labels(
      d,
      gen = c(Male = 1, Female = 2, Female = 3)
    )

    result <- surveyreports:::.banner_levels_labelled(d, "gen")

    expect_identical(
      levels(result),
      c("Male", "Female"),
      label = paste0(nm, ": one Female level")
    )
    expect_identical(
      as.character(result),
      c("Male", "Female", "Female")[d@data$gen],
      label = paste0(nm, ": codes 2 and 3 read Female")
    )
  }
})

test_that(".banner_levels_labelled() keeps a label with no row as an unused level", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    d@data$gen <- c(rep(1, 180), rep(2, 20))
    d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2, Other = 3))

    result <- surveyreports:::.banner_levels_labelled(d, "gen")

    expect_identical(
      levels(result),
      c("Male", "Female", "Other"),
      label = paste0(nm, ": levels")
    )
    expect_identical(
      sum(result == "Other", na.rm = TRUE),
      0L,
      label = paste0(nm, ": Other holds no row")
    )
  }
})

test_that(".banner_levels_labelled() returns a plain column as character", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- designs[[nm]]
    d@data$group[1:5] <- NA_character_
    d@data$code <- rep(c(1L, 2L, NA_integer_), length.out = nrow(d@data))

    grp <- surveyreports:::.banner_levels_labelled(d, "group")
    code <- surveyreports:::.banner_levels_labelled(d, "code")

    expect_identical(grp, d@data$group, label = paste0(nm, ": group"))
    expect_identical(
      code,
      as.character(d@data$code),
      label = paste0(nm, ": unlabelled integer")
    )
  }
})

test_that(".banner_levels_labelled() maps an unlabelled code to NA, as get_freqs() does", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$gen <- rep(c(1, 2, 3), length.out = nrow(d@data))
  d <- suppressWarnings(
    surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))
  )

  result <- surveyreports:::.banner_levels_labelled(d, "gen")
  ref <- suppressWarnings(surveycore::get_effective_n(d, group = gen))

  expect_true(all(is.na(result[as.vector(d@data$gen) == 3])))
  expect_setequal(as.character(unique(result)), as.character(ref$gen))
})

test_that(".banner_heading() returns the variable label when one is set", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- surveycore::set_var_label(designs[[nm]], group = "Region")

    expect_no_warning(
      result <- surveyreports:::.banner_heading(d, "group")
    )
    expect_identical(
      result,
      list(heading = "Region", fell_back = FALSE),
      label = paste0(nm, ": label")
    )
  }
})

test_that(".banner_heading() falls back to the column name with no label", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    expect_no_warning(
      result <- surveyreports:::.banner_heading(designs[[nm]], "group")
    )
    expect_identical(
      result,
      list(heading = "group", fell_back = TRUE),
      label = paste0(nm, ": fallback")
    )
  }
})

test_that(".banner_heading() falls back when the label is an empty string", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$group <- structure(d@data$group, label = "")

  result <- surveyreports:::.banner_heading(d, "group")

  expect_identical(result, list(heading = "group", fell_back = TRUE))
})

# 20. Metadata resolvers: unwired helpers -------------------------------------
# .resolve_roles() and .resolve_base_notes() have no caller yet. Later PRs
# wire them into export_crosstab() and export_topline(). Until then they are
# tested directly. c(result) drops the "malformed" attribute of
# .resolve_roles(), which section 21 tests.

# Sets one role payload of each shape that surveycore accepts unchanged.
add_role_payloads <- function(d) {
  surveycore::set_var_extra(
    d,
    q1 = list(role = "item"),
    q2 = list(role = c("item", "demographic")),
    y1 = list(role = 3L),
    y2 = list(role = character(0)),
    y3 = list(other = "x"),
    group = list(role = "banana")
  )
}

test_that(".resolve_roles() returns a length-1 character role, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    result <- surveyreports:::.resolve_roles(d, "q1")
    expect_identical(c(result), c(q1 = "item"), label = nm)
  }
})

test_that(".resolve_roles() returns an unrecognized role string as-is, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    result <- surveyreports:::.resolve_roles(d, "group")
    expect_identical(c(result), c(group = "banana"), label = nm)
  }
})

test_that(".resolve_roles() returns NA for an absent role key, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    # y3 has a var_extra entry without a role; bat_1 has no entry at all.
    result <- surveyreports:::.resolve_roles(d, c("y3", "bat_1"))
    expect_identical(
      c(result),
      c(y3 = NA_character_, bat_1 = NA_character_),
      label = nm
    )
  }
})

test_that(".resolve_roles() returns NA for a length-0 role, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_no_error(result <- surveyreports:::.resolve_roles(d, "y2"))
    expect_identical(c(result), c(y2 = NA_character_), label = nm)
  }
})

test_that(".resolve_roles() returns NA for a length-2 role, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_no_error(result <- surveyreports:::.resolve_roles(d, "q2"))
    expect_identical(c(result), c(q2 = NA_character_), label = nm)
  }
})

test_that(".resolve_roles() returns NA for a non-character role, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_no_error(result <- surveyreports:::.resolve_roles(d, "y1"))
    expect_identical(c(result), c(y1 = NA_character_), label = nm)
  }
})

test_that(".resolve_roles() names and orders its result by cols, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  cols <- c("group", "y3", "y2", "y1", "q2", "q1")

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    result <- surveyreports:::.resolve_roles(d, cols)
    expect_identical(
      c(result),
      c(
        group = "banana",
        y3 = NA_character_,
        y2 = NA_character_,
        y1 = NA_character_,
        q2 = NA_character_,
        q1 = "item"
      ),
      label = nm
    )
  }
})

test_that(".resolve_roles() raises no warning on a foreign payload", {
  skip_if_not_installed("surveycore")
  d <- add_role_payloads(make_all_designs(seed = 42)$taylor)

  expect_no_warning(
    surveyreports:::.resolve_roles(d, c("q1", "q2", "y1", "y2", "group"))
  )
})

test_that(".resolve_roles() returns an empty named vector for no cols", {
  skip_if_not_installed("surveycore")
  d <- add_role_payloads(make_all_designs(seed = 42)$taylor)

  result <- surveyreports:::.resolve_roles(d, character(0))

  # c() drops an empty names attribute, so this one compares in full.
  expect_identical(
    result,
    structure(character(0), names = character(0), malformed = character(0))
  )
})

test_that(".resolve_roles() resolves a role that agrees across a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(designs$taylor, q1 = list(role = "item")),
    w2 = surveycore::set_var_extra(designs$replicate, q1 = list(role = "item"))
  )

  expect_no_error(result <- surveyreports:::.resolve_roles(coll, "q1"))
  expect_identical(c(result), c(q1 = "item"))
})

test_that(".resolve_roles() returns NA for a role that disagrees across a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(designs$taylor, q1 = list(role = "item")),
    w2 = surveycore::set_var_extra(
      designs$nonprob,
      q1 = list(role = "free_text")
    )
  )

  expect_no_error(result <- surveyreports:::.resolve_roles(coll, "q1"))
  expect_identical(c(result), c(q1 = NA_character_))
})

test_that(".resolve_roles() returns NA for a role missing in one member", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(
      designs$taylor,
      q1 = list(role = "item"),
      q2 = list(role = "demographic")
    ),
    w2 = surveycore::set_var_extra(designs$twophase, q2 = list(role = 3L))
  )

  expect_no_error(
    result <- surveyreports:::.resolve_roles(coll, c("q2", "q1"))
  )
  expect_identical(c(result), c(q2 = NA_character_, q1 = NA_character_))
})

test_that(".resolve_base_notes() returns the caller and the universe separately, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  caller <- c(q1 = "Asked of all U.S. adults.")

  for (nm in names(designs)) {
    d <- surveycore::set_universe(
      designs[[nm]],
      q1 = "Adults",
      q2 = "Voters"
    )
    result <- surveyreports:::.resolve_base_notes(d, caller)
    expect_identical(
      result,
      list(caller = caller, universe = c(q1 = "Adults", q2 = "Voters")),
      label = nm
    )
  }
})

test_that(".resolve_base_notes() returns an empty named universe with only a caller vector, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  caller <- c(q2 = "Asked of voters.")

  for (nm in names(designs)) {
    result <- surveyreports:::.resolve_base_notes(designs[[nm]], caller)
    expect_identical(
      result,
      list(
        caller = caller,
        universe = structure(character(0), names = character(0))
      ),
      label = nm
    )
  }
})

test_that(".resolve_base_notes() returns a NULL caller with only a universe, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- surveycore::set_universe(designs[[nm]], q2 = "Voters")
    result <- surveyreports:::.resolve_base_notes(d, NULL)
    expect_identical(
      result,
      list(caller = NULL, universe = c(q2 = "Voters")),
      label = nm
    )
  }
})

test_that(".resolve_base_notes() returns NULL when both sources are empty, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    result <- surveyreports:::.resolve_base_notes(designs[[nm]], NULL)
    expect_identical(result, NULL, label = nm)
  }
})

test_that(".resolve_base_notes() treats a zero-length caller vector as empty", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor

  expect_identical(
    surveyreports:::.resolve_base_notes(d, character(0)),
    NULL
  )
  expect_identical(
    surveyreports:::.resolve_base_notes(
      surveycore::set_universe(d, q1 = "Adults"),
      character(0)
    ),
    list(caller = NULL, universe = c(q1 = "Adults"))
  )
})

test_that(".resolve_base_notes() omits an empty or NA universe entry", {
  skip_if_not_installed("surveycore")
  d <- surveycore::set_universe(
    make_all_designs(seed = 42)$taylor,
    q1 = "",
    q2 = NA_character_,
    group = "Adults"
  )

  expect_identical(
    surveyreports:::.resolve_base_notes(d, NULL),
    list(caller = NULL, universe = c(group = "Adults"))
  )
})

test_that(".resolve_base_notes() keeps a universe that agrees across a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_universe(designs$taylor, q1 = "Adults"),
    w2 = surveycore::set_universe(designs$replicate, q1 = "Adults")
  )

  expect_no_error(result <- surveyreports:::.resolve_base_notes(coll, NULL))
  expect_identical(result, list(caller = NULL, universe = c(q1 = "Adults")))
})

test_that(".resolve_base_notes() omits a universe that disagrees across a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_universe(designs$taylor, q1 = "Adults", q2 = "Voters"),
    w2 = surveycore::set_universe(
      designs$nonprob,
      q1 = "Adults",
      q2 = "Parents"
    )
  )

  expect_no_error(result <- surveyreports:::.resolve_base_notes(coll, NULL))
  expect_identical(result, list(caller = NULL, universe = c(q1 = "Adults")))
})

test_that(".resolve_base_notes() omits a universe missing in one member", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_universe(designs$taylor, q1 = "Adults", q2 = "Voters"),
    w2 = surveycore::set_universe(designs$twophase, q2 = "Voters")
  )

  expect_no_error(result <- surveyreports:::.resolve_base_notes(coll, NULL))
  expect_identical(result, list(caller = NULL, universe = c(q2 = "Voters")))
})

test_that(".resolve_base_notes() passes the caller vector through on a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  caller <- c(q2 = "Asked of voters.")
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_universe(designs$taylor, q2 = "Voters"),
    w2 = surveycore::set_universe(designs$replicate, q2 = "Parents")
  )

  expect_no_error(result <- surveyreports:::.resolve_base_notes(coll, caller))
  expect_identical(
    result,
    list(
      caller = caller,
      universe = structure(character(0), names = character(0))
    )
  )
})

test_that(".resolve_base_notes() returns NULL on a collection with no agreeing universe and no caller", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_universe(designs$taylor, q1 = "Adults"),
    w2 = surveycore::set_universe(designs$replicate, q1 = "Parents")
  )

  expect_no_error(result <- surveyreports:::.resolve_base_notes(coll, NULL))
  expect_identical(result, NULL)
})

# 21. Selection guards: unwired helpers ---------------------------------------
# .apply_role_guard() and .reject_design_vars() have no caller yet. Later PRs
# wire them into export_crosstab() and export_topline(). Until then they are
# tested directly, with the malformed attribute of .resolve_roles() that the
# role guard reads.

# Calls the role guard on vars with the vars empty class.
guard_vars <- function(d, cols) {
  surveyreports:::.apply_role_guard(
    d,
    cols,
    "vars",
    "surveyreports_error_vars_all_dropped"
  )
}

test_that(".resolve_roles() lists length-2 and non-character payloads as malformed, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    result <- surveyreports:::.resolve_roles(d, c("y1", "q1", "q2", "group"))
    expect_identical(attr(result, "malformed"), c("y1", "q2"), label = nm)
  }
})

test_that(".resolve_roles() does not list an absent key or a length-0 payload as malformed, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    # y2 has a length-0 role, y3 has no role key, bat_1 has no entry at all.
    result <- surveyreports:::.resolve_roles(d, c("y2", "y3", "bat_1"))
    expect_identical(attr(result, "malformed"), character(0), label = nm)
  }
})

test_that(".resolve_roles() sets an empty malformed attribute on a design with no var_extra, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    result <- surveyreports:::.resolve_roles(designs[[nm]], c("q1", "q2"))
    expect_identical(attr(result, "malformed"), character(0), label = nm)
  }
})

test_that(".resolve_roles() lists a column malformed in one collection member", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(
      designs$taylor,
      q1 = list(role = "item"),
      q2 = list(role = "item")
    ),
    w2 = surveycore::set_var_extra(
      designs$replicate,
      q1 = list(role = "item"),
      q2 = list(role = c("item", "demographic"))
    )
  )

  expect_no_error(result <- surveyreports:::.resolve_roles(coll, c("q1", "q2")))
  expect_identical(c(result), c(q1 = "item", q2 = NA_character_))
  expect_identical(attr(result, "malformed"), "q2")
})

test_that(".apply_role_guard() drops each non-substantive role with a warning, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (role in c("weight", "identifier", "paradata", "free_text")) {
    for (nm in names(designs)) {
      d <- surveycore::set_var_extra(designs[[nm]], q2 = list(role = role))
      expect_warning(
        result <- guard_vars(d, c("q1", "q2")),
        class = "surveyreports_warning_role_dropped"
      )
      expect_identical(result, "q1", label = paste0(nm, ": ", role))
    }
  }
})

test_that(".apply_role_guard() keeps the substantive roles with no warning, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- surveycore::set_var_extra(
      designs[[nm]],
      q1 = list(role = "item"),
      q2 = list(role = "demographic"),
      group = list(role = "treatment")
    )
    expect_no_warning(result <- guard_vars(d, c("q1", "q2", "group")))
    expect_identical(result, c("q1", "q2", "group"), label = nm)
  }
})

test_that(".apply_role_guard() keeps an unrecognized role string with a warning, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_warning(
      result <- guard_vars(d, c("q1", "group")),
      class = "surveyreports_warning_unknown_role"
    )
    expect_identical(result, c("q1", "group"), label = nm)
  }
})

test_that(".apply_role_guard() keeps a length-2 role with a warning, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_warning(
      result <- guard_vars(d, c("q1", "q2")),
      class = "surveyreports_warning_unknown_role"
    )
    expect_identical(result, c("q1", "q2"), label = nm)
  }
})

test_that(".apply_role_guard() keeps a non-character role with a warning, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_warning(
      result <- guard_vars(d, c("y1", "q1")),
      class = "surveyreports_warning_unknown_role"
    )
    expect_identical(result, c("y1", "q1"), label = nm)
  }
})

test_that(".apply_role_guard() keeps an absent or length-0 role with no warning, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- add_role_payloads(designs[[nm]])
    expect_no_warning(result <- guard_vars(d, c("y2", "y3", "bat_1")))
    expect_identical(result, c("y2", "y3", "bat_1"), label = nm)
  }
})

test_that(".apply_role_guard() returns the survivors in input order, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- surveycore::set_var_extra(
      designs[[nm]],
      bat_1 = list(role = "paradata"),
      q1 = list(role = "item")
    )
    expect_warning(
      result <- guard_vars(d, c("bat_1", "q2", "q1")),
      class = "surveyreports_warning_role_dropped"
    )
    expect_identical(result, c("q2", "q1"), label = nm)
  }
})

test_that(".apply_role_guard() aborts with the vars class when every column is dropped, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- surveycore::set_var_extra(
      designs[[nm]],
      q1 = list(role = "free_text"),
      q2 = list(role = "identifier")
    )
    expect_error(
      guard_vars(d, c("q1", "q2")),
      class = "surveyreports_error_vars_all_dropped",
      label = nm
    )
  }
})

test_that(".apply_role_guard() aborts with the banner class when every column is dropped, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d <- surveycore::set_var_extra(designs[[nm]], group = list(role = "weight"))
    expect_error(
      surveyreports:::.apply_role_guard(
        d,
        "group",
        "banner",
        "surveyreports_error_banner_empty_selection"
      ),
      class = "surveyreports_error_banner_empty_selection",
      label = nm
    )
  }
})

test_that(".apply_role_guard() raises one drop warning that lists every dropped column", {
  skip_if_not_installed("surveycore")
  d <- surveycore::set_var_extra(
    make_all_designs(seed = 42)$taylor,
    q1 = list(role = "free_text"),
    q2 = list(role = "paradata")
  )

  msgs <- testthat::capture_warnings(
    result <- guard_vars(d, c("q1", "q2", "group"))
  )

  expect_length(msgs, 1L)
  expect_match(msgs, "q1 (free_text)", fixed = TRUE)
  expect_match(msgs, "q2 (paradata)", fixed = TRUE)
  expect_match(msgs, "vars", fixed = TRUE)
  expect_identical(result, "group")
})

test_that(".apply_role_guard() raises one unknown-role warning that lists every affected column", {
  skip_if_not_installed("surveycore")
  d <- add_role_payloads(make_all_designs(seed = 42)$taylor)

  msgs <- testthat::capture_warnings(
    result <- guard_vars(d, c("group", "q2", "y1", "q1"))
  )

  expect_length(msgs, 1L)
  expect_match(msgs, "group (banana)", fixed = TRUE)
  expect_match(msgs, "q2", fixed = TRUE)
  expect_match(msgs, "y1", fixed = TRUE)
  expect_identical(result, c("group", "q2", "y1", "q1"))
})

test_that(".apply_role_guard() raises the drop warning and the unknown-role warning in one call", {
  skip_if_not_installed("surveycore")
  d <- surveycore::set_var_extra(
    make_all_designs(seed = 42)$taylor,
    q1 = list(role = "free_text"),
    group = list(role = "banana")
  )

  expect_warning(
    expect_warning(
      result <- guard_vars(d, c("q1", "q2", "group")),
      class = "surveyreports_warning_unknown_role"
    ),
    class = "surveyreports_warning_role_dropped"
  )
  expect_identical(result, c("q2", "group"))
})

test_that(".apply_role_guard() drops a role that agrees across a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(
      designs$taylor,
      q2 = list(role = "paradata")
    ),
    w2 = surveycore::set_var_extra(
      designs$nonprob,
      q2 = list(role = "paradata")
    )
  )

  expect_warning(
    result <- guard_vars(coll, c("q1", "q2")),
    class = "surveyreports_warning_role_dropped"
  )
  expect_identical(result, "q1")
})

test_that(".apply_role_guard() keeps a role that disagrees across a collection with no warning", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(
      designs$taylor,
      q2 = list(role = "paradata")
    ),
    w2 = surveycore::set_var_extra(designs$replicate, q2 = list(role = "item"))
  )

  expect_no_warning(result <- guard_vars(coll, c("q1", "q2")))
  expect_identical(result, c("q1", "q2"))
})

test_that(".apply_role_guard() warns on a role malformed in one collection member", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = surveycore::set_var_extra(designs$taylor, q2 = list(role = "item")),
    w2 = surveycore::set_var_extra(designs$twophase, q2 = list(role = 3L))
  )

  expect_warning(
    result <- guard_vars(coll, c("q1", "q2")),
    class = "surveyreports_warning_unknown_role"
  )
  expect_identical(result, c("q1", "q2"))
})

test_that(".reject_design_vars() aborts on each Taylor design column", {
  skip_if_not_installed("surveycore")
  # The fixture's Taylor design sets no FPC, so this design adds one.
  d <- surveycore::as_survey(
    make_survey_data(seed = 42),
    ids = psu,
    strata = strata,
    weights = wt,
    fpc = fpc,
    nest = TRUE
  )

  for (col in c("wt", "psu", "strata", "fpc")) {
    expect_error(
      surveyreports:::.reject_design_vars(d, c("q1", col), "vars"),
      class = "surveyreports_error_design_variable_selected",
      label = col
    )
  }
})

test_that(".reject_design_vars() aborts on the weight and every replicate weight", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$replicate

  for (col in c("wt", paste0("rwt", 1:10))) {
    expect_error(
      surveyreports:::.reject_design_vars(d, col, "banner"),
      class = "surveyreports_error_design_variable_selected",
      label = col
    )
  }
})

test_that(".reject_design_vars() aborts on the twophase subset and phase-1 columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$twophase

  for (col in c("in_phase2", "psu", "wt", "strata")) {
    expect_error(
      surveyreports:::.reject_design_vars(d, col, "vars"),
      class = "surveyreports_error_design_variable_selected",
      label = col
    )
  }
})

test_that(".reject_design_vars() aborts on each twophase phase-2 column", {
  skip_if_not_installed("surveycore")
  # The fixture's twophase design uses method = "approx" and sets no phase-2
  # column, so this design sets all four.
  df <- make_survey_data(seed = 42)
  df$id2 <- seq_len(nrow(df))
  df$st2 <- rep(1:2, length.out = nrow(df))
  df$pr2 <- 0.5
  df$fpc2 <- 1000L
  phase1 <- surveycore::as_survey(
    df,
    ids = psu,
    strata = strata,
    weights = wt,
    fpc = fpc,
    nest = TRUE
  )
  d <- surveycore::as_survey_twophase(
    phase1,
    ids2 = id2,
    strata2 = st2,
    probs2 = pr2,
    fpc2 = fpc2,
    subset = in_phase2,
    method = "full"
  )

  for (col in c("id2", "st2", "pr2", "fpc2")) {
    expect_error(
      surveyreports:::.reject_design_vars(d, col, "vars"),
      class = "surveyreports_error_design_variable_selected",
      label = col
    )
  }
})

test_that(".reject_design_vars() aborts on the nonprob weight", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$nonprob

  expect_error(
    surveyreports:::.reject_design_vars(d, c("q1", "wt"), "vars"),
    class = "surveyreports_error_design_variable_selected"
  )
})

test_that(".reject_design_vars() aborts on each nonprob replicate weight", {
  skip_if_not_installed("surveycore")
  # The fixture's nonprob design sets no replicate weights, so this design
  # adds them.
  df <- make_all_designs(seed = 42)$replicate@data
  d <- surveycore::as_survey_nonprob(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("rwt"),
    type = "bootstrap"
  )

  for (col in paste0("rwt", 1:10)) {
    expect_error(
      surveyreports:::.reject_design_vars(d, col, "vars"),
      class = "surveyreports_error_design_variable_selected",
      label = col
    )
  }
})

test_that(".reject_design_vars() returns TRUE invisibly for a clean selection, on every design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    result <- withVisible(
      surveyreports:::.reject_design_vars(
        designs[[nm]],
        c("q1", "q2", "group", "bat_1"),
        "vars"
      )
    )
    expect_false(result$visible, label = nm)
    expect_identical(result$value, TRUE, label = nm)
  }
})

test_that(".reject_design_vars() never matches a slot that holds no column name", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  # The value of type, fpctype and method, and the text of nest and scale.
  cols <- c("JK1", "fraction", "approx", "TRUE", "0.9")

  for (nm in names(designs)) {
    expect_identical(
      surveyreports:::.reject_design_vars(designs[[nm]], cols, "vars"),
      TRUE,
      label = nm
    )
  }
})

test_that(".reject_design_vars() names the column, the argument and the slot", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$replicate

  expect_error(
    surveyreports:::.reject_design_vars(d, c("q1", "rwt3"), "banner"),
    regexp = "(?s)rwt3.*banner.*repweights",
    perl = TRUE,
    class = "surveyreports_error_design_variable_selected"
  )
})

test_that(".reject_design_vars() checks every member of a collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    w1 = designs$taylor,
    w2 = designs$replicate
  )

  expect_error(
    surveyreports:::.reject_design_vars(coll, "psu", "vars"),
    class = "surveyreports_error_design_variable_selected"
  )
  expect_error(
    surveyreports:::.reject_design_vars(coll, "rwt1", "vars"),
    regexp = "w2",
    class = "surveyreports_error_design_variable_selected"
  )
  expect_identical(
    surveyreports:::.reject_design_vars(coll, c("q1", "group"), "vars"),
    TRUE
  )
})

# 22. Format and write helpers: unwired ---------------------------------------
# None of these six helpers takes a design, so the cross-design loop does not
# apply. They have no caller yet. Later PRs wire them into export_crosstab().
# Until then they are tested directly.

# .fmt_pct() ------------------------------------------------------------------

test_that(".fmt_pct() writes a dash when the cell has no rows", {
  expect_identical(surveyreports:::.fmt_pct(0.356, 1L, FALSE), "-")
  expect_identical(surveyreports:::.fmt_pct(NA_real_, 1L, FALSE), "-")
})

test_that(".fmt_pct() writes a dash for an NA estimate in a cell with rows", {
  expect_identical(surveyreports:::.fmt_pct(NA_real_, 1L, TRUE), "-")
})

test_that(".fmt_pct() writes 0% for an estimate of exactly zero", {
  expect_identical(surveyreports:::.fmt_pct(0, 1L, TRUE), "0%")
  expect_identical(surveyreports:::.fmt_pct(0, 2L, TRUE), "0%")
})

test_that(".fmt_pct() writes the floor string for a nonzero value that rounds to zero", {
  expect_identical(surveyreports:::.fmt_pct(0.0004, 1L, TRUE), "<0.1%")
  expect_identical(surveyreports:::.fmt_pct(1e-9, 1L, TRUE), "<0.1%")
})

test_that(".fmt_pct() writes the ceiling string for a value below 100 that rounds to 100", {
  expect_identical(surveyreports:::.fmt_pct(0.9997, 1L, TRUE), ">99.9%")
  expect_identical(surveyreports:::.fmt_pct(1 - 1e-9, 1L, TRUE), ">99.9%")
})

test_that(".fmt_pct() multiplies a proportion by 100 and rounds it", {
  expect_identical(surveyreports:::.fmt_pct(0.356, 1L, TRUE), "35.6%")
  expect_identical(surveyreports:::.fmt_pct(0.356, 0L, TRUE), "36%")
  expect_identical(surveyreports:::.fmt_pct(0.35612, 2L, TRUE), "35.61%")
  expect_identical(surveyreports:::.fmt_pct(1, 1L, TRUE), "100%")
})

test_that(".fmt_pct() drops a decimal part that rounds away", {
  expect_identical(surveyreports:::.fmt_pct(0.4101, 1L, TRUE), "41%")
  expect_identical(surveyreports:::.fmt_pct(0.3, 1L, TRUE), "30%")
})

test_that(".fmt_pct() rounds half to even", {
  expect_identical(surveyreports:::.fmt_pct(0.4125, 1L, TRUE), "41.2%")
})

test_that(".fmt_pct() floor string follows decimals at 0, 1 and 2", {
  expect_identical(surveyreports:::.fmt_pct(0.004, 0L, TRUE), "<1%")
  expect_identical(surveyreports:::.fmt_pct(0.0004, 1L, TRUE), "<0.1%")
  expect_identical(surveyreports:::.fmt_pct(0.00004, 2L, TRUE), "<0.01%")
  # The same value leaves the floor once the precision can show it.
  expect_identical(surveyreports:::.fmt_pct(0.0004, 2L, TRUE), "0.04%")
})

test_that(".fmt_pct() ceiling string follows decimals at 0, 1 and 2", {
  expect_identical(surveyreports:::.fmt_pct(0.996, 0L, TRUE), ">99%")
  expect_identical(surveyreports:::.fmt_pct(0.9996, 1L, TRUE), ">99.9%")
  expect_identical(surveyreports:::.fmt_pct(0.99996, 2L, TRUE), ">99.99%")
  # The same value leaves the ceiling once the precision can show it.
  expect_identical(surveyreports:::.fmt_pct(0.9996, 2L, TRUE), "99.96%")
})

test_that(".fmt_pct() prints a negative value with a hyphen-minus", {
  expect_identical(surveyreports:::.fmt_pct(-0.00343, 1L, TRUE), "-0.3%")
})

test_that(".fmt_pct() prints a negative value that rounds to zero as 0%", {
  expect_identical(surveyreports:::.fmt_pct(-0.0001, 1L, TRUE), "0%")
})

# .fmt_variance() -------------------------------------------------------------

test_that(".fmt_variance() writes the standard error in parentheses with one %", {
  rows <- tibble::tibble(pct = 0.356, se = 0.0290, n = 50L)

  result <- surveyreports:::.fmt_variance(rows, "se", 1L, TRUE)

  expect_identical(result, "(2.9%)")
})

test_that(".fmt_variance() writes the interval bounds with an en-dash separator", {
  rows <- tibble::tibble(
    pct = 0.356,
    ci_low = 0.3004,
    ci_high = 0.413,
    n = 50L
  )

  result <- surveyreports:::.fmt_variance(rows, "ci", 1L, TRUE)

  expect_identical(result, "(30% – 41.3%)")
  expect_identical(lengths(regmatches(result, gregexpr("%", result))), 2L)
})

test_that(".fmt_variance() prints a negative lower bound with a hyphen-minus", {
  rows <- tibble::tibble(
    pct = 0.0067,
    ci_low = -0.00343,
    ci_high = 0.0178,
    n = 300L
  )

  result <- surveyreports:::.fmt_variance(rows, "ci", 1L, TRUE)

  expect_identical(result, "(-0.3% – 1.8%)")
  expect_identical(substr(result, 2L, 2L), "-")
})

test_that(".fmt_variance() inherits the floor string from .fmt_pct()", {
  rows <- tibble::tibble(pct = 0.001, se = 0.000004, n = 500L)

  expect_identical(
    surveyreports:::.fmt_variance(rows, "se", 1L, TRUE),
    "(<0.1%)"
  )
})

test_that(".fmt_variance() returns an empty string when variance is NULL", {
  rows <- tibble::tibble(pct = 0.356, se = 0.0290, n = 50L)

  expect_identical(surveyreports:::.fmt_variance(rows, NULL, 1L, TRUE), "")
})

test_that(".fmt_variance() returns an empty string when the cell has no rows", {
  rows <- tibble::tibble(
    pct = 0.356,
    se = 0.0290,
    ci_low = 0.3,
    ci_high = 0.413,
    n = 50L
  )

  expect_identical(surveyreports:::.fmt_variance(rows, "se", 1L, FALSE), "")
  expect_identical(surveyreports:::.fmt_variance(rows, "ci", 1L, FALSE), "")
})

# Gap 17: a 0% cell can have a column with rows and no row of its own. Its own
# rows are then absent or have n = 0, and it carries no variance (spec 3.12).
test_that(".fmt_variance() returns an empty string when the cell's own row is absent", {
  rows <- tibble::tibble(
    pct = double(0),
    se = double(0),
    ci_low = double(0),
    ci_high = double(0),
    n = integer(0)
  )

  expect_identical(surveyreports:::.fmt_variance(rows, "se", 1L, TRUE), "")
  expect_identical(surveyreports:::.fmt_variance(rows, "ci", 1L, TRUE), "")
})

test_that(".fmt_variance() returns an empty string when the cell's own row has n = 0", {
  rows <- tibble::tibble(
    pct = 0,
    se = 0,
    ci_low = 0,
    ci_high = 0,
    n = 0L
  )

  expect_identical(surveyreports:::.fmt_variance(rows, "se", 1L, TRUE), "")
  expect_identical(surveyreports:::.fmt_variance(rows, "ci", 1L, TRUE), "")
})

# .format_withheld_lines() ----------------------------------------------------

test_that(".format_withheld_lines() writes one line per withheld subgroup in frame order", {
  withheld <- tibble::tibble(
    level = c("Female", "Other"),
    banner_var = c("gen", "gen"),
    n_eff = c(18.347, 4)
  )

  result <- surveyreports:::.format_withheld_lines(withheld, 100)

  expect_identical(
    result,
    c(
      "\"Female\" (gen) withheld: effective sample size 18.3, below the minimum of 100.",
      "\"Other\" (gen) withheld: effective sample size 4.0, below the minimum of 100."
    )
  )
})

test_that(".format_withheld_lines() names the effective N and no raw N", {
  withheld <- tibble::tibble(
    level = "North:Female",
    banner_var = "..interaction_1..",
    n_eff = 46.8
  )

  result <- surveyreports:::.format_withheld_lines(withheld, 50)

  expect_match(result, "North:Female", fixed = TRUE)
  expect_match(result, "..interaction_1..", fixed = TRUE)
  expect_match(result, "46.8", fixed = TRUE)
  expect_no_match(result, "n=", fixed = TRUE)
  expect_no_match(result, "raw", fixed = TRUE)
})

test_that(".format_withheld_lines() returns character(0) for a zero-row frame and for NULL", {
  empty <- tibble::tibble(
    level = character(0),
    banner_var = character(0),
    n_eff = numeric(0)
  )

  expect_identical(
    surveyreports:::.format_withheld_lines(empty, 100),
    character(0)
  )
  expect_identical(
    surveyreports:::.format_withheld_lines(NULL, 100),
    character(0)
  )
})

# .build_withheld() -----------------------------------------------------------

test_that(".build_withheld() keeps one row per subgroup strictly below the floor", {
  counts <- tibble::tibble(
    level = c("Total", "Male", "Female", "Other"),
    n = c(200L, 120L, 70L, 10L),
    n_eff = c(185.4, 110.1, 64.2, 100)
  )

  result <- surveyreports:::.build_withheld(counts, 100, "gen")

  expect_identical(names(result), c("level", "banner_var", "n_eff"))
  expect_identical(result$level, "Female")
  expect_identical(result$banner_var, "gen")
  expect_equal(result$n_eff, 64.2)
})

test_that(".build_withheld() keeps the levels in the order they were resolved", {
  counts <- tibble::tibble(
    level = c("c", "a", "b"),
    n = c(10L, 20L, 30L),
    n_eff = c(9, 18, 27)
  )

  result <- surveyreports:::.build_withheld(counts, 100, "grp")

  expect_identical(result$level, c("c", "a", "b"))
  expect_identical(result$banner_var, c("grp", "grp", "grp"))
  expect_equal(result$n_eff, c(9, 18, 27))
})

test_that(".build_withheld() returns a typed zero-row tibble when nothing is below the floor", {
  counts <- tibble::tibble(
    level = c("Male", "Female"),
    n = c(120L, 110L),
    n_eff = c(110.1, 101.5)
  )

  result <- surveyreports:::.build_withheld(counts, 100, "gen")

  expect_s3_class(result, "tbl_df")
  expect_identical(nrow(result), 0L)
  expect_identical(names(result), c("level", "banner_var", "n_eff"))
  expect_identical(result$level, character(0))
  expect_identical(result$banner_var, character(0))
  expect_identical(result$n_eff, numeric(0))
})

test_that(".build_withheld() never returns NULL", {
  counts <- tibble::tibble(
    level = character(0),
    n = integer(0),
    n_eff = numeric(0)
  )

  result_empty <- surveyreports:::.build_withheld(counts, 100, "gen")
  result_off <- surveyreports:::.build_withheld(
    tibble::tibble(level = "Female", n = 5L, n_eff = 4.2),
    0,
    "gen"
  )

  expect_false(is.null(result_empty))
  expect_false(is.null(result_off))
  expect_identical(nrow(result_empty), 0L)
  expect_identical(nrow(result_off), 0L)
})

test_that(".build_withheld() converts a factor level to character", {
  counts <- tibble::tibble(
    level = factor(c("Male", "Female")),
    n = c(120L, 20L),
    n_eff = c(110.1, 18.3)
  )

  result <- surveyreports:::.build_withheld(counts, 100, "gen")

  expect_identical(result$level, "Female")
})

test_that(".build_withheld() does not withhold a level whose n_eff is NA", {
  counts <- tibble::tibble(
    level = c("Male", "Female"),
    n = c(120L, 20L),
    n_eff = c(NA_real_, 18.3)
  )

  result <- surveyreports:::.build_withheld(counts, 100, "gen")

  expect_identical(result$level, "Female")
})

# .write_sample_size_rows() ---------------------------------------------------

# A workbook with one empty sheet named "S".
ss_workbook <- function() {
  openxlsx2::wb_add_worksheet(openxlsx2::wb_workbook(), "S")
}

ss_counts <- function() {
  tibble::tibble(
    level = c("Total", "Male", "Female"),
    n = c(200L, 120L, 80L),
    n_eff = c(185.43, 110.06, 72.35)
  )
}

test_that(".write_sample_size_rows() writes two labelled rows and one cell per counts row", {
  res <- surveyreports:::.write_sample_size_rows(
    ss_workbook(),
    "S",
    start_row = 3L,
    label_cols = 1L,
    counts = ss_counts(),
    show_ess = TRUE
  )

  expect_identical(names(res), c("wb", "next_row"))
  expect_identical(res$next_row, 5L)

  df <- openxlsx2::wb_to_df(res$wb, sheet = "S", col_names = FALSE)
  expect_identical(rownames(df), c("3", "4"))
  expect_identical(
    df[[1L]],
    c("Unweighted sample size", "Effective sample size")
  )
  expect_identical(ncol(df), 4L)
  expect_equal(unname(unlist(df[1L, 2:4])), c(200, 120, 80))
  expect_equal(unname(unlist(df[2L, 2:4])), c(185.4, 110.1, 72.3))
})

test_that(".write_sample_size_rows() leaves a second label column blank", {
  res <- surveyreports:::.write_sample_size_rows(
    ss_workbook(),
    "S",
    start_row = 1L,
    label_cols = 2L,
    counts = ss_counts(),
    show_ess = TRUE
  )

  df <- openxlsx2::wb_to_df(res$wb, sheet = "S", col_names = FALSE)
  expect_identical(
    df[[1L]],
    c("Unweighted sample size", "Effective sample size")
  )
  expect_true(all(is.na(df[[2L]])))
  expect_identical(ncol(df), 5L)
  expect_equal(unname(unlist(df[1L, 3:5])), c(200, 120, 80))
  expect_equal(unname(unlist(df[2L, 3:5])), c(185.4, 110.1, 72.3))
})

test_that(".write_sample_size_rows() writes the cells in counts order", {
  counts <- ss_counts()[c(3L, 1L, 2L), ]

  res <- surveyreports:::.write_sample_size_rows(
    ss_workbook(),
    "S",
    start_row = 1L,
    label_cols = 1L,
    counts = counts,
    show_ess = TRUE
  )

  df <- openxlsx2::wb_to_df(res$wb, sheet = "S", col_names = FALSE)
  expect_equal(unname(unlist(df[1L, 2:4])), c(80, 200, 120))
})

test_that(".write_sample_size_rows() writes only the unweighted row when show_ess is FALSE", {
  res <- surveyreports:::.write_sample_size_rows(
    ss_workbook(),
    "S",
    start_row = 3L,
    label_cols = 1L,
    counts = ss_counts(),
    show_ess = FALSE
  )

  expect_identical(res$next_row, 4L)
  df <- openxlsx2::wb_to_df(res$wb, sheet = "S", col_names = FALSE)
  expect_identical(nrow(df), 1L)
  expect_identical(df[[1L]], "Unweighted sample size")
  expect_equal(unname(unlist(df[1L, 2:4])), c(200, 120, 80))
})

test_that(".write_sample_size_rows() writes the labels and no data cell for a zero-row counts frame", {
  counts <- ss_counts()[0L, ]

  res <- surveyreports:::.write_sample_size_rows(
    ss_workbook(),
    "S",
    start_row = 4L,
    label_cols = 2L,
    counts = counts,
    show_ess = TRUE
  )

  expect_identical(res$next_row, 6L)
  df <- openxlsx2::wb_to_df(res$wb, sheet = "S", col_names = FALSE)
  expect_identical(ncol(df), 1L)
  expect_identical(rownames(df), c("4", "5"))
  expect_identical(
    df[[1L]],
    c("Unweighted sample size", "Effective sample size")
  )
})

# .unique_sheet_name() --------------------------------------------------------

test_that(".unique_sheet_name() returns a free name unchanged", {
  wb <- openxlsx2::wb_add_worksheet(openxlsx2::wb_workbook(), "About")

  expect_identical(surveyreports:::.unique_sheet_name(wb, "q1"), "q1")
  expect_identical(
    surveyreports:::.unique_sheet_name(openxlsx2::wb_workbook(), "q1"),
    "q1"
  )
})

test_that(".unique_sheet_name() suffixes a taken name with _2, then _3", {
  wb <- openxlsx2::wb_add_worksheet(openxlsx2::wb_workbook(), "About")

  expect_identical(surveyreports:::.unique_sheet_name(wb, "About"), "About_2")

  wb <- openxlsx2::wb_add_worksheet(wb, "About_2")
  expect_identical(surveyreports:::.unique_sheet_name(wb, "About"), "About_3")
})

test_that(".unique_sheet_name() folds case when it compares names", {
  wb <- openxlsx2::wb_add_worksheet(openxlsx2::wb_workbook(), "About")

  expect_identical(surveyreports:::.unique_sheet_name(wb, "about"), "about_2")
  expect_identical(surveyreports:::.unique_sheet_name(wb, "ABOUT"), "ABOUT_2")
})

test_that(".unique_sheet_name() truncates a long free name to 31 characters", {
  name <- strrep("abcdefghij", 4L)

  result <- surveyreports:::.unique_sheet_name(openxlsx2::wb_workbook(), name)

  expect_identical(result, substr(name, 1L, 31L))
  expect_identical(nchar(result), 31L)
})

test_that(".unique_sheet_name() keeps a suffixed long name at 31 characters", {
  first <- paste0(strrep("x", 31L), "_alpha")
  second <- paste0(strrep("x", 31L), "_beta")
  wb <- openxlsx2::wb_workbook()
  wb <- openxlsx2::wb_add_worksheet(
    wb,
    surveyreports:::.unique_sheet_name(wb, first)
  )

  result <- surveyreports:::.unique_sheet_name(wb, second)

  expect_identical(result, paste0(strrep("x", 29L), "_2"))
  expect_identical(nchar(result), 31L)
  wb <- openxlsx2::wb_add_worksheet(wb, result)
  expect_identical(
    unname(openxlsx2::wb_get_sheet_names(wb)),
    c(strrep("x", 31L), result)
  )
})

# 23. Cover sheet ---------------------------------------------------------------
# Every workbook gains an "About" sheet as sheet 1 (spec 3.14). The sheet has
# a Key / Value header row, then the survey metadata block, the withheld block
# and the glossary block (spec 3.15).

# about_sheet(), about_glossary() and cover_design() are in helper-export.R.

test_that("export_crosstab() writes the About sheet as sheet 1 for all designs (XA-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

    wb <- openxlsx2::wb_load(out)
    expect_identical(
      unname(wb$get_sheet_names()),
      c("About", "q1"),
      label = paste0(nm, ": sheet order")
    )
  }
})

test_that("export_crosstab() writes the About sheet with no dataset metadata, glossary included (XA-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])
    expect_identical(
      nrow(surveycore::extract_dataset_metadata(d, format = "data_frame")),
      0L,
      label = paste0(nm, ": no metadata set")
    )

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

    about <- about_sheet(out)
    expect_identical(
      about$A,
      c(
        "Key",
        "What these numbers mean",
        "Unweighted sample size",
        "Effective sample size (ESS)"
      ),
      label = paste0(nm, ": About column A")
    )
    expect_identical(about$B[[1L]], "Value", label = paste0(nm, ": header B1"))
    expect_true(
      is.na(about$B[[2L]]),
      label = paste0(nm, ": heading has column B empty")
    )
    expect_true(
      all(nzchar(about$B[3:4])),
      label = paste0(nm, ": each term has its text")
    )
  }
})

# The display label of each dataset key, in surveycore's canonical key order.
cover_key_labels <- c(
  survey_name = "Survey",
  data_name = "Dataset",
  vendor = "Vendor",
  field_start = "Field start",
  field_end = "Field end",
  field_period = "Field period"
)

test_that("export_crosstab() writes every set key in canonical order (XA-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    # Set in an order that is not the canonical one, so a writer that keeps
    # the call order fails.
    d <- surveycore::set_dataset_metadata(
      cover_design(designs[[nm]]),
      field_period = "Spring 2024",
      vendor = "Test Vendor",
      field_end = "2024-03-31",
      data_name = "Test Data v2",
      field_start = "2024-03-01",
      survey_name = "Test Survey"
    )
    oracle <- surveycore::extract_dataset_metadata(d, format = "data_frame")

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

    about <- about_sheet(out)
    expect_identical(
      about$A[2:7],
      unname(cover_key_labels[oracle$key]),
      label = paste0(nm, ": labels in the oracle's key order")
    )
    expect_identical(
      about$A[2:7],
      c(
        "Survey",
        "Dataset",
        "Vendor",
        "Field start",
        "Field end",
        "Field period"
      ),
      label = paste0(nm, ": the six display labels")
    )
    expect_identical(
      about$B[2:7],
      oracle$value,
      label = paste0(nm, ": each value against its key")
    )
    expect_identical(
      about$B[2:7],
      c(
        "Test Survey",
        "Test Data v2",
        "Test Vendor",
        "2024-03-01",
        "2024-03-31",
        "Spring 2024"
      ),
      label = paste0(nm, ": the six values")
    )
    expect_true(
      is.na(about$A[[8L]]) && is.na(about$B[[8L]]),
      label = paste0(nm, ": one blank row after the block")
    )
  }
})

test_that("export_crosstab() writes no row for an unset key (XA-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_dataset_metadata(
      cover_design(designs[[nm]]),
      vendor = "Test Vendor",
      field_end = "2024-03-31"
    )
    expect_false(
      surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data),
      label = paste0(nm, ": no domain column")
    )

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

    about <- about_sheet(out)
    blank <- which(is.na(about$A) & is.na(about$B))[[1L]]
    survey_block <- about[2:(blank - 1L), ]
    expect_identical(
      nrow(survey_block),
      2L,
      label = paste0(nm, ": two rows")
    )
    expect_identical(
      survey_block$A,
      c("Vendor", "Field end"),
      label = paste0(nm, ": the two set keys")
    )
    expect_false(
      anyNA(survey_block$B),
      label = paste0(nm, ": no blank-valued row")
    )
    expect_identical(
      about$A[[blank + 1L]],
      "What these numbers mean",
      label = paste0(nm, ": the glossary follows")
    )
  }
})

test_that("export_crosstab() writes a file that opens on the About sheet (XA-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_dataset_metadata(
      cover_design(designs[[nm]]),
      survey_name = "Test Survey"
    )

    crosstab_quiet(
      d,
      vars = c(q1, q2),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    # Read the active sheet after a save and a reload. A workbook still in
    # memory has no active sheet set, so the check would pass vacuously.
    wb <- openxlsx2::wb_load(out)
    expect_identical(
      unname(wb$get_sheet_names()),
      c("About", "q1", "q2"),
      label = paste0(nm, ": data sheets follow")
    )
    expect_equal(
      wb$get_active_sheet(),
      1,
      label = paste0(nm, ": active sheet")
    )
  }
})

test_that("export_crosstab() writes the domain row only on a restricted design (XA-13)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- surveycore::set_dataset_metadata(
      cover_design(designs[[nm]]),
      survey_name = "Test Survey"
    )
    d_dom <- d
    d_dom@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d_dom@data$group == "A"
    oracle_n <- surveycore::get_effective_n(d_dom)$n

    if (file.exists(out)) {
      file.remove(out)
    }
    # q2 is the banner, because `group` holds one level inside the domain.
    crosstab_quiet(
      d_dom,
      vars = q1,
      banner = q2,
      file_name = out,
      min_eff_n = 0
    )
    about <- about_sheet(out)

    expect_identical(
      about$A[2:3],
      c("Survey", "Restricted to"),
      label = paste0(nm, ": domain row below the dataset keys")
    )
    expect_identical(
      about$B[[3L]],
      paste0(oracle_n, " of ", nrow(d_dom@data), " rows"),
      label = paste0(nm, ": in-domain count against the total")
    )
    expect_identical(
      about$B[[3L]],
      paste0(oracle_n, " of 200 rows"),
      label = paste0(nm, ": total is the design's 200 rows")
    )

    file.remove(out)
    crosstab_quiet(d, vars = q1, banner = q2, file_name = out, min_eff_n = 0)
    about <- about_sheet(out)

    expect_false(
      "Restricted to" %in% about$A,
      label = paste0(nm, ": no domain row without the domain column")
    )
    expect_identical(
      about$A[2:3],
      c("Survey", NA_character_),
      label = paste0(nm, ": the survey block ends after its key")
    )
  }
})

test_that("export_crosstab() suffixes a data sheet named About (XA-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])
    d@data$About <- d@data$q1
    d <- surveycore::set_var_label(d, About = "About question")
    expect_true("About" %in% names(d@data), label = paste0(nm, ": column"))

    crosstab_quiet(
      d,
      vars = About,
      banner = group,
      file_name = out,
      layout = "per_question",
      min_eff_n = 0
    )

    wb <- openxlsx2::wb_load(out)
    expect_identical(
      unname(wb$get_sheet_names()),
      c("About", "About_2"),
      label = paste0(nm, ": cover sheet, then the suffixed data sheet")
    )
    about <- about_sheet(out)
    expect_true(
      "What these numbers mean" %in% about$A,
      label = paste0(nm, ": cover sheet keeps its glossary")
    )
    expect_false(
      "About question" %in% about$A,
      label = paste0(nm, ": no question block on the cover sheet")
    )
    data_sheet <- openxlsx2::wb_to_df(
      out,
      sheet = "About_2",
      col_names = FALSE
    )
    expect_identical(
      as.character(data_sheet[[1L]][[1L]]),
      "About question",
      label = paste0(nm, ": the question block is on About_2")
    )
  }
})

test_that("export_crosstab() folds case when it checks a sheet name (XA-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])
    d@data$about <- d@data$q1
    d <- surveycore::set_var_label(d, about = "About question")

    result <- crosstab_quiet(
      d,
      vars = about,
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    expect_identical(result, out, label = paste0(nm, ": returns the path"))
    expect_true(file.exists(out), label = paste0(nm, ": the save succeeds"))
    wb <- openxlsx2::wb_load(out)
    expect_identical(
      unname(wb$get_sheet_names()),
      c("About", "about_2"),
      label = paste0(nm, ": the data sheet is suffixed")
    )
  }
})

test_that("export_crosstab() gives two variables sharing 31 characters two sheets (XA-11)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  long_a <- paste0(strrep("x", 31L), "_alpha")
  long_b <- paste0(strrep("x", 31L), "_beta")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])
    d@data[[long_a]] <- d@data$q1
    d@data[[long_b]] <- d@data$q2
    d <- surveycore::set_var_label(
      d,
      variable = c(long_a, long_b),
      label = c("Long one", "Long two")
    )

    crosstab_quiet(
      d,
      vars = tidyselect::all_of(c(long_a, long_b)),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    wb <- openxlsx2::wb_load(out)
    sheets <- unname(wb$get_sheet_names())
    expect_identical(
      sheets,
      c("About", strrep("x", 31L), paste0(strrep("x", 29L), "_2")),
      label = paste0(nm, ": both sheets exist")
    )
    expect_false(anyDuplicated(tolower(sheets)) > 0L, label = nm)
  }
})

test_that("export_crosstab() writes the About sheet with no merged cell and two stored widths", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_dataset_metadata(
      cover_design(designs[[nm]]),
      survey_name = "Test Survey"
    )

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

    wb <- openxlsx2::wb_load(out)
    ws <- wb$worksheets[[match("About", wb$get_sheet_names())]]
    expect_identical(
      length(ws$mergeCells),
      0L,
      label = paste0(nm, ": no merged cell")
    )
    widths <- as.numeric(
      sub('.*width="([0-9.]+)".*', "\\1", ws$cols_attr)
    )
    cols <- as.integer(sub('.*min="([0-9]+)".*', "\\1", ws$cols_attr))
    expect_identical(cols, 1:2, label = paste0(nm, ": Key and Value widths"))
    expect_identical(
      floor(widths),
      c(44, 12),
      label = paste0(nm, ": the widths of spec 3.16")
    )
  }
})

# The paths below have no caller among the export functions yet: no export
# function withholds, sets a floor or writes string cells. Later PRs wire
# them in. Until then .write_cover_sheet() is tested directly.

# An in-memory workbook with its cover sheet written from `...`.
cover_workbook <- function(design, ...) {
  args <- utils::modifyList(
    list(
      withheld = NULL,
      min_eff_n = NULL,
      has_banner = FALSE,
      string_cells = FALSE,
      decimals = 1L,
      variance = NULL
    ),
    list(...)
  )
  wb <- openxlsx2::wb_add_worksheet(openxlsx2::wb_workbook(), "About")
  surveyreports:::.write_cover_sheet(
    wb,
    design,
    args$withheld,
    args$min_eff_n,
    args$has_banner,
    args$string_cells,
    args$decimals,
    args$variance
  )
}

cover_withheld <- function() {
  tibble::tibble(
    level = c("Female", "Other"),
    banner_var = c("gen", "gen"),
    n_eff = c(18.347, 4)
  )
}

# The `Why a column is missing` entry at one floor. The entry states the
# minimum as a number, in the form format(scientific = FALSE, trim = TRUE)
# writes it (spec 3.15, gap 14).
glossary_missing_text <- function(min_eff_n) {
  paste(
    "A subgroup whose effective sample size falls below the minimum is not",
    "shown. The minimum for this workbook is an effective sample size of",
    paste0(format(min_eff_n, scientific = FALSE, trim = TRUE), "."),
    "The test is on the size of the subgroup itself, not on how many of its",
    "members answered any one question, so a question that many people",
    "skipped can still be shown for a subgroup that clears the minimum."
  )
}

# The dash sentence of the `Percentages` entry, word for word (spec 3.15,
# gap 17). It closes the entry at every `decimals` value.
glossary_dash_sentence <- paste(
  "A dash means nobody in that column answered the question, or it was",
  "never asked there."
)

glossary_text <- list(
  unweighted = paste(
    "The number of people who answered. It does not change when weights are",
    "applied. Report text writes this as N for the full sample and n for a",
    "subgroup."
  ),
  ess = paste(
    "The sample size left after weighting. Weights make some people count",
    "for more than others, and that costs precision, so this number is",
    "smaller than the unweighted sample size — the more the weights vary,",
    "the smaller it gets. It adjusts for the weights alone. It does not",
    "adjust for clustered sampling, so on a clustered survey the true",
    "precision is lower than this number suggests."
  ),
  missing = glossary_missing_text(100),
  pct = paste(
    "Each percentage is based on the people who answered that question,",
    "which can be fewer than the sample size shown above the table. A value",
    "that is not zero but rounds to zero at the shown precision reads <0.1%.",
    "A value below 100 that rounds to 100 reads >99.9%. A true zero reads",
    "0%.",
    glossary_dash_sentence
  ),
  ci = paste(
    "The interval is a normal approximation. For a very rare or a",
    "near-unanimous answer a bound can fall below 0 percent or rise above 100",
    "percent. That is a property of the approximation, not a count of people."
  )
)

test_that(".write_cover_sheet() writes the withheld block with the minimum and one line per subgroup", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  withheld <- cover_withheld()

  for (nm in names(designs)) {
    wb <- cover_workbook(
      designs[[nm]],
      withheld = withheld,
      min_eff_n = 100,
      has_banner = TRUE
    )

    about <- about_sheet(wb)
    expect_identical(
      about$A[1:5],
      c(
        "Key",
        "Subgroups not shown",
        "Minimum effective sample size",
        "Not shown",
        "Not shown"
      ),
      label = paste0(nm, ": block rows")
    )
    expect_identical(
      about$B[3:5],
      c("100", surveyreports:::.format_withheld_lines(withheld, 100)),
      label = paste0(nm, ": the minimum, then the lines")
    )
    expect_identical(
      about$A[6:7],
      c(NA_character_, "What these numbers mean"),
      label = paste0(nm, ": one blank row, then the glossary")
    )
  }
})

test_that(".write_cover_sheet() states None for a zero-row withheld frame", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    wb <- cover_workbook(
      designs[[nm]],
      withheld = cover_withheld()[0L, ],
      min_eff_n = 100,
      has_banner = TRUE
    )

    about <- about_sheet(wb)
    expect_identical(
      about$A[2:4],
      c("Subgroups not shown", "Minimum effective sample size", "Not shown"),
      label = paste0(nm, ": block rows")
    )
    expect_identical(
      about$B[3:4],
      c("100", "None"),
      label = paste0(nm, ": the minimum, then None")
    )
  }
})

test_that(".write_cover_sheet() writes no withheld block for NULL or a zero floor", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    null_frame <- about_sheet(cover_workbook(
      designs[[nm]],
      withheld = NULL,
      min_eff_n = 100,
      has_banner = TRUE
    ))
    zero_floor <- about_sheet(cover_workbook(
      designs[[nm]],
      withheld = cover_withheld()[0L, ],
      min_eff_n = 0,
      has_banner = TRUE
    ))

    expect_false(
      "Subgroups not shown" %in% null_frame$A,
      label = paste0(nm, ": NULL writes no block")
    )
    expect_false(
      "Subgroups not shown" %in% zero_floor$A,
      label = paste0(nm, ": a zero floor writes no block")
    )
    expect_identical(
      zero_floor$A[[2L]],
      "What these numbers mean",
      label = paste0(nm, ": the glossary is still written")
    )
  }
})

test_that(".write_cover_sheet() writes all five glossary terms when every condition holds", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    wb <- cover_workbook(
      designs[[nm]],
      min_eff_n = 100,
      has_banner = TRUE,
      string_cells = TRUE,
      variance = "ci"
    )

    glossary <- about_glossary(about_sheet(wb))
    expect_identical(
      glossary,
      c(
        "Unweighted sample size" = glossary_text$unweighted,
        "Effective sample size (ESS)" = glossary_text$ess,
        "Why a column is missing" = glossary_text$missing,
        "Percentages" = glossary_text$pct,
        "Confidence intervals" = glossary_text$ci
      ),
      label = paste0(nm, ": five terms with their text")
    )
  }
})

test_that(".write_cover_sheet() writes the missing-column entry only with a floor and a banner", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    no_banner <- about_glossary(about_sheet(cover_workbook(
      designs[[nm]],
      min_eff_n = 100,
      has_banner = FALSE
    )))
    no_floor <- about_glossary(about_sheet(cover_workbook(
      designs[[nm]],
      min_eff_n = 0,
      has_banner = TRUE
    )))

    expect_false(
      "Why a column is missing" %in% names(no_banner),
      label = paste0(nm, ": absent without a banner")
    )
    expect_false(
      "Why a column is missing" %in% names(no_floor),
      label = paste0(nm, ": absent at a zero floor")
    )
  }
})

test_that(".write_cover_sheet() adds no sixth term under variance = 'se'", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    glossary <- about_glossary(about_sheet(cover_workbook(
      designs[[nm]],
      min_eff_n = 100,
      has_banner = TRUE,
      string_cells = TRUE,
      variance = "se"
    )))

    expect_identical(
      names(glossary),
      c(
        "Unweighted sample size",
        "Effective sample size (ESS)",
        "Why a column is missing",
        "Percentages"
      ),
      label = paste0(nm, ": four terms, no entry for the standard error")
    )
  }
})

test_that(".fmt_pct_limits() returns the floor and ceiling strings at 0, 1 and 2", {
  expect_identical(
    surveyreports:::.fmt_pct_limits(0L),
    c(floor = "<1%", ceiling = ">99%")
  )
  expect_identical(
    surveyreports:::.fmt_pct_limits(1L),
    c(floor = "<0.1%", ceiling = ">99.9%")
  )
  expect_identical(
    surveyreports:::.fmt_pct_limits(2L),
    c(floor = "<0.01%", ceiling = ">99.99%")
  )
})

test_that(".write_cover_sheet() writes the Percentages limits at decimals = 0", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expected <- paste(
    "Each percentage is based on the people who answered that question,",
    "which can be fewer than the sample size shown above the table. A value",
    "that is not zero but rounds to zero at the shown precision reads <1%.",
    "A value below 100 that rounds to 100 reads >99%. A true zero reads",
    "0%.",
    glossary_dash_sentence
  )

  for (nm in names(designs)) {
    glossary <- about_glossary(about_sheet(cover_workbook(
      designs[[nm]],
      string_cells = TRUE,
      decimals = 0L
    )))

    expect_identical(
      glossary[["Percentages"]],
      expected,
      label = paste0(nm, ": <1% and >99%")
    )
  }
})

test_that(".write_cover_sheet() writes the Percentages limits at decimals = 2", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expected <- paste(
    "Each percentage is based on the people who answered that question,",
    "which can be fewer than the sample size shown above the table. A value",
    "that is not zero but rounds to zero at the shown precision reads",
    "<0.01%. A value below 100 that rounds to 100 reads >99.99%. A true",
    "zero reads 0%.",
    glossary_dash_sentence
  )

  for (nm in names(designs)) {
    glossary <- about_glossary(about_sheet(cover_workbook(
      designs[[nm]],
      string_cells = TRUE,
      decimals = 2L
    )))

    expect_identical(
      glossary[["Percentages"]],
      expected,
      label = paste0(nm, ": <0.01% and >99.99%")
    )
  }
})

test_that(".write_cover_sheet() keeps the Percentages text at decimals = 1", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    glossary <- about_glossary(about_sheet(cover_workbook(
      designs[[nm]],
      string_cells = TRUE,
      decimals = 1L
    )))

    expect_identical(
      glossary[["Percentages"]],
      glossary_text$pct,
      label = paste0(nm, ": <0.1% and >99.9%")
    )
  }
})

# No export function writes string cells yet, so the dash sentence is reached
# through a direct .write_cover_sheet() call with string_cells = TRUE.
test_that(".write_cover_sheet() ends the Percentages entry with the dash sentence of spec 3.15", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)

  for (nm in names(designs)) {
    for (dec in 0:2) {
      lbl <- paste0(nm, ", decimals = ", dec)
      pct <- about_glossary(about_sheet(cover_workbook(
        designs[[nm]],
        string_cells = TRUE,
        decimals = dec
      )))[["Percentages"]]

      expect_true(
        endsWith(
          pct,
          paste(
            "A true zero reads 0%. A dash means nobody in that column",
            "answered the question, or it was never asked there."
          )
        ),
        label = paste0(lbl, ": the dash sentence closes the entry")
      )
      expect_false(
        grepl("never offered", pct, fixed = TRUE),
        label = paste0(lbl, ": no `never offered`")
      )
      expect_false(
        grepl("not chosen", pct, fixed = TRUE),
        label = paste0(lbl, ": no `not chosen`")
      )
    }
  }
})

# 24. Base notes fall back to the universe -------------------------------------
# A variable with no caller note takes its universe text, verbatim. A caller
# note wins, and is exempt from the unanimity rule. A battery or SATA block
# prints the universe only when every member carries the same text
# (spec 3.6).

# A design whose q1, SATA, battery and banner columns carry variable labels,
# so the missing-label warning does not fire in a test about base notes.
note_design <- function(d) {
  surveycore::set_var_label(
    d,
    q1 = "Question one",
    group = "Group",
    sata_a = "Option A",
    sata_b = "Option B",
    sata_c = "Option C",
    bat_1 = "Item one",
    bat_2 = "Item two",
    bat_3 = "Item three"
  )
}

# Column A of one sheet, as a character vector indexed by sheet row.
sheet_col_a <- function(path, sheet) {
  df <- openxlsx2::wb_to_df(
    path,
    sheet = sheet,
    col_names = FALSE,
    cols = 1L,
    skip_empty_rows = FALSE
  )
  as.character(df[[1L]])
}

# Writes the battery block for one design and returns column A of its sheet.
battery_col_a <- function(d, out, base_notes = NULL) {
  if (file.exists(out)) {
    file.remove(out)
  }
  crosstab_quiet(
    d,
    vars = c(bat_1, bat_2, bat_3),
    banner = group,
    file_name = out,
    base_notes = base_notes,
    min_eff_n = 0
  )
  sheet_col_a(out, "bat_1")
}

test_that("export_crosstab() writes the universe as the base note, verbatim (XM-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  universe <- "Asked of all U.S. adults."

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_universe(note_design(designs[[nm]]), q1 = universe)

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)
    col_a <- sheet_col_a(out, "q1")

    expect_identical(col_a[[1L]], "Question one", label = paste0(nm, ": title"))
    expect_identical(col_a[[2L]], universe, label = paste0(nm, ": base note"))
    expect_identical(col_a[[4L]], "Response", label = paste0(nm, ": header"))
    # No "Base:" prefix is added anywhere (spec 3.6).
    expect_false(
      any(startsWith(col_a, "Base:"), na.rm = TRUE),
      label = paste0(nm, ": no Base: prefix")
    )
  }
})

test_that("export_crosstab() writes the caller's note over the universe (XM-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_universe(note_design(designs[[nm]]), q1 = "Adults")

    crosstab_quiet(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      base_notes = c(q1 = "Caller text"),
      min_eff_n = 0
    )
    col_a <- sheet_col_a(out, "q1")

    expect_identical(col_a[[2L]], "Caller text", label = paste0(nm, ": note"))
    expect_false(
      "Adults" %in% col_a,
      label = paste0(nm, ": the universe is not written")
    )
  }
})

test_that("export_crosstab() prints a battery universe its members agree on (XM-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  universe <- "Rated by all adults."

  for (nm in names(designs)) {
    d <- surveycore::set_universe(
      note_design(designs[[nm]]),
      bat_1 = universe,
      bat_2 = universe,
      bat_3 = universe
    )

    col_a <- battery_col_a(d, out)

    expect_identical(
      col_a[[1L]],
      "Please rate the following items:",
      label = paste0(nm, ": preface")
    )
    expect_identical(col_a[[2L]], universe, label = paste0(nm, ": base note"))
    expect_identical(
      sum(col_a == universe, na.rm = TRUE),
      1L,
      label = paste0(nm, ": one base-note row")
    )
    expect_identical(col_a[[4L]], "Item", label = paste0(nm, ": header"))
  }
})

test_that("export_crosstab() prints no battery universe its members disagree on (XM-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  universe <- "Rated by all adults."
  other <- "Rated by parents."

  for (nm in names(designs)) {
    d <- surveycore::set_universe(
      note_design(designs[[nm]]),
      bat_1 = universe,
      bat_2 = other,
      bat_3 = universe
    )

    col_a <- battery_col_a(d, out)

    expect_identical(
      sum(col_a %in% c(universe, other)),
      0L,
      label = paste0(nm, ": no base-note row")
    )
    expect_identical(col_a[[3L]], "Item", label = paste0(nm, ": header"))
  }
})

test_that("export_crosstab() prints no battery universe when one member is unset (XM-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  universe <- "Rated by all adults."

  for (nm in names(designs)) {
    d <- surveycore::set_universe(
      note_design(designs[[nm]]),
      bat_1 = universe,
      bat_3 = universe
    )

    col_a <- battery_col_a(d, out)

    expect_false(universe %in% col_a, label = paste0(nm, ": no base-note row"))
    expect_identical(col_a[[3L]], "Item", label = paste0(nm, ": header"))
  }
})

test_that("export_crosstab() prints a SATA universe its members agree on (XM-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  universe <- "Asked of all adults."

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_universe(
      note_design(designs[[nm]]),
      sata_a = universe,
      sata_b = universe,
      sata_c = universe
    )

    crosstab_quiet(
      d,
      vars = c(sata_a, sata_b, sata_c),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )
    col_a <- sheet_col_a(out, "sata_a")

    expect_identical(
      col_a[[1L]],
      "Which of the following apply to you?",
      label = paste0(nm, ": preface")
    )
    expect_identical(col_a[[2L]], universe, label = paste0(nm, ": base note"))
    expect_identical(
      sum(col_a == universe, na.rm = TRUE),
      1L,
      label = paste0(nm, ": one base-note row")
    )
    expect_identical(col_a[[4L]], "Item", label = paste0(nm, ": header"))
  }
})

test_that("export_crosstab() exempts a battery caller note from the unanimity rule", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    # The members disagree, so the universe alone would print nothing.
    d <- surveycore::set_universe(
      note_design(designs[[nm]]),
      bat_1 = "Rated by all adults.",
      bat_2 = "Rated by parents.",
      bat_3 = "Rated by all adults."
    )

    col_a <- battery_col_a(d, out, base_notes = c(bat_1 = "Caller text"))

    expect_identical(col_a[[2L]], "Caller text", label = paste0(nm, ": note"))
    expect_false(
      any(c("Rated by all adults.", "Rated by parents.") %in% col_a),
      label = paste0(nm, ": no universe")
    )
  }
})

# 25. Selection guards ---------------------------------------------------------
# export_crosstab() runs the design-variable check on `vars`, then on
# `banner`, then the role guard on both, then re-validates `interactions`
# against the surviving banner. All of it runs after both tidy-select
# resolutions and before classification (spec 3.10, spec 3.11).

# A design whose q1, q2, group, SATA and battery columns carry variable
# labels, so the missing-label warning does not fire in a guard test. A block
# is found by its title or its sheet.
guard_design <- function(d) {
  surveycore::set_var_label(
    note_design(d),
    q2 = "Question two"
  )
}

# The sheet names of a written workbook, without the "About" cover sheet.
data_sheets <- function(path) {
  setdiff(openxlsx2::wb_load(path)$sheet_names, "About")
}

# Adds two banner columns: the labelled `gen` of add_labelled_banner() and a
# character `reg`, labelled "Gender" and "Region".
add_gen_reg <- function(d) {
  d <- add_labelled_banner(d)
  d@data$reg <- rep(c("North", "South"), length.out = nrow(d@data))
  surveycore::set_var_label(d, gen = "Gender", reg = "Region")
}

# Every row of one sheet as a data frame, blank rows kept.
sheet_rows <- function(path, sheet) {
  openxlsx2::wb_to_df(
    path,
    sheet = sheet,
    col_names = FALSE,
    skip_empty_rows = FALSE
  )
}

# crosstab_quiet() is in helper-export.R. It muffles the surveycore nonprob
# SRS fallback warning and no other. The snapshots call export_crosstab()
# directly, on the taylor design, which raises no such warning.

test_that("export_crosstab() drops a free_text column from vars (XM-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q2 = list(role = "free_text")
    )

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )

    expect_identical(data_sheets(out), "q1", label = paste0(nm, ": sheets"))
    expect_identical(
      sheet_col_a(out, "q1")[[1L]],
      "Question one",
      label = paste0(nm, ": q1 block")
    )
  }
})

test_that("export_crosstab() drops a vars column for each non-substantive role (XM-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    for (role in c("weight", "identifier", "paradata", "free_text")) {
      if (file.exists(out)) {
        file.remove(out)
      }
      d <- surveycore::set_var_extra(
        guard_design(designs[[nm]]),
        q2 = list(role = role)
      )

      expect_warning(
        crosstab_quiet(
          d,
          vars = c(q1, q2),
          banner = group,
          file_name = out,
          min_eff_n = 0
        ),
        class = "surveyreports_warning_role_dropped"
      )

      expect_identical(
        data_sheets(out),
        "q1",
        label = paste0(nm, ", ", role, ": no q2 sheet")
      )
    }
  }
})

test_that("export_crosstab() keeps a vars column for each substantive role (XM-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    for (role in c("item", "demographic", "treatment")) {
      if (file.exists(out)) {
        file.remove(out)
      }
      d <- surveycore::set_var_extra(
        guard_design(designs[[nm]]),
        q2 = list(role = role)
      )

      expect_no_warning(
        crosstab_quiet(
          d,
          vars = c(q1, q2),
          banner = group,
          file_name = out,
          min_eff_n = 0
        )
      )

      expect_identical(
        data_sheets(out),
        c("q1", "q2"),
        label = paste0(nm, ", ", role, ": both sheets")
      )
      expect_identical(
        sheet_col_a(out, "q2")[[1L]],
        "Question two",
        label = paste0(nm, ", ", role, ": q2 block")
      )
    }
  }
})

# The spanner reads the banner column's variable label (spec 3.8). The
# label-independent check is the comparison with the same call at
# banner = gen: dropping reg must leave exactly that sheet.
test_that("export_crosstab() drops a paradata column from banner (XM-11)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  ref <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    for (path in c(out, ref)) {
      if (file.exists(path)) {
        file.remove(path)
      }
    }
    base <- add_gen_reg(guard_design(designs[[nm]]))
    d <- surveycore::set_var_extra(base, reg = list(role = "paradata"))

    expect_warning(
      crosstab_quiet(
        d,
        vars = q1,
        banner = c(gen, reg),
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )
    crosstab_quiet(
      base,
      vars = q1,
      banner = gen,
      file_name = ref,
      min_eff_n = 0
    )

    rows <- sheet_rows(out, "q1")
    spanners <- as.character(unlist(rows[2L, ]))
    expect_false(
      any(c("reg", "Region") %in% spanners),
      label = paste0(nm, ": no Region spanner")
    )
    expect_true(
      "Gender" %in% spanners,
      label = paste0(nm, ": the Gender spanner")
    )
    expect_identical(
      rows,
      sheet_rows(ref, "q1"),
      label = paste0(nm, ": the same sheet as banner = gen")
    )
  }
})

test_that("export_crosstab() keeps a battery whose 2 of 3 members survive (XM-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  items <- c("Item one", "Item two", "Item three")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      bat_2 = list(role = "paradata")
    )

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )
    col_a <- sheet_col_a(out, "bat_1")

    expect_identical(data_sheets(out), "bat_1", label = paste0(nm, ": sheets"))
    expect_identical(
      col_a[[1L]],
      "Please rate the following items:",
      label = paste0(nm, ": preface")
    )
    expect_identical(col_a[[3L]], "Item", label = paste0(nm, ": header"))
    expect_identical(
      col_a[col_a %in% items],
      c("Item one", "Item three"),
      label = paste0(nm, ": the surviving items")
    )
    # A single-response block writes "Response" in column A; a battery writes
    # it in column B.
    expect_false("Response" %in% col_a, label = paste0(nm, ": not split"))
  }
})

test_that("export_crosstab() renders a battery reduced to one member as a single question (XM-13)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      bat_2 = list(role = "paradata"),
      bat_3 = list(role = "paradata")
    )

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )
    col_a <- sheet_col_a(out, "bat_1")

    expect_identical(data_sheets(out), "bat_1", label = paste0(nm, ": sheets"))
    expect_identical(col_a[[1L]], "Item one", label = paste0(nm, ": title"))
    expect_identical(col_a[[3L]], "Response", label = paste0(nm, ": header"))
    expect_false(
      "Please rate the following items:" %in% col_a,
      label = paste0(nm, ": no preface")
    )
  }
})

test_that("export_crosstab() keeps a SATA group whose 2 of 3 members survive (XM-14)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  options <- c("Option A", "Option B", "Option C")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      sata_b = list(role = "paradata")
    )

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(sata_a, sata_b, sata_c),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )
    col_a <- sheet_col_a(out, "sata_a")

    expect_identical(data_sheets(out), "sata_a", label = paste0(nm, ": sheets"))
    expect_identical(
      col_a[[1L]],
      "Which of the following apply to you?",
      label = paste0(nm, ": preface")
    )
    expect_identical(col_a[[3L]], "Item", label = paste0(nm, ": header"))
    expect_identical(
      col_a[col_a %in% options],
      c("Option A", "Option C"),
      label = paste0(nm, ": the surviving options")
    )
  }
})

test_that("export_crosstab() names the sheet after the first surviving member (XM-15)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      bat_1 = list(role = "paradata")
    )

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        layout = "per_question",
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )

    expect_identical(data_sheets(out), "bat_2", label = paste0(nm, ": sheet"))
    expect_identical(
      sheet_col_a(out, "bat_2")[[1L]],
      "Please rate the following items:",
      label = paste0(nm, ": preface")
    )
  }
})

test_that("export_crosstab() keeps every column of a design with no role set (XM-16)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- guard_design(designs[[nm]])

    expect_no_warning(
      crosstab_quiet(
        d,
        vars = c(q1, q2, sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      )
    )

    expect_identical(
      data_sheets(out),
      c("q1", "q2", "sata_a", "bat_1"),
      label = paste0(nm, ": every block")
    )
  }
})

test_that("export_crosstab() judges battery unanimity on the surviving members (XM-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  universe <- "Rated by all adults."
  other <- "Rated by parents."

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_universe(
      guard_design(designs[[nm]]),
      bat_1 = universe,
      bat_2 = other,
      bat_3 = universe
    )
    d <- surveycore::set_var_extra(d, bat_2 = list(role = "paradata"))

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )
    col_a <- sheet_col_a(out, "bat_1")

    expect_identical(col_a[[2L]], universe, label = paste0(nm, ": base note"))
    expect_false(other %in% col_a, label = paste0(nm, ": no dropped universe"))
  }
})

# tidyselect raises its external-vector deprecation with the class
# lifecycle_warning_deprecated when a bare character vector reaches a
# selection. The block sets lifecycle_verbosity to "warning", so the warning
# fires on every call here, not once per session. Measured on tidyselect
# 1.2.1: the warning fires for a bare vector from the global environment and
# not for one from package code, so the bare call this PR replaced did not
# raise it either. The block guards the all_of() call against a future
# tidyselect that warns in both cases.
test_that("export_crosstab() raises no tidyselect deprecation warning (XM-17)", {
  skip_if_not_installed("surveycore")
  withr::local_options(lifecycle_verbosity = "warning")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- guard_design(designs[[nm]])

    expect_no_warning(
      crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "lifecycle_warning_deprecated"
    )
    expect_true(file.exists(out), label = paste0(nm, ": file written"))
  }
})

test_that("export_crosstab() aborts when every vars column is non-substantive (XE-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  all_dropped <- function(d) {
    surveycore::set_var_extra(
      guard_design(d),
      q1 = list(role = "free_text"),
      q2 = list(role = "free_text")
    )
  }

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- all_dropped(designs[[nm]])

    cnd <- expect_error(
      crosstab_quiet(d, vars = c(q1, q2), banner = group, file_name = out),
      class = "surveyreports_error_vars_all_dropped"
    )
    expect_match(
      conditionMessage(cnd),
      "q1 (free_text) and q2 (free_text)",
      fixed = TRUE,
      label = paste0(nm, ": every dropped column and its role")
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }

  d <- all_dropped(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)
  )
})

test_that("export_crosstab()'s all-dropped vars error is not the empty-selection class (XE-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q1 = list(role = "free_text"),
      q2 = list(role = "free_text")
    )

    cnd <- expect_error(
      crosstab_quiet(d, vars = c(q1, q2), banner = group, file_name = out),
      class = "surveyreports_error_vars_all_dropped"
    )
    expect_false(
      inherits(cnd, "surveyreports_error_vars_empty_selection"),
      label = paste0(nm, ": not the tidyselect class")
    )
  }
})

test_that("export_crosstab() aborts when every banner column is non-substantive (XE-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  all_dropped <- function(d) {
    surveycore::set_var_extra(
      add_gen_reg(guard_design(d)),
      gen = list(role = "paradata"),
      reg = list(role = "paradata")
    )
  }

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- all_dropped(designs[[nm]])

    expect_error(
      crosstab_quiet(d, vars = q1, banner = c(gen, reg), file_name = out),
      class = "surveyreports_error_banner_empty_selection"
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }

  d <- all_dropped(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = c(gen, reg), file_name = out)
  )
})

# The re-validation path: without the role, the same call passes both checks
# and writes the file. With reg dropped from the banner, the element passes
# the check at step 7 and fails the one at step 11 (spec 3.11). The role
# warning comes first, so the snapshot records it before the error.
test_that("export_crosstab() re-validates interactions against the surviving banner (XE-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    base <- add_gen_reg(guard_design(designs[[nm]]))
    d <- surveycore::set_var_extra(base, reg = list(role = "paradata"))

    crosstab_quiet(
      base,
      vars = q1,
      banner = c(gen, reg),
      file_name = out,
      interactions = list(c("gen", "reg")),
      min_eff_n = 0
    )
    expect_true(file.exists(out), label = paste0(nm, ": passes with no role"))
    file.remove(out)

    expect_warning(
      expect_error(
        crosstab_quiet(
          d,
          vars = q1,
          banner = c(gen, reg),
          file_name = out,
          interactions = list(c("gen", "reg")),
          min_eff_n = 0
        ),
        class = "surveyreports_error_interaction_not_in_banner"
      ),
      class = "surveyreports_warning_role_dropped"
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }

  d <- surveycore::set_var_extra(
    add_gen_reg(guard_design(designs$taylor)),
    reg = list(role = "paradata")
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = q1,
      banner = c(gen, reg),
      file_name = out,
      interactions = list(c("gen", "reg")),
      min_eff_n = 0
    )
  )
})

# The class alone: section 12 snapshots this class's message.
test_that("export_crosstab() still rejects a survey_collection (XE-08)", {
  skip_if_not_installed("surveycore")
  coll <- surveycore::as_survey_collection(
    w1 = guard_design(make_all_designs(seed = 42)$taylor),
    w2 = guard_design(make_all_designs(seed = 7)$taylor)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")
  if (file.exists(out)) {
    file.remove(out)
  }

  expect_error(
    crosstab_quiet(coll, vars = q1, banner = group, file_name = out),
    class = "surveyreports_error_collection_not_supported_for_crosstab"
  )
  expect_false(file.exists(out))
})

# surveycore exports no filter verb, so the all-FALSE domain is written into
# the domain column directly, as surveytidy's filter() would leave it.
test_that("export_crosstab() aborts on an empty domain (XE-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  empty_domain <- function(d) {
    d <- guard_design(d)
    d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(d@data))
    d
  }

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- empty_domain(designs[[nm]])

    expect_error(
      crosstab_quiet(d, vars = c(q1, q2), banner = group, file_name = out),
      class = "surveyreports_error_empty_domain"
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }

  d <- empty_domain(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)
  )
})

# The class alone: section 12 snapshots this class's message.
test_that("export_crosstab() still rejects a plain data frame (XE-10)", {
  df <- make_survey_data(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  if (file.exists(out)) {
    file.remove(out)
  }

  expect_error(
    crosstab_quiet(df, vars = c(q1, q2), banner = group, file_name = out),
    class = "surveyreports_error_not_survey_object"
  )
  expect_false(file.exists(out))
})

# XE-12 to XE-15 set no role, so each proves the design read and not the
# role table.
test_that("export_crosstab() aborts when vars names the design's weight column (XE-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- guard_design(designs[[nm]])

    cnd <- expect_error(
      crosstab_quiet(d, vars = c(q1, wt), banner = group, file_name = out),
      class = "surveyreports_error_design_variable_selected"
    )
    expect_match(
      conditionMessage(cnd),
      "wt in `vars`",
      fixed = TRUE,
      label = paste0(nm, ": names the column and vars")
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }

  d <- guard_design(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = c(q1, wt), banner = group, file_name = out)
  )
})

# The class alone: XE-12 snapshots the `vars` wording.
test_that("export_crosstab() aborts when vars names the stratum or cluster id column (XE-13)", {
  skip_if_not_installed("surveycore")
  d <- guard_design(make_all_designs(seed = 42)$taylor)
  out <- withr::local_tempfile(fileext = ".xlsx")
  if (file.exists(out)) {
    file.remove(out)
  }

  expect_error(
    crosstab_quiet(d, vars = c(q1, strata), banner = group, file_name = out),
    class = "surveyreports_error_design_variable_selected"
  )
  expect_error(
    crosstab_quiet(d, vars = c(q1, psu), banner = group, file_name = out),
    class = "surveyreports_error_design_variable_selected"
  )
  expect_false(file.exists(out))
})

test_that("export_crosstab() aborts when banner names the design's weight column (XE-14)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- guard_design(designs[[nm]])

    cnd <- expect_error(
      crosstab_quiet(d, vars = q1, banner = c(group, wt), file_name = out),
      class = "surveyreports_error_design_variable_selected"
    )
    expect_match(
      conditionMessage(cnd),
      "wt in `banner`",
      fixed = TRUE,
      label = paste0(nm, ": names the column and banner")
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }

  d <- guard_design(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = c(group, wt), file_name = out)
  )
})

# The class alone: XE-12 snapshots the `vars` wording. Neither column is a
# weight, a stratum or a cluster id.
test_that("export_crosstab() aborts on a replicate-weight or twophase subset column (XE-15)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")
  if (file.exists(out)) {
    file.remove(out)
  }

  expect_error(
    crosstab_quiet(
      guard_design(designs$replicate),
      vars = c(q1, rwt1),
      banner = group,
      file_name = out
    ),
    class = "surveyreports_error_design_variable_selected"
  )
  expect_error(
    crosstab_quiet(
      guard_design(designs$twophase),
      vars = c(q1, in_phase2),
      banner = group,
      file_name = out
    ),
    class = "surveyreports_error_design_variable_selected"
  )
  expect_false(file.exists(out))
})

# The class alone: XE-09 snapshots it. The empty-domain check runs at step 4,
# before the role guard at step 10, so the role warning for q2 must never
# fire (spec 3.11).
test_that("export_crosstab() aborts on an empty domain before the role guard (XX-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q2 = list(role = "free_text")
    )
    d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(d@data))

    expect_no_warning(
      expect_error(
        crosstab_quiet(d, vars = c(q1, q2), banner = group, file_name = out),
        class = "surveyreports_error_empty_domain"
      ),
      class = "surveyreports_warning_role_dropped"
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file written"))
  }
})

test_that("export_crosstab() warns once for a dropped vars column and still writes the file (XV-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q2 = list(role = "free_text")
    )

    expect_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_role_dropped"
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_true(file.exists(out), label = paste0(nm, ": file written"))
  }

  d <- surveycore::set_var_extra(
    guard_design(designs$taylor),
    q2 = list(role = "free_text")
  )
  expect_snapshot(
    export_crosstab(
      d,
      vars = c(q1, q2),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )
  )
})

test_that("export_crosstab() warns for a dropped banner column under its own name (XV-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      add_gen_reg(guard_design(designs[[nm]])),
      reg = list(role = "paradata")
    )

    expect_warning(
      result <- crosstab_quiet(
        d,
        vars = q1,
        banner = c(gen, reg),
        file_name = out,
        min_eff_n = 0
      ),
      regexp = "`banner`",
      class = "surveyreports_warning_role_dropped"
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_true(file.exists(out), label = paste0(nm, ": file written"))
  }

  d <- surveycore::set_var_extra(
    add_gen_reg(guard_design(designs$taylor)),
    reg = list(role = "paradata")
  )
  expect_snapshot(
    export_crosstab(
      d,
      vars = q1,
      banner = c(gen, reg),
      file_name = out,
      min_eff_n = 0
    )
  )
})

test_that("export_crosstab() keeps a column with an unrecognized role and warns (XV-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q2 = list(role = "curiosity")
    )

    expect_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_unknown_role"
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_identical(
      data_sheets(out),
      c("q1", "q2"),
      label = paste0(nm, ": the q2 block")
    )
  }

  d <- surveycore::set_var_extra(
    guard_design(designs$taylor),
    q2 = list(role = "curiosity")
  )
  expect_snapshot(
    export_crosstab(
      d,
      vars = c(q1, q2),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )
  )
})

# The class alone: XV-07 snapshots it.
test_that("export_crosstab() keeps a column with a length-2 role and warns (XV-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q2 = list(role = c("item", "demographic"))
    )

    expect_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_unknown_role"
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_identical(
      data_sheets(out),
      c("q1", "q2"),
      label = paste0(nm, ": the q2 block")
    )
  }
})

# The class alone: XV-07 snapshots it.
test_that("export_crosstab() keeps a column with a non-character role and warns (XV-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- surveycore::set_var_extra(
      guard_design(designs[[nm]]),
      q2 = list(role = 3L)
    )

    expect_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_unknown_role"
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_identical(
      data_sheets(out),
      c("q1", "q2"),
      label = paste0(nm, ": the q2 block")
    )
  }
})

# 26. min_eff_n withholding ----------------------------------------------------
# One floor replaces the two suppression modes. A banner level whose
# effective N is strictly below min_eff_n loses its column: its heading, its
# cells and its share of the spanner. min_eff_n = 0 withholds nothing
# (spec 3.5). min_eff_n is validated at step 8 of spec 3.11.

# The labelled `gen` banner of the test-spec: 180 Male rows, then 20 Female
# rows, coded 1 and 2, with the variable label "Gender". q1 and the SATA and
# battery columns carry labels too, so no missing-label warning fires.
add_gen_fixture <- function(d) {
  d <- guard_design(d)
  d@data$gen <- c(rep(1, 180), rep(2, 20))
  d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))
  surveycore::set_var_label(d, gen = "Gender")
}

# The floor for the withholding tests. The test-spec names 100, which puts
# Female below the floor and Male above it on three designs. The twophase
# design keeps 107 of the 180 Male rows in phase 2, for an effective N of
# 99.2, so at 100 its Male level is withheld too. At 50 every design
# withholds Female (effective N 18.1 or less) and keeps Male (99.2 or more),
# and both levels sit clear of the floor.
gen_floor <- 50

# The oracle row of one gen level: n and n_eff from surveycore.
gen_oracle <- function(d, level) {
  ref <- suppressWarnings(
    surveycore::get_effective_n(d, group = gen),
    classes = c(
      "surveycore_warning_small_cell",
      "surveycore_warning_nonprob_srs_fallback"
    )
  )
  ref[as.character(ref$gen) == level, ]
}

# Writes the q1 crosstab of a gen-fixture design over banner = gen.
write_gen_q1 <- function(d, path, min_eff_n) {
  if (file.exists(path)) {
    file.remove(path)
  }
  crosstab_quiet(
    d,
    vars = q1,
    banner = gen,
    file_name = path,
    min_eff_n = min_eff_n
  )
}

# The row index of the heading row: the first row whose column A reads
# `label`.
heading_index <- function(rows, label = "Response") {
  match(label, as.character(rows[[1L]]))
}

# The heading row of one block, as a character vector, blank cells NA.
heading_cells <- function(path, sheet, label = "Response") {
  rows <- sheet_rows(path, sheet)
  as.character(unlist(rows[heading_index(rows, label), ]))
}

# The cells of one heading's column, from the first row under the heading row
# through the last written row of column A, as text.
column_cells <- function(path, sheet, heading) {
  rows <- sheet_rows(path, sheet)
  h <- heading_index(rows)
  j <- match(heading, as.character(unlist(rows[h, ])))
  last <- max(which(!is.na(as.character(rows[[1L]]))))
  as.character(rows[[j]][seq.int(h + 1L, last)])
}

# The number of columns the gen spanner spans: 1 when its cell is not merged,
# else the width of its merged range. The spanner reads the variable label,
# "Gender" (spec 3.8). The match also accepts the column name, "gen".
spanner_width <- function(path, sheet) {
  rows <- sheet_rows(path, sheet)
  spanner_row <- heading_index(rows) - 1L
  col <- which(
    as.character(unlist(rows[spanner_row, ])) %in% c("gen", "Gender")
  )
  wb <- openxlsx2::wb_load(path)
  ws <- wb$worksheets[[match(sheet, wb$get_sheet_names())]]
  refs <- regmatches(
    ws$mergeCells,
    regexpr("(?<=ref=\")[^\"]+", ws$mergeCells, perl = TRUE)
  )
  for (ref in refs) {
    ends <- strsplit(ref, ":", fixed = TRUE)[[1L]]
    cols <- openxlsx2::col2int(gsub("[0-9]", "", ends))
    row <- as.integer(gsub("[A-Z]", "", ends[[1L]]))
    if (row == spanner_row && col >= cols[[1L]] && col <= cols[[2L]]) {
      return(cols[[2L]] - cols[[1L]] + 1L)
    }
  }
  1L
}

test_that("export_crosstab() rejects an invalid min_eff_n before writing (XE-11)", {
  skip_if_not_installed("surveycore")
  d <- add_gen_fixture(make_all_designs(seed = 42)$taylor)
  out <- withr::local_tempfile(fileext = ".xlsx")
  bad <- list(-5, NA, Inf, c(50, 100), "100")

  for (i in seq_along(bad)) {
    expect_error(
      export_crosstab(
        d,
        vars = q1,
        banner = gen,
        file_name = out,
        min_eff_n = bad[[i]]
      ),
      class = "surveyreports_error_invalid_min_eff_n",
      label = paste0("input ", i)
    )
    expect_false(file.exists(out), label = paste0("input ", i, ": no file"))
  }

  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = gen, file_name = out, min_eff_n = -5)
  )
})

test_that("export_crosstab() drops a below-floor level's heading and cells (XW-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    expect_warning(
      result <- write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))

    rows <- sheet_rows(out, "q1")
    h <- heading_index(rows)
    headings <- as.character(unlist(rows[h, ]))
    expect_false("Female" %in% headings, label = paste0(nm, ": no heading"))
    expect_true("Male" %in% headings, label = paste0(nm, ": Male heading"))

    # The sheet ends at the last heading, so no Female cell survives to the
    # right of it.
    expect_identical(
      ncol(rows),
      max(which(!is.na(headings))),
      label = paste0(nm, ": no cell beyond the headings")
    )
  }
})

test_that("export_crosstab() leaves the surviving column unchanged (XW-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  ref <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    expect_warning(
      write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )
    write_gen_q1(d, ref, 0)

    male <- column_cells(out, "q1", "Male")
    expect_gt(length(male), 1L)
    expect_identical(
      male,
      column_cells(ref, "q1", "Male"),
      label = paste0(nm, ": Male cells")
    )
  }
})

test_that("export_crosstab() shrinks the spanner of a withheld level (XW-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  ref <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    expect_warning(
      write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )
    write_gen_q1(d, ref, 0)

    expect_identical(spanner_width(out, "q1"), 1L, label = paste0(nm, ": 1"))
    expect_identical(spanner_width(ref, "q1"), 2L, label = paste0(nm, ": 2"))
  }
})

test_that("export_crosstab() withholds nothing at min_eff_n = 0 (XW-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    expect_no_warning(write_gen_q1(d, out, 0))

    headings <- heading_cells(out, "q1")
    expect_true(
      all(c("Male", "Female") %in% headings),
      label = paste0(nm, ": both headings")
    )
    expect_false(
      any(is.na(column_cells(out, "q1", "Female"))),
      label = paste0(nm, ": Female cells")
    )
  }
})

test_that("export_crosstab() tests the floor on effective N, not raw N (XW-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    female <- gen_oracle(d, "Female")
    # A floor between Female's effective N and its raw n: a raw-N test keeps
    # the column, and the effective-N test withholds it.
    floor_n <- (female$n + female$n_eff) / 2
    expect_true(female$n >= floor_n, label = paste0(nm, ": raw n clears"))
    expect_true(female$n_eff < floor_n, label = paste0(nm, ": n_eff fails"))

    expect_warning(
      write_gen_q1(d, out, floor_n),
      class = "surveyreports_warning_subgroup_withheld"
    )

    headings <- heading_cells(out, "q1")
    expect_false("Female" %in% headings, label = paste0(nm, ": withheld"))
    expect_true("Male" %in% headings, label = paste0(nm, ": Male kept"))
  }
})

test_that("export_crosstab() removes a withheld column, not blanks it (XW-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  ref <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    expect_warning(
      write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )
    write_gen_q1(d, ref, 0)

    expect_identical(
      ncol(sheet_rows(out, "q1")),
      ncol(sheet_rows(ref, "q1")) - 1L,
      label = paste0(nm, ": sheet width")
    )
    expect_identical(
      sum(!is.na(heading_cells(out, "q1"))),
      sum(!is.na(heading_cells(ref, "q1"))) - 1L,
      label = paste0(nm, ": heading count")
    )
  }
})

test_that("export_crosstab() keeps a level whose effective N equals min_eff_n (XW-13)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    at_floor <- gen_oracle(d, "Female")$n_eff

    expect_no_warning(write_gen_q1(d, out, at_floor))

    expect_true(
      "Female" %in% heading_cells(out, "q1"),
      label = paste0(nm, ": Female heading")
    )
    expect_false(
      any(is.na(column_cells(out, "q1", "Female"))),
      label = paste0(nm, ": Female cells")
    )
    cells <- as.character(unlist(sheet_rows(out, "q1")))
    expect_false(
      any(grepl("suppressed", cells, fixed = TRUE)),
      label = paste0(nm, ": no withheld line")
    )
  }
})

test_that("export_crosstab() withholds a below-floor column from SATA and battery blocks", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- add_gen_fixture(designs[[nm]])

    expect_warning(
      crosstab_quiet(
        d,
        vars = c(sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
        banner = gen,
        file_name = out,
        min_eff_n = gen_floor,
        withheld_note = "every"
      ),
      class = "surveyreports_warning_subgroup_withheld"
    )

    for (sheet in c("sata_a", "bat_1")) {
      lbl <- paste(nm, sheet)
      headings <- heading_cells(out, sheet, label = "Item")
      expect_false("Female" %in% headings, label = paste(lbl, "Female"))
      expect_true("Male" %in% headings, label = paste(lbl, "Male"))
      expect_false("N" %in% headings, label = paste(lbl, "N"))
      expect_true(
        any(grepl("Female", sheet_col_a(out, sheet), fixed = TRUE)),
        label = paste(lbl, "the withheld line")
      )
    }
  }
})

# 27. Banner headings and the all-NA drop --------------------------------------
# A banner spanner reads the column's variable label, an interaction spanner
# reads the labels of its parts, and a crossed heading reads value labels
# (spec 3.8). The banner label checks of spec 3.7 run on the surviving banner
# columns. A variable with no non-missing value leaves the output at step 15
# of spec 3.11, with one warning that names every dropped variable, or an
# error when no variable is left (spec 3.17, spec 3.18).

# The labelled `reg` banner of the test-spec: codes 1 and 2, labelled North
# and South, with the variable label "Region".
add_reg_fixture <- function(d) {
  d@data$reg <- c(rep(1, 120), rep(2, 80))
  d <- surveycore::set_val_labels(d, reg = c(North = 1, South = 2))
  surveycore::set_var_label(d, reg = "Region")
}

# A factor banner `lik` whose level order is not alphabetical, with the
# variable label "Likert". The levels repeat in a fixed order, so every design
# holds every level in its tabulated rows.
add_lik_fixture <- function(d) {
  d@data$lik <- factor(
    rep(c("Low", "Medium", "High"), length.out = nrow(d@data)),
    levels = c("Low", "Medium", "High")
  )
  surveycore::set_var_label(d, lik = "Likert")
}

# A banner `nolab` with no variable label. Its values alternate, so every
# design holds both levels.
add_nolab_fixture <- function(d) {
  d@data$nolab <- rep(c("x", "y"), length.out = nrow(d@data))
  d
}

# The duplicate-label fixture: the labelled `gen` banner with one label,
# Female, on the codes 2 and 3.
add_duplicate_label <- function(d) {
  d <- add_gen_fixture(d)
  surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2, Female = 3))
}

# The two-unlabelled-codes fixture: `gen` holds the codes 1, 2 and 3, and only
# code 1 carries a label. surveycore warns about the unlabelled codes when
# the labels are set. That warning is fixture setup, not the behavior under
# test.
add_unlabelled_codes <- function(d) {
  d <- add_gen_fixture(d)
  d@data$gen <- c(rep(1, 100), rep(2, 50), rep(3, 50))
  suppressWarnings(
    surveycore::set_val_labels(d, gen = c(Male = 1)),
    classes = "surveycore_warning_missing_labels"
  )
}

# A column all-NA inside group A only, with a variable label, so the
# missing-label warning does not fire when the column is kept.
add_dom_na <- function(d) {
  d@data$dom_na <- ifelse(d@data$group == "A", NA_character_, d@data$q1)
  surveycore::set_var_label(d, dom_na = "Asked outside group A")
}

# Sets each named column to all-NA integers. The SATA and battery metadata of
# the generator stays on the column.
set_all_na <- function(d, cols) {
  for (col in cols) {
    d@data[[col]] <- NA_integer_
  }
  d
}

# Removes the file at `path` when it exists, so the next assertion reads the
# file that the next call writes, or its absence.
fresh_path <- function(path) {
  if (file.exists(path)) {
    file.remove(path)
  }
  invisible(path)
}

# The spanner row of the first block of a sheet: the row above its heading
# row, as a character vector, blank cells NA.
spanner_cells <- function(path, sheet, label = "Response") {
  rows <- sheet_rows(path, sheet)
  as.character(unlist(rows[heading_index(rows, label) - 1L, ]))
}

# Every non-blank cell of one sheet, as a character vector.
sheet_text <- function(path, sheet) {
  cells <- as.character(unlist(sheet_rows(path, sheet)))
  cells[!is.na(cells)]
}

# Writes the q1 crosstab of the gen and reg fixtures, crossed.
write_gen_reg_crossed <- function(d, path) {
  fresh_path(path)
  crosstab_quiet(
    d,
    vars = q1,
    banner = c(gen, reg),
    interactions = list(c("gen", "reg")),
    file_name = path,
    min_eff_n = 0
  )
}

test_that("export_crosstab() writes the variable label as the banner spanner (XH-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_gen_fixture(designs[[nm]])

    crosstab_quiet(d, vars = q1, banner = gen, file_name = out, min_eff_n = 0)

    spanners <- spanner_cells(out, "q1")
    expect_true("Gender" %in% spanners, label = paste0(nm, ": Gender spanner"))
    expect_false("gen" %in% spanners, label = paste0(nm, ": no gen spanner"))
  }
})

test_that("export_crosstab() falls back to the column name for an unlabelled banner (XH-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_nolab_fixture(guard_design(designs[[nm]]))

    expect_warning(
      crosstab_quiet(
        d,
        vars = q1,
        banner = nolab,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_missing_variable_label"
    )

    expect_true(
      "nolab" %in% spanner_cells(out, "q1"),
      label = paste0(nm, ": nolab spanner")
    )
  }
})

test_that("export_crosstab() names an unlabelled banner column in the missing-label warning (XV-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_nolab_fixture(guard_design(designs[[nm]]))

    w <- expect_warning(
      result <- crosstab_quiet(
        d,
        vars = q1,
        banner = nolab,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_missing_variable_label"
    )

    msg <- conditionMessage(w)
    expect_match(msg, "nolab", fixed = TRUE, label = paste0(nm, ": nolab"))
    expect_no_match(msg, "q1", fixed = TRUE, label = paste0(nm, ": no q1"))
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
  }

  d <- add_nolab_fixture(guard_design(designs$taylor))
  expect_snapshot(
    export_crosstab(
      d,
      vars = q1,
      banner = nolab,
      file_name = out,
      min_eff_n = 0
    )
  )
})

test_that("export_crosstab() writes value labels in a crossed heading (XH-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_reg_fixture(add_gen_fixture(designs[[nm]]))

    write_gen_reg_crossed(d, out)

    headings <- heading_cells(out, "q1")
    expect_true(
      "Male \u00d7 North" %in% headings,
      label = paste0(nm, ": Male x North heading")
    )
    expect_false(
      "1 \u00d7 1" %in% headings,
      label = paste0(nm, ": no 1 x 1 heading")
    )
  }
})

test_that("export_crosstab() writes both variable labels on an interaction spanner (XH-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_reg_fixture(add_gen_fixture(designs[[nm]]))

    write_gen_reg_crossed(d, out)

    spanners <- spanner_cells(out, "q1")
    expect_true(
      "Gender \u00d7 Region" %in% spanners,
      label = paste0(nm, ": Gender x Region spanner")
    )
    expect_false(
      "gen \u00d7 reg" %in% spanners,
      label = paste0(nm, ": no gen x reg spanner")
    )
  }
})

test_that("export_crosstab() keeps the factor level order in crossed headings (XH-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  expected <- paste(
    rep(c("Low", "Medium", "High"), times = 2L),
    rep(c("North", "South"), each = 3L),
    sep = " \u00d7 "
  )

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_reg_fixture(add_lik_fixture(guard_design(designs[[nm]])))

    crosstab_quiet(
      d,
      vars = q1,
      banner = c(lik, reg),
      interactions = list(c("lik", "reg")),
      file_name = out,
      min_eff_n = 0
    )

    headings <- heading_cells(out, "q1")
    crossed <- headings[grepl("\u00d7", headings, fixed = TRUE)]
    expect_identical(crossed, expected, label = paste0(nm, ": crossed order"))
  }
})

# The crossed levels of the gen and reg fixtures in code order, gen varying
# fastest within each reg level, less every cell that holds no row of the
# design. The order is built from the codes, not from the labels.
crossed_code_order <- function(d) {
  gen_lab <- c(Male = 1, Female = 2)
  reg_lab <- c(North = 1, South = 2)
  # expand.grid() varies its first argument fastest.
  grid <- expand.grid(gen = gen_lab, reg = reg_lab)
  observed <- unique(paste(d@data$gen, d@data$reg))
  grid <- grid[paste(grid$gen, grid$reg) %in% observed, ]
  paste(
    names(gen_lab)[match(grid$gen, gen_lab)],
    names(reg_lab)[match(grid$reg, reg_lab)],
    sep = " \u00d7 "
  )
}

# The percentage a written cell holds, as a number, whether the cell stores
# a number or a string such as "41.2%".
cell_pct <- function(x) {
  as.numeric(sub("%", "", as.character(x), fixed = TRUE))
}

test_that("export_crosstab() keeps the code order of a labelled banner in crossed headings (XH-05a)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  # The order an alphabetical sort of the labels writes. It must not appear.
  alphabetical <- c(
    "Male \u00d7 North",
    "Female \u00d7 South",
    "Male \u00d7 South"
  )

  for (nm in names(designs)) {
    d <- add_reg_fixture(add_gen_fixture(designs[[nm]]))
    expect_true(is.numeric(d@data$gen), label = paste0(nm, ": gen is codes"))
    expected <- crossed_code_order(d)
    expect_identical(
      expected,
      c("Male \u00d7 North", "Male \u00d7 South", "Female \u00d7 South"),
      label = paste0(nm, ": expected order")
    )

    write_gen_reg_crossed(d, out)

    headings <- heading_cells(out, "q1")
    expect_identical(
      headings[headings %in% c("Male", "Female")],
      c("Male", "Female"),
      label = paste0(nm, ": Gender group order")
    )
    crossed <- headings[grepl("\u00d7", headings, fixed = TRUE)]
    expect_identical(crossed, expected, label = paste0(nm, ": crossed order"))
    expect_false(
      identical(crossed, alphabetical),
      label = paste0(nm, ": not alphabetical")
    )
    expect_false(
      "Female \u00d7 North" %in% headings,
      label = paste0(nm, ": no empty crossed cell")
    )

    # The cells under a moved heading hold that subgroup's estimates. Male x
    # South is second in code order and third in alphabetical order.
    d@data$cross <- paste(
      c("Male", "Female")[d@data$gen],
      c("North", "South")[d@data$reg],
      sep = " \u00d7 "
    )
    ref <- suppressWarnings(
      surveycore::get_freqs(d, q1, group = cross),
      classes = c(
        "surveycore_warning_small_cell",
        "surveycore_warning_nonprob_srs_fallback"
      )
    )
    ref <- ref[as.character(ref$cross) == "Male \u00d7 South", ]
    expect_gt(nrow(ref), 0L, label = paste0(nm, ": oracle rows"))
    rows <- sheet_rows(out, "q1")
    h <- heading_index(rows)
    j <- match("Male \u00d7 South", as.character(unlist(rows[h, ])))
    labels_a <- as.character(rows[[1L]])
    for (val in as.character(ref$q1)) {
      i <- which(labels_a == val & seq_along(labels_a) > h)
      expect_identical(length(i), 1L, label = paste0(nm, ": row ", val))
      expect_equal(
        cell_pct(rows[[j]][[i]]),
        round(100 * ref$pct[as.character(ref$q1) == val], 1L),
        tolerance = 1e-10,
        label = paste0(nm, ": Male x South cell for ", val)
      )
    }
  }

  # A value label whose code holds no row (the XX-07 fixture) adds no crossed
  # column and no withheld line, at a floor that withholds a real cell.
  for (nm in names(designs)) {
    d <- add_reg_fixture(
      surveycore::set_val_labels(
        add_gen_fixture(designs[[nm]]),
        gen = c(Male = 1, Female = 2, Other = 3)
      )
    )

    fresh_path(out)
    suppressWarnings(
      crosstab_quiet(
        d,
        vars = q1,
        banner = c(gen, reg),
        interactions = list(c("gen", "reg")),
        file_name = out,
        min_eff_n = gen_floor
      ),
      classes = "surveyreports_warning_subgroup_withheld"
    )

    headings <- heading_cells(out, "q1")
    crossed <- headings[grepl("\u00d7", headings, fixed = TRUE)]
    expect_false(
      any(grepl("Other", crossed, fixed = TRUE)),
      label = paste0(nm, ": no Other crossed column")
    )
    expect_false(
      any(grepl("Female \u00d7 North", headings, fixed = TRUE)),
      label = paste0(nm, ": no empty crossed column")
    )
    about <- about_sheet(out)
    withheld <- about$B[about$A %in% "Not shown"]
    expect_false(
      any(grepl("Other", withheld, fixed = TRUE)),
      label = paste0(nm, ": no Other withheld line")
    )
    expect_false(
      any(grepl("Female \u00d7 North", withheld, fixed = TRUE)),
      label = paste0(nm, ": no empty-cell withheld line")
    )
    expect_true(
      any(grepl("Female \u00d7 South", withheld, fixed = TRUE)),
      label = paste0(nm, ": the real small cell is withheld")
    )
  }
})

test_that("export_crosstab() keeps the factor level order of a banner (XH-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  lik_levels <- c("Low", "Medium", "High")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_lik_fixture(guard_design(designs[[nm]]))

    crosstab_quiet(d, vars = q1, banner = lik, file_name = out, min_eff_n = 0)

    headings <- heading_cells(out, "q1")
    expect_identical(
      headings[headings %in% lik_levels],
      lik_levels,
      label = paste0(nm, ": heading order")
    )
  }
})

test_that("export_crosstab() names a sheet tab by the variable name (XH-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  long_label <- paste(
    "How much do you agree or disagree with the statement",
    "about the local council?"
  )

  for (nm in names(designs)) {
    fresh_path(out)
    d <- surveycore::set_var_label(
      guard_design(designs[[nm]]),
      q1 = long_label
    )

    crosstab_quiet(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      layout = "per_question",
      min_eff_n = 0
    )

    expect_identical(data_sheets(out), "q1", label = paste0(nm, ": sheets"))
  }
})

test_that("export_crosstab() rejects a banner value label on two codes (XE-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_duplicate_label(designs[[nm]])

    err <- expect_error(
      crosstab_quiet(d, vars = q1, banner = gen, file_name = out),
      class = "surveyreports_error_duplicate_value_label"
    )

    msg <- conditionMessage(err)
    expect_match(msg, "\\bgen\\b", label = paste0(nm, ": names gen"))
    expect_match(msg, "Female", fixed = TRUE, label = paste0(nm, ": Female"))
    expect_false(file.exists(out), label = paste0(nm, ": no file"))
  }

  d <- add_duplicate_label(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = gen, file_name = out)
  )
})

test_that("export_crosstab() rejects a banner with two unlabelled codes (XE-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_unlabelled_codes(designs[[nm]])

    err <- expect_error(
      crosstab_quiet(d, vars = q1, banner = gen, file_name = out),
      class = "surveyreports_error_multiple_unlabelled_codes"
    )

    msg <- conditionMessage(err)
    expect_match(msg, "\\bgen\\b", label = paste0(nm, ": names gen"))
    expect_match(msg, "\\b2\\b", label = paste0(nm, ": code 2"))
    expect_match(msg, "\\b3\\b", label = paste0(nm, ": code 3"))
    expect_false(file.exists(out), label = paste0(nm, ": no file"))
  }

  d <- add_unlabelled_codes(designs$taylor)
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = gen, file_name = out)
  )
})

test_that("export_crosstab() drops an all-NA variable (XX-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  ref <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    fresh_path(ref)
    lbl <- paste0("export_crosstab(), ", nm)
    d <- guard_design(designs[[nm]])

    w <- expect_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, all_na_var),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_all_na_dropped"
    )
    crosstab_quiet(d, vars = q1, banner = group, file_name = ref, min_eff_n = 0)

    expect_identical(result, out, label = paste0(lbl, ": the path"))
    expect_match(
      conditionMessage(w),
      "all_na_var",
      fixed = TRUE,
      label = paste0(lbl, ": names all_na_var")
    )
    expect_identical(data_sheets(out), "q1", label = paste0(lbl, ": sheets"))
    expect_identical(
      sheet_rows(out, "q1"),
      sheet_rows(ref, "q1"),
      label = paste0(lbl, ": the q1 block as with vars = q1")
    )
  }
})

test_that("export_crosstab() names every dropped all-NA variable in one warning (XV-14)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- designs[[nm]]
    d@data$all_na_2 <- NA_character_

    w_label <- expect_warning(
      w_na <- expect_warning(
        result <- crosstab_quiet(
          d,
          vars = c(q1, all_na_var, q2, all_na_2),
          banner = group,
          file_name = out,
          min_eff_n = 0
        ),
        class = "surveyreports_warning_all_na_dropped"
      ),
      class = "surveyreports_warning_missing_variable_label"
    )

    msg_na <- conditionMessage(w_na)
    first <- regexpr("all_na_var", msg_na, fixed = TRUE)
    second <- regexpr("all_na_2", msg_na, fixed = TRUE)
    expect_true(first > 0L, label = paste0(nm, ": names all_na_var"))
    expect_true(second > first, label = paste0(nm, ": all_na_2 after"))
    expect_no_match(msg_na, "q1", fixed = TRUE, label = paste0(nm, ": no q1"))
    expect_no_match(msg_na, "q2", fixed = TRUE, label = paste0(nm, ": no q2"))

    msg_label <- conditionMessage(w_label)
    expect_match(
      msg_label,
      "q1",
      fixed = TRUE,
      label = paste0(nm, ": label q1")
    )
    expect_match(
      msg_label,
      "q2",
      fixed = TRUE,
      label = paste0(nm, ": label q2")
    )
    expect_no_match(
      msg_label,
      "all_na",
      fixed = TRUE,
      label = paste0(nm, ": the label warning names no dropped variable")
    )

    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_identical(
      openxlsx2::wb_load(out)$sheet_names,
      c("About", "q1", "q2"),
      label = paste0(nm, ": sheets")
    )
  }

  d <- designs$taylor
  d@data$all_na_2 <- NA_character_
  expect_snapshot(
    export_crosstab(
      d,
      vars = c(q1, all_na_var, q2, all_na_2),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )
  )
})

test_that("export_crosstab() aborts when every variable is all-NA (XE-16)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- add_gen_fixture(designs[[nm]])
    d@data$all_na_2 <- NA_character_

    expect_no_warning(
      err <- expect_error(
        crosstab_quiet(
          d,
          vars = c(all_na_var, all_na_2),
          banner = gen,
          file_name = out,
          min_eff_n = 0
        ),
        class = "surveyreports_error_vars_all_na"
      )
    )

    msg <- conditionMessage(err)
    expect_match(msg, "all_na_var", fixed = TRUE, label = paste0(nm, ": var"))
    expect_match(msg, "all_na_2", fixed = TRUE, label = paste0(nm, ": var 2"))
    expect_false(
      inherits(err, "surveyreports_error_vars_all_dropped"),
      label = paste0(nm, ": not the role guard class")
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file"))

    # The second call, at the default floor: Female falls below it, but the
    # abort at step 15 comes before any withholding warning (spec 3.11).
    fresh_path(out)
    expect_no_warning(
      expect_error(
        crosstab_quiet(
          d,
          vars = c(all_na_var, all_na_2),
          banner = gen,
          file_name = out
        ),
        class = "surveyreports_error_vars_all_na"
      )
    )
    expect_false(file.exists(out), label = paste0(nm, ": no file, default"))
  }

  d <- add_gen_fixture(designs$taylor)
  d@data$all_na_2 <- NA_character_
  expect_snapshot(
    error = TRUE,
    export_crosstab(
      d,
      vars = c(all_na_var, all_na_2),
      banner = gen,
      file_name = out,
      min_eff_n = 0
    )
  )
})

test_that("export_crosstab() muffles the surveycore all-NA warning (XV-15)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- surveycore::set_var_label(
      designs[[nm]],
      all_na_var = "No answers",
      q1 = "Question one",
      group = "Group"
    )

    expect_no_warning(
      w <- expect_warning(
        crosstab_quiet(
          d,
          vars = c(all_na_var, q1),
          banner = group,
          file_name = out,
          min_eff_n = 0
        ),
        class = "surveyreports_warning_all_na_dropped"
      ),
      class = "surveycore_warning_all_na_freqs"
    )

    expect_match(
      conditionMessage(w),
      "all_na_var",
      fixed = TRUE,
      label = paste0(nm, ": names all_na_var")
    )
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
  }
})

# The interaction helper is the third of the three frequency helpers that
# muffle the class (spec 2.3). XV-15 reaches the other two.
test_that("export_crosstab() muffles the surveycore all-NA warning on an interaction (XV-15)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- surveycore::set_var_label(
      add_reg_fixture(add_gen_fixture(designs[[nm]])),
      all_na_var = "No answers"
    )

    expect_no_warning(
      w <- expect_warning(
        crosstab_quiet(
          d,
          vars = c(all_na_var, q1),
          banner = c(gen, reg),
          interactions = list(c("gen", "reg")),
          file_name = out,
          min_eff_n = 0
        ),
        class = "surveyreports_warning_all_na_dropped"
      ),
      class = "surveycore_warning_all_na_freqs"
    )

    expect_match(
      conditionMessage(w),
      "all_na_var",
      fixed = TRUE,
      label = paste0(nm, ": names all_na_var")
    )
    expect_identical(data_sheets(out), "q1", label = paste0(nm, ": sheets"))
  }
})

test_that("export_crosstab() keeps a group whose other items survive (XX-14)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  sata_preface <- "Which of the following apply to you?"
  bat_preface <- "Please rate the following items:"

  for (nm in names(designs)) {
    fresh_path(out)
    lbl <- paste0("export_crosstab(), ", nm)
    d <- set_all_na(cover_design(designs[[nm]]), c("sata_a", "bat_1"))

    w <- expect_warning(
      crosstab_quiet(
        d,
        vars = c(q1, sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_all_na_dropped"
    )

    msg <- conditionMessage(w)
    first <- regexpr("sata_a", msg, fixed = TRUE)
    second <- regexpr("bat_1", msg, fixed = TRUE)
    expect_true(first > 0L, label = paste0(lbl, ": names sata_a"))
    expect_true(second > first, label = paste0(lbl, ": bat_1 after sata_a"))
    expect_identical(
      data_sheets(out),
      c("q1", "sata_b", "bat_2"),
      label = paste0(lbl, ": sheets")
    )

    sata_a_col <- sheet_col_a(out, "sata_b")
    expect_identical(
      sata_a_col[[1L]],
      sata_preface,
      label = paste0(lbl, ": SATA")
    )
    expect_true(
      all(c("sata_b", "sata_c") %in% sata_a_col),
      label = paste0(lbl, ": SATA items")
    )
    bat_a_col <- sheet_col_a(out, "bat_2")
    expect_identical(
      bat_a_col[[1L]],
      bat_preface,
      label = paste0(lbl, ": battery")
    )
    expect_true(
      all(c("bat_2", "bat_3") %in% bat_a_col),
      label = paste0(lbl, ": battery items")
    )
    for (sheet in c("sata_b", "bat_2")) {
      expect_false(
        any(c("sata_a", "bat_1") %in% sheet_text(out, sheet)),
        label = paste0(lbl, ": no dropped item on ", sheet)
      )
    }

    fresh_path(out)
    d <- set_all_na(d, "bat_2")

    w <- expect_warning(
      crosstab_quiet(
        d,
        vars = c(q1, sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_all_na_dropped"
    )

    msg <- conditionMessage(w)
    first <- regexpr("bat_1", msg, fixed = TRUE)
    second <- regexpr("bat_2", msg, fixed = TRUE)
    expect_true(first > 0L, label = paste0(lbl, ": names bat_1"))
    expect_true(second > first, label = paste0(lbl, ": bat_2 after bat_1"))
    expect_identical(
      data_sheets(out),
      c("q1", "sata_b", "bat_3"),
      label = paste0(lbl, ": sheets, bat_2 dropped too")
    )
    bat_a_col <- sheet_col_a(out, "bat_3")
    expect_identical(
      bat_a_col[[1L]],
      bat_preface,
      label = paste0(lbl, ": bat_3")
    )
    expect_true("bat_3" %in% bat_a_col, label = paste0(lbl, ": bat_3 item"))
    expect_false(
      any(c("bat_1", "bat_2") %in% sheet_text(out, "bat_3")),
      label = paste0(lbl, ": no dropped battery item")
    )
  }
})

test_that("export_crosstab() drops a group whose every item is all-NA (XX-15)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    lbl <- paste0("export_crosstab(), ", nm)
    d <- set_all_na(cover_design(designs[[nm]]), c("bat_1", "bat_2", "bat_3"))

    w <- expect_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_all_na_dropped"
    )

    pos <- vapply(
      c("bat_1", "bat_2", "bat_3"),
      function(v) as.integer(regexpr(v, conditionMessage(w), fixed = TRUE)),
      integer(1L)
    )
    expect_true(all(pos > 0L), label = paste0(lbl, ": names every item"))
    expect_false(is.unsorted(pos), label = paste0(lbl, ": input order"))
    expect_identical(result, out, label = paste0(lbl, ": the path"))
    expect_identical(data_sheets(out), "q1", label = paste0(lbl, ": sheets"))
  }
})

test_that("export_crosstab() drops a variable all-NA inside the domain only (XX-16)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    lbl <- paste0("export_crosstab(), ", nm)
    d <- add_dom_na(add_gen_fixture(designs[[nm]]))
    d_dom <- d
    d_dom@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d_dom@data$group == "A"

    fresh_path(out)
    w <- expect_warning(
      crosstab_quiet(
        d_dom,
        vars = c(q1, dom_na),
        banner = gen,
        file_name = out,
        min_eff_n = 0
      ),
      class = "surveyreports_warning_all_na_dropped"
    )
    expect_match(
      conditionMessage(w),
      "dom_na",
      fixed = TRUE,
      label = paste0(lbl, ": names dom_na")
    )
    expect_identical(data_sheets(out), "q1", label = paste0(lbl, ": domain"))

    fresh_path(out)
    expect_no_warning(
      crosstab_quiet(
        d,
        vars = c(q1, dom_na),
        banner = gen,
        file_name = out,
        min_eff_n = 0
      )
    )
    expect_identical(
      data_sheets(out),
      c("q1", "dom_na"),
      label = paste0(lbl, ": no domain")
    )
  }
})

# 28. The withheld notices -----------------------------------------------------
# The floor reaches the crossed cells of an interaction. Three warnings report
# what the floor did, after the all-NA drop, and `withheld_note` decides where
# the withheld lines are written: on the About sheet, under each table, or
# nowhere (spec 3.5, spec 3.11, spec 3.14, spec 3.18).

# The oracle of each crossed gen x reg cell, from surveycore, over a column
# built here from the two fixtures' value labels.
cross_oracle <- function(d) {
  gen_lab <- c("Male", "Female")[d@data$gen]
  reg_lab <- c("North", "South")[d@data$reg]
  d@data$cross <- paste(gen_lab, reg_lab, sep = " × ")
  ref <- suppressWarnings(
    surveycore::get_effective_n(d, group = cross),
    classes = c(
      "surveycore_warning_small_cell",
      "surveycore_warning_nonprob_srs_fallback"
    )
  )
  tibble::tibble(level = as.character(ref$cross), n_eff = ref$n_eff)
}

# A floor between the smallest crossed cell and the next one, rounded to a
# whole number, so at least one cell falls below it and at least one clears
# it on every design.
cross_floor <- function(ref) {
  sorted <- sort(ref$n_eff)
  round((sorted[[1L]] + sorted[[2L]]) / 2)
}

# Writes the q1 crosstab of the gen and reg fixtures, crossed, at a floor.
write_crossed_at <- function(d, path, min_eff_n, ...) {
  fresh_path(path)
  crosstab_quiet(
    d,
    vars = q1,
    banner = c(gen, reg),
    interactions = list(c("gen", "reg")),
    file_name = path,
    min_eff_n = min_eff_n,
    ...
  )
}

test_that("export_crosstab() withholds a crossed cell below the floor (XW-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_reg_fixture(add_gen_fixture(designs[[nm]]))
    ref <- cross_oracle(d)
    floor_n <- cross_floor(ref)
    below <- ref$level[ref$n_eff < floor_n]
    above <- ref$level[ref$n_eff >= floor_n]
    expect_gt(length(below), 0L, label = paste0(nm, ": a cell below"))
    expect_gt(length(above), 0L, label = paste0(nm, ": a cell above"))

    suppressWarnings(
      write_crossed_at(d, out, floor_n),
      classes = "surveyreports_warning_subgroup_withheld"
    )

    headings <- heading_cells(out, "q1")
    expect_false(
      any(below %in% headings),
      label = paste0(nm, ": no below-floor crossed heading")
    )
    expect_true(
      all(above %in% headings),
      label = paste0(nm, ": every surviving crossed heading")
    )
  }
})

# The expected withheld line of one subgroup, built here from the wording of
# spec 3.14: the subgroup, its banner variable and its effective N at one
# decimal, and no raw N.
withheld_line <- function(level, banner_var, n_eff, floor_n) {
  paste0(
    "\"",
    level,
    "\" (",
    banner_var,
    ") withheld: effective sample size ",
    formatC(n_eff, format = "f", digits = 1L),
    ", below the minimum of ",
    floor_n,
    "."
  )
}

# The withheld lines of the About sheet: column B of each `Not shown` row.
about_withheld <- function(path) {
  about <- about_sheet(path)
  about$B[about$A %in% "Not shown"]
}

# The line rows of the About sheet's withheld block, read by position: every
# row from the one under `Minimum effective sample size` down to the blank
# row that closes the block. Column A of each should read `Not shown`.
about_withheld_rows <- function(path) {
  about <- about_sheet(path)
  first <- match("Minimum effective sample size", about$A) + 1L
  blank <- which(is.na(about$A) & is.na(about$B))
  last <- min(blank[blank > first]) - 1L
  about[seq.int(first, last), ]
}

# Whether any cell of columns A or B of an About frame holds `text`.
about_holds <- function(about, text) {
  any(grepl(text, c(about$A, about$B), fixed = TRUE))
}

test_that("export_crosstab() names the subgroup, banner and effective N in each line (XW-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    female <- gen_oracle(d, "Female")
    expected <- withheld_line("Female", "gen", female$n_eff, gen_floor)

    w <- expect_warning(
      write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )

    lines <- about_withheld(out)
    expect_identical(lines, expected, label = paste0(nm, ": the About line"))
    expect_match(
      conditionMessage(w),
      expected,
      fixed = TRUE,
      label = paste0(nm, ": the warning line")
    )
    for (text in c(lines, conditionMessage(w))) {
      expect_no_match(
        text,
        paste0("\\b", female$n, "\\b"),
        label = paste0(nm, ": no raw N")
      )
    }
  }
})

test_that("export_crosstab() warns once per call for withheld subgroups (XV-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    female <- gen_oracle(d, "Female")

    for (note in c("once", "every", "none")) {
      lbl <- paste0(nm, ", withheld_note = ", note)
      fresh_path(out)
      w <- expect_warning(
        result <- crosstab_quiet(
          d,
          vars = q1,
          banner = gen,
          file_name = out,
          min_eff_n = gen_floor,
          withheld_note = note
        ),
        class = "surveyreports_warning_subgroup_withheld"
      )
      msg <- conditionMessage(w)
      expect_match(msg, "\"Female\" (gen)", fixed = TRUE, label = lbl)
      expect_match(
        msg,
        formatC(female$n_eff, format = "f", digits = 1L),
        fixed = TRUE,
        label = paste0(lbl, ": effective N")
      )
      expect_identical(result, out, label = paste0(lbl, ": the path"))
      expect_true(file.exists(out), label = paste0(lbl, ": file exists"))

      fresh_path(out)
      msgs <- testthat::capture_warnings(
        crosstab_quiet(
          d,
          vars = q1,
          banner = gen,
          file_name = out,
          min_eff_n = gen_floor,
          withheld_note = note
        )
      )
      expect_length(msgs, 1L)
    }
  }

  expect_snapshot(
    export_crosstab(
      add_gen_fixture(designs$taylor),
      vars = q1,
      banner = gen,
      file_name = out,
      min_eff_n = gen_floor
    )
  )
})

# The full sample's effective N, from surveycore.
full_oracle <- function(d) {
  suppressWarnings(
    surveycore::get_effective_n(d),
    classes = c(
      "surveycore_warning_small_cell",
      "surveycore_warning_nonprob_srs_fallback"
    )
  )$n_eff
}

test_that("export_crosstab() warns when every level of a banner is withheld (XV-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    male <- gen_oracle(d, "Male")$n_eff
    full <- full_oracle(d)
    # Above every gen level and below the full sample, so the full-sample
    # warning is not due.
    floor_n <- round((male + full) / 2)
    expect_true(male < floor_n && floor_n <= full, label = nm)

    w <- expect_warning(
      expect_warning(
        result <- write_gen_q1(d, out, floor_n),
        class = "surveyreports_warning_subgroup_withheld"
      ),
      class = "surveyreports_warning_banner_all_withheld"
    )

    expect_match(conditionMessage(w), "gen", fixed = TRUE, label = nm)
    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    headings <- heading_cells(out, "q1")
    expect_true("Total" %in% headings, label = paste0(nm, ": Total kept"))
    expect_false(
      any(c("Male", "Female") %in% headings),
      label = paste0(nm, ": no gen column")
    )
    expect_false(
      "Gender" %in% spanner_cells(out, "q1"),
      label = paste0(nm, ": no gen spanner")
    )
  }

  d <- add_gen_fixture(designs$taylor)
  floor_n <- round((gen_oracle(d, "Male")$n_eff + full_oracle(d)) / 2)
  expect_snapshot(
    export_crosstab(
      d,
      vars = q1,
      banner = gen,
      file_name = out,
      min_eff_n = floor_n
    )
  )
})

test_that("export_crosstab() warns when the full sample is below the floor (XV-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  ref <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    floor_n <- ceiling(full_oracle(d)) + 1

    w <- expect_warning(
      expect_warning(
        expect_warning(
          result <- write_gen_q1(d, out, floor_n),
          class = "surveyreports_warning_subgroup_withheld"
        ),
        class = "surveyreports_warning_banner_all_withheld"
      ),
      class = "surveyreports_warning_full_sample_below_min"
    )
    write_gen_q1(d, ref, 0)

    expect_match(
      conditionMessage(w),
      formatC(full_oracle(d), format = "f", digits = 1L),
      fixed = TRUE,
      label = paste0(nm, ": the full-sample effective N")
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
    # Nothing is removed for the full sample: its column is written in full.
    total <- column_cells(out, "q1", "Total")
    expect_gt(length(total), 1L)
    expect_identical(
      total,
      column_cells(ref, "q1", "Total"),
      label = paste0(nm, ": the Total column")
    )

    fresh_path(out)
    msgs <- testthat::capture_warnings(write_gen_q1(d, out, floor_n))
    expect_identical(
      sum(grepl("full sample", msgs, fixed = TRUE)),
      1L,
      label = paste0(nm, ": one full-sample warning")
    )
  }

  d <- add_gen_fixture(designs$taylor)
  expect_snapshot(
    export_crosstab(
      d,
      vars = q1,
      banner = gen,
      file_name = out,
      min_eff_n = ceiling(full_oracle(d)) + 1
    )
  )
})

# The class of a captured warning, read from the fixed wording of its first
# line. testing.md forbids a calling handler in a test, and
# testthat::capture_warnings() returns the messages in order but not the
# conditions, so each class is matched by a phrase only its message holds.
warning_class_of <- function(msg) {
  phrases <- c(
    role_dropped = "for a non-substantive role",
    unknown_role = "with an unrecognized role",
    missing_variable_label = "no variable_label",
    all_na_dropped = "with no non-missing value",
    subgroup_withheld = "are withheld.",
    banner_all_withheld = "Every subgroup of",
    full_sample_below_min = "of the full sample"
  )
  first_line <- strsplit(msg, "\n", fixed = TRUE)[[1L]][[1L]]
  hit <- vapply(
    phrases,
    function(p) grepl(p, first_line, fixed = TRUE),
    logical(1L)
  )
  paste0("surveyreports_warning_", names(phrases)[hit])
}

test_that("export_crosstab() raises the seven warnings in the order of spec 3.11 (XV-11)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  expected <- paste0(
    "surveyreports_warning_",
    c(
      "role_dropped",
      "unknown_role",
      "missing_variable_label",
      "all_na_dropped",
      "subgroup_withheld",
      "banner_all_withheld",
      "full_sample_below_min"
    )
  )

  for (nm in names(designs)) {
    fresh_path(out)
    d <- surveycore::set_var_extra(
      add_nolab_fixture(guard_design(designs[[nm]])),
      q2 = list(role = "free_text"),
      q1 = list(role = "banana")
    )
    # A floor above the full sample, so all three withholding warnings fire.
    expect_lt(full_oracle(d), 1000, label = nm)

    msgs <- testthat::capture_warnings(
      crosstab_quiet(
        d,
        vars = c(q1, q2, all_na_var),
        banner = nolab,
        file_name = out,
        min_eff_n = 1000
      )
    )

    classes <- vapply(msgs, warning_class_of, character(1L), USE.NAMES = FALSE)
    expect_identical(classes, expected, label = paste0(nm, ": the order"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
  }
})

test_that("export_crosstab() raises no condition of the renamed class (XV-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  # Built in two parts, so a search of the tree for the old class finds no
  # use of it (spec VIII).
  old_class <- paste0("surveyreports_warning_subgroup_", "suppressed")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    w <- expect_warning(
      write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )

    expect_false(inherits(w, old_class), label = paste0(nm, ": not the old"))
  }
})

test_that("export_crosstab() raises no warning when every subgroup clears the floor (XV-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    # No column carries a role, and every group level clears a floor of 10.
    d <- guard_design(designs[[nm]])

    expect_no_warning(
      result <- crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = group,
        file_name = out,
        min_eff_n = 10
      )
    )
    expect_identical(result, out, label = paste0(nm, ": the path"))
  }
})

test_that("export_crosstab() lets no surveycore small-cell warning through (XV-13)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    # Female holds 20 rows, or fewer on twophase, so its effective N is
    # below 30, the raw-N threshold of surveycore's small-cell warning.
    expect_lt(gen_oracle(d, "Female")$n_eff, 30, label = nm)

    expect_no_warning(
      write_gen_q1(d, out, 0),
      class = "surveycore_warning_small_cell"
    )
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
  }
})

# Writes the gen-fixture crosstab of `vars` at gen_floor under one
# withheld_note value. Female is withheld, so the call warns; the warning is
# asserted by XV-03 and absorbed here.
write_gen_note <- function(d, path, note, vars, layout = "per_question") {
  fresh_path(path)
  suppressWarnings(
    crosstab_quiet(
      d,
      vars = tidyselect::all_of(vars),
      banner = gen,
      file_name = path,
      layout = layout,
      min_eff_n = gen_floor,
      withheld_note = note
    ),
    classes = "surveyreports_warning_subgroup_withheld"
  )
}

# The last written cell of column A of one sheet.
last_col_a <- function(path, sheet) {
  col_a <- sheet_col_a(path, sheet)
  col_a[[max(which(!is.na(col_a)))]]
}

test_that("export_crosstab() writes the withheld lines once, on the About sheet (XW-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    line <- withheld_line(
      "Female",
      "gen",
      gen_oracle(d, "Female")$n_eff,
      gen_floor
    )

    write_gen_note(d, out, "once", c("q1", "q2"))

    expect_identical(about_withheld(out), line, label = paste0(nm, ": About"))
    for (sheet in c("q1", "q2")) {
      expect_false(
        any(grepl("withheld", sheet_text(out, sheet), fixed = TRUE)),
        label = paste0(nm, ": no line under ", sheet)
      )
    }
  }
})

test_that("export_crosstab() writes the withheld lines under each table at withheld_note = every (XW-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    line <- withheld_line(
      "Female",
      "gen",
      gen_oracle(d, "Female")$n_eff,
      gen_floor
    )

    write_gen_note(d, out, "every", c("q1", "q2"))
    for (sheet in c("q1", "q2")) {
      expect_identical(
        last_col_a(out, sheet),
        line,
        label = paste0(nm, ": the block ", sheet, " ends with the line")
      )
    }
    about <- about_sheet(out)
    expect_false(
      "Subgroups not shown" %in% about$A,
      label = paste0(nm, ": no withheld block on the About sheet")
    )
    # With no withheld block, the glossary entry is where the reader finds
    # the minimum (spec 3.15, gap 14).
    expect_identical(
      about_glossary(about)[["Why a column is missing"]],
      glossary_missing_text(gen_floor),
      label = paste0(nm, ": the entry states the minimum")
    )
    expect_false(
      about_holds(about, "listed above"),
      label = paste0(nm, ": no `listed above`")
    )

    # The SATA and battery routes end their blocks the same way.
    group_vars <- c("sata_a", "sata_b", "sata_c", "bat_1", "bat_2", "bat_3")
    write_gen_note(d, out, "every", group_vars)
    for (sheet in c("sata_a", "bat_1")) {
      expect_identical(
        last_col_a(out, sheet),
        line,
        label = paste0(nm, ": the block ", sheet, " ends with the line")
      )
    }

    # On the stacked sheet each block carries its own copy.
    write_gen_note(d, out, "every", c("q1", "q2"), layout = "stacked")
    expect_identical(
      sum(sheet_col_a(out, "Crosstab") %in% line),
      2L,
      label = paste0(nm, ": one line per stacked block")
    )
  }
})

test_that("export_crosstab() writes no withheld line at withheld_note = none (XW-11)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    fresh_path(out)
    expect_warning(
      crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = gen,
        file_name = out,
        min_eff_n = gen_floor,
        withheld_note = "none"
      ),
      class = "surveyreports_warning_subgroup_withheld"
    )

    for (sheet in openxlsx2::wb_load(out)$sheet_names) {
      expect_false(
        any(grepl("withheld", sheet_text(out, sheet), fixed = TRUE)),
        label = paste0(nm, ": no line on ", sheet)
      )
    }
    # The column is still withheld at "none".
    expect_false(
      "Female" %in% heading_cells(out, "q1"),
      label = paste0(nm, ": Female withheld")
    )
    # The glossary entry states the minimum, as at "every" (spec 3.15,
    # gap 14).
    about <- about_sheet(out)
    expect_identical(
      about_glossary(about)[["Why a column is missing"]],
      glossary_missing_text(gen_floor),
      label = paste0(nm, ": the entry states the minimum")
    )
    expect_false(
      about_holds(about, "listed above"),
      label = paste0(nm, ": no `listed above`")
    )
  }
})

test_that("export_crosstab() names an interaction whose every cell is withheld (XV-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_reg_fixture(add_gen_fixture(designs[[nm]]))
    ref <- cross_oracle(d)
    male <- gen_oracle(d, "Male")$n_eff
    # Above every crossed cell and below Male, so the interaction empties
    # and the gen column group keeps Male.
    floor_n <- round((max(ref$n_eff) + male) / 2)
    expect_true(max(ref$n_eff) < floor_n && floor_n <= male, label = nm)

    w <- expect_warning(
      expect_warning(
        write_crossed_at(d, out, floor_n),
        class = "surveyreports_warning_subgroup_withheld"
      ),
      class = "surveyreports_warning_banner_all_withheld"
    )

    expect_match(
      conditionMessage(w),
      "gen × reg",
      fixed = TRUE,
      label = paste0(nm, ": names the interaction")
    )
    expect_false(
      "Gender × Region" %in% spanner_cells(out, "q1"),
      label = paste0(nm, ": no interaction spanner")
    )
    expect_true(
      "Male" %in% heading_cells(out, "q1"),
      label = paste0(nm, ": Male kept")
    )
  }
})

test_that("export_crosstab() lists a withheld crossed cell on the About sheet (XW-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_reg_fixture(add_gen_fixture(designs[[nm]]))
    ref <- cross_oracle(d)
    floor_n <- cross_floor(ref)
    below <- ref[ref$n_eff < floor_n, ]
    expected <- withheld_line(
      below$level,
      "gen × reg",
      below$n_eff,
      floor_n
    )

    suppressWarnings(
      write_crossed_at(d, out, floor_n),
      classes = "surveyreports_warning_subgroup_withheld"
    )

    lines <- about_withheld(out)
    expect_true(
      all(expected %in% lines),
      label = paste0(nm, ": each crossed cell is listed")
    )
    expect_true(
      any(grepl("(gen)", lines, fixed = TRUE)),
      label = paste0(nm, ": the banner level is listed too")
    )
    # Each line sits in column B with `Not shown` in column A, on every line
    # and not on the first only (spec 3.14, gap 9c).
    rows <- about_withheld_rows(out)
    expect_identical(
      rows$A,
      rep("Not shown", length(lines)),
      label = paste0(nm, ": Not shown on every line")
    )
    expect_identical(rows$B, lines, label = paste0(nm, ": the lines in B"))
    expect_gt(nrow(rows), 1L, label = paste0(nm, ": more than one line"))
  }
})

test_that("export_crosstab() writes None when the floor withholds nothing (XA-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- guard_design(designs[[nm]])

    expect_no_warning(
      crosstab_quiet(
        d,
        vars = q1,
        banner = group,
        file_name = out,
        min_eff_n = 10
      )
    )

    about <- about_sheet(out)
    expect_true(
      "Subgroups not shown" %in% about$A,
      label = paste0(nm, ": the block")
    )
    expect_identical(
      about$B[about$A %in% "Minimum effective sample size"],
      "10",
      label = paste0(nm, ": the minimum")
    )
    expect_identical(about_withheld(out), "None", label = paste0(nm, ": None"))
    # One row, `Not shown` in column A beside `None` in column B (spec 3.14).
    rows <- about_withheld_rows(out)
    expect_identical(
      rows$A,
      "Not shown",
      label = paste0(nm, ": Not shown beside None")
    )
    expect_identical(rows$B, "None", label = paste0(nm, ": one None row"))
  }
})

test_that("export_crosstab() states the minimum in the glossary at every withheld_note value (XA-05b)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  # The XA-05 call at three withheld_note values, then a fractional floor.
  cases <- list(
    list(min_eff_n = 50, note = "once", shown = "50"),
    list(min_eff_n = 50, note = "every", shown = "50"),
    list(min_eff_n = 50, note = "none", shown = "50"),
    list(min_eff_n = 12.5, note = "every", shown = "12.5")
  )

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])

    for (case in cases) {
      lbl <- paste0(
        nm,
        ", min_eff_n = ",
        case$shown,
        ", withheld_note = ",
        case$note
      )
      fresh_path(out)

      # The test-spec row says a floor of 50 withholds nothing. On this
      # fixture it withholds `B` (effective N 47.7), and on twophase every
      # `group` level. The entry text does not depend on that, so the two
      # withholding warnings are absorbed here; XV-03 and XV-04 assert them.
      suppressWarnings(
        crosstab_quiet(
          d,
          vars = q1,
          banner = group,
          file_name = out,
          min_eff_n = case$min_eff_n,
          withheld_note = case$note
        ),
        classes = c(
          "surveyreports_warning_subgroup_withheld",
          "surveyreports_warning_banner_all_withheld"
        )
      )

      about <- about_sheet(out)
      entry <- about_glossary(about)[["Why a column is missing"]]
      expect_identical(
        entry,
        glossary_missing_text(case$min_eff_n),
        label = paste0(lbl, ": the entry text")
      )
      expect_match(
        entry,
        paste0(
          "The minimum for this workbook is an effective sample size of ",
          case$shown,
          "."
        ),
        fixed = TRUE,
        label = paste0(lbl, ": the minimum as a number")
      )
      expect_false(
        about_holds(about, "listed above"),
        label = paste0(lbl, ": no `listed above`")
      )
      # Only "once" writes the withheld block, so under "every" and "none"
      # the About sheet states the minimum in the entry alone.
      expect_identical(
        "Subgroups not shown" %in% about$A,
        identical(case$note, "once"),
        label = paste0(lbl, ": the withheld block")
      )
    }
  }
})

test_that("export_crosstab() writes no withheld block at min_eff_n = 0 (XA-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- guard_design(designs[[nm]])

    crosstab_quiet(d, vars = q1, banner = group, file_name = out, min_eff_n = 0)

    about <- about_sheet(out)
    expect_false(
      "Subgroups not shown" %in% about$A,
      label = paste0(nm, ": no withheld block")
    )
    expect_true(
      "What these numbers mean" %in% about$A,
      label = paste0(nm, ": the glossary")
    )
  }
})

# TRUE when the cell's resolved font is bold. A cell with no style of its own
# takes style 0, the workbook default. test-export-topline.R holds the same
# helper; helper-export.R is outside this change.
cell_is_bold <- function(wb, sheet, dims) {
  style <- unname(openxlsx2::wb_get_cell_style(wb, sheet, dims))
  style_id <- if (is.na(style) || !nzchar(style)) 0L else as.integer(style)
  xf <- wb$styles_mgr$styles$cellXfs[[style_id + 1L]]
  font_id <- as.integer(sub('.*fontId="([0-9]+)".*', "\\1", xf))
  font <- wb$styles_mgr$styles$fonts[[font_id + 1L]]
  grepl("<b/>|<b val=\"1\"/>|<b val=\"true\"/>", font)
}

test_that("export_crosstab() writes the About header and block headings bold (XA-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  headings <- c("Subgroups not shown", "What these numbers mean")

  for (nm in names(designs)) {
    d <- surveycore::set_dataset_metadata(
      add_gen_fixture(designs[[nm]]),
      survey_name = "Test Survey",
      data_name = "Test Data v2",
      vendor = "Test Vendor",
      field_start = "2024-03-01",
      field_end = "2024-03-31",
      field_period = "Spring 2024"
    )

    suppressWarnings(
      write_gen_q1(d, out, gen_floor),
      classes = "surveyreports_warning_subgroup_withheld"
    )

    about <- about_sheet(out)
    # The survey block has content, so all three blocks are present.
    expect_identical(about$A[1:2], c("Key", "Survey"), label = nm)
    expect_true(all(headings %in% about$A), label = paste0(nm, ": blocks"))

    wb <- openxlsx2::wb_load(out)
    for (dims in c("A1", "B1")) {
      expect_true(
        cell_is_bold(wb, "About", dims),
        label = paste0(nm, ": ", dims, " is bold")
      )
    }
    for (h in headings) {
      expect_true(
        cell_is_bold(wb, "About", paste0("A", match(h, about$A))),
        label = paste0(nm, ": ", h, " is bold")
      )
    }
    min_row <- match("Minimum effective sample size", about$A)
    for (dims in paste0(c("A", "B"), min_row)) {
      expect_false(
        cell_is_bold(wb, "About", dims),
        label = paste0(nm, ": ", dims, " is not bold")
      )
    }
  }
})

# A one-row design: surveycore builds no design from one row, so the domain
# keeps one row, a phase-2 row so that the twophase design tabulates it.
# surveycore warns that the banner then holds one level; that warning is
# fixture setup and is muffled.
one_row_design <- function(d) {
  d <- guard_design(d)
  k <- which(d@data$in_phase2)[[1L]]
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- seq_len(nrow(d@data)) == k
  d
}

test_that("export_crosstab() withholds every subgroup of a one-row design (XX-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- one_row_design(designs[[nm]])
    expect_identical(full_oracle(d), 1, label = paste0(nm, ": one row"))

    expect_warning(
      expect_warning(
        expect_warning(
          result <- suppressWarnings(
            crosstab_quiet(d, vars = q1, banner = group, file_name = out),
            classes = "surveycore_warning_single_level"
          ),
          class = "surveyreports_warning_subgroup_withheld"
        ),
        class = "surveyreports_warning_banner_all_withheld"
      ),
      class = "surveyreports_warning_full_sample_below_min"
    )

    expect_identical(result, out, label = paste0(nm, ": the path"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    expect_false(
      any(c("A", "B", "C") %in% heading_cells(out, "q1")),
      label = paste0(nm, ": no group column")
    )
  }
})

test_that("export_crosstab() writes no column and no entry for an unused factor level (XX-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- guard_design(designs[[nm]])
    d@data$fb <- factor(
      rep(c("Low", "Medium", "High"), length.out = nrow(d@data)),
      levels = c("Low", "Medium", "High", "Unused")
    )
    d <- surveycore::set_var_label(d, fb = "Factor banner")

    # A floor of 10 withholds a level with no rows if one reaches the floor.
    expect_no_warning(
      crosstab_quiet(d, vars = q1, banner = fb, file_name = out, min_eff_n = 10)
    )

    expect_false(
      "Unused" %in% heading_cells(out, "q1"),
      label = paste0(nm, ": no column")
    )
    expect_identical(about_withheld(out), "None", label = paste0(nm, ": None"))
    expect_false(
      any(grepl("Unused", sheet_text(out, "About"), fixed = TRUE)),
      label = paste0(nm, ": no entry")
    )
  }
})

test_that("export_crosstab() never mentions an unobserved value label (XX-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- surveycore::set_val_labels(
      add_gen_fixture(designs[[nm]]),
      gen = c(Male = 1, Female = 2, Other = 3)
    )

    expect_no_warning(
      crosstab_quiet(
        d,
        vars = q1,
        banner = gen,
        file_name = out,
        min_eff_n = 10
      )
    )

    for (sheet in openxlsx2::wb_load(out)$sheet_names) {
      expect_false(
        any(grepl("Other", sheet_text(out, sheet), fixed = TRUE)),
        label = paste0(nm, ": no mention on ", sheet)
      )
    }
    expect_identical(about_withheld(out), "None", label = paste0(nm, ": None"))
  }
})

test_that("export_crosstab() withholds one unlabelled code as a missing label (XX-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    d@data$gen <- c(rep(1, 150), rep(2, 30), rep(3, 20))
    d <- suppressWarnings(
      surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2)),
      classes = "surveycore_warning_missing_labels"
    )
    ref <- suppressWarnings(
      surveycore::get_effective_n(d, group = gen),
      classes = c(
        "surveycore_warning_small_cell",
        "surveycore_warning_nonprob_srs_fallback"
      )
    )
    unlabelled <- ref[is.na(ref$gen), ]
    # Its true unweighted count: the code-3 rows the design tabulates.
    tabulated <- if (nm == "twophase") d@data$in_phase2 else TRUE
    expect_identical(
      unlabelled$n,
      sum(d@data$gen == 3 & tabulated),
      label = paste0(nm, ": the true count")
    )

    w <- expect_warning(
      write_gen_q1(d, out, gen_floor),
      class = "surveyreports_warning_subgroup_withheld"
    )

    line <- paste0(
      "[no value label] (gen) withheld: effective sample size ",
      formatC(unlabelled$n_eff, format = "f", digits = 1L),
      ", below the minimum of ",
      gen_floor,
      "."
    )
    expect_true(line %in% about_withheld(out), label = paste0(nm, ": About"))
    expect_match(conditionMessage(w), line, fixed = TRUE, label = nm)
    expect_false(
      any(grepl("\"3\"", about_withheld(out), fixed = TRUE)),
      label = paste0(nm, ": not named as code 3")
    )
  }
})

test_that("export_crosstab() skips a self-banner column for its own variable (XX-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    d <- guard_design(designs[[nm]])

    expect_no_warning(
      crosstab_quiet(
        d,
        vars = c(q1, q2),
        banner = q1,
        file_name = out,
        min_eff_n = 10
      )
    )

    expect_false(
      "Question one" %in% spanner_cells(out, "q1"),
      label = paste0(nm, ": skipped for q1")
    )
    expect_true(
      "Question one" %in% spanner_cells(out, "q2"),
      label = paste0(nm, ": kept for q2")
    )
  }
})

# 29. Label columns and sample sizes -------------------------------------------
# A block has one label column, `Response` or `Item`, or two for a battery,
# `Item` then `Response`. Two sample-size rows, `Unweighted sample size` and
# `Effective sample size`, sit under the heading row by default, below the
# estimates under sample_size_display = "bottom", and nowhere under "none".
# They replace the per-response N column (spec 3.4, spec 3.16).

ss_labels <- c("Unweighted sample size", "Effective sample size")

# The rows of one block below its heading row that hold an estimate: column A
# is not a sample-size label, and the first data column, `first_col`, holds a
# value.
estimate_rows <- function(rows, h, first_col) {
  below <- rows[seq.int(h + 1L, nrow(rows)), , drop = FALSE]
  keep <- !as.character(below[[1L]]) %in% ss_labels &
    !is.na(below[[first_col]])
  below[keep, , drop = FALSE]
}

# The surveycore warnings an oracle call raises on the fixture designs. They
# are about the oracle call, not about the code under test.
oracle_classes <- c(
  "surveycore_warning_small_cell",
  "surveycore_warning_nonprob_srs_fallback"
)

# The get_freqs() frame of one variable: its response values, in order, and
# the unweighted count of each.
oracle_freqs <- function(d, var) {
  suppressWarnings(
    surveycore::get_freqs(d, !!rlang::sym(var)),
    classes = oracle_classes
  )
}

# The number of response values of one variable, from surveycore.
n_values <- function(d, var) {
  nrow(oracle_freqs(d, var))
}

test_that("export_crosstab() renders a SATA block and a battery block in their own shapes (XD-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  sata <- c("sata_a", "sata_b", "sata_c")
  bat <- c("bat_1", "bat_2", "bat_3")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    shape <- list()
    for (vars in list(sata, bat)) {
      fresh_path(out)
      crosstab_quiet(
        d,
        vars = tidyselect::all_of(vars),
        banner = gen,
        file_name = out,
        min_eff_n = 0
      )
      rows <- sheet_rows(out, vars[[1L]])
      h <- heading_index(rows, "Item")
      heading <- as.character(unlist(rows[h, ]))
      first_col <- match("Total", heading)
      shape[[vars[[1L]]]] <- list(
        labels = heading[seq_len(first_col - 1L)],
        n_rows = nrow(estimate_rows(rows, h, first_col))
      )
    }

    expect_identical(shape$sata_a$labels, "Item", label = paste0(nm, ": SATA"))
    expect_identical(shape$sata_a$n_rows, 3L, label = paste0(nm, ": SATA rows"))
    expect_identical(
      shape$bat_1$labels,
      c("Item", "Response"),
      label = paste0(nm, ": battery")
    )
    expect_identical(
      shape$bat_1$n_rows,
      sum(vapply(bat, function(v) n_values(d, v), integer(1L))),
      label = paste0(nm, ": battery rows")
    )
    expect_gt(shape$bat_1$n_rows, shape$sata_a$n_rows)
  }
})

test_that("export_crosstab() writes the two sample-size rows under the heading row (XS-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    crosstab_quiet(
      guard_design(designs[[nm]]),
      vars = q1,
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    col_a <- sheet_col_a(out, "q1")
    h <- match("Response", col_a)
    expect_identical(col_a[h + 1:2], ss_labels, label = nm)
  }
})

test_that("export_crosstab() rejects the removed arguments as unused (XE-07)", {
  skip_if_not_installed("surveycore")
  d <- guard_design(make_all_designs(seed = 42)$taylor)
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      pub_type = "external"
    ),
    "unused argument"
  )
  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      show_n = FALSE
    ),
    "unused argument"
  )
  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      show_eff_n = TRUE
    ),
    "unused argument"
  )
  expect_false(file.exists(out))
})

# Writes the q1 crosstab of a guard-design over banner = group, with no
# subgroup withheld, and returns the path. `...` reaches export_crosstab().
write_group_q1 <- function(d, path, ...) {
  fresh_path(path)
  crosstab_quiet(
    guard_design(d),
    vars = q1,
    banner = group,
    file_name = path,
    min_eff_n = 0,
    ...
  )
  path
}

# The resolved font of one cell: whether it is italic, and its size. A cell
# with no style of its own takes style 0, the workbook default.
cell_font <- function(wb, sheet, dims) {
  style <- unname(openxlsx2::wb_get_cell_style(wb, sheet, dims))
  style_id <- if (is.na(style) || !nzchar(style)) 0L else as.integer(style)
  xf <- wb$styles_mgr$styles$cellXfs[[style_id + 1L]]
  font_id <- as.integer(sub('.*fontId="([0-9]+)".*', "\\1", xf))
  font <- wb$styles_mgr$styles$fonts[[font_id + 1L]]
  list(
    italic = grepl("<i/>|<i val=\"1\"/>|<i val=\"true\"/>", font),
    size = as.numeric(sub('.*<sz val="([0-9.]+)".*', "\\1", font))
  )
}

test_that("export_crosstab() writes both sample-size rows italic and one point smaller (XS-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    write_group_q1(designs[[nm]], out)
    col_a <- sheet_col_a(out, "q1")
    h <- match("Response", col_a)
    wb <- openxlsx2::wb_load(out)

    # The estimate cell: the Total column of the first response row.
    estimate <- cell_font(
      wb,
      "q1",
      openxlsx2::wb_dims(rows = h + 3L, cols = 2L)
    )
    expect_false(estimate$italic, label = paste0(nm, ": estimate not italic"))

    # The label cell and the four data cells (Total, A, B, C) of each row.
    for (row in h + 1:2) {
      for (col in 1:5) {
        font <- cell_font(wb, "q1", openxlsx2::wb_dims(rows = row, cols = col))
        lbl <- paste0(nm, ": row ", row, ", column ", col)
        expect_true(font$italic, label = paste(lbl, "italic"))
        expect_equal(font$size, estimate$size - 1, label = paste(lbl, "size"))
      }
    }
  }
})

test_that("export_crosstab() matches the subgroup counts to surveycore (XS-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    write_group_q1(d, out)
    rows <- sheet_rows(out, "q1")
    h <- heading_index(rows)
    heading <- as.character(unlist(rows[h, ]))
    ref <- suppressWarnings(
      surveycore::get_effective_n(d, group = group),
      classes = oracle_classes
    )

    for (level in c("A", "B", "C")) {
      j <- match(level, heading)
      k <- match(level, as.character(ref$group))
      lbl <- paste0(nm, ": ", level)
      expect_identical(
        as.integer(rows[[j]][[h + 1L]]),
        as.integer(ref$n[[k]]),
        label = paste(lbl, "n")
      )
      expect_equal(
        as.numeric(rows[[j]][[h + 2L]]),
        round(ref$n_eff[[k]], 1L),
        tolerance = 1e-8,
        label = paste(lbl, "n_eff")
      )
    }
  }
})

test_that("export_crosstab() writes the full sample's counts in the Total column (XS-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    write_group_q1(d, out, show_total = TRUE)
    rows <- sheet_rows(out, "q1")
    h <- heading_index(rows)
    j <- match("Total", as.character(unlist(rows[h, ])))
    ref <- suppressWarnings(
      surveycore::get_effective_n(d),
      classes = oracle_classes
    )

    expect_identical(
      as.integer(rows[[j]][[h + 1L]]),
      as.integer(ref$n[[1L]]),
      label = paste0(nm, ": n")
    )
    expect_equal(
      as.numeric(rows[[j]][[h + 2L]]),
      round(ref$n_eff[[1L]], 1L),
      tolerance = 1e-8,
      label = paste0(nm, ": n_eff")
    )
  }
})

test_that("export_crosstab() drops only the effective row under show_ess = FALSE (XS-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    write_group_q1(designs[[nm]], out, show_ess = FALSE)
    col_a <- sheet_col_a(out, "q1")
    h <- match("Response", col_a)

    expect_identical(col_a[[h + 1L]], ss_labels[[1L]], label = nm)
    expect_false(ss_labels[[2L]] %in% col_a, label = nm)
  }
})

test_that("export_crosstab() moves both rows below the estimates under \"bottom\" (XS-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    fresh_path(out)
    # Female is withheld, so the block ends with a withheld line, the
    # footnote the two rows must precede.
    suppressWarnings(
      crosstab_quiet(
        d,
        vars = q1,
        banner = gen,
        file_name = out,
        min_eff_n = gen_floor,
        withheld_note = "every",
        sample_size_display = "bottom"
      ),
      classes = "surveyreports_warning_subgroup_withheld"
    )

    col_a <- sheet_col_a(out, "q1")
    h <- match("Response", col_a)
    ss_at <- match(ss_labels, col_a)
    value_at <- match(as.character(oracle_freqs(d, "q1")[[1L]]), col_a)
    withheld_at <- which(grepl("withheld", col_a, fixed = TRUE))

    expect_false(anyNA(value_at), label = paste0(nm, ": every value"))
    expect_true(all(value_at > h), label = paste0(nm, ": values"))
    expect_identical(ss_at[[2L]], ss_at[[1L]] + 1L, label = nm)
    expect_true(ss_at[[1L]] > max(value_at), label = paste0(nm, ": below"))
    expect_identical(length(withheld_at), 1L, label = paste0(nm, ": line"))
    expect_true(withheld_at > ss_at[[2L]], label = paste0(nm, ": footnote"))
    expect_false(
      any(col_a[seq_len(max(value_at))] %in% ss_labels),
      label = paste0(nm, ": none above")
    )
  }
})

test_that("export_crosstab() writes no sample-size row under \"none\" (XS-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    write_group_q1(designs[[nm]], out, sample_size_display = "none")
    cells <- sheet_text(out, "q1")

    expect_true("Response" %in% cells, label = paste0(nm, ": the block"))
    expect_false(any(ss_labels %in% cells), label = nm)
  }
})

test_that("export_crosstab() writes no N column on any block shape (XS-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  sheets <- c(q1 = "Response", sata_a = "Item", bat_1 = "Item")

  for (nm in names(designs)) {
    fresh_path(out)
    crosstab_quiet(
      guard_design(designs[[nm]]),
      vars = c(q1, sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    for (sheet in names(sheets)) {
      heading <- heading_cells(out, sheet, label = sheets[[sheet]])
      heading <- heading[!is.na(heading)]
      lbl <- paste0(nm, ": ", sheet)
      expect_false("N" %in% heading, label = paste(lbl, "no N"))
      expect_identical(heading[[length(heading)]], "C", label = lbl)
    }
  }
})

test_that("export_crosstab() counts the design's rows, not the variable's answers (XS-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    d@data$q1[1:60] <- NA_character_
    expect_identical(sum(is.na(d@data$q1)), 60L)
    write_group_q1(d, out)

    rows <- sheet_rows(out, "q1")
    h <- heading_index(rows)
    heading <- as.character(unlist(rows[h, ]))
    cell_n <- as.integer(rows[[match("Total", heading)]][[h + 1L]])

    # The design's in-scope rows: the phase-2 rows on the twophase design.
    in_scope <- if (nm == "twophase") d@data$in_phase2 else TRUE
    expect_identical(
      cell_n,
      as.integer(sum(rep_len(in_scope, nrow(d@data)))),
      label = paste0(nm, ": in-scope rows")
    )
    # The response rows count the answered rows only, so they total less.
    answered <- sum(oracle_freqs(d, "q1")$n)
    expect_lt(answered, cell_n, label = paste0(nm, ": response rows"))

    # A subgroup cell ignores the variable as well.
    ref <- suppressWarnings(
      surveycore::get_effective_n(d, group = group),
      classes = oracle_classes
    )
    expect_identical(
      as.integer(rows[[match("A", heading)]][[h + 1L]]),
      as.integer(ref$n[as.character(ref$group) == "A"]),
      label = paste0(nm, ": subgroup A")
    )
  }
})

test_that("export_crosstab() leaves the second label column blank on battery sample-size rows (XS-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    crosstab_quiet(
      guard_design(designs[[nm]]),
      vars = c(bat_1, bat_2, bat_3),
      banner = group,
      file_name = out,
      min_eff_n = 0
    )

    rows <- sheet_rows(out, "bat_1")
    at <- match(ss_labels, as.character(rows[[1L]]))
    expect_false(anyNA(at), label = paste0(nm, ": both rows"))
    expect_true(all(is.na(rows[[2L]][at])), label = paste0(nm, ": blank"))
    expect_false(anyNA(rows[[3L]][at]), label = paste0(nm, ": counts"))
  }
})

# 30. Sheet properties ---------------------------------------------------------
# The single route writes no `Total` row of `100%` cells (spec 3.9). The
# column widths, the wraps, the heading row height and the freeze pane are
# fixed by the arguments, never by the cell text (spec 3.16).

test_that("export_crosstab() writes no 100% cell on any sheet (XH-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    for (layout in c("per_question", "stacked")) {
      fresh_path(out)
      crosstab_quiet(
        guard_design(designs[[nm]]),
        vars = c(q1, sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
        banner = group,
        file_name = out,
        min_eff_n = 0,
        layout = layout
      )

      for (sheet in data_sheets(out)) {
        lbl <- paste0(nm, ", ", layout, ": ", sheet)
        expect_true(
          "Response" %in%
            sheet_text(out, sheet) ||
            "Item" %in% sheet_text(out, sheet),
          label = paste(lbl, "a block")
        )
        expect_false("100%" %in% sheet_text(out, sheet), label = lbl)
      }
    }
  }
})

# The stored width of each column of one sheet, read after wb_load(), as the
# integer part. openxlsx2 1.28 stores a set width w as w + 0.711, so the
# integer part is the width that was set. A column with no stored width is
# NA. The vector is indexed by column number.
col_widths <- function(path, sheet) {
  wb <- openxlsx2::wb_load(path)
  attrs <- wb$worksheets[[match(sheet, wb$get_sheet_names())]]$cols_attr
  out <- rep(NA_integer_, 0L)
  for (a in attrs) {
    from <- as.integer(sub('.*min="([0-9]+)".*', "\\1", a))
    to <- as.integer(sub('.*max="([0-9]+)".*', "\\1", a))
    if (!grepl('width="', a, fixed = TRUE)) {
      next
    }
    width <- as.numeric(sub('.*width="([0-9.]+)".*', "\\1", a))
    out[from:to] <- as.integer(floor(width))
  }
  out
}

# The number of columns of the first block on a sheet: the non-blank cells of
# its heading row.
block_width <- function(path, sheet, label = "Response") {
  sum(!is.na(heading_cells(path, sheet, label)))
}

# Writes `vars` over banner = gen on a gen-fixture design, with nothing
# withheld. `vars` is a character vector; `...` reaches export_crosstab().
write_gen_vars <- function(d, path, vars, ...) {
  fresh_path(path)
  crosstab_quiet(
    d,
    vars = tidyselect::all_of(vars),
    banner = gen,
    file_name = path,
    min_eff_n = 0,
    ...
  )
  path
}

test_that("export_crosstab() sets the label and data column widths (XB-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  bat <- c("bat_1", "bat_2", "bat_3")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    write_gen_vars(d, out, "q1")
    n_cols <- block_width(out, "q1")
    expect_identical(n_cols, 4L, label = paste0(nm, ": Response, Total, 2"))
    expect_identical(
      col_widths(out, "q1")[seq_len(n_cols)],
      c(44L, rep(12L, n_cols - 1L)),
      label = paste0(nm, ": q1")
    )

    write_gen_vars(d, out, bat)
    n_cols <- block_width(out, "bat_1", "Item")
    expect_identical(n_cols, 5L, label = paste0(nm, ": Item, Response, 3"))
    expect_identical(
      col_widths(out, "bat_1")[seq_len(n_cols)],
      c(44L, 20L, rep(12L, n_cols - 2L)),
      label = paste0(nm, ": battery")
    )
  }
})

test_that("export_crosstab() keeps the same widths when the labels grow (XB-02)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  short <- c("Yes", "No")
  long <- c(
    "Yes, without any doubt at all, in every case that I can think of",
    "No, not under any circumstances that I am able to imagine today"
  )

  for (nm in names(designs)) {
    widths <- list()
    for (labels in list(short, long)) {
      d <- add_gen_fixture(designs[[nm]])
      d@data$q1 <- rep(labels, length.out = nrow(d@data))
      write_gen_vars(d, out, "q1")
      expect_true(
        all(labels %in% sheet_col_a(out, "q1")),
        label = paste0(nm, ": the labels are written")
      )
      widths[[length(widths) + 1L]] <- col_widths(out, "q1")
    }

    expect_gt(min(nchar(long)), 5L * max(nchar(short)))
    expect_identical(widths[[2L]], widths[[1L]], label = nm)
    expect_identical(widths[[1L]], c(44L, 12L, 12L, 12L), label = nm)
  }
})

# TRUE when the cell's resolved alignment wraps. A cell with no style of its
# own takes style 0, the workbook default.
cell_wraps <- function(wb, sheet, dims) {
  style <- unname(openxlsx2::wb_get_cell_style(wb, sheet, dims))
  style_id <- if (is.na(style) || !nzchar(style)) 0L else as.integer(style)
  xf <- wb$styles_mgr$styles$cellXfs[[style_id + 1L]]
  grepl('wrapText="1"|wrapText="true"', xf)
}

# The stored height of one sheet row, or NA when the row has none of its own.
row_height <- function(wb, sheet, row) {
  attrs <- wb$worksheets[[match(
    sheet,
    wb$get_sheet_names()
  )]]$sheet_data$row_attr
  ht <- attrs$ht[attrs$r == as.character(row)]
  if (length(ht) == 0L || !nzchar(ht)) NA_real_ else as.numeric(ht)
}

test_that("export_crosstab() wraps the label column and the heading row (XB-03)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    write_gen_vars(add_gen_fixture(designs[[nm]]), out, "q1")
    col_a <- sheet_col_a(out, "q1")
    h <- match("Response", col_a)
    n_cols <- block_width(out, "q1")
    wb <- openxlsx2::wb_load(out)

    # Column A from the heading row down: the heading, the two sample-size
    # labels and every response label.
    for (row in seq.int(h, length(col_a))) {
      expect_true(
        cell_wraps(wb, "q1", paste0("A", row)),
        label = paste0(nm, ": A", row, " wraps")
      )
    }
    for (col in seq_len(n_cols)) {
      dims <- openxlsx2::wb_dims(rows = h, cols = col)
      expect_true(
        cell_wraps(wb, "q1", dims),
        label = paste0(nm, ": heading ", dims, " wraps")
      )
    }
    # The estimate cell: the Total column of the first response row.
    estimate <- openxlsx2::wb_dims(rows = h + 3L, cols = 2L)
    expect_false(
      cell_wraps(wb, "q1", estimate),
      label = paste0(nm, ": ", estimate, " does not wrap")
    )

    expect_identical(
      row_height(wb, "q1", h),
      30,
      label = paste0(nm, ": the heading row height")
    )
    expect_identical(
      row_height(wb, "q1", h + 3L),
      NA_real_,
      label = paste0(nm, ": a data row has no height")
    )
  }
})

# The freeze pane of one sheet, read after wb_load(): the <pane> XML as one
# string, "" when the sheet has no pane.
freeze_pane <- function(path, sheet) {
  wb <- openxlsx2::wb_load(path)
  pane <- wb$worksheets[[match(sheet, wb$get_sheet_names())]]$freezePane
  if (length(pane) == 0L) "" else pane
}

test_that("export_crosstab() freezes the pane under \"top\" and not under \"bottom\" (XB-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    write_gen_vars(d, out, "q1", sample_size_display = "top")
    last_ss <- match(ss_labels[[2L]], sheet_col_a(out, "q1"))
    pane <- freeze_pane(out, "q1")
    expect_match(
      pane,
      paste0('ySplit="', last_ss, '"'),
      fixed = TRUE,
      label = paste0(nm, ": top, the split")
    )
    expect_match(
      pane,
      paste0('topLeftCell="A', last_ss + 1L, '"'),
      fixed = TRUE,
      label = paste0(nm, ": top, the first data row")
    )

    write_gen_vars(d, out, "q1", sample_size_display = "bottom")
    expect_identical(
      freeze_pane(out, "q1"),
      "",
      label = paste0(nm, ": bottom, no pane")
    )
  }
})

# The stacked call of XB-11 and XB-12: the first block holds the title in
# row 1, the base note in row 2, the spanner in row 3, the heading row in row
# 4 and the two sample-size rows in rows 5 and 6.
write_stacked_pane <- function(d, path, vars, notes) {
  write_gen_vars(
    d,
    path,
    vars,
    layout = "stacked",
    base_notes = notes,
    variance = NULL,
    sample_size_display = "top",
    show_ess = TRUE
  )
}

test_that("export_crosstab() takes the stacked sheet's pane from its first block (XB-11)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  notes <- c(q1 = "Base: all adults", q2 = "Base: all adults")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    write_stacked_pane(d, out, c("q1", "q2"), notes)

    col_a <- sheet_col_a(out, "Crosstab")
    expect_identical(
      col_a[1:6],
      c("Question one", "Base: all adults", NA, "Response", ss_labels),
      label = paste0(nm, ": the first block")
    )
    # The second block's first data row, below its own sample-size rows.
    second_ss <- which(col_a == ss_labels[[2L]])
    expect_identical(length(second_ss), 2L, label = paste0(nm, ": 2 blocks"))

    pane <- freeze_pane(out, "Crosstab")
    expect_match(pane, 'topLeftCell="A7"', fixed = TRUE, label = nm)
    expect_match(pane, 'ySplit="6"', fixed = TRUE, label = nm)
    expect_false(
      grepl(
        paste0('topLeftCell="A', second_ss[[2L]] + 1L, '"'),
        pane,
        fixed = TRUE
      ),
      label = paste0(nm, ": not the second block")
    )
  }
})

test_that("export_crosstab() keeps the stacked pane when the first variable is dropped (XB-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    w <- expect_warning(
      write_stacked_pane(
        d,
        out,
        c("all_na_var", "q1"),
        c(q1 = "Base: all adults")
      ),
      class = "surveyreports_warning_all_na_dropped"
    )
    expect_match(conditionMessage(w), "all_na_var", fixed = TRUE, label = nm)

    expect_false(
      "all_na_var" %in% sheet_text(out, "Crosstab"),
      label = paste0(nm, ": nothing written")
    )
    expect_identical(
      sheet_col_a(out, "Crosstab")[1:6],
      c("Question one", "Base: all adults", NA, "Response", ss_labels),
      label = paste0(nm, ": q1 starts at row 1")
    )
    pane <- freeze_pane(out, "Crosstab")
    expect_match(pane, 'topLeftCell="A7"', fixed = TRUE, label = nm)
    expect_match(pane, 'ySplit="6"', fixed = TRUE, label = nm)
  }
})

test_that("export_crosstab() widens column B of a stacked sheet with a battery (XB-13)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    write_gen_vars(
      d,
      out,
      c("q1", "bat_1", "bat_2", "bat_3"),
      layout = "stacked",
      variance = NULL
    )
    rows <- sheet_rows(out, "Crosstab")
    col_a <- as.character(rows[[1L]])
    col_b <- as.character(rows[[2L]])

    # The battery block: Item, Response, Total, Male, Female.
    expect_identical(
      col_widths(out, "Crosstab")[1:5],
      c(44L, 20L, 12L, 12L, 12L),
      label = paste0(nm, ": widths")
    )

    # The q1 estimate rows sit between its sample-size rows and the blank
    # row that ends the block. The battery's Response cells sit in column B
    # below its own sample-size rows.
    ss_at <- which(col_a == ss_labels[[2L]])
    expect_identical(length(ss_at), 2L, label = paste0(nm, ": 2 blocks"))
    q1_end <- which(is.na(col_a) & seq_along(col_a) > ss_at[[1L]])[[1L]] - 1L
    q1_rows <- seq.int(ss_at[[1L]] + 1L, q1_end)
    bat_rows <- seq.int(ss_at[[2L]] + 1L, length(col_b))
    bat_rows <- bat_rows[!is.na(col_b[bat_rows])]
    expect_gt(length(q1_rows), 0L)
    expect_identical(
      length(bat_rows),
      sum(vapply(
        c("bat_1", "bat_2", "bat_3"),
        function(v) n_values(d, v),
        integer(1L)
      )),
      label = paste0(nm, ": battery rows")
    )

    wb <- openxlsx2::wb_load(out)
    for (row in bat_rows) {
      expect_true(
        cell_wraps(wb, "Crosstab", paste0("B", row)),
        label = paste0(nm, ": Response B", row, " wraps")
      )
    }
    for (row in q1_rows) {
      expect_false(
        cell_wraps(wb, "Crosstab", paste0("B", row)),
        label = paste0(nm, ": q1 estimate B", row, " does not wrap")
      )
    }
  }
})

# 31. Edge cases: response rows and sample sizes -------------------------------
# A block with fewer response rows keeps its sample-size rows, because they
# count the design's rows, not the tabulated variable (spec 3.4, spec 3.19).
# XX-01 and XX-04 turn on the design and the variable, not on a banner, so
# they run against both export functions.

export_fns <- c("export_crosstab", "export_topline")

# The rows a design tabulates: the phase-2 subset of a twophase design, then
# the in-domain rows when the design carries a domain column.
# test-export-topline.R holds the same helper as in_scope_rows();
# helper-export.R is outside this change.
tabulated_rows <- function(d) {
  keep <- rep(TRUE, nrow(d@data))
  if (S7::S7_inherits(d, surveycore::survey_twophase)) {
    keep <- keep & d@data[[d@variables$subset]]
  }
  if (surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data)) {
    keep <- keep & d@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  }
  sum(keep)
}

# Writes the block of one variable with one of the two export functions:
# banner = group, with nothing withheld, for the crosstab. `var` is a
# character scalar.
write_one <- function(fn, d, path, var) {
  fresh_path(path)
  if (fn == "export_crosstab") {
    crosstab_quiet(
      d,
      vars = tidyselect::all_of(var),
      banner = group,
      file_name = path,
      min_eff_n = 0
    )
  } else {
    topline_quiet(d, vars = tidyselect::all_of(var), file_name = path)
  }
}

# The block that write_one() wrote for `var`: its response labels, and its
# sample sizes. The crosstab gives its two sample-size rows, every column.
# The topline gives the N cell of its Total row, its one unweighted count.
block_summary <- function(fn, path, var) {
  if (fn == "export_crosstab") {
    rows <- sheet_rows(path, var)
    h <- heading_index(rows)
    list(
      responses = as.character(estimate_rows(rows, h, 2L)[[1L]]),
      n = as.integer(rows[[2L]][[h + 1L]]),
      sizes = as.character(unlist(rows[h + 1:2, ]))
    )
  } else {
    rows <- openxlsx2::wb_to_df(
      path,
      sheet = "Topline",
      col_names = FALSE,
      skip_empty_rows = FALSE
    )
    col_a <- as.character(rows[[1L]])
    h <- match("Response", col_a)
    total <- match("Total", col_a)
    list(
      responses = col_a[seq.int(h + 1L, total - 1L)],
      n = as.integer(rows[[3L]][[total]]),
      sizes = as.character(rows[[3L]][[total]])
    )
  }
}

test_that("both export functions report a sample size of 1 on a one-row design (XX-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- one_row_design(designs[[nm]])
    expect_identical(tabulated_rows(d), 1L, label = paste0(nm, ": one row"))

    for (fn in export_fns) {
      lbl <- paste0(nm, ", ", fn)
      result <- suppressWarnings(
        write_one(fn, d, out, "q1"),
        classes = "surveycore_warning_single_level"
      )
      expect_identical(result, out, label = paste0(lbl, ": the path"))
      expect_identical(
        block_summary(fn, out, "q1")$n,
        1L,
        label = paste0(lbl, ": the unweighted sample size")
      )
    }
  }
})

test_that("both export functions write one response row for a single-value variable (XX-04)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    d@data$constant <- "Agree"
    d <- surveycore::set_var_label(d, constant = "A constant")

    for (fn in export_fns) {
      lbl <- paste0(nm, ", ", fn)
      write_one(fn, d, out, "q1")
      other <- block_summary(fn, out, "q1")
      write_one(fn, d, out, "constant")
      single <- block_summary(fn, out, "constant")

      expect_identical(single$responses, "Agree", label = lbl)
      expect_gt(length(other$responses), 1L)
      expect_identical(
        single$sizes,
        other$sizes,
        label = paste0(lbl, ": the sample sizes")
      )
    }
  }
})

test_that("export_crosstab() writes no response row for an unused factor level", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    d@data$fq <- factor(
      rep(c("Low", "High"), length.out = nrow(d@data)),
      levels = c("Low", "Medium", "High")
    )
    d <- surveycore::set_var_label(d, fq = "A factor")

    write_one("export_crosstab", d, out, "q1")
    other <- block_summary("export_crosstab", out, "q1")
    write_one("export_crosstab", d, out, "fq")
    fq <- block_summary("export_crosstab", out, "fq")

    expect_identical(fq$responses, c("Low", "High"), label = nm)
    expect_false("Medium" %in% sheet_text(out, "fq"), label = nm)
    expect_identical(fq$sizes, other$sizes, label = paste0(nm, ": sizes"))
  }
})

test_that("export_crosstab() writes the stacked layout on one sheet (XX-11)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    fresh_path(out)
    crosstab_quiet(
      guard_design(designs[[nm]]),
      vars = c(q1, q2),
      banner = group,
      file_name = out,
      min_eff_n = 0,
      layout = "stacked"
    )

    expect_identical(
      openxlsx2::wb_load(out)$sheet_names,
      c("About", "Crosstab"),
      label = paste0(nm, ": two sheets")
    )

    col_a <- sheet_col_a(out, "Crosstab")
    h <- which(col_a == "Response")
    expect_identical(length(h), 2L, label = paste0(nm, ": two blocks"))
    # Each block's sample-size rows sit under its own heading row.
    for (k in 1:2) {
      expect_identical(
        col_a[h[[k]] + 1:2],
        ss_labels,
        label = paste0(nm, ": block ", k)
      )
    }
    # One blank row between the last row of q1 and the title of q2.
    q2_title <- h[[2L]] - 2L
    expect_identical(col_a[[q2_title]], "Question two", label = nm)
    expect_true(is.na(col_a[[q2_title - 1L]]), label = paste0(nm, ": blank"))
    expect_false(
      is.na(col_a[[q2_title - 2L]]),
      label = paste0(nm, ": one blank row")
    )
  }
})

test_that("export_crosstab() counts more rows than the answers, with no warning (XX-12)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    d@data$q1[1:60] <- NA_character_
    expect_identical(sum(is.na(d@data$q1)), 60L)

    expect_no_warning(write_one("export_crosstab", d, out, "q1"))

    summary <- block_summary("export_crosstab", out, "q1")
    answered <- sum(oracle_freqs(d, "q1")$n)
    expect_identical(summary$n, tabulated_rows(d), label = nm)
    expect_lt(answered, summary$n, label = paste0(nm, ": the response rows"))
  }
})

# 32. Numerical accuracy: the sample-size counts -------------------------------
# The two sample-size rows match surveycore::get_effective_n(), the oracle,
# for the full sample and for a subgroup, and follow the rows the design
# tabulates (spec 3.4, spec 3.20).

# The two counts of one column of the q1 block: the cells of the unweighted
# and the effective sample-size rows, under the heading row, in column
# `col`, as numbers. Column 2 is the Total column.
ss_cells <- function(path, col = 2L) {
  rows <- sheet_rows(path, "q1")
  h <- heading_index(rows)
  expect_identical(
    as.character(rows[[1L]][h + 1:2]),
    ss_labels,
    label = "the sample-size rows under the heading row"
  )
  list(
    n = as.integer(rows[[col]][[h + 1L]]),
    n_eff = as.numeric(rows[[col]][[h + 2L]])
  )
}

# The full-sample oracle row: n and n_eff from surveycore.
full_counts_oracle <- function(d) {
  suppressWarnings(
    surveycore::get_effective_n(d),
    classes = oracle_classes
  )
}

test_that("export_crosstab() writes the full-sample unweighted count (XN-01) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    write_gen_vars(d, out, "q1")
    expect_identical(
      ss_cells(out)$n,
      as.integer(full_counts_oracle(d)$n),
      label = nm
    )
  }
})

test_that("export_crosstab() writes the full-sample effective N (XN-02) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    write_gen_vars(d, out, "q1")
    expect_equal(
      ss_cells(out)$n_eff,
      round(full_counts_oracle(d)$n_eff, 1L),
      tolerance = 1e-8,
      label = nm
    )
  }
})

test_that("export_crosstab() writes a subgroup's two counts (XN-03) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    write_gen_vars(d, out, "q1")
    heading <- heading_cells(out, "q1")

    for (level in c("Male", "Female")) {
      cells <- ss_cells(out, match(level, heading))
      ref <- gen_oracle(d, level)
      lbl <- paste0(nm, ": ", level)
      expect_identical(cells$n, as.integer(ref$n), label = paste(lbl, "n"))
      expect_equal(
        cells$n_eff,
        round(ref$n_eff, 1L),
        tolerance = 1e-8,
        label = paste(lbl, "n_eff")
      )
    }
  }
})

test_that("export_crosstab() counts the rows the design tabulates (XN-04) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    write_gen_vars(d, out, "q1")
    expected <- tabulated_rows(d)
    if (nm == "twophase") {
      # The phase-2 subset, not every row of @data.
      expect_identical(expected, 119L)
      expect_lt(expected, nrow(d@data))
    }
    expect_identical(ss_cells(out)$n, expected, label = nm)
  }
})

test_that("export_crosstab() counts the in-domain rows on a restricted design (XN-05) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$group == "A"
    # Missing q1 answers inside the domain, so the variable's N differs from
    # the in-domain row count.
    d@data$q1[d@data$group == "A"][1:10] <- NA_character_
    write_gen_vars(d, out, "q1")

    expected <- tabulated_rows(d)
    expect_lt(expected, nrow(d@data))
    answered <- sum(oracle_freqs(d, "q1")$n)
    expect_lt(answered, expected, label = paste0(nm, ": the variable's N"))
    expect_identical(ss_cells(out)$n, expected, label = nm)
  }
})

# 33. Percentage cells ---------------------------------------------------------
# Every estimate cell is a string in one of five forms: a rounded percentage,
# `0%`, the floor string, the ceiling string, or `-`. The whole banner column
# of a variable decides between `0%` and `-`: `0%` when people in the column
# answered and nobody chose the category, `-` when nobody there answered
# (spec 3.3, gap 17). The expected strings are built here from
# surveycore::get_freqs() and round(), not with .fmt_pct().

# The variable label of each fixture column that guard_design() sets. A SATA
# or battery block writes the label in column A.
pct_items <- c(
  q1 = "Question one",
  sata_a = "Option A",
  sata_b = "Option B",
  sata_c = "Option C",
  bat_1 = "Item one",
  bat_2 = "Item two",
  bat_3 = "Item three"
)

# The SATA fixture. sata_a is recoded 1 = Yes, 2 = No, so its chosen value is
# the label of code 1, "Yes". sata_b and sata_c stay unlabelled 0/1, so their
# chosen value is "1".
pct_sata_design <- function(d) {
  d@data$sata_a <- ifelse(d@data$sata_a == 1L, 1, 2)
  d@metadata@value_labels[["sata_a"]] <- c(Yes = 1, No = 2)
  d <- surveycore::set_sata(d, variable = c("sata_a", "sata_b", "sata_c"))
  guard_design(d)
}

pct_sata_chosen <- c(sata_a = "Yes", sata_b = "1", sata_c = "1")

# The get_freqs() rows of one variable, over the whole sample when `banner`
# is NULL, else by `banner`: the column level, the value, pct and n.
pct_oracle <- function(d, var, banner = NULL) {
  ref <- if (is.null(banner)) {
    suppressWarnings(
      surveycore::get_freqs(d, !!rlang::sym(var)),
      classes = oracle_classes
    )
  } else {
    suppressWarnings(
      surveycore::get_freqs(
        d,
        !!rlang::sym(var),
        group = !!rlang::sym(banner)
      ),
      classes = oracle_classes
    )
  }
  data.frame(
    level = if (is.null(banner)) "Total" else as.character(ref[[banner]]),
    value = as.character(ref[[var]]),
    pct = ref$pct,
    n = ref$n,
    stringsAsFactors = FALSE
  )
}

# The expected string of one cell. `col_rows` are the oracle rows of the
# variable in the cell's column; `own` is the row of the cell's category, or
# no row. `-` when nobody in the column answered; `0%` when the column
# answered and the category has no row or n = 0; else the rounded percentage.
expected_pct <- function(col_rows, own, decimals) {
  if (!any(col_rows$n > 0L, na.rm = TRUE)) {
    return("-")
  }
  if (nrow(own) == 0L || own$n[[1L]] == 0L) {
    return("0%")
  }
  paste0(round(own$pct[[1L]] * 100, decimals), "%")
}

# Writes one block of `vars` over banner = group at `decimals`.
write_pct_block <- function(d, path, vars, decimals = 1L) {
  fresh_path(path)
  crosstab_quiet(
    d,
    vars = tidyselect::all_of(vars),
    banner = group,
    file_name = path,
    min_eff_n = 0,
    decimals = decimals
  )
}

# The estimate rows of the first block of one sheet, the heading row, and the
# data columns from Total on. Column A is filled down for a battery, whose
# item label sits on the first value row of the item only.
pct_block <- function(path, sheet, label) {
  rows <- sheet_rows(path, sheet)
  h <- heading_index(rows, label)
  heading <- as.character(unlist(rows[h, ]))
  first_col <- match("Total", heading)
  est <- estimate_rows(rows, h, first_col)
  col_a <- as.character(est[[1L]])
  for (i in seq_along(col_a)[-1L]) {
    if (is.na(col_a[[i]])) {
      col_a[[i]] <- col_a[[i - 1L]]
    }
  }
  list(
    est = est,
    col_a = col_a,
    heading = heading,
    data_cols = seq.int(first_col, max(which(!is.na(heading))))
  )
}

# Checks every estimate cell of one block against the oracle, and returns the
# number of cells checked. `kind` is "single", "sata" or "battery".
expect_pct_cells <- function(d, path, vars, kind, decimals, lbl) {
  label <- if (kind == "single") "Response" else "Item"
  blk <- pct_block(path, vars[[1L]], label)
  n_checked <- 0L
  for (var in vars) {
    ref_total <- pct_oracle(d, var)
    ref_group <- pct_oracle(d, var, "group")
    for (r in seq_len(nrow(blk$est))) {
      if (kind != "single" && blk$col_a[[r]] != pct_items[[var]]) {
        next
      }
      value <- switch(
        kind,
        single = blk$col_a[[r]],
        sata = pct_sata_chosen[[var]],
        battery = as.character(blk$est[[2L]][[r]])
      )
      for (j in blk$data_cols) {
        level <- blk$heading[[j]]
        col_rows <- if (level == "Total") {
          ref_total
        } else {
          ref_group[ref_group$level == level, ]
        }
        own <- col_rows[col_rows$value == value, ]
        expect_identical(
          as.character(blk$est[[j]][[r]]),
          expected_pct(col_rows, own, decimals),
          label = paste0(lbl, ": ", var, " = ", value, " in ", level)
        )
        n_checked <- n_checked + 1L
      }
    }
  }
  # Every estimate cell of the block was checked once.
  expect_identical(
    n_checked,
    nrow(blk$est) * length(blk$data_cols),
    label = paste0(lbl, ": cells checked")
  )
  n_checked
}

# The three blocks every cross-design row writes: a single-response block, a
# SATA block with a labelled code-1 item, and a battery block.
pct_blocks <- list(
  single = "q1",
  sata = c("sata_a", "sata_b", "sata_c"),
  battery = c("bat_1", "bat_2", "bat_3")
)

# The XML type of every estimate cell of the first block of one sheet.
# "inlineStr" or "s" is a string; an empty type or "n" is a number.
estimate_cell_types <- function(path, sheet, label) {
  rows <- sheet_rows(path, sheet)
  h <- heading_index(rows, label)
  heading <- as.character(unlist(rows[h, ]))
  first_col <- match("Total", heading)
  last_col <- max(which(!is.na(heading)))
  below <- seq.int(h + 1L, nrow(rows))
  est_rows <- below[
    !as.character(rows[[1L]][below]) %in% ss_labels &
      !is.na(rows[[first_col]][below])
  ]
  wb <- openxlsx2::wb_load(path)
  cc <- wb$worksheets[[match(sheet, wb$sheet_names)]]$sheet_data$cc
  col <- openxlsx2::col2int(cc$c_r)
  keep <- as.integer(cc$row_r) %in%
    est_rows &
    col >= first_col &
    col <= last_col
  list(
    types = cc$c_t[keep],
    n_cells = length(est_rows) * (last_col - first_col + 1L)
  )
}

# The pattern of a rounded percentage, and the four special forms at
# decimals = 1.
pct_pattern <- "^[0-9]+(\\.[0-9]+)?%$"
pct_special <- c("-", "0%", "<0.1%", ">99.9%")

test_that("export_crosstab() writes every estimate cell as a string carrying % (XC-01)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    for (kind in names(pct_blocks)) {
      vars <- pct_blocks[[kind]]
      label <- if (kind == "single") "Response" else "Item"
      lbl <- paste0(nm, ", ", kind)
      write_pct_block(d, out, vars)

      types <- estimate_cell_types(out, vars[[1L]], label)
      expect_gt(types$n_cells, 0L, label = lbl)
      expect_identical(
        length(types$types),
        types$n_cells,
        label = paste0(lbl, ": every estimate cell is written")
      )
      expect_true(
        all(types$types %in% c("inlineStr", "s", "str")),
        label = paste0(lbl, ": no estimate cell is numeric")
      )

      blk <- pct_block(out, vars[[1L]], label)
      cells <- as.character(unlist(blk$est[blk$data_cols]))
      expect_true(
        all(grepl(pct_pattern, cells) | cells %in% pct_special),
        label = paste0(lbl, ": every cell is one of the five forms")
      )
    }
  }
})

test_that("export_crosstab() writes each percentage as get_freqs() rounds it (XC-02) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    for (kind in names(pct_blocks)) {
      vars <- pct_blocks[[kind]]
      write_pct_block(d, out, vars)
      n <- expect_pct_cells(d, out, vars, kind, 1L, paste0(nm, ", ", kind))
      expect_gt(n, 0L)
    }
  }
})

test_that("export_crosstab() rounds each percentage to `decimals` (XC-03) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    for (decimals in c(0L, 2L)) {
      for (kind in names(pct_blocks)) {
        vars <- pct_blocks[[kind]]
        write_pct_block(d, out, vars, decimals)
        lbl <- paste0(nm, ", ", kind, ", decimals = ", decimals)
        n <- expect_pct_cells(d, out, vars, kind, decimals, lbl)
        expect_gt(n, 0L)
      }
    }
  }
})

# A 10,000-row taylor design with unit weights, so each estimate is an exact
# share. `Rare` is held by 3 rows, rows 1 to 3; `Agree` by the other 9,997.
# The banner `g` alternates A and B, so column A holds 2 `Rare` rows of 5,000
# and column B holds 1.
rare_design <- function() {
  df <- data.frame(
    rq = c(rep("Rare", 3L), rep("Agree", 9997L)),
    g = rep(c("A", "B"), 5000L),
    wt = 1
  )
  d <- surveycore::as_survey(df, weights = wt)
  surveycore::set_var_label(d, rq = "Rare question", g = "Group")
}

# The rq block of the rare design at `decimals`: the cells of the `Rare` and
# `Agree` rows in the Total, A and B columns, and every cell of the sheet.
rare_cells <- function(d, path, decimals) {
  fresh_path(path)
  export_crosstab(
    d,
    vars = rq,
    banner = g,
    file_name = path,
    min_eff_n = 0,
    decimals = decimals
  )
  rows <- sheet_rows(path, "rq")
  h <- heading_index(rows)
  heading <- as.character(unlist(rows[h, ]))
  cols <- match(c("Total", "A", "B"), heading)
  col_a <- as.character(rows[[1L]])
  cell_row <- function(value) {
    r <- which(col_a == value)
    stats::setNames(
      vapply(cols, function(j) as.character(rows[[j]][[r]]), character(1L)),
      c("Total", "A", "B")
    )
  }
  list(
    rare = cell_row("Rare"),
    agree = cell_row("Agree"),
    sheet = as.character(unlist(rows))
  )
}

test_that("export_crosstab() writes <0.1% for a nonzero value that rounds to zero (XC-04)", {
  skip_if_not_installed("surveycore")
  d <- rare_design()
  out <- withr::local_tempfile(fileext = ".xlsx")

  # The oracle: 3 in 10,000 overall, 2 and 1 in 5,000 in A and B.
  ref <- pct_oracle(d, "rq")
  expect_equal(ref$pct[ref$value == "Rare"] * 100, 0.03, tolerance = 1e-10)

  cells <- rare_cells(d, out, 1L)
  expect_identical(
    cells$rare,
    c(Total = "<0.1%", A = "<0.1%", B = "<0.1%")
  )
})

test_that("export_crosstab() floor string follows `decimals` (XC-05)", {
  skip_if_not_installed("surveycore")
  d <- rare_design()
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_identical(
    rare_cells(d, out, 0L)$rare,
    c(Total = "<1%", A = "<1%", B = "<1%")
  )
  # At 2 places the value no longer rounds to zero.
  expect_identical(
    rare_cells(d, out, 2L)$rare,
    c(Total = "0.03%", A = "0.04%", B = "0.02%")
  )
})

test_that("export_crosstab() writes >99.9% for a value below 100 that rounds to 100 (XC-05a)", {
  skip_if_not_installed("surveycore")
  d <- rare_design()
  out <- withr::local_tempfile(fileext = ".xlsx")

  ref <- pct_oracle(d, "rq")
  expect_equal(ref$pct[ref$value == "Agree"] * 100, 99.97, tolerance = 1e-10)

  cells <- rare_cells(d, out, 1L)
  expect_identical(
    cells$agree,
    c(Total = ">99.9%", A = ">99.9%", B = ">99.9%")
  )
  expect_false("100.0%" %in% cells$sheet)
  expect_false("100%" %in% cells$sheet)
})

test_that("export_crosstab() ceiling string follows `decimals` (XC-05b)", {
  skip_if_not_installed("surveycore")
  d <- rare_design()
  out <- withr::local_tempfile(fileext = ".xlsx")

  cells <- rare_cells(d, out, 0L)
  expect_identical(cells$agree, c(Total = ">99%", A = ">99%", B = ">99%"))
  expect_false("100%" %in% cells$sheet)

  # At 2 places the value no longer rounds to 100.
  cells <- rare_cells(d, out, 2L)
  expect_identical(
    cells$agree,
    c(Total = "99.97%", A = "99.96%", B = "99.98%")
  )
  expect_false("100.00%" %in% cells$sheet)
})

test_that("export_crosstab() writes 0% for a category nobody in an answering column chose (XC-06)", {
  skip_if_not_installed("surveycore")
  d <- guard_design(make_all_designs(seed = 42)$taylor)
  # `Rare` is held only by rows of group A, so B and C answered and nobody
  # there chose it.
  rare_rows <- d@data$group == "A" & seq_len(nrow(d@data)) %% 7L == 0L
  d@data$qz <- ifelse(rare_rows, "Rare", d@data$q1)
  d <- surveycore::set_var_label(d, qz = "Question zero")
  out <- withr::local_tempfile(fileext = ".xlsx")

  # The oracle: B and C have answers, and no `Rare` row with n > 0.
  ref <- pct_oracle(d, "qz", "group")
  for (lvl in c("B", "C")) {
    col_rows <- ref[ref$level == lvl, ]
    expect_true(any(col_rows$n > 0L), label = paste0(lvl, " answered"))
    expect_false(
      any(col_rows$n[col_rows$value == "Rare"] > 0L),
      label = paste0(lvl, " has no Rare answer")
    )
  }

  write_pct_block(d, out, "qz")
  blk <- pct_block(out, "qz", "Response")
  r <- which(blk$col_a == "Rare")
  cells <- vapply(
    c("A", "B", "C"),
    function(lvl) {
      as.character(blk$est[[match(lvl, blk$heading)]][[r]])
    },
    character(1L)
  )
  expect_identical(unname(cells[c("B", "C")]), c("0%", "0%"))
  expect_match(cells[["A"]], pct_pattern)
  expect_false(cells[["A"]] %in% pct_special)
})

test_that("export_crosstab() writes 0% and - in a battery block by the same rule (XC-06a)", {
  skip_if_not_installed("surveycore")
  d <- guard_design(make_all_designs(seed = 42)$taylor)
  # Value 5 of bat_1 is held only by rows of group A.
  move <- d@data$group != "A" & d@data$bat_1 == 5L
  d@data$bat_1[move] <- 4L
  # bat_2 was never asked of group C.
  d@data$bat_2[d@data$group == "C"] <- NA_integer_
  out <- withr::local_tempfile(fileext = ".xlsx")

  write_pct_block(d, out, pct_blocks$battery)
  blk <- pct_block(out, "bat_1", "Item")
  response <- as.character(blk$est[[2L]])
  cell <- function(item, value, lvl) {
    r <- which(blk$col_a == item & response == value)
    as.character(blk$est[[match(lvl, blk$heading)]][[r]])
  }

  expect_identical(cell("Item one", "5", "B"), "0%")
  expect_identical(cell("Item one", "5", "C"), "0%")
  expect_match(cell("Item one", "5", "A"), pct_pattern)

  bat_2_values <- response[blk$col_a == "Item two"]
  expect_gt(length(bat_2_values), 0L)
  for (value in bat_2_values) {
    expect_identical(cell("Item two", value, "C"), "-", label = value)
    expect_match(cell("Item two", value, "A"), pct_pattern, label = value)
  }

  # Every cell of the block still matches the oracle.
  expect_pct_cells(d, out, pct_blocks$battery, "battery", 1L, "taylor")
})

test_that("export_crosstab() writes - for a column with no answers (XC-07)", {
  skip_if_not_installed("surveycore")
  d <- guard_design(make_all_designs(seed = 42)$taylor)
  d@data$q1[d@data$group == "C"] <- NA_character_
  out <- withr::local_tempfile(fileext = ".xlsx")

  # The oracle has rows for C, each with n = 0: row presence alone must not
  # drive the cell.
  ref <- pct_oracle(d, "q1", "group")
  c_rows <- ref[ref$level == "C", ]
  expect_gt(nrow(c_rows), 0L)
  expect_true(all(c_rows$n == 0L))

  write_pct_block(d, out, "q1")
  blk <- pct_block(out, "q1", "Response")
  col_c <- as.character(blk$est[[match("C", blk$heading)]])
  col_a <- as.character(blk$est[[match("A", blk$heading)]])
  expect_identical(length(col_c), 3L)
  expect_identical(col_c, rep("-", 3L))
  expect_true(all(grepl(pct_pattern, col_a)))
  expect_false(any(col_a %in% pct_special))
})

test_that("export_crosstab() writes - for a SATA item never asked and 0% for one nobody chose (XC-07a)", {
  skip_if_not_installed("surveycore")
  d <- pct_sata_design(make_all_designs(seed = 42)$taylor)
  in_c <- d@data$group == "C"
  # sata_a, labelled 1 = Yes, was never asked of group C.
  d@data$sata_a[in_c] <- NA
  # sata_b was asked of group C, and nobody there chose it.
  d@data$sata_b[in_c] <- 0L
  out <- withr::local_tempfile(fileext = ".xlsx")

  write_pct_block(d, out, pct_blocks$sata)
  blk <- pct_block(out, "sata_a", "Item")
  col_c <- match("C", blk$heading)
  cell <- function(item) {
    as.character(blk$est[[col_c]][[which(blk$col_a == item)]])
  }

  expect_identical(cell("Option A"), "-")
  expect_identical(cell("Option B"), "0%")
  expect_match(cell("Option C"), pct_pattern)

  # No cell in the block is blank.
  cells <- as.character(unlist(blk$est[blk$data_cols]))
  expect_identical(length(cells), 3L * length(blk$data_cols))
  expect_false(anyNA(cells))
  expect_true(all(nzchar(cells)))

  # Every cell of the block still matches the oracle.
  expect_pct_cells(d, out, pct_blocks$sata, "sata", 1L, "taylor")
})

test_that("export_crosstab() writes every special form apart in one block (XC-08)", {
  skip_if_not_installed("surveycore")
  # Unit weights, 10,000 rows. Column A: 4,998 Agree and 2 Rare. Column B:
  # 2,000 Agree and 2,000 Other, no Rare. Column C: 1,000 rows, no answer.
  df <- data.frame(
    rq = c(
      rep("Rare", 2L),
      rep("Agree", 4998L),
      rep(c("Agree", "Other"), each = 2000L),
      rep(NA_character_, 1000L)
    ),
    g = rep(c("A", "B", "C"), c(5000L, 4000L, 1000L)),
    wt = 1
  )
  d <- surveycore::as_survey(df, weights = wt)
  d <- surveycore::set_var_label(d, rq = "Mixed question", g = "Group")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = rq, banner = g, file_name = out, min_eff_n = 0)

  blk <- pct_block(out, "rq", "Response")
  cell <- function(value, lvl) {
    as.character(blk$est[[match(lvl, blk$heading)]][[
      which(blk$col_a == value)
    ]])
  }

  expect_identical(cell("Rare", "A"), "<0.1%")
  expect_identical(cell("Agree", "A"), ">99.9%")
  expect_identical(cell("Other", "A"), "0%")
  expect_identical(cell("Rare", "B"), "0%")
  expect_identical(cell("Agree", "B"), "50%")
  expect_identical(cell("Other", "B"), "50%")
  for (value in c("Rare", "Agree", "Other")) {
    expect_identical(cell(value, "C"), "-", label = value)
  }

  cells <- as.character(unlist(blk$est[blk$data_cols]))
  expect_true(all(c("<0.1%", ">99.9%", "0%", "-", "50%") %in% cells))
})

# 34. Variance strings, the legend row and the sheet room ----------------------
# Under variance = "se" or "ci", each estimate cell shows the standard error
# or the interval in parentheses, one % per number. variance_display = "cell"
# puts it on a second line of the cell; "row" puts it on its own row under the
# estimate row. A legend row under the title says what the parentheses hold.
# The sheet makes room: wider data columns under "ci", and wrapped 30-point
# estimate rows when the value shares the cell. A `-` cell, and a `0%` cell
# with no row of its own, carry no variance (spec 3.12, spec 3.16). The
# expected strings are built here from surveycore::get_freqs(), round() and
# paste0(), never with .fmt_variance() or .fmt_pct().

var_en_dash <- intToUtf8(0x2013L)

# The get_freqs() rows of one variable with its variance columns, over the
# whole sample when `banner` is NULL, else by `banner`.
var_oracle <- function(
  d,
  var,
  banner = NULL,
  variance = "se",
  conf_level = 0.95
) {
  ref <- if (is.null(banner)) {
    suppressWarnings(
      surveycore::get_freqs(
        d,
        !!rlang::sym(var),
        variance = variance,
        conf_level = conf_level
      ),
      classes = oracle_classes
    )
  } else {
    suppressWarnings(
      surveycore::get_freqs(
        d,
        !!rlang::sym(var),
        group = !!rlang::sym(banner),
        variance = variance,
        conf_level = conf_level
      ),
      classes = oracle_classes
    )
  }
  out <- data.frame(
    level = if (is.null(banner)) "Total" else as.character(ref[[banner]]),
    value = as.character(ref[[var]]),
    pct = ref$pct,
    n = ref$n,
    stringsAsFactors = FALSE
  )
  if (variance == "se") {
    out$se <- ref$se
  } else {
    out$ci_low <- ref$ci_low
    out$ci_high <- ref$ci_high
  }
  out
}

# The expected variance string of one cell. "" when nobody in the column
# answered, or when the cell's own row is absent or has n = 0.
expected_variance <- function(col_rows, own, variance, decimals = 1L) {
  if (
    !any(col_rows$n > 0L, na.rm = TRUE) ||
      nrow(own) == 0L ||
      own$n[[1L]] == 0L
  ) {
    return("")
  }
  if (variance == "se") {
    return(paste0("(", round(own$se[[1L]] * 100, decimals), "%)"))
  }
  paste0(
    "(",
    round(own$ci_low[[1L]] * 100, decimals),
    "% ",
    var_en_dash,
    " ",
    round(own$ci_high[[1L]] * 100, decimals),
    "%)"
  )
}

# Writes one block of `vars` over banner = group with a variance.
write_var_block <- function(d, path, vars, variance, display = "cell", ...) {
  fresh_path(path)
  crosstab_quiet(
    d,
    vars = tidyselect::all_of(vars),
    banner = group,
    file_name = path,
    min_eff_n = 0,
    variance = variance,
    variance_display = display,
    ...
  )
}

# The oracle rows of one cell: `col_rows`, the rows of the cell's column, and
# `own`, the row of the cell's category.
var_cell_oracle <- function(ref_total, ref_group, level, value) {
  col_rows <- if (level == "Total") {
    ref_total
  } else {
    ref_group[ref_group$level == level, ]
  }
  list(col_rows = col_rows, own = col_rows[col_rows$value == value, ])
}

# The response value an estimate row of a block stands for.
var_row_value <- function(kind, var, blk, r) {
  switch(
    kind,
    single = blk$col_a[[r]],
    sata = pct_sata_chosen[[var]],
    battery = as.character(blk$est[[2L]][[r]])
  )
}

# Checks every estimate cell of one block written under
# variance_display = "cell": the estimate, then a line break and the variance
# string when the cell has one. Returns the number of cells that carry a
# variance string.
expect_variance_cells <- function(
  d,
  path,
  vars,
  kind,
  variance,
  lbl,
  conf_level = 0.95
) {
  label <- if (kind == "single") "Response" else "Item"
  blk <- pct_block(path, vars[[1L]], label)
  n_checked <- 0L
  n_variance <- 0L
  for (var in vars) {
    ref_total <- var_oracle(d, var, NULL, variance, conf_level)
    ref_group <- var_oracle(d, var, "group", variance, conf_level)
    for (r in seq_len(nrow(blk$est))) {
      if (kind != "single" && blk$col_a[[r]] != pct_items[[var]]) {
        next
      }
      value <- var_row_value(kind, var, blk, r)
      for (j in blk$data_cols) {
        level <- blk$heading[[j]]
        cell <- var_cell_oracle(ref_total, ref_group, level, value)
        expected <- expected_pct(cell$col_rows, cell$own, 1L)
        v <- expected_variance(cell$col_rows, cell$own, variance)
        if (nzchar(v)) {
          expected <- paste0(expected, "\n", v)
          n_variance <- n_variance + 1L
        }
        expect_identical(
          as.character(blk$est[[j]][[r]]),
          expected,
          label = paste0(lbl, ": ", var, " = ", value, " in ", level)
        )
        n_checked <- n_checked + 1L
      }
    }
  }
  expect_identical(
    n_checked,
    nrow(blk$est) * length(blk$data_cols),
    label = paste0(lbl, ": cells checked")
  )
  n_variance
}

# The rows of the first block of one sheet from its first data row to the
# sheet's last row, the heading row, and the data columns from Total on. The
# sample-size rows sit under the heading row (sample_size_display = "top").
block_body <- function(path, sheet, label) {
  rows <- sheet_rows(path, sheet)
  h <- heading_index(rows, label)
  heading <- as.character(unlist(rows[h, ]))
  first_col <- match("Total", heading)
  first <- h + 1L + length(ss_labels)
  list(
    rows = rows[seq.int(first, nrow(rows)), , drop = FALSE],
    row_nums = seq.int(first, nrow(rows)),
    ss_rows = seq.int(h + 1L, first - 1L),
    heading = heading,
    label_cols = seq_len(first_col - 1L),
    data_cols = seq.int(first_col, max(which(!is.na(heading))))
  )
}

test_that("export_crosstab() writes the standard error on a second line of the cell (XH-15, XN-09) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    for (kind in names(pct_blocks)) {
      vars <- pct_blocks[[kind]]
      lbl <- paste0(nm, ", ", kind)
      write_var_block(d, out, vars, "se")
      n <- expect_variance_cells(d, out, vars, kind, "se", lbl)
      expect_gt(n, 0L, label = lbl)
    }
  }
})

test_that("export_crosstab() writes the interval bounds with an en-dash (XH-16, XN-10) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    for (kind in names(pct_blocks)) {
      vars <- pct_blocks[[kind]]
      lbl <- paste0(nm, ", ", kind)
      write_var_block(d, out, vars, "ci")
      n <- expect_variance_cells(d, out, vars, kind, "ci", lbl)
      expect_gt(n, 0L, label = lbl)

      # One % per bound, and no hyphen-minus between the two bounds.
      blk <- pct_block(
        out,
        vars[[1L]],
        if (kind == "single") "Response" else "Item"
      )
      cells <- as.character(unlist(blk$est[blk$data_cols]))
      second <- sub("^[^\n]*\n", "", cells[grepl("\n", cells, fixed = TRUE)])
      expect_true(
        all(lengths(regmatches(second, gregexpr("%", second))) == 2L),
        label = paste0(lbl, ": two % per interval")
      )
      expect_true(
        all(grepl(paste0("% ", var_en_dash, " "), second, fixed = TRUE)),
        label = paste0(lbl, ": the en-dash separator")
      )
    }
  }
})

# 300 rows with unit weights. `Rare` is held by rows 1 and 2, so the full
# sample holds 2 of 300. The banner `g` alternates A and B, so each column
# holds one `Rare` row of 150.
neg_bound_design <- function() {
  df <- data.frame(
    rq = c(rep("Rare", 2L), rep("Agree", 298L)),
    g = rep(c("A", "B"), 150L),
    wt = 1
  )
  d <- surveycore::as_survey(df, weights = wt)
  surveycore::set_var_label(d, rq = "Rare question", g = "Group")
}

test_that("export_crosstab() prints a negative lower bound as surveycore returns it (XH-16a) [numerical]", {
  skip_if_not_installed("surveycore")
  d <- neg_bound_design()
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = rq,
    banner = g,
    file_name = out,
    min_eff_n = 0,
    variance = "ci"
  )

  ref <- var_oracle(d, "rq", NULL, "ci")
  own <- ref[ref$value == "Rare", ]
  expect_lt(own$ci_low, 0)
  expect_lt(round(own$ci_low * 100, 1), 0)

  blk <- pct_block(out, "rq", "Response")
  cell <- as.character(blk$est[[match("Total", blk$heading)]][[
    which(blk$col_a == "Rare")
  ]])
  expect_identical(
    cell,
    paste0(
      paste0(round(own$pct * 100, 1), "%"),
      "\n(",
      round(own$ci_low * 100, 1),
      "% ",
      var_en_dash,
      " ",
      round(own$ci_high * 100, 1),
      "%)"
    )
  )
  # The printed lower bound is negative: a hyphen-minus right after the
  # opening parenthesis.
  expect_match(cell, "\n(-", fixed = TRUE)
})

test_that("export_crosstab() writes the variance on its own row under variance_display = \"row\" (XH-17) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    for (kind in names(pct_blocks)) {
      vars <- pct_blocks[[kind]]
      label <- if (kind == "single") "Response" else "Item"
      lbl <- paste0(nm, ", ", kind)

      write_var_block(d, out, vars, "se", "cell")
      n_cell <- nrow(block_body(out, vars[[1L]], label)$rows)

      write_var_block(d, out, vars, "se", "row")
      body <- block_body(out, vars[[1L]], label)
      expect_identical(
        nrow(body$rows),
        2L * n_cell,
        label = paste0(lbl, ": twice as many rows")
      )

      est_idx <- seq.int(1L, nrow(body$rows), by = 2L)
      var_idx <- est_idx + 1L
      est <- body$rows[est_idx, , drop = FALSE]
      vrows <- body$rows[var_idx, , drop = FALSE]

      # The estimate cells hold no parenthesis and no second line.
      est_cells <- as.character(unlist(est[body$data_cols]))
      expect_false(any(grepl("(", est_cells, fixed = TRUE)), label = lbl)
      expect_false(any(grepl("\n", est_cells, fixed = TRUE)), label = lbl)
      # The label columns of a variance row are blank.
      expect_true(
        all(is.na(unlist(vrows[body$label_cols]))),
        label = paste0(lbl, ": variance-row labels blank")
      )

      # Each variance cell matches the oracle; a cell with no variance
      # string is blank.
      blk <- list(
        est = est,
        col_a = as.character(est[[1L]]),
        heading = body$heading,
        data_cols = body$data_cols
      )
      for (i in seq_along(blk$col_a)[-1L]) {
        if (is.na(blk$col_a[[i]])) {
          blk$col_a[[i]] <- blk$col_a[[i - 1L]]
        }
      }
      n_checked <- 0L
      for (var in vars) {
        ref_total <- var_oracle(d, var, NULL, "se")
        ref_group <- var_oracle(d, var, "group", "se")
        for (r in seq_len(nrow(est))) {
          if (kind != "single" && blk$col_a[[r]] != pct_items[[var]]) {
            next
          }
          value <- var_row_value(kind, var, blk, r)
          for (j in body$data_cols) {
            cell <- var_cell_oracle(
              ref_total,
              ref_group,
              blk$heading[[j]],
              value
            )
            expect_identical(
              as.character(est[[j]][[r]]),
              expected_pct(cell$col_rows, cell$own, 1L),
              label = paste0(lbl, ": estimate ", var, " = ", value)
            )
            v <- expected_variance(cell$col_rows, cell$own, "se")
            expect_identical(
              as.character(vrows[[j]][[r]]),
              if (nzchar(v)) v else NA_character_,
              label = paste0(lbl, ": variance ", var, " = ", value)
            )
            n_checked <- n_checked + 1L
          }
        }
      }
      expect_identical(
        n_checked,
        nrow(est) * length(body$data_cols),
        label = paste0(lbl, ": cells checked")
      )
    }
  }
})

test_that("export_crosstab() writes the legend row only under `variance` (XH-18)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  note <- c(q1 = "Base: all adults")
  legends <- c(
    se = "Percentages; standard error in parentheses.",
    ci = "Percentages; 95% confidence interval in parentheses."
  )

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])

    write_var_block(d, out, "q1", NULL, base_notes = note)
    expect_identical(
      sheet_col_a(out, "q1")[1:4],
      c("Question one", "Base: all adults", NA, "Response"),
      label = paste0(nm, ": no legend")
    )
    expect_false(
      any(startsWith(sheet_text(out, "q1"), "Percentages")),
      label = paste0(nm, ": no legend anywhere")
    )

    for (v in names(legends)) {
      write_var_block(d, out, "q1", v, base_notes = note)
      expect_identical(
        sheet_col_a(out, "q1")[1:5],
        c("Question one", "Base: all adults", legends[[v]], NA, "Response"),
        label = paste0(nm, ": ", v)
      )
    }
  }
})

test_that("export_crosstab() names a non-default conf_level in the legend (XH-19) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- pct_sata_design(designs[[nm]])
    write_var_block(d, out, "q1", "ci", conf_level = 0.9)

    col_a <- sheet_col_a(out, "q1")
    expect_identical(
      col_a[[2L]],
      "Percentages; 90% confidence interval in parentheses.",
      label = nm
    )
    expect_false(any(grepl("95%", col_a, fixed = TRUE)), label = nm)

    # The intervals are the 90 percent ones.
    n <- expect_variance_cells(d, out, "q1", "single", "ci", nm, 0.9)
    expect_gt(n, 0L, label = nm)
  }
})

test_that("export_crosstab() writes - alone, with no variance, under both displays (XH-20)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    d@data$q1[d@data$group == "C"] <- NA_character_

    # The oracle: column C has no row with n > 0.
    ref <- var_oracle(d, "q1", "group", "se")
    expect_false(any(ref$n[ref$level == "C"] > 0L), label = nm)

    write_var_block(d, out, "q1", "se", "cell")
    blk <- pct_block(out, "q1", "Response")
    col_c <- as.character(blk$est[[match("C", blk$heading)]])
    col_a <- as.character(blk$est[[match("A", blk$heading)]])
    expect_identical(col_c, rep("-", 3L), label = paste0(nm, ": cell"))
    expect_true(
      all(grepl("\n(", col_a, fixed = TRUE)),
      label = paste0(nm, ": A carries a variance")
    )

    write_var_block(d, out, "q1", "se", "row")
    body <- block_body(out, "q1", "Response")
    j <- match("C", body$heading)
    cells_c <- as.character(body$rows[[j]])
    expect_identical(
      cells_c,
      rep(c("-", NA_character_), 3L),
      label = paste0(nm, ": row")
    )
  }
})

test_that("export_crosstab() writes 0% alone for a cell with no row of its own, under both displays", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- guard_design(designs[[nm]])
    # `Rare` is held only by rows of group A, so B and C answered and nobody
    # there chose it.
    rare_rows <- d@data$group == "A" & seq_len(nrow(d@data)) %% 7L == 0L
    d@data$qz <- ifelse(rare_rows, "Rare", d@data$q1)
    d <- surveycore::set_var_label(d, qz = "Question zero")

    # The oracle: B and C have answers, and no `Rare` row with n > 0.
    ref <- var_oracle(d, "qz", "group", "se")
    for (lvl in c("B", "C")) {
      col_rows <- ref[ref$level == lvl, ]
      expect_true(any(col_rows$n > 0L), label = paste(nm, lvl))
      expect_false(
        any(col_rows$n[col_rows$value == "Rare"] > 0L),
        label = paste(nm, lvl)
      )
    }

    write_var_block(d, out, "qz", "se", "cell")
    blk <- pct_block(out, "qz", "Response")
    r <- which(blk$col_a == "Rare")
    cell <- function(lvl) as.character(blk$est[[match(lvl, blk$heading)]][[r]])
    expect_identical(cell("B"), "0%", label = paste0(nm, ": cell, B"))
    expect_identical(cell("C"), "0%", label = paste0(nm, ": cell, C"))
    expect_match(cell("A"), "\n(", fixed = TRUE, label = paste0(nm, ": A"))

    write_var_block(d, out, "qz", "se", "row")
    body <- block_body(out, "qz", "Response")
    r <- which(as.character(body$rows[[1L]]) == "Rare")
    for (lvl in c("B", "C")) {
      j <- match(lvl, body$heading)
      expect_identical(
        as.character(body$rows[[j]][c(r, r + 1L)]),
        c("0%", NA_character_),
        label = paste0(nm, ": row, ", lvl)
      )
    }
    j <- match("A", body$heading)
    expect_match(
      as.character(body$rows[[j]][[r + 1L]]),
      "^\\(",
      label = paste0(nm, ": row, A")
    )
  }
})

# The data columns of the first block of a gen-fixture sheet, from its
# heading row: every column right of the label columns.
gen_data_cols <- function(path, sheet, label = "Response") {
  heading <- heading_cells(path, sheet, label)
  seq.int(match("Total", heading), max(which(!is.na(heading))))
}

test_that("export_crosstab() widens every data column under an interval (XB-05)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    for (display in c("cell", "row")) {
      write_gen_vars(d, out, "q1", variance = "ci", variance_display = display)
      n_cols <- block_width(out, "q1")
      expect_identical(n_cols, 4L, label = paste0(nm, ", ", display))
      expect_identical(
        col_widths(out, "q1")[seq_len(n_cols)],
        c(44L, rep(17L, n_cols - 1L)),
        label = paste0(nm, ", ", display)
      )
    }
  }
})

test_that("export_crosstab() sets the interval width from `decimals` (XB-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  widths <- c(`0` = 15L, `2` = 19L)

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    for (dec in names(widths)) {
      write_gen_vars(
        d,
        out,
        "q1",
        variance = "ci",
        variance_display = "cell",
        decimals = as.integer(dec)
      )
      n_cols <- block_width(out, "q1")
      expect_identical(
        col_widths(out, "q1")[seq_len(n_cols)],
        c(44L, rep(widths[[dec]], n_cols - 1L)),
        label = paste0(nm, ", decimals = ", dec)
      )
    }
  }
})

test_that("export_crosstab() keeps the width of 12 under a standard error (XB-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    for (display in c("cell", "row")) {
      write_gen_vars(d, out, "q1", variance = "se", variance_display = display)
      n_cols <- block_width(out, "q1")
      expect_identical(
        col_widths(out, "q1")[seq_len(n_cols)],
        c(44L, rep(12L, n_cols - 1L)),
        label = paste0(nm, ", ", display)
      )
    }
  }
})

# The three blocks of the sheet-property rows over the gen fixture: the
# variables, the sheet name and the heading label of each.
var_gen_blocks <- list(
  single = list(vars = "q1", label = "Response"),
  sata = list(vars = c("sata_a", "sata_b", "sata_c"), label = "Item"),
  battery = list(vars = c("bat_1", "bat_2", "bat_3"), label = "Item")
)

test_that("export_crosstab() wraps every estimate cell when the variance shares it (XB-08)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    for (kind in names(var_gen_blocks)) {
      blk <- var_gen_blocks[[kind]]
      sheet <- blk$vars[[1L]]
      for (v in c("ci", "se")) {
        lbl <- paste0(nm, ", ", kind, ", ", v)
        write_gen_vars(
          d,
          out,
          blk$vars,
          variance = v,
          variance_display = "cell"
        )
        body <- block_body(out, sheet, blk$label)
        expect_gt(length(body$row_nums), 0L, label = lbl)
        wb <- openxlsx2::wb_load(out)
        for (row in body$row_nums) {
          for (col in body$data_cols) {
            dims <- openxlsx2::wb_dims(rows = row, cols = col)
            expect_true(
              cell_wraps(wb, sheet, dims),
              label = paste0(lbl, ": ", dims, " wraps")
            )
          }
        }
        dims <- openxlsx2::wb_dims(
          rows = body$ss_rows[[1L]],
          cols = body$data_cols[[1L]]
        )
        expect_false(
          cell_wraps(wb, sheet, dims),
          label = paste0(lbl, ": sample-size ", dims, " does not wrap")
        )
      }
    }
  }
})

test_that("export_crosstab() sets each estimate row to 30 points when the variance shares the cell (XB-09)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    for (kind in names(var_gen_blocks)) {
      blk <- var_gen_blocks[[kind]]
      sheet <- blk$vars[[1L]]
      for (v in c("ci", "se")) {
        lbl <- paste0(nm, ", ", kind, ", ", v)
        write_gen_vars(
          d,
          out,
          blk$vars,
          variance = v,
          variance_display = "cell"
        )
        body <- block_body(out, sheet, blk$label)
        expect_gt(length(body$row_nums), 0L, label = lbl)
        wb <- openxlsx2::wb_load(out)
        for (row in body$row_nums) {
          expect_identical(
            row_height(wb, sheet, row),
            30,
            label = paste0(lbl, ": row ", row)
          )
        }
        for (row in body$ss_rows) {
          expect_identical(
            row_height(wb, sheet, row),
            NA_real_,
            label = paste0(lbl, ": sample-size row ", row)
          )
        }
      }
    }
  }
})

test_that("export_crosstab() sets no wrap and no estimate-row height without a second line (XB-10)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  calls <- list(
    list(variance = NULL, variance_display = "cell"),
    list(variance = "ci", variance_display = "row")
  )

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])
    for (kind in names(var_gen_blocks)) {
      blk <- var_gen_blocks[[kind]]
      sheet <- blk$vars[[1L]]
      for (call in calls) {
        lbl <- paste0(
          nm,
          ", ",
          kind,
          ", ",
          if (is.null(call$variance)) "NULL" else call$variance
        )
        fresh_path(out)
        crosstab_quiet(
          d,
          vars = tidyselect::all_of(blk$vars),
          banner = gen,
          file_name = out,
          min_eff_n = 0,
          variance = call$variance,
          variance_display = call$variance_display
        )
        body <- block_body(out, sheet, blk$label)
        expect_gt(length(body$row_nums), 0L, label = lbl)
        wb <- openxlsx2::wb_load(out)
        # Every row of the body: the estimate rows, and under "row" the
        # variance rows too.
        for (row in body$row_nums) {
          expect_identical(
            row_height(wb, sheet, row),
            NA_real_,
            label = paste0(lbl, ": row ", row)
          )
          for (col in body$data_cols) {
            dims <- openxlsx2::wb_dims(rows = row, cols = col)
            expect_false(
              cell_wraps(wb, sheet, dims),
              label = paste0(lbl, ": ", dims)
            )
          }
        }
      }
    }
  }
})

test_that("export_crosstab() gives column B the interval width when that is larger (XB-14)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")
  bat <- c("bat_1", "bat_2", "bat_3")

  for (nm in names(designs)) {
    d <- add_gen_fixture(designs[[nm]])

    # The stacked sheet: the battery block is Item, Response, Total, Male,
    # Female, so it spans five columns.
    for (dec in c(1L, 3L)) {
      write_gen_vars(
        d,
        out,
        c("q1", bat),
        layout = "stacked",
        variance = "ci",
        variance_display = "cell",
        decimals = dec
      )
      data_w <- 15L + 2L * dec
      expect_identical(
        col_widths(out, "Crosstab")[1:5],
        c(44L, max(20L, data_w), rep(data_w, 3L)),
        label = paste0(nm, ", stacked, decimals = ", dec)
      )
    }

    # The per-question battery sheet: column B is a label column only.
    write_gen_vars(d, out, bat, variance = "ci", decimals = 3L)
    expect_identical(
      col_widths(out, "bat_1")[1:5],
      c(44L, 20L, rep(21L, 3L)),
      label = paste0(nm, ", per question")
    )
  }
})

test_that("export_crosstab() takes variance_display after variance and before conf_level", {
  args <- names(formals(export_crosstab))
  expect_identical(
    args[match("variance", args) + 0:2],
    c("variance", "variance_display", "conf_level")
  )
  expect_identical(
    eval(formals(export_crosstab)$variance_display),
    c("cell", "row")
  )
})
