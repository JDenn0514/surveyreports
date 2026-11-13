# tests/testthat/test-export-crosstab.R

# 1. Happy paths ------------------------------------------------------------------

test_that("export_crosstab() creates a non-empty .xlsx file for all 4 design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    result <- withVisible(export_crosstab(
      designs[[nm]],
      vars = q1,
      banner = group,
      file_name = out
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
    export_crosstab(d, vars = q1, banner = group, file_name = out)
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
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = q1,
      banner = c(group, q2),
      file_name = out,
      interactions = list(c("group", "q2"))
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
    export_crosstab(d, vars = c(q1, group), banner = c(group), file_name = out)
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
    file.remove(out)
    expect_no_error(
      suppressWarnings(
        export_crosstab(
          designs[[nm]],
          vars = c(sata_a, sata_b, sata_c),
          banner = group,
          file_name = out
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
    file.remove(out)
    expect_no_error(
      suppressWarnings(
        export_crosstab(
          designs[[nm]],
          vars = c(bat_1, bat_2, bat_3),
          banner = group,
          file_name = out
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
    file.remove(out)
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
    file.remove(out)
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
    variable = "q1",
    label = "Agreement question"
  )
  d <- surveycore::set_question_preface(
    d,
    variable = "q1",
    preface = "Intro text"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)

  expect_identical(as.character(df[1L, 1L]), "Agreement question")
})

# 8. Variance options -------------------------------------------------------------

test_that("export_crosstab() variance=NULL produces no se/ci columns in output frame", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
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
  d <- make_all_designs(seed = 42)$taylor
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
  d <- make_all_designs(seed = 42)$taylor
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

# 9. show_n and show_eff_n --------------------------------------------------------

test_that("export_crosstab() show_n=FALSE produces no N row-level data in workbook", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      show_n = FALSE
    )
  )

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  # With show_n=FALSE the workbook should not contain standalone "N" column
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_false(
    any(grepl("^N$", cells)),
    label = "no N header when show_n=FALSE"
  )
})

test_that("export_crosstab() show_n=TRUE includes N column in workbook", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      show_n = TRUE
    )
  )

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_true(
    any(grepl("^N$", cells)),
    label = "N header present when show_n=TRUE"
  )
})

test_that("export_crosstab() show_eff_n=TRUE produces file without error", {
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
        show_eff_n = TRUE
      )
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
    rep("A", 45L),
    rep("B", 3L),
    rep("C", 2L)
  )
  d_small <- surveycore::as_survey(
    df_small,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )

  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(
      d_small,
      vars = q1,
      banner = group,
      file_name = out,
      pub_type = "external"
    ),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  # Suppression footnote should be written (contains "suppressed")
  expect_true(
    any(grepl("suppressed", cells, ignore.case = TRUE)),
    label = "suppression footnote present in workbook"
  )
})

test_that("export_crosstab() pub_type='none' does not suppress any columns", {
  skip_if_not_installed("surveycore")
  df_small <- make_survey_data(n = 50L, seed = 99L)
  df_small$group <- c(rep("A", 45L), rep("B", 3L), rep("C", 2L))
  d_small <- surveycore::as_survey(
    df_small,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )
  # Set label so missing-variable-label warning does not fire, allowing
  # expect_no_warning() to reliably detect any suppression warning
  d_small <- surveycore::set_var_label(d_small, variable = "q1", label = "Q1")
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(
    export_crosstab(
      d_small,
      vars = q1,
      banner = group,
      file_name = out,
      pub_type = "none"
    )
  )
  # All 3 banner levels should be present
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "q1", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_true(
    any(grepl("^A$", cells)),
    label = "A still present with pub_type='none'"
  )
})

test_that("export_crosstab() pub_type='internal' suppresses below internal threshold", {
  skip_if_not_installed("surveycore")
  # N=2 per level ensures raw_n < 50 (internal threshold)
  df_small <- data.frame(
    psu = 1L:6L,
    strata = rep(1L:2L, 3L),
    fpc = rep(100L, 6L),
    wt = rep(1.0, 6L),
    q1 = c("Agree", "Disagree", "Agree", "Neutral", "Disagree", "Agree"),
    group = c("A", "A", "B", "B", "C", "C")
  )
  d <- surveycore::as_survey(
    df_small,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      pub_type = "internal"
    ),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))
})

test_that("export_crosstab() SATA render writes suppression footnote with pub_type", {
  skip_if_not_installed("surveycore")
  # N=2 per group level triggers suppression for pub_type='external'
  df_small <- data.frame(
    psu = 1L:6L,
    strata = rep(1L:2L, 3L),
    fpc = rep(100L, 6L),
    wt = rep(1.0, 6L),
    sata_a = c(0L, 1L, 0L, 1L, 0L, 1L),
    sata_b = c(1L, 0L, 1L, 0L, 1L, 0L),
    group = c("A", "A", "B", "B", "C", "C")
  )
  d <- surveycore::as_survey(
    df_small,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )
  d <- surveycore::set_sata(d, variable = c("sata_a", "sata_b"))
  d <- surveycore::set_question_preface(
    d,
    variable = c("sata_a", "sata_b"),
    preface = rep("Which apply?", 2L)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(
      d,
      vars = c(sata_a, sata_b),
      banner = group,
      file_name = out,
      pub_type = "external"
    ),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))
})

test_that("export_crosstab() battery render writes suppression footnote with pub_type", {
  skip_if_not_installed("surveycore")
  # N=2 per group level triggers suppression for pub_type='external'
  df_small <- data.frame(
    psu = 1L:6L,
    strata = rep(1L:2L, 3L),
    fpc = rep(100L, 6L),
    wt = rep(1.0, 6L),
    bat_1 = c(1L, 2L, 3L, 4L, 5L, 1L),
    bat_2 = c(2L, 3L, 4L, 5L, 1L, 2L),
    group = c("A", "A", "B", "B", "C", "C")
  )
  d <- surveycore::as_survey(
    df_small,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )
  d <- surveycore::set_question_preface(
    d,
    variable = c("bat_1", "bat_2"),
    preface = rep("Rate these items:", 2L)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(
      d,
      vars = c(bat_1, bat_2),
      banner = group,
      file_name = out,
      pub_type = "external"
    ),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_true(file.exists(out))
})

# 11. Missing metadata warning ----------------------------------------------------

test_that("export_crosstab() warns about missing variable_label when unset", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_crosstab(d, vars = q1, banner = group, file_name = out),
    class = "surveyreports_warning_missing_variable_label"
  )
})

test_that("export_crosstab() does not warn when variable_label is set", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out
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

test_that("export_crosstab() errors when decimals is not a positive integer", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      decimals = 0
    ),
    class = "surveyreports_error_invalid_decimals"
  )
  expect_snapshot(
    error = TRUE,
    export_crosstab(d, vars = q1, banner = group, file_name = out, decimals = 0)
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

test_that("export_crosstab() handles all-NA variable without crashing", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
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
  df_small$psu <- 1L:2L
  d_small <- surveycore::as_survey(
    df_small,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
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
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    export_crosstab(
      d_one_banner,
      vars = q1,
      banner = banner_one,
      file_name = out
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
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

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
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "q1", col_names = FALSE)
  ref <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (i in seq_len(nrow(ref))) {
    val <- as.character(ref[[1L]][[i]])
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
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out,
    show_total = FALSE
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

test_that("export_crosstab() show_total shifts the N column one position right", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out_with <- withr::local_tempfile(fileext = ".xlsx")
  out_without <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(d, vars = q1, banner = group, file_name = out_with)
  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out_without,
    show_total = FALSE
  )

  hdr_with <- as.character(unlist(
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
    label = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c),
    banner = group,
    file_name = out
  )

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  header <- as.character(unlist(df[3L, ]))
  expect_identical(header[1L:2L], c("Item", "Total"))

  # Total value for sata_a equals its full-sample share of value 1
  ref <- suppressWarnings(surveycore::get_freqs(d, sata_a))
  ref_pct <- ref$pct[as.character(ref[[1L]]) == "1"]
  row_a <- which(as.character(df[[1L]]) == "Option A")[[1L]]
  expect_equal(
    as.numeric(df[row_a, 2L]),
    round(ref_pct * 100, 1L),
    tolerance = 1e-10
  )
})

# 16. base_notes ------------------------------------------------------------------

test_that("export_crosstab() writes an italic base row under the title and shifts the table", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = q1,
    banner = group,
    file_name = out,
    base_notes = c(q1 = "Base: All respondents (n=200)")
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
    variable = "q1",
    label = "Agreement question"
  )
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
    d,
    variable = c("q1", "q2"),
    label = c("Agreement question", "Yes/no question")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(q1, q2),
    banner = group,
    file_name = out,
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
    label = c("Option A", "Option B", "Option C", "Item 1", "Item 2", "Item 3")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c, bat_1, bat_2, bat_3),
    banner = group,
    file_name = out,
    base_notes = c(sata_a = "Base: sata group", bat_1 = "Base: battery group")
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
    variable = c("bat_1", "bat_2", "bat_3"),
    label = c("Item one", "Item two", "Item three")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(bat_1, bat_2, bat_3),
    banner = group,
    file_name = out
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

test_that("export_crosstab() battery N column follows the banner columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("bat_1", "bat_2", "bat_3"),
    label = c("Item one", "Item two", "Item three")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(bat_1, bat_2, bat_3),
    banner = group,
    file_name = out
  )

  df <- openxlsx2::wb_to_df(out, sheet = "bat_1", col_names = FALSE)
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
    label = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c),
    banner = group,
    file_name = out
  )

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
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
  asked <- d@data$group != "C"
  d@data$sata_a <- ifelse(asked, d@data$sata_a, NA_integer_)
  d@data$sata_b <- ifelse(asked, 0L, NA_integer_) # asked, never selected
  d@data$sata_c <- ifelse(asked, d@data$sata_c, NA_integer_)
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_crosstab(
    d,
    vars = c(sata_a, sata_b, sata_c),
    banner = group,
    file_name = out
  )

  df <- openxlsx2::wb_to_df(out, sheet = "sata_a", col_names = FALSE)
  # Header: Item | Total | A | B | C | N
  row_a <- which(as.character(df[[1L]]) == "Option A")[[1L]]
  row_b <- which(as.character(df[[1L]]) == "Option B")[[1L]]

  # Asked subgroups have values; the never-asked C column stays blank
  expect_false(is.na(df[row_a, 3L]), label = "asked subgroup A has a value")
  expect_true(is.na(df[row_a, 5L]), label = "never-asked subgroup C is blank")
  # True zero prints 0 in asked subgroups but stays blank in C
  expect_identical(as.numeric(df[row_b, 3L]), 0)
  expect_true(
    is.na(df[row_b, 5L]),
    label = "zero row stays blank where never asked"
  )
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

    expect_true(is.character(result), label = paste0(nm, ": character"))
    expect_identical(length(result), nrow(d@data), label = paste0(nm, ": len"))
    expect_identical(
      result[!is.na(codes) & codes == 1],
      rep("Male", sum(codes == 1, na.rm = TRUE)),
      label = paste0(nm, ": code 1")
    )
    expect_identical(
      result[!is.na(codes) & codes == 2],
      rep("Female", sum(codes == 2, na.rm = TRUE)),
      label = paste0(nm, ": code 2")
    )
    expect_identical(is.na(result), is.na(codes), label = paste0(nm, ": NA"))
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
  expect_setequal(unique(result), as.character(ref$gen))
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

# The About sheet as a data frame of columns A and B, one row per sheet row.
# Blank rows stay in the frame, so a row index is a sheet row minus 1.
about_sheet <- function(path) {
  df <- openxlsx2::wb_to_df(
    path,
    sheet = "About",
    col_names = FALSE,
    cols = 1:2
  )
  data.frame(
    A = as.character(df[[1L]]),
    B = as.character(df[[2L]]),
    stringsAsFactors = FALSE
  )
}

# The glossary terms of an About sheet, in sheet order: the column A cells
# below the "What these numbers mean" heading.
about_glossary <- function(about) {
  start <- match("What these numbers mean", about$A)
  rows <- about[seq.int(start + 1L, nrow(about)), ]
  stats::setNames(rows$B, rows$A)
}

# A design whose q1, q2 and group carry variable labels, so the missing-label
# warning does not fire in a test about the cover sheet.
cover_design <- function(d) {
  surveycore::set_var_label(
    d,
    q1 = "Question one",
    q2 = "Question two",
    group = "Group"
  )
}

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

    export_crosstab(d, vars = q1, banner = group, file_name = out)

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

    export_crosstab(d, vars = q1, banner = group, file_name = out)

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

    export_crosstab(d, vars = q1, banner = group, file_name = out)

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

    export_crosstab(d, vars = q1, banner = group, file_name = out)

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

    export_crosstab(d, vars = c(q1, q2), banner = group, file_name = out)

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
    export_crosstab(d_dom, vars = q1, banner = q2, file_name = out)
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
    export_crosstab(d, vars = q1, banner = q2, file_name = out)
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

    export_crosstab(
      d,
      vars = About,
      banner = group,
      file_name = out,
      layout = "per_question"
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

    result <- export_crosstab(d, vars = about, banner = group, file_name = out)

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

    export_crosstab(
      d,
      vars = tidyselect::all_of(c(long_a, long_b)),
      banner = group,
      file_name = out
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

    export_crosstab(d, vars = q1, banner = group, file_name = out)

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
  missing = paste(
    "A subgroup whose effective sample size falls below the minimum is not",
    "shown. The minimum for this workbook is listed above. The test is on",
    "the size of the subgroup itself, not on how many of its members",
    "answered any one question, so a question that many people skipped can",
    "still be shown for a subgroup that clears the minimum."
  ),
  pct = paste(
    "Each percentage is based on the people who answered that question,",
    "which can be fewer than the sample size shown above the table. A value",
    "that is not zero but rounds to zero at the shown precision reads <0.1%.",
    "A value below 100 that rounds to 100 reads >99.9%. A true zero reads",
    "0%. A dash means the answer was not chosen in that column, or was never",
    "offered there."
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
    "0%. A dash means the answer was not chosen in that column, or was never",
    "offered there."
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
    "zero reads 0%. A dash means the answer was not chosen in that column,",
    "or was never offered there."
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
