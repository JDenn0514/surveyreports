# tests/testthat/test-export-topline.R

# 1. Happy paths ------------------------------------------------------------------

test_that("make_all_designs() returns one design per survey_base subclass", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  expect_identical(
    names(designs),
    c("taylor", "replicate", "twophase", "nonprob")
  )
  expect_true(S7::S7_inherits(designs$nonprob, surveycore::survey_nonprob))
})

test_that("export_topline() creates a non-empty .xlsx file for all 4 design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    result <- withVisible(export_topline(
      designs[[nm]],
      vars = q1,
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
    expect_true(
      "Topline" %in% wb$sheet_names,
      label = paste0(nm, ": Topline sheet")
    )
  }
})

# 2. Multiple variables -----------------------------------------------------------

test_that("export_topline() includes all variable names in the workbook for multiple vars", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(d, vars = c(q1, q2), file_name = out)

  wb <- openxlsx2::wb_load(out)
  expect_true("Topline" %in% wb$sheet_names)

  cells <- unlist(openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE))
  cells <- as.character(cells[!is.na(cells)])

  # question_text falls back to variable name when no label is set;
  # the label warning fires — suppress it here since we're testing workbook content
  expect_true(
    any(grepl("q1|Agree|Neutral|Disagree", cells)),
    label = "q1 content in workbook"
  )
  expect_true(any(grepl("q2|Yes|No", cells)), label = "q2 content in workbook")
})

# 3. survey_collection wave columns -----------------------------------------------

test_that("export_topline() handles survey_collection with wave columns", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  coll <- surveycore::as_survey_collection(
    wave1 = designs$taylor,
    wave2 = designs$replicate
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(export_topline(coll, vars = q1, file_name = out))
  expect_true(file.exists(out))

  wb <- openxlsx2::wb_load(out)
  expect_true("Topline" %in% wb$sheet_names)

  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(any(grepl("Total", cells)), label = "Total column present")
  expect_true(any(grepl("wave1", cells)), label = "wave1 in headers")
  expect_true(any(grepl("wave2", cells)), label = "wave2 in headers")
  expect_true(any(grepl("n=", cells)), label = "(n=) in wave headers")
})

# 4. var_type dispatch: SATA and battery ------------------------------------------

test_that("export_topline() handles SATA variables for all design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    expect_no_error(
      export_topline(
        designs[[nm]],
        vars = c(sata_a, sata_b, sata_c),
        file_name = out
      )
    )
    expect_true(file.exists(out))
  }
})

test_that("export_topline() handles battery variables for all design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    expect_no_error(
      export_topline(
        designs[[nm]],
        vars = c(bat_1, bat_2, bat_3),
        file_name = out
      )
    )
    expect_true(file.exists(out))
  }
})

test_that("export_topline() heads a SATA block with the shared question preface", {
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
    export_topline(d, vars = c(sata_a, sata_b, sata_c), file_name = out)

    wb <- openxlsx2::wb_load(out)
    df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)

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

test_that("export_topline() heads a battery block with the shared question preface", {
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
    export_topline(d, vars = c(bat_1, bat_2, bat_3), file_name = out)

    wb <- openxlsx2::wb_load(out)
    df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)

    expect_identical(
      as.character(df[1L, 1L]),
      "Please rate the following items:",
      label = paste0(nm, ": battery header cell is the question preface")
    )
    expect_true(
      all(c("Item one", "Item two", "Item three") %in% as.character(df[[1L]])),
      label = paste0(nm, ": item labels remain the sub-item headers")
    )
  }
})

test_that("export_topline() heads a single block with variable_label even when a preface is set", {
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

  export_topline(d, vars = q1, file_name = out)

  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)

  expect_identical(as.character(df[1L, 1L]), "Agreement question")
})

test_that(".group_header_text() falls back to question_text when no preface exists", {
  frame_na <- tibble::tibble(
    question_text = "First item label",
    question_preface = NA_character_
  )
  frame_empty <- tibble::tibble(
    question_text = "First item label",
    question_preface = ""
  )

  expect_identical(
    surveyreports:::.group_header_text(frame_na),
    "First item label"
  )
  expect_identical(
    surveyreports:::.group_header_text(frame_empty),
    "First item label"
  )
})

# 5. Variance options -------------------------------------------------------------

test_that("export_topline() variance = NULL produces no se/ci columns in frame", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(
    d,
    vars = q1,
    file_name = out,
    variance = NULL
  ))
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_false(
    any(grepl("(?i)\\bse\\b|std.*err", cells, perl = TRUE)),
    label = "no se column when variance=NULL"
  )
  expect_false(
    any(grepl("(?i)ci_|conf.*int|lower|upper", cells, perl = TRUE)),
    label = "no ci column when variance=NULL"
  )
})

test_that("export_topline() variance = 'se' produces no error", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(
      d,
      vars = q1,
      file_name = out,
      variance = "se"
    ))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() variance = 'ci' produces no error", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(
      d,
      vars = q1,
      file_name = out,
      variance = "ci"
    ))
  )
  expect_true(file.exists(out))
})

# 6. show_n and show_eff_n --------------------------------------------------------

test_that("export_topline() show_n = FALSE omits N from workbook", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(
    d,
    vars = q1,
    file_name = out,
    show_n = FALSE
  ))
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)

  # With show_n = FALSE the third column should be empty / absent
  expect_true(ncol(df) <= 2L || all(is.na(df[[3]])))
})

test_that("export_topline() show_n = TRUE includes N column", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(d, vars = q1, file_name = out, show_n = TRUE))
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(any(grepl("^N$", cells)), label = "N header present")
})

test_that("export_topline() show_eff_n = TRUE adds eff N to % header", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_topline(d, vars = q1, file_name = out, show_eff_n = TRUE)
  )
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(any(grepl("Eff N", cells)), label = "Eff N in header")
})

# 7. Missing metadata warning -----------------------------------------------------

test_that("export_topline() warns about missing variable_label when unset", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_topline(d, vars = q1, file_name = out),
    class = "surveyreports_warning_missing_variable_label"
  )
})

test_that("export_topline() does not warn when variable_label is set", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(export_topline(d, vars = q1, file_name = out))
})

test_that("export_topline() uses variable name as question text when label unset", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(d, vars = q1, file_name = out))
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(
    any(grepl("^q1$", cells)),
    label = "var name used as question text"
  )
})

# 9. Edge cases -------------------------------------------------------------------

test_that("export_topline() handles all-NA variable without crashing", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  # all_na_var is NA_character_ for every row
  expect_no_error(
    suppressWarnings(export_topline(d, vars = all_na_var, file_name = out))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles a single-value variable", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$sv <- "constant"
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(d, vars = sv, file_name = out))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles a minimal two-row design", {
  skip_if_not_installed("surveycore")
  # surveycore requires >= 2 rows; 2-row is the minimal viable design
  df2 <- data.frame(q1 = c("Agree", "Disagree"), wt = c(1.0, 1.5))
  d2 <- surveycore::as_survey(df2, weights = wt)
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(d2, vars = q1, file_name = out))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() collection with show_eff_n = TRUE writes the wave headers", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll <- surveycore::as_survey_collection(
    wave1 = designs$taylor,
    wave2 = designs$replicate
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_topline(coll, vars = q1, file_name = out, show_eff_n = TRUE)
  )
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(file.exists(out))
  # The wave headers are always written. No header carries an effective N
  # on a collection; TN-03 asserts the exact text.
  expect_true(any(grepl("wave1|wave2|Total", cells)))
})

test_that("export_topline() handles all-NA SATA variable without crashing", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$sata_a <- NA_integer_
  d@data$sata_b <- NA_integer_
  d@data$sata_c <- NA_integer_
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_topline(d, vars = c(sata_a, sata_b, sata_c), file_name = out)
    )
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles all-NA battery variable without crashing", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$bat_1 <- NA_integer_
  d@data$bat_2 <- NA_integer_
  d@data$bat_3 <- NA_integer_
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_topline(d, vars = c(bat_1, bat_2, bat_3), file_name = out)
    )
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles survey_collection where one wave is missing the variable", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  # wave2 design without q1 — validation passes (uses wave1), wave2 gets (n/a) placeholder
  df_no_q1 <- make_survey_data(seed = 42)
  df_no_q1 <- df_no_q1[, !names(df_no_q1) %in% "q1"]
  wave2_no_q1 <- surveycore::as_survey(
    df_no_q1,
    ids = psu,
    strata = strata,
    weights = wt,
    nest = TRUE
  )
  coll <- surveycore::as_survey_collection(
    wave1 = designs$taylor,
    wave2 = wave2_no_q1
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(coll, vars = q1, file_name = out))
  )
  expect_true(file.exists(out))
  wb <- openxlsx2::wb_load(out)
  df <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])
  expect_true(any(grepl("wave1", cells)))
  expect_true(any(grepl("wave2", cells)))
})

# 10. Numerical accuracy ----------------------------------------------------------

test_that(".build_freq_frame() totals match surveycore::get_freqs() for q1 [numerical]", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d,
    "q1",
    clf,
    conf_level = 0.95,
    show_eff_n = FALSE
  )$frame
  total_rows <- frame[frame$subgroup_type == "total", ]

  ref <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (val in ref[[1L]]) {
    rr_pct <- total_rows$pct[total_rows$value == as.character(val)]
    sc_pct <- ref$pct[ref[[1L]] == val]
    expect_equal(
      rr_pct,
      sc_pct,
      tolerance = 1e-10,
      label = paste0("pct match for value '", val, "'")
    )
  }
})

test_that(".build_freq_frame() SE matches surveycore::get_freqs() with variance='se'", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d,
    "q1",
    clf,
    variance = "se",
    conf_level = 0.95
  )$frame
  total_rows <- frame[frame$subgroup_type == "total", ]

  ref <- suppressWarnings(surveycore::get_freqs(d, q1, variance = "se"))

  for (val in ref[[1L]]) {
    rr_se <- total_rows$se[total_rows$value == as.character(val)]
    sc_se <- ref$se[ref[[1L]] == val]
    expect_equal(
      rr_se,
      sc_se,
      tolerance = 1e-8,
      label = paste0("se match for value '", val, "'")
    )
  }
})

test_that(".build_freq_frame() CI bounds match surveycore::get_freqs() with variance='ci'", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d,
    "q1",
    clf,
    variance = "ci",
    conf_level = 0.95
  )$frame
  total_rows <- frame[frame$subgroup_type == "total", ]

  ref <- suppressWarnings(surveycore::get_freqs(
    d,
    q1,
    variance = "ci",
    conf_level = 0.95
  ))

  for (val in ref[[1L]]) {
    rr_low <- total_rows$ci_low[total_rows$value == as.character(val)]
    rr_high <- total_rows$ci_high[total_rows$value == as.character(val)]
    sc_low <- ref$ci_low[ref[[1L]] == val]
    sc_high <- ref$ci_high[ref[[1L]] == val]
    expect_equal(
      rr_low,
      sc_low,
      tolerance = 1e-6,
      label = paste0("ci_low match for value '", val, "'")
    )
    expect_equal(
      rr_high,
      sc_high,
      tolerance = 1e-6,
      label = paste0("ci_high match for value '", val, "'")
    )
  }
})

# 8. Error paths -------------------------------------------------------------------

test_that("export_topline() errors when design is not a survey object", {
  out <- withr::local_tempfile(fileext = ".xlsx")
  df <- data.frame(q1 = 1:5, wt = rep(1, 5))

  expect_error(
    export_topline(df, vars = q1, file_name = out),
    class = "surveyreports_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, export_topline(df, vars = q1, file_name = out))
})

test_that("export_topline() errors when vars resolves to zero columns", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = starts_with("zzz"), file_name = out),
    class = "surveyreports_error_vars_empty_selection"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(d, vars = starts_with("zzz"), file_name = out)
  )
})

test_that("export_topline() errors when vars_resolved contains a missing column", {
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

test_that("export_topline() errors when file_name does not end in .xlsx", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor

  expect_error(
    export_topline(d, vars = q1, file_name = "output.csv"),
    class = "surveyreports_error_invalid_file_name"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(d, vars = q1, file_name = "output.csv")
  )
})

test_that("export_topline() errors when conf_level is outside (0, 1)", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = q1, file_name = out, conf_level = 1.5),
    class = "surveyreports_error_invalid_conf_level"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(d, vars = q1, file_name = out, conf_level = 1.5)
  )
})

test_that("export_topline() errors when decimals is not a positive integer", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = q1, file_name = out, decimals = 0),
    class = "surveyreports_error_invalid_decimals"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(d, vars = q1, file_name = out, decimals = 0)
  )
})

# 11. base_notes ------------------------------------------------------------------

test_that("export_topline() writes an italic base row under the title and shifts the table", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(
    d,
    vars = q1,
    file_name = out,
    base_notes = c(q1 = "Base: All respondents (n=200)")
  )

  df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
  expect_identical(as.character(df[1L, 1L]), "Agreement question")
  expect_identical(as.character(df[2L, 1L]), "Base: All respondents (n=200)")
  # Header shifted from row 2 to row 3
  expect_identical(as.character(df[3L, 1L]), "Response")
})

test_that("export_topline() writes no base row when base_notes is NULL", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = "q1",
    label = "Agreement question"
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(d, vars = q1, file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
  expect_identical(as.character(df[2L, 1L]), "Response")
  expect_false(any(grepl("^Base:", as.character(df[[1L]])), na.rm = TRUE))
})

test_that("export_topline() keys battery sub-item base notes by their own variable names", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("bat_1", "bat_2", "bat_3"),
    label = c("Item one", "Item two", "Item three")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(
    d,
    vars = c(bat_1, bat_2, bat_3),
    file_name = out,
    base_notes = c(
      bat_1 = "Base: item-one note",
      bat_3 = "Base: item-three note"
    )
  )

  df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
  col_a <- as.character(df[[1L]])

  row_1 <- which(col_a == "Item one")[[1L]]
  row_2 <- which(col_a == "Item two")[[1L]]
  row_3 <- which(col_a == "Item three")[[1L]]
  expect_identical(col_a[[row_1 + 1L]], "Base: item-one note")
  expect_identical(
    col_a[[row_2 + 1L]],
    "Response",
    label = "sub-item without an entry gets no base row"
  )
  expect_identical(col_a[[row_3 + 1L]], "Base: item-three note")
})

test_that("export_topline() keys a SATA group's base note by its first member", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(
    d,
    vars = c(sata_a, sata_b, sata_c),
    file_name = out,
    base_notes = c(sata_a = "Base: sata group note")
  )

  df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
  expect_identical(as.character(df[2L, 1L]), "Base: sata group note")
  expect_identical(as.character(df[3L, 1L]), "Item")
})

test_that("export_topline() errors when base_notes is not fully named", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(
      d,
      vars = q1,
      file_name = out,
      base_notes = c("unnamed note")
    ),
    class = "surveyreports_error_base_notes_invalid"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(
      d,
      vars = q1,
      file_name = out,
      base_notes = c("unnamed note")
    )
  )
})

test_that("export_topline() errors when base_notes is not a character vector", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = q1, file_name = out, base_notes = 1L:3L),
    class = "surveyreports_error_base_notes_invalid"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(d, vars = q1, file_name = out, base_notes = 1L:3L)
  )
})

# 12. True-zero SATA cells --------------------------------------------------------

test_that("export_topline() prints 0 for an asked-but-never-selected SATA option", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$sata_b <- 0L
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(d, vars = c(sata_a, sata_b, sata_c), file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
  row_b <- which(as.character(df[[1L]]) == "Option B")[[1L]]
  expect_identical(as.numeric(df[row_b, 2L]), 0)
  expect_identical(as.numeric(df[row_b, 3L]), 0)
})

test_that("export_topline() leaves a never-asked SATA item blank, not 0", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  # sata_b: never asked at all (all NA) -- must stay blank
  d@data$sata_b <- NA_integer_
  d <- surveycore::set_var_label(
    d,
    variable = c("sata_a", "sata_b", "sata_c"),
    label = c("Option A", "Option B", "Option C")
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(d, vars = c(sata_a, sata_b, sata_c), file_name = out)

  df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
  col_a <- as.character(df[[1L]])
  row_b <- which(col_a == "Option B")
  if (length(row_b) > 0L) {
    expect_true(
      is.na(df[row_b[[1L]], 2L]),
      label = "never-asked item pct is blank"
    )
  } else {
    # get_freqs() may drop an all-NA item from the frame entirely --
    # absence (no 0-valued row) also satisfies the contract
    expect_true(TRUE)
  }
})

# 13. Cover sheet ---------------------------------------------------------------
# Every workbook gains an "About" sheet as sheet 1 (spec 3.14, spec 4.1). A
# topline workbook withholds nothing and writes numeric cells, so its glossary
# holds two entries, or three under variance = "ci" (spec 3.15).

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

# The glossary of an About sheet, term = text, in sheet order.
about_glossary <- function(about) {
  start <- match("What these numbers mean", about$A)
  rows <- about[seq.int(start + 1L, nrow(about)), ]
  stats::setNames(rows$B, rows$A)
}

# TRUE when the cell's resolved font is bold. A cell with no style of its own
# takes style 0, the workbook default.
cell_is_bold <- function(wb, sheet, dims) {
  style <- unname(openxlsx2::wb_get_cell_style(wb, sheet, dims))
  style_id <- if (is.na(style) || !nzchar(style)) 0L else as.integer(style)
  xf <- wb$styles_mgr$styles$cellXfs[[style_id + 1L]]
  font_id <- as.integer(sub('.*fontId="([0-9]+)".*', "\\1", xf))
  font <- wb$styles_mgr$styles$fonts[[font_id + 1L]]
  grepl("<b/>|<b val=\"1\"/>|<b val=\"true\"/>", font)
}

# A design whose q1 and q2 carry variable labels, so the missing-label
# warning does not fire in a test about the cover sheet.
cover_design <- function(d) {
  surveycore::set_var_label(d, q1 = "Question one", q2 = "Question two")
}

topline_glossary_text <- list(
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
  ci = paste(
    "The interval is a normal approximation. For a very rare or a",
    "near-unanimous answer a bound can fall below 0 percent or rise above 100",
    "percent. That is a property of the approximation, not a count of people."
  )
)

test_that("export_topline() writes the About sheet first with a topline glossary (TP-06)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])

    export_topline(d, vars = q1, file_name = out, variance = NULL)

    wb <- openxlsx2::wb_load(out)
    expect_identical(
      unname(wb$get_sheet_names()),
      c("About", "Topline"),
      label = paste0(nm, ": About is sheet 1")
    )
    glossary <- about_glossary(about_sheet(out))
    expect_identical(
      glossary,
      c(
        "Unweighted sample size" = topline_glossary_text$unweighted,
        "Effective sample size (ESS)" = topline_glossary_text$ess
      ),
      label = paste0(nm, ": the two sample-size terms")
    )
    expect_false(
      "Why a column is missing" %in% names(glossary),
      label = paste0(nm, ": no missing-column entry")
    )
    expect_false(
      "Percentages" %in% names(glossary),
      label = paste0(nm, ": no Percentages entry")
    )
  }
})

test_that("export_topline() adds the interval entry under variance = 'ci' (TP-06a)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])

    export_topline(d, vars = q1, file_name = out, variance = "ci")

    glossary <- about_glossary(about_sheet(out))
    expect_identical(
      glossary[["Confidence intervals"]],
      topline_glossary_text$ci,
      label = paste0(nm, ": the interval entry with its text")
    )
    expect_identical(
      names(glossary),
      c(
        "Unweighted sample size",
        "Effective sample size (ESS)",
        "Confidence intervals"
      ),
      label = paste0(nm, ": three entries")
    )
    expect_false(
      "Why a column is missing" %in% names(glossary),
      label = paste0(nm, ": no missing-column entry")
    )
    expect_false(
      "Percentages" %in% names(glossary),
      label = paste0(nm, ": no Percentages entry")
    )
  }
})

test_that("export_topline() writes no withheld block on the About sheet (TP-07)", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])

    export_topline(d, vars = c(q1, q2), file_name = out)

    about <- about_sheet(out)
    expect_identical(
      about$A,
      c(
        "Key",
        "What these numbers mean",
        "Unweighted sample size",
        "Effective sample size (ESS)"
      ),
      label = paste0(nm, ": header and glossary only")
    )
    expect_false(
      any(c("Subgroups not shown", "Not shown") %in% about$A),
      label = paste0(nm, ": no withheld block")
    )
  }
})

# A two-wave collection from two taylor designs, waves named w1 and w2.
cover_collection <- function(w1, w2) {
  surveycore::as_survey_collection(
    w1 = cover_design(w1),
    w2 = cover_design(w2)
  )
}

test_that("export_topline() writes one metadata block per wave in @surveys order (TC-05)", {
  skip_if_not_installed("surveycore")
  w1 <- surveycore::set_dataset_metadata(
    make_all_designs(seed = 42)$taylor,
    vendor = "Vendor One",
    survey_name = "Wave 1 Survey",
    field_end = "2024-01-31",
    field_start = "2024-01-02"
  )
  w2 <- surveycore::set_dataset_metadata(
    make_all_designs(seed = 7)$taylor,
    field_period = "Summer 2024",
    data_name = "Wave 2 Data",
    survey_name = "Wave 2 Survey",
    vendor = "Vendor Two",
    field_start = "2024-06-01"
  )
  coll <- cover_collection(w1, w2)
  expect_identical(names(coll@surveys), c("w1", "w2"))
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(coll, vars = q1, file_name = out)

  about <- about_sheet(out)
  expect_identical(about$A[[1L]], "Key")
  expect_identical(about$B[[1L]], "Value")

  # Wave 1: rows 2 to 6, then one blank row.
  expect_identical(about$A[[2L]], "w1")
  expect_true(is.na(about$B[[2L]]))
  expect_identical(
    about$A[3:6],
    c("Survey", "Vendor", "Field start", "Field end")
  )
  expect_identical(
    about$B[3:6],
    c("Wave 1 Survey", "Vendor One", "2024-01-02", "2024-01-31")
  )
  expect_true(is.na(about$A[[7L]]) && is.na(about$B[[7L]]))

  # Wave 2: rows 8 to 13, then one blank row before the glossary.
  expect_identical(about$A[[8L]], "w2")
  expect_true(is.na(about$B[[8L]]))
  expect_identical(
    about$A[9:13],
    c("Survey", "Dataset", "Vendor", "Field start", "Field period")
  )
  expect_identical(
    about$B[9:13],
    c("Wave 2 Survey", "Wave 2 Data", "Vendor Two", "2024-06-01", "Summer 2024")
  )
  expect_true(is.na(about$A[[14L]]) && is.na(about$B[[14L]]))
  expect_identical(about$A[[15L]], "What these numbers mean")
  expect_identical(sum(is.na(about$A) & is.na(about$B)), 2L)
})

test_that("export_topline() writes a bold heading for a wave with no keys (TC-06)", {
  skip_if_not_installed("surveycore")
  w1 <- surveycore::set_dataset_metadata(
    make_all_designs(seed = 42)$taylor,
    survey_name = "Wave 1 Survey"
  )
  coll <- cover_collection(w1, make_all_designs(seed = 7)$taylor)
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(coll, vars = q1, file_name = out)

  about <- about_sheet(out)
  expect_identical(
    about$A[1:6],
    c("Key", "w1", "Survey", NA, "w2", NA)
  )
  expect_identical(about$A[[7L]], "What these numbers mean")
  expect_true(is.na(about$B[[6L]]))

  wb <- openxlsx2::wb_load(out)
  expect_true(cell_is_bold(wb, "About", "A5"), label = "w2 heading is bold")
  expect_true(cell_is_bold(wb, "About", "A2"), label = "w1 heading is bold")
  expect_false(cell_is_bold(wb, "About", "A3"), label = "a key is not bold")
})

test_that("export_topline() writes the About sheet for a collection with no metadata (TC-07)", {
  skip_if_not_installed("surveycore")
  coll <- cover_collection(
    make_all_designs(seed = 42)$taylor,
    make_all_designs(seed = 7)$taylor
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(coll, vars = q1, file_name = out)

  wb <- openxlsx2::wb_load(out)
  expect_identical(unname(wb$get_sheet_names()), c("About", "Topline"))
  about <- about_sheet(out)
  expect_identical(
    about_glossary(about),
    c(
      "Unweighted sample size" = topline_glossary_text$unweighted,
      "Effective sample size (ESS)" = topline_glossary_text$ess
    )
  )
})

# 14. Effective N rewiring -----------------------------------------------------
# The effective N comes from surveycore::get_effective_n(), through
# .resolve_eff_n(), so it follows the rows the design tabulates: the phase-2
# subset of a twophase design and the in-domain rows of a restricted design
# (spec 1.4.1, spec 2.3, spec 3.20).

# The single-design block of the "Topline" sheet as a data frame of columns A
# to C, keyed by sheet row in the row names.
topline_block <- function(path) {
  df <- openxlsx2::wb_to_df(
    path,
    sheet = "Topline",
    col_names = FALSE,
    cols = 1:3
  )
  data.frame(
    A = as.character(df[[1L]]),
    B = as.character(df[[2L]]),
    C = as.character(df[[3L]]),
    row = as.integer(rownames(df)),
    stringsAsFactors = FALSE
  )
}

# The rows a design tabulates: the phase-2 subset of a twophase design, then
# the in-domain rows when the design carries a domain column.
in_scope_rows <- function(d) {
  keep <- rep(TRUE, nrow(d@data))
  if (S7::S7_inherits(d, surveycore::survey_twophase)) {
    keep <- keep & d@data[[d@variables$subset]]
  }
  if (surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data)) {
    keep <- keep & d@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  }
  sum(keep)
}

test_that("export_topline() reports N over the rows the design tabulates (TN-02) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    for (restricted in c(FALSE, TRUE)) {
      d <- cover_design(designs[[nm]])
      if (restricted) {
        d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$group == "A"
      }
      lbl <- paste0(nm, if (restricted) " (domain)" else "")
      if (file.exists(out)) {
        file.remove(out)
      }

      export_topline(d, vars = q1, file_name = out, show_eff_n = TRUE)
      block <- topline_block(out)

      # The unweighted N: the N cell of the Total row.
      expected_n <- in_scope_rows(d)
      expect_identical(
        as.integer(block$C[block$A == "Total"]),
        expected_n,
        label = paste0(lbl, ": N of the Total row")
      )

      # The effective N in the percentage header is computed over the same
      # rows. The oracle's n confirms the oracle covers those rows.
      oracle <- surveycore::get_effective_n(d)
      expect_identical(
        as.integer(oracle$n),
        expected_n,
        label = paste0(lbl, ": oracle n")
      )
      header <- block$B[block$A == "Response"]
      reported_eff_n <- as.numeric(gsub("[^0-9]", "", header))
      expect_identical(
        reported_eff_n,
        round(oracle$n_eff),
        label = paste0(lbl, ": effective N in the header")
      )
    }
  }
})

test_that("export_topline() returns the path for a collection under show_eff_n (TC-08)", {
  skip_if_not_installed("surveycore")
  coll <- cover_collection(
    make_all_designs(seed = 42)$taylor,
    make_all_designs(seed = 7)$taylor
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  result <- withVisible(
    export_topline(coll, vars = q1, file_name = out, show_eff_n = TRUE)
  )

  expect_false(result$visible)
  expect_identical(result$value, out)
  expect_true(file.exists(out))
})

test_that("export_topline() writes no effective N in a collection header (TN-03) [numerical]", {
  skip_if_not_installed("surveycore")
  coll <- cover_collection(
    make_all_designs(seed = 42)$taylor,
    make_all_designs(seed = 7)$taylor
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (eff in c(FALSE, TRUE)) {
    lbl <- paste0("show_eff_n = ", eff)
    if (file.exists(out)) {
      file.remove(out)
    }

    export_topline(coll, vars = q1, file_name = out, show_eff_n = eff)

    df <- openxlsx2::wb_to_df(out, sheet = "Topline", col_names = FALSE)
    header_row <- which(as.character(df[[1L]]) == "Response")
    headers <- as.character(unlist(df[header_row, -1L]))
    headers <- headers[!is.na(headers)]

    expected <- vapply(
      names(coll@surveys),
      function(wn) {
        wave_n <- sum(surveycore::get_freqs(coll@surveys[[wn]], q1)$n)
        paste0(wn, "\n(n=", formatC(wave_n, format = "d", big.mark = ","), ")")
      },
      character(1L),
      USE.NAMES = FALSE
    )
    expect_identical(
      headers,
      c("Total", expected),
      label = paste0(lbl, ": the header row")
    )
    expect_false(
      any(grepl("Eff N", headers)),
      label = paste0(lbl, ": no effective N in any header")
    )
  }
})

test_that("export_topline() writes a whole-number effective N in the % header (TN-01) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])

    export_topline(d, vars = q1, file_name = out, show_eff_n = TRUE)
    block <- topline_block(out)

    oracle <- round(surveycore::get_effective_n(d)$n_eff)
    expected <- paste0(
      "%\n(Eff N=",
      formatC(oracle, format = "d", big.mark = ","),
      ")"
    )
    expect_identical(
      block$B[block$A == "Response"],
      expected,
      label = paste0(nm, ": the percentage header")
    )
    expect_false(
      "Total" %in% c(block$B, block$C),
      label = paste0(nm, ": no header cell reads Total")
    )
  }
})

test_that("export_topline() writes a thousands separator in the effective N (TN-01) [numerical]", {
  skip_if_not_installed("surveycore")
  df <- make_survey_data(n = 2000, n_psu = 20, n_strata = 4, seed = 123)
  d <- cover_design(surveycore::as_survey(df, weights = wt))
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(d, vars = q1, file_name = out, show_eff_n = TRUE)
  block <- topline_block(out)

  oracle <- round(surveycore::get_effective_n(d)$n_eff)
  expect_gte(oracle, 1000)
  expected <- paste0(
    "%\n(Eff N=",
    formatC(oracle, format = "d", big.mark = ","),
    ")"
  )
  expect_identical(block$B[block$A == "Response"], expected)
  expect_match(expected, "Eff N=[0-9],[0-9]{3}[)]$")
})

test_that("export_topline() percentages match surveycore::get_freqs() as numbers (TN-04) [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  expect_identical(length(designs), 4L)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    if (file.exists(out)) {
      file.remove(out)
    }
    d <- cover_design(designs[[nm]])

    export_topline(d, vars = q1, file_name = out, decimals = 1L)
    block <- topline_block(out)

    first <- block$row[block$A == "Response"] + 1L
    last <- block$row[block$A == "Total"] - 1L
    cells <- openxlsx2::wb_to_df(
      out,
      sheet = "Topline",
      col_names = FALSE,
      rows = first:last,
      cols = 1:2
    )
    expect_true(is.numeric(cells[[2L]]), label = paste0(nm, ": numeric cells"))

    ref <- surveycore::get_freqs(d, q1)
    expect_identical(
      sort(as.character(cells[[1L]])),
      sort(as.character(ref[[1L]])),
      label = paste0(nm, ": response levels")
    )
    for (val in as.character(ref[[1L]])) {
      expect_equal(
        cells[[2L]][as.character(cells[[1L]]) == val],
        round(ref$pct[as.character(ref[[1L]]) == val] * 100, 1L),
        tolerance = 1e-10,
        label = paste0(nm, ": pct for '", val, "'")
      )
    }
  }
})
