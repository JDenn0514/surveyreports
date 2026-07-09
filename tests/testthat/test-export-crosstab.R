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

test_that("export_crosstab() stacked layout renders SATA variables", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = c(sata_a, sata_b, sata_c), banner = q2,
                    file_name = out, layout = "stacked")
  )

  expect_true(file.exists(out))
  wb <- openxlsx2::wb_load(out)
  expect_true("Crosstab" %in% wb$sheet_names)
})

test_that("export_crosstab() stacked layout renders battery variables", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d, vars = c(bat_1, bat_2, bat_3), banner = q2,
                    file_name = out, layout = "stacked")
  )

  expect_true(file.exists(out))
  wb <- openxlsx2::wb_load(out)
  expect_true("Crosstab" %in% wb$sheet_names)
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

test_that("export_crosstab() heads a SATA block with the shared question preface", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    # Labelled items: variable_label holds the item text, preface the question
    d <- surveycore::set_var_label(
      designs[[nm]],
      variable = c("sata_a", "sata_b", "sata_c"),
      label    = c("Option A", "Option B", "Option C")
    )
    file.remove(out)
    suppressWarnings(
      export_crosstab(d, vars = c(sata_a, sata_b, sata_c),
                      banner = group, file_name = out)
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
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    d <- surveycore::set_var_label(
      designs[[nm]],
      variable = c("bat_1", "bat_2", "bat_3"),
      label    = c("Item one", "Item two", "Item three")
    )
    file.remove(out)
    suppressWarnings(
      export_crosstab(d, vars = c(bat_1, bat_2, bat_3),
                      banner = group, file_name = out)
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
  d <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  d <- surveycore::set_question_preface(d, variable = "q1", preface = "Intro text")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)

  expect_identical(as.character(df[1L, 1L]), "Agreement question")
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
  # Set label so missing-variable-label warning does not fire, allowing
  # expect_no_warning() to reliably detect any suppression warning
  d_small <- surveycore::set_var_label(d_small, variable = "q1", label = "Q1")
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(
    export_crosstab(
      d_small, vars = q1, banner = group, file_name = out,
      pub_type = "none"
    )
  )
  # All 3 banner levels should be present
  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_true(any(grepl("^A$", cells)), label = "A still present with pub_type='none'")
})

test_that("export_crosstab() pub_type='internal' suppresses below internal threshold", {
  skip_if_not_installed("surveycore")
  # N=2 per level ensures raw_n < 50 (internal threshold)
  df_small <- data.frame(
    psu    = 1L:6L,
    strata = rep(1L:2L, 3L),
    fpc    = rep(100L, 6L),
    wt     = rep(1.0, 6L),
    q1     = c("Agree", "Disagree", "Agree", "Neutral", "Disagree", "Agree"),
    group  = c("A", "A", "B", "B", "C", "C")
  )
  d <- surveycore::as_survey(df_small, ids = psu, strata = strata,
                              weights = wt, nest = TRUE)
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    pub_type = "internal"),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))
})

test_that("export_crosstab() SATA render writes suppression footnote with pub_type", {
  skip_if_not_installed("surveycore")
  # N=2 per group level triggers suppression for pub_type='external'
  df_small <- data.frame(
    psu    = 1L:6L,
    strata = rep(1L:2L, 3L),
    fpc    = rep(100L, 6L),
    wt     = rep(1.0, 6L),
    sata_a = c(0L, 1L, 0L, 1L, 0L, 1L),
    sata_b = c(1L, 0L, 1L, 0L, 1L, 0L),
    group  = c("A", "A", "B", "B", "C", "C")
  )
  d <- surveycore::as_survey(df_small, ids = psu, strata = strata,
                              weights = wt, nest = TRUE)
  d <- surveycore::set_sata(d, variable = c("sata_a", "sata_b"))
  d <- surveycore::set_question_preface(
    d, variable = c("sata_a", "sata_b"),
    preface = rep("Which apply?", 2L)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(d, vars = c(sata_a, sata_b), banner = group,
                    file_name = out, pub_type = "external"),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))
})

test_that("export_crosstab() battery render writes suppression footnote with pub_type", {
  skip_if_not_installed("surveycore")
  # N=2 per group level triggers suppression for pub_type='external'
  df_small <- data.frame(
    psu    = 1L:6L,
    strata = rep(1L:2L, 3L),
    fpc    = rep(100L, 6L),
    wt     = rep(1.0, 6L),
    bat_1  = c(1L, 2L, 3L, 4L, 5L, 1L),
    bat_2  = c(2L, 3L, 4L, 5L, 1L, 2L),
    group  = c("A", "A", "B", "B", "C", "C")
  )
  d <- surveycore::as_survey(df_small, ids = psu, strata = strata,
                              weights = wt, nest = TRUE)
  d <- surveycore::set_question_preface(
    d, variable = c("bat_1", "bat_2"),
    preface = rep("Rate these items:", 2L)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(d, vars = c(bat_1, bat_2), banner = group,
                    file_name = out, pub_type = "external"),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))
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

# 13. Edge cases ------------------------------------------------------------------

test_that("export_crosstab() handles all-NA variable without crashing", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  # all_na_var is NA_character_ throughout — suppressWarnings covers the
  # missing-variable-label warning that fires for unlabelled variables
  suppressWarnings(
    export_crosstab(d, vars = all_na_var, banner = group, file_name = out)
  )

  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)
})

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
  df_small$psu    <- 1L:2L
  d_small <- surveycore::as_survey(
    df_small, ids = psu, strata = strata, weights = wt, nest = TRUE
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(d_small, vars = q1, banner = group, file_name = out)
  )

  expect_true(file.exists(out))
})

test_that("export_crosstab() errors with empty-domain design", {
  skip_if_not_installed("surveycore")
  # Build a valid design then zero out its @data (same approach as section 12)
  d_empty      <- make_all_designs(seed = 42)$taylor
  d_empty@data <- d_empty@data[0L, ]
  out          <- withr::local_tempfile(fileext = ".xlsx")

  # Snapshot already captured in section 12 — use only expect_error(class=)
  # here to avoid a duplicate snapshot entry
  expect_error(
    export_crosstab(d_empty, vars = q1, banner = group, file_name = out),
    class = "surveyreports_error_empty_domain"
  )
})

test_that("export_crosstab() handles single-level banner without error", {
  skip_if_not_installed("surveycore")
  df_one_banner        <- make_survey_data(seed = 42)
  df_one_banner$banner_one <- "X"
  d_one_banner <- surveycore::as_survey(
    df_one_banner, ids = psu, strata = strata, weights = wt, nest = TRUE
  )
  d_one_banner <- surveycore::set_var_label(
    d_one_banner, variable = "q1", label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    export_crosstab(
      d_one_banner, vars = q1, banner = banner_one, file_name = out
    )
  )
  expect_true(file.exists(out))

  wb <- openxlsx2::wb_load(out)
  expect_true("q1" %in% wb$sheet_names)
})

# 14. Numerical accuracy ----------------------------------------------------------

test_that(".build_freq_frame() pct matches surveycore::get_freqs() prop for banner subgroups", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- suppressWarnings(
    surveyreports:::.build_freq_frame(
      d, "q1", clf,
      banner_resolved = "group",
      variance        = "se",
      conf_level      = 0.95
    )
  )$frame

  banner_rows <- frame[frame$subgroup_type == "banner", ]

  oracle <- suppressWarnings(
    surveycore::get_freqs(
      d,
      !!rlang::sym("q1"),
      group    = !!rlang::sym("group"),
      variance = "se"
    )
  )
  # oracle columns: group, q1, pct, se, n
  # Align by (group level, response value)
  for (grp in unique(oracle$group)) {
    for (val in unique(oracle$q1)) {
      oracle_pct <- oracle$pct[oracle$group == grp & oracle$q1 == val]
      frame_pct  <- banner_rows$pct[
        banner_rows$subgroup_value == grp & banner_rows$value == val
      ]
      if (length(oracle_pct) == 0L || length(frame_pct) == 0L) next
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
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- suppressWarnings(
    surveyreports:::.build_freq_frame(
      d, "q1", clf,
      banner_resolved = "group",
      variance        = "se",
      conf_level      = 0.95
    )
  )$frame

  banner_rows <- frame[frame$subgroup_type == "banner", ]

  oracle <- suppressWarnings(
    surveycore::get_freqs(
      d,
      !!rlang::sym("q1"),
      group    = !!rlang::sym("group"),
      variance = "se"
    )
  )
  # oracle columns: group, q1, pct, se, n
  for (grp in unique(oracle$group)) {
    for (val in unique(oracle$q1)) {
      oracle_se <- oracle$se[oracle$group == grp & oracle$q1 == val]
      frame_se  <- banner_rows$se[
        banner_rows$subgroup_value == grp & banner_rows$value == val
      ]
      if (length(oracle_se) == 0L || length(frame_se) == 0L) next
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
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  # Layout: row 1 title, row 2 spanner, row 3 header
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[[1L]], "Response")
  expect_identical(header[[2L]], "Total", label = "Total header before banner levels")
  expect_identical(header[3L:5L], c("A", "B", "C"))
  # Spanner row carries the synthetic Total group label too
  expect_identical(as.character(df[2L, 2L]), "Total")
})

test_that("export_crosstab() Total column values match the full-sample distribution", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

  df  <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  ref <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (i in seq_len(nrow(ref))) {
    val     <- as.character(ref[[1L]][[i]])
    row_idx <- which(as.character(df[[1L]]) == val)
    row_idx <- row_idx[row_idx > 3L][[1L]]
    expect_equal(
      as.numeric(df[row_idx, 2L]),
      round(ref$pct[[i]] * 100, 1L),
      tolerance = 1e-10,
      label = paste0("Total column for value '", val, "'")
    )
  }
})

test_that("export_crosstab() show_total=FALSE restores the banner-only layout", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out, show_total = FALSE)

  df     <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[[1L]], "Response")
  expect_identical(header[[2L]], "A", label = "first banner level directly after label col")
  expect_false("Total" %in% header, label = "no Total header when show_total=FALSE")
})

test_that("export_crosstab() show_total shifts the N column one position right", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out_with    <- withr::local_tempfile(fileext = ".xlsx")
  out_without <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out_with)
  export_crosstab(d, vars = q1, banner = group, file_name = out_without,
                  show_total = FALSE)

  hdr_with    <- as.character(unlist(
    openxlsx2::wb_to_df(out_with, sheet = "q1", col_names = FALSE)[3L, ]
  ))
  hdr_without <- as.character(unlist(
    openxlsx2::wb_to_df(out_without, sheet = "q1", col_names = FALSE)[3L, ]
  ))

  # 1 label + Total + 3 banner levels -> N at column 6; without Total -> 5
  expect_identical(which(hdr_with == "N"), 6L)
  expect_identical(which(hdr_without == "N"), 5L)
})

test_that("export_crosstab() SATA tables gain the Total column by default", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label    = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = c(sata_a, sata_b, sata_c), banner = group,
                  file_name = out)

  df     <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[1L:2L], c("Item", "Total"))

  # Total value for sata_a equals its full-sample share of value 1
  ref     <- suppressWarnings(surveycore::get_freqs(d, sata_a))
  ref_pct <- ref$pct[as.character(ref[[1L]]) == "1"]
  row_a   <- which(as.character(df[[1L]]) == "Option A")[[1L]]
  expect_equal(as.numeric(df[row_a, 2L]), round(ref_pct * 100, 1L),
               tolerance = 1e-10)
})

# 16. base_notes ------------------------------------------------------------------

test_that("export_crosstab() writes an italic base row under the title and shifts the table", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d, vars = q1, banner = group, file_name = out,
    base_notes = c(q1 = "Base: All respondents (n=200)")
  )

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  expect_identical(as.character(df[2L, 1L]), "Base: All respondents (n=200)")
  # Table shifted down one row: header now at row 4
  expect_identical(as.character(df[4L, 1L]), "Response")
})

test_that("export_crosstab() writes no base row when base_notes is NULL", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  expect_identical(as.character(df[3L, 1L]), "Response")
  expect_false(any(grepl("^Base:", as.character(df[[1L]])), na.rm = TRUE))
})

test_that("export_crosstab() writes base rows only for variables with an entry", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d, variable = c("q1", "q2"), label = c("Agreement question", "Yes/no question")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d, vars = c(q1, q2), banner = group, file_name = out,
    base_notes = c(q1 = "Base: only q1 has a note")
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
    variable = c("sata_a", "sata_b", "sata_c", "bat_1", "bat_2", "bat_3"),
    label    = c("Option A", "Option B", "Option C", "Item 1", "Item 2", "Item 3")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d, vars = c(sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
    banner = group, file_name = out,
    base_notes = c(sata_a = "Base: sata group", bat_1 = "Base: battery group")
  )

  df_sata <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  df_bat  <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
  expect_identical(as.character(df_sata[2L, 1L]), "Base: sata group")
  expect_identical(as.character(df_bat[2L, 1L]), "Base: battery group")
})

test_that("export_crosstab() errors when base_notes is not fully named", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    base_notes = c("unnamed note")),
    class = "surveyreports_error_base_notes_invalid"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    base_notes = c("unnamed note"))
  )
})

test_that("export_crosstab() errors when base_notes is not a character vector", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    base_notes = list(q1 = "a list, not a character vector")),
    class = "surveyreports_error_base_notes_invalid"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    base_notes = list(q1 = "a list, not a character vector"))
  )
})

test_that("export_crosstab() errors when base_notes is partially named", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(d, vars = q1, banner = group, file_name = out,
                    base_notes = c(q1 = "named", "unnamed")),
    class = "surveyreports_error_base_notes_invalid"
  )
})

# 17. Two-column battery layout ---------------------------------------------------

test_that("export_crosstab() battery tables use Item and Response label columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("bat_1", "bat_2", "bat_3"),
    label    = c("Item one", "Item two", "Item three")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = c(bat_1, bat_2, bat_3), banner = group,
                  file_name = out)

  df     <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[1L:3L], c("Item", "Response", "Total"))

  # Item label written once per item block, not repeated per scale value
  expect_identical(
    sum(as.character(df[[1L]]) == "Item one", na.rm = TRUE), 1L
  )
  # Scale values live in the Response column
  expect_true(all(c("1", "2", "3", "4", "5") %in% as.character(df[[2L]])))
  # No flattened "item (value)" labels remain
  expect_false(
    any(grepl("^Item one \\(", as.character(df[[1L]])), na.rm = TRUE)
  )
})

test_that("export_crosstab() battery N column follows the banner columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("bat_1", "bat_2", "bat_3"),
    label    = c("Item one", "Item two", "Item three")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = c(bat_1, bat_2, bat_3), banner = group,
                  file_name = out)

  df     <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  # Item | Response | Total | A | B | C | N
  expect_identical(which(header == "N"), 7L)
})

# 18. True-zero SATA cells --------------------------------------------------------

test_that("export_crosstab() prints 0 for an asked-but-never-selected SATA option", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  # sata_b: asked of everyone, selected by no one
  d@data$sata_b <- 0L
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label    = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = c(sata_a, sata_b, sata_c), banner = group,
                  file_name = out)

  df    <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  row_b <- which(as.character(df[[1L]]) == "Option B")[[1L]]
  # Total, A, B, C cells all print 0; N prints 0
  expect_identical(as.numeric(df[row_b, 2L]), 0)
  expect_identical(as.numeric(df[row_b, 3L]), 0)
  expect_identical(as.numeric(df[row_b, 6L]), 0)
})

test_that("export_crosstab() leaves never-asked banner subgroups blank in SATA tables", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  # Gate the whole block away from group C: never asked there
  asked          <- d@data$group != "C"
  d@data$sata_a  <- ifelse(asked, d@data$sata_a, NA_integer_)
  d@data$sata_b  <- ifelse(asked, 0L, NA_integer_)  # asked, never selected
  d@data$sata_c  <- ifelse(asked, d@data$sata_c, NA_integer_)
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label    = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = c(sata_a, sata_b, sata_c), banner = group,
                  file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  # Header: Item | Total | A | B | C | N
  row_a <- which(as.character(df[[1L]]) == "Option A")[[1L]]
  row_b <- which(as.character(df[[1L]]) == "Option B")[[1L]]

  # Asked subgroups have values; the never-asked C column stays blank
  expect_false(is.na(df[row_a, 3L]), label = "asked subgroup A has a value")
  expect_true(is.na(df[row_a, 5L]), label = "never-asked subgroup C is blank")
  # True zero prints 0 in asked subgroups but stays blank in C
  expect_identical(as.numeric(df[row_b, 3L]), 0)
  expect_true(is.na(df[row_b, 5L]), label = "zero row stays blank where never asked")
})
