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
