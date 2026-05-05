# Testing

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Test file granularity | 1 file per source file; large files may split |
| `test_that()` scope | One observable behavior per block |
| Nesting | Flat — no `describe()` blocks |
| Coverage target | 98%+ line coverage; PRs blocked below 95% |
| Test categories | Happy path + error paths + edge cases |
| All design types | Every `report_*()` tested with all three: taylor, replicate, twophase |
| Private function testing | Default indirect; direct only when gap can't be closed via public API |
| Error testing | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` for all user-facing errors |
| Result structure | Assert tibble columns present and correct types in every test block |
| Numerical accuracy | Compare against surveycore's `get_*()` functions |
| Snapshot failures | Block PRs; update via `snapshot_review()` before opening |
| Warning capture | `expect_warning()` wrapping call; result from return value |
| Structural assertions | `expect_identical()` |
| Numeric assertions | `expect_equal()` |
| Synthetic data | `make_all_designs(seed = N)` in `helper-test-data.R` |
| Edge case data | Inline in tests — never add edge case params to a data generator |
| `skip_if_not_installed` | Block-level, inside the affected `test_that()` block |

---

## File Mapping

| Source file | Test file |
|-------------|-----------|
| `R/report-freqs.R` | `tests/testthat/test-report-freqs.R` |
| `R/report-means.R` | `tests/testthat/test-report-means.R` |
| `R/report-totals.R` | `tests/testthat/test-report-totals.R` |
| `R/utils.R` | (covered inline by other test files) |

---

## Test Structure

**One behavior per block.** Descriptions are present-tense assertions, not vague
categories:

```r
# Correct
test_that("report_freqs() rejects non-survey-design input", { ... })
test_that("report_freqs() returns one row per variable × value", { ... })

# Wrong — vague
test_that("report_freqs() validates input", { ... })
```

**Flat structure only.** No `describe()` blocks.

---

## What to Test

### Coverage

**98%+ line coverage** is the target. PRs that drop below **95%** are blocked by CI.

Lines excluded from coverage are marked `# nocov` with an explanatory comment:

```r
# nocov start
# Defensive: this branch is unreachable via any public function.
if (is.null(x@data)) {
  cli::cli_abort("Internal error: @data is NULL", class = "surveyreports_error_internal")
}
# nocov end
```

Acceptable: defensive branches unreachable via public API, platform-specific paths.
Never acceptable: covering for missing tests or "hard to trigger" errors.

### Three mandatory categories

Every exported function must have tests in all three:

1. **Happy path** — normal inputs, expected behavior
2. **Error paths** — every typed error class from `plans/error-messages.md`
3. **Edge cases** — all-NA variable, single-row data, single-value variable, empty domain

### Cross-design testing (REQUIRED)

Every `report_*()` function must be tested with all three design types via
`make_all_designs()`:

```r
test_that("report_freqs() returns a tibble for all design types", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- report_freqs(d, vars = q1)
    expect_s3_class(result, "tbl_df")
    expect_true(all(c("variable", "value", "prop") %in% names(result)))
  }
})
```

Never write a test that only covers one design type.

### Result structure assertions

Assert structure before numerical checks in every block:

```r
test_that("report_freqs() returns the expected columns", {
  d <- make_all_designs(seed = 42)$taylor
  result <- report_freqs(d, vars = q1)

  expect_s3_class(result, "tbl_df")
  expect_true(all(c("variable", "value", "prop", "prop_se") %in% names(result)))
  expect_true(is.character(result$variable))
  expect_true(is.numeric(result$prop))

  expect_identical(unique(result$variable), "q1")
})
```

### Testing private functions

Default to **indirect testing** via the public API. Only test directly when
coverage cannot be closed indirectly AND the behavior is material.

---

## Assertions

### Error testing: dual pattern

All surveyreports errors are user-facing. Use both assertions:

```r
test_that("report_freqs() errors when design is not a survey object", {
  df <- data.frame(q1 = 1:5, wt = rep(1, 5))

  expect_error(
    report_freqs(df, vars = q1),
    class = "surveyreports_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, report_freqs(df, vars = q1))
})

test_that("report_freqs() errors when vars are not in the design", {
  d <- make_all_designs(seed = 42)$taylor

  expect_error(
    report_freqs(d, vars = nonexistent_var),
    class = "surveyreports_error_var_not_found"
  )
  expect_snapshot(error = TRUE, report_freqs(d, vars = nonexistent_var))
})
```

### Snapshots

Snapshot failures block PRs. Update intentional message changes with
`testthat::snapshot_review()` — never `snapshot_accept()` blindly.

Snapshots live in `tests/testthat/_snaps/` and are committed to version control.

### Warning capture

```r
test_that("report_freqs() warns and still returns a result for all-NA variable", {
  d <- make_all_designs(seed = 42)$taylor

  expect_warning(
    result <- report_freqs(d, vars = all_na_var),
    class = "surveyreports_warning_all_na"
  )
  expect_s3_class(result, "tbl_df")
})
```

Do not use `withCallingHandlers()` or `tryCatch()` in tests.

### `expect_identical()` vs `expect_equal()`

| Use `expect_identical()` for... | Use `expect_equal()` for... |
|---------------------------------|-----------------------------|
| Character vectors, names, column presence | Floating-point output |
| `NULL` and `NA` values | Numeric computations with tolerance |
| Exact string/integer values | Weights, proportions, estimates, SEs |

---

## Numerical Accuracy Testing

Compare `report_*()` output against surveycore's single-variable `get_*()` functions.
Put these in a dedicated section at the end of each test file.

```r
test_that("report_means() matches surveycore::get_means() per variable [numerical]", {
  d <- make_all_designs(seed = 42)$taylor

  sc_result <- surveycore::get_means(d, y1)
  rr_result <- report_means(d, vars = y1)

  expect_equal(
    rr_result$mean[rr_result$variable == "y1"],
    sc_result$mean,
    tolerance = 1e-10
  )
  expect_equal(
    rr_result$mean_se[rr_result$variable == "y1"],
    sc_result$se,
    tolerance = 1e-8
  )
})
```

Numerical tolerances:

| Estimand | Tolerance |
|----------|-----------|
| Point estimates (mean, total, proportion) | `1e-10` |
| SE / variance | `1e-8` |
| CI bounds | `1e-6` |

---

## Test Data

### `make_all_designs()` and `make_survey_data()`

Both defined in `tests/testthat/helper-test-data.R`:

```r
# make_all_designs: named list of three design objects
designs <- make_all_designs(seed = 42)
# designs$taylor    — survey_taylor
# designs$replicate — survey_replicate (BRR)
# designs$twophase  — survey_twophase

# make_survey_data: plain data.frame
df <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)
# Columns: psu, strata, fpc, wt, y1, y2, y3, q1, q2, group
```

| Test type | Data source |
|-----------|-------------|
| Structure, error conditions | `make_all_designs()` |
| Numerical accuracy | `make_all_designs()` with `surveycore::get_*()` as reference |
| Edge case data | Inline in tests |

### Edge case data: inline

```r
test_that("report_freqs() handles all-NA variable", {
  d <- make_all_designs(seed = 42)$taylor
  d@data$all_na <- NA_real_
  # ...
})
```

Do not add edge case parameters to `make_all_designs()` or `make_survey_data()`.

### `skip_if_not_installed()` — block-level

```r
test_that("estimates match reference package [numerical]", {
  skip_if_not_installed("ref_pkg")
  # ...
})
```

Do not place `skip_if_not_installed()` at the top of a file.

---

## Test File Section Templates

### `test-report-freqs.R`
```
# 1. Happy paths — result tibble structure for all 3 design types
# 2. Multiple variables — all vars appear in output; one row per var × value
# 3. Group argument — group column present; rows split by group × value
# 4. ci = FALSE — CI columns absent from result
# 5. Error paths — non-survey object, var not found
# 6. Edge cases — all-NA variable, single-row data, single-value variable
# 7. Numerical accuracy — results match surveycore::get_freqs() per variable
```

### `test-report-means.R`
```
# 1. Happy paths — result tibble structure for all 3 design types
# 2. Multiple variables — all vars appear in output
# 3. Group argument — group column present
# 4. Error paths — non-survey object, var not found, non-numeric variable
# 5. Edge cases — all-NA variable, single-row data
# 6. Numerical accuracy — results match surveycore::get_means() per variable
```
