# tests/testthat/test-export-topline.R

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
