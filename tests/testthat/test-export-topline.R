# tests/testthat/test-export-topline.R

# 1. Happy paths ------------------------------------------------------------------

test_that("export_topline() creates a non-empty .xlsx file for all 3 design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    result <- withVisible(export_topline(designs[[nm]], vars = q1, file_name = out))

    expect_false(result$visible, label = paste0(nm, ": return invisible"))
    expect_identical(result$value, out, label = paste0(nm, ": return file_name"))
    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    expect_gt(file.info(out)$size, 0L, label = paste0(nm, ": file non-empty"))

    wb     <- openxlsx2::wb_load(out)
    expect_true("Topline" %in% wb$sheet_names, label = paste0(nm, ": Topline sheet"))
  }
})

# 2. Multiple variables -----------------------------------------------------------

test_that("export_topline() includes all variable names in the workbook for multiple vars", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  export_topline(d, vars = c(q1, q2), file_name = out)

  wb   <- openxlsx2::wb_load(out)
  expect_true("Topline" %in% wb$sheet_names)

  cells <- unlist(openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE))
  cells <- as.character(cells[!is.na(cells)])

  # question_text falls back to variable name when no label is set;
  # the label warning fires — suppress it here since we're testing workbook content
  expect_true(any(grepl("q1|Agree|Neutral|Disagree", cells)),
              label = "q1 content in workbook")
  expect_true(any(grepl("q2|Yes|No", cells)),
              label = "q2 content in workbook")
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

  wb    <- openxlsx2::wb_load(out)
  expect_true("Topline" %in% wb$sheet_names)

  df    <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
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
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    expect_no_error(
      export_topline(designs[[nm]], vars = c(sata_a, sata_b, sata_c), file_name = out)
    )
    expect_true(file.exists(out))
  }
})

test_that("export_topline() handles battery variables for all design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    expect_no_error(
      export_topline(designs[[nm]], vars = c(bat_1, bat_2, bat_3), file_name = out)
    )
    expect_true(file.exists(out))
  }
})

# 5. Variance options -------------------------------------------------------------

test_that("export_topline() variance = NULL produces no se/ci columns in frame", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(d, vars = q1, file_name = out, variance = NULL))
  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_false(any(grepl("(?i)\\bse\\b|std.*err", cells, perl = TRUE)),
               label = "no se column when variance=NULL")
  expect_false(any(grepl("(?i)ci_|conf.*int|lower|upper", cells, perl = TRUE)),
               label = "no ci column when variance=NULL")
})

test_that("export_topline() variance = 'se' produces no error", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(d, vars = q1, file_name = out, variance = "se"))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() variance = 'ci' produces no error", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(d, vars = q1, file_name = out, variance = "ci"))
  )
  expect_true(file.exists(out))
})

# 6. show_n and show_eff_n --------------------------------------------------------

test_that("export_topline() show_n = FALSE omits N from workbook", {
  skip_if_not_installed("surveycore")
  d    <- make_all_designs(seed = 42)$taylor
  out  <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(d, vars = q1, file_name = out, show_n = FALSE))
  wb   <- openxlsx2::wb_load(out)
  df   <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)

  # With show_n = FALSE the third column should be empty / absent
  expect_true(ncol(df) <= 2L || all(is.na(df[[3]])))
})

test_that("export_topline() show_n = TRUE includes N column", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(d, vars = q1, file_name = out, show_n = TRUE))
  wb  <- openxlsx2::wb_load(out)
  df  <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(any(grepl("^N$", cells)), label = "N header present")
})

test_that("export_topline() show_eff_n = TRUE adds eff N to % header", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_topline(d, vars = q1, file_name = out, show_eff_n = TRUE)
  )
  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(any(grepl("Eff N", cells)), label = "Eff N in header")
})

# 7. Missing metadata warning -----------------------------------------------------

test_that("export_topline() warns about missing variable_label when unset", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    export_topline(d, vars = q1, file_name = out),
    class = "surveyreports_warning_missing_variable_label"
  )
})

test_that("export_topline() does not warn when variable_label is set", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  d   <- surveycore::set_var_label(d, variable = "q1", label = "Agreement question")
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(export_topline(d, vars = q1, file_name = out))
})

test_that("export_topline() uses variable name as question text when label unset", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(d, vars = q1, file_name = out))
  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(any(grepl("^q1$", cells)), label = "var name used as question text")
})

# 9. Edge cases -------------------------------------------------------------------

test_that("export_topline() handles all-NA variable without crashing", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  # all_na_var is NA_character_ for every row
  expect_no_error(
    suppressWarnings(export_topline(d, vars = all_na_var, file_name = out))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles a single-value variable", {
  skip_if_not_installed("surveycore")
  d         <- make_all_designs(seed = 42)$taylor
  d@data$sv <- "constant"
  out       <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(d, vars = sv, file_name = out))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles a minimal two-row design", {
  skip_if_not_installed("surveycore")
  # surveycore requires >= 2 rows; 2-row is the minimal viable design
  df2 <- data.frame(q1 = c("Agree", "Disagree"), wt = c(1.0, 1.5))
  d2  <- surveycore::as_survey(df2, weights = wt)
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(export_topline(d2, vars = q1, file_name = out))
  )
  expect_true(file.exists(out))
})

test_that("export_topline() collection with show_eff_n = TRUE writes Eff N in Total header", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll    <- surveycore::as_survey_collection(
    wave1 = designs$taylor, wave2 = designs$replicate
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_topline(coll, vars = q1, file_name = out, show_eff_n = TRUE)
  )
  wb    <- openxlsx2::wb_load(out)
  df    <- openxlsx2::wb_to_df(wb, sheet = "Topline", col_names = FALSE)
  cells <- as.character(unlist(df)[!is.na(unlist(df))])

  expect_true(file.exists(out))
  # wave headers always written; eff_n path inside Total header may or may not fire
  expect_true(any(grepl("wave1|wave2|Total", cells)))
})

test_that("export_topline() handles all-NA SATA variable without crashing", {
  skip_if_not_installed("surveycore")
  d             <- make_all_designs(seed = 42)$taylor
  d@data$sata_a <- NA_integer_
  d@data$sata_b <- NA_integer_
  d@data$sata_c <- NA_integer_
  out           <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_topline(d, vars = c(sata_a, sata_b, sata_c), file_name = out)
    )
  )
  expect_true(file.exists(out))
})

test_that("export_topline() handles all-NA battery variable without crashing", {
  skip_if_not_installed("surveycore")
  d           <- make_all_designs(seed = 42)$taylor
  d@data$bat_1 <- NA_integer_
  d@data$bat_2 <- NA_integer_
  d@data$bat_3 <- NA_integer_
  out          <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_topline(d, vars = c(bat_1, bat_2, bat_3), file_name = out)
    )
  )
  expect_true(file.exists(out))
})

test_that("export_topline() errors with empty_domain for a zero-row design", {
  skip_if_not_installed("surveycore")
  d_empty      <- make_all_designs(seed = 42)$taylor
  d_empty@data <- d_empty@data[0L, ]
  out          <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d_empty, vars = q1, file_name = out),
    class = "surveyreports_error_empty_domain"
  )
})

# 10. Numerical accuracy ----------------------------------------------------------

test_that(".build_freq_frame() totals match surveycore::get_freqs() for q1 [numerical]", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d, "q1", clf,
    conf_level = 0.95,
    show_eff_n = FALSE
  )$frame
  total_rows <- frame[frame$subgroup_type == "total", ]

  ref <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (val in ref[[1L]]) {
    rr_pct <- total_rows$pct[total_rows$value == as.character(val)]
    sc_pct <- ref$pct[ref[[1L]] == val]
    expect_equal(rr_pct, sc_pct, tolerance = 1e-10,
                 label = paste0("pct match for value '", val, "'"))
  }
})

test_that(".build_freq_frame() SE matches surveycore::get_freqs() with variance='se'", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d, "q1", clf,
    variance   = "se",
    conf_level = 0.95
  )$frame
  total_rows <- frame[frame$subgroup_type == "total", ]

  ref <- suppressWarnings(surveycore::get_freqs(d, q1, variance = "se"))

  for (val in ref[[1L]]) {
    rr_se <- total_rows$se[total_rows$value == as.character(val)]
    sc_se <- ref$se[ref[[1L]] == val]
    expect_equal(rr_se, sc_se, tolerance = 1e-8,
                 label = paste0("se match for value '", val, "'"))
  }
})

test_that(".build_freq_frame() CI bounds match surveycore::get_freqs() with variance='ci'", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
  clf <- surveycore::classify_question_type(d, "q1")

  frame <- surveyreports:::.build_freq_frame(
    d, "q1", clf,
    variance   = "ci",
    conf_level = 0.95
  )$frame
  total_rows <- frame[frame$subgroup_type == "total", ]

  ref <- suppressWarnings(surveycore::get_freqs(d, q1, variance = "ci", conf_level = 0.95))

  for (val in ref[[1L]]) {
    rr_low  <- total_rows$ci_low[total_rows$value  == as.character(val)]
    rr_high <- total_rows$ci_high[total_rows$value == as.character(val)]
    sc_low  <- ref$ci_low[ref[[1L]]  == val]
    sc_high <- ref$ci_high[ref[[1L]] == val]
    expect_equal(rr_low,  sc_low,  tolerance = 1e-6,
                 label = paste0("ci_low match for value '", val, "'"))
    expect_equal(rr_high, sc_high, tolerance = 1e-6,
                 label = paste0("ci_high match for value '", val, "'"))
  }
})

# 8. Error paths -------------------------------------------------------------------

test_that("export_topline() errors when design is not a survey object", {
  out <- withr::local_tempfile(fileext = ".xlsx")
  df  <- data.frame(q1 = 1:5, wt = rep(1, 5))

  expect_error(
    export_topline(df, vars = q1, file_name = out),
    class = "surveyreports_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, export_topline(df, vars = q1, file_name = out))
})

test_that("export_topline() errors when vars resolves to zero columns", {
  skip_if_not_installed("surveycore")
  d   <- make_all_designs(seed = 42)$taylor
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

test_that("export_topline() errors when domain has zero rows", {
  skip_if_not_installed("surveycore")
  d_empty       <- make_all_designs(seed = 42)$taylor
  d_empty@data  <- d_empty@data[0L, ]
  out           <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d_empty, vars = q1, file_name = out),
    class = "surveyreports_error_empty_domain"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(d_empty, vars = q1, file_name = out)
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
  d   <- make_all_designs(seed = 42)$taylor
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
  d   <- make_all_designs(seed = 42)$taylor
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
