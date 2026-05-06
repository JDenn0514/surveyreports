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
