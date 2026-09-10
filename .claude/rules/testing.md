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
| All design types | Every design-taking function tested with all four `survey_base` subclasses: taylor, replicate, twophase, nonprob |
| Private function testing | Default indirect; direct only when gap can't be closed via public API |
| Error testing | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` for all user-facing errors |
| Result structure | Assert the written sheet's cells, or the result tibble's columns and types, in every test block |
| Numerical accuracy | Compare against surveycore's `get_*()` functions |
| Snapshot failures | Block PRs; update via `snapshot_review()` before opening |
| Warning capture | `expect_warning()` wrapping call; result from return value |
| Structural assertions | `expect_identical()` |
| Numeric assertions | `expect_equal()` |
| Synthetic data | `make_all_designs(seed = N)` in `helper-test-data.R` |
| Edge case data | Inline in tests; the generator carries only the fixed columns it already has |
| `skip_if_not_installed` | Block-level, inside the affected `test_that()` block |

---

## File Mapping

| Source file | Test file |
|-------------|-----------|
| `R/export-topline.R` | `tests/testthat/test-export-topline.R` |
| `R/export-crosstab.R` | `tests/testthat/test-export-crosstab.R` |
| `R/pool-pvals.R` | `tests/testthat/test-pool-pvals.R` |
| `R/export-utils.R` | (covered inline by the two export test files) |
| `R/data.R` | `tests/testthat/test-package.R` |

---

## Test Structure

**One behavior per block.** Descriptions are present-tense assertions, not vague
categories:

```r
# Correct
test_that("export_topline() rejects non-survey-design input", { ... })
test_that("export_topline() writes one block per variable", { ... })

# Wrong — vague
test_that("export_topline() validates input", { ... })
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
3. **Edge cases** — all-NA variable, single-row data, single-value variable,
   empty banner level, a missing variable label

### Cross-design testing (REQUIRED)

Every function that accepts a `design` must be tested with all four
`survey_base` subclasses — taylor, replicate, twophase, and nonprob — via
`make_all_designs()`. Loop over the names so a failure says which design broke:

```r
test_that("export_topline() writes a non-empty file for all design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out <- withr::local_tempfile(fileext = ".xlsx")

  for (nm in names(designs)) {
    file.remove(out)
    export_topline(designs[[nm]], vars = q1, file_name = out)

    expect_true(file.exists(out), label = paste0(nm, ": file exists"))
    expect_gt(file.info(out)$size, 0L, label = paste0(nm, ": non-empty"))
  }
})
```

Never write a test that covers only one design type.

`export_topline()` also accepts a `survey_collection` for wave comparison. That
is a fifth case, not one of the four — give it its own block.

`pool_pvals()` takes a list of tibbles, not a design, so this rule does not
apply to it.

**Gap to close:** `make_all_designs()` currently returns three designs —
`taylor`, `replicate`, and `twophase`. It must gain a `nonprob` entry built
with `surveycore::as_survey_nonprob()`. Until it does, the loops above cover
three of the four required subclasses.

### Result structure assertions

Assert structure before numerical checks in every block:

An `export_*()` function returns a path, so assert on the workbook it wrote:

```r
test_that("export_topline() returns the path invisibly and writes the sheet", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  result <- withVisible(export_topline(d, vars = q1, file_name = out))

  expect_false(result$visible)
  expect_identical(result$value, out)

  wb <- openxlsx2::wb_load(out)
  expect_true("Topline" %in% wb$sheet_names)
})
```

For `pool_pvals()`, which returns data, assert the columns and their types:

```r
test_that("pool_pvals() returns the adjusted p-value column", {
  result <- pool_pvals(list(tibble::tibble(p_value = c(0.01, 0.05))))

  expect_s3_class(result, "survey_pooled_pvals")
  expect_true(all(c("p_value", "p_value_adj") %in% names(result)))
  expect_true(is.numeric(result$p_value_adj))
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
test_that("export_topline() errors when design is not a survey object", {
  df <- data.frame(q1 = 1:5, wt = rep(1, 5))
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(df, vars = q1, file_name = out),
    class = "surveyreports_error_not_survey_object"
  )
  expect_snapshot(
    error = TRUE,
    export_topline(df, vars = q1, file_name = out)
  )
})

test_that("export_topline() errors when vars are not in the design", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = nonexistent_var, file_name = out),
    class = "surveyreports_error_var_not_found"
  )
})
```

Snapshot the message for each error class once. Repeating the snapshot for
every function that raises the same class adds files without adding coverage.

### Snapshots

Snapshot failures block PRs. Update intentional message changes with
`testthat::snapshot_review()` — never `snapshot_accept()` blindly.

Snapshots live in `tests/testthat/_snaps/` and are committed to version control.

### Warning capture

```r
test_that("export_crosstab() warns when a subgroup is suppressed", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    result <- export_crosstab(
      d,
      vars = q1,
      banner = group,
      file_name = out,
      pub_type = "external"
    ),
    class = "surveyreports_warning_subgroup_suppressed"
  )
  expect_identical(result, out)
  expect_true(file.exists(out))
})
```

A warning must not stop the write. Assert the file still exists.

Do not use `withCallingHandlers()` or `tryCatch()` in tests.

### `expect_identical()` vs `expect_equal()`

| Use `expect_identical()` for... | Use `expect_equal()` for... |
|---------------------------------|-----------------------------|
| Character vectors, names, column presence | Floating-point output |
| `NULL` and `NA` values | Numeric computations with tolerance |
| Exact string/integer values | Weights, proportions, estimates, SEs |

---

## Numerical Accuracy Testing

Compare the estimates surveyreports computes against surveycore's
single-variable `get_*()` functions. Put these in a dedicated section at the end
of each test file and tag the description `[numerical]`.

An `export_*()` function returns a path, so its numbers are not reachable from
the return value. Test the frame builder directly instead — this is the one
place where testing an internal helper beats going through the public API:

```r
test_that(".build_freq_frame() totals match surveycore::get_freqs() [numerical]", {
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
    expect_equal(
      total_rows$pct[total_rows$value == as.character(val)],
      ref$pct[ref[[1L]] == val],
      tolerance = 1e-10,
      label = paste0("pct match for value '", val, "'")
    )
  }
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
# make_all_designs: named list of design objects
designs <- make_all_designs(seed = 42)
# designs$taylor    — survey_taylor
# designs$replicate — survey_replicate (JK1, delete-one-PSU jackknife)
# designs$twophase  — survey_twophase
# designs$nonprob   — survey_nonprob  (not present yet; see the gap above)

# make_survey_data: plain data.frame, 19 columns
df <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)
```

`make_survey_data()` columns, by what they are for:

| Columns | For testing |
|---------|-------------|
| `psu`, `strata`, `fpc`, `wt` | Design construction |
| `y1`, `y2`, `y3` | Continuous variables |
| `q1`, `q2` | Categorical single-response questions |
| `group` | A banner variable |
| `sata_a`, `sata_b`, `sata_c` | Select-all-that-apply blocks |
| `bat_1`, `bat_2`, `bat_3` | Battery blocks on a shared 1–5 scale |
| `in_phase2` | The phase-2 indicator for the two-phase design |
| `all_na_var` | The all-NA edge case |

| Test type | Data source |
|-----------|-------------|
| Structure, error conditions | `make_all_designs()` |
| Numerical accuracy | `make_all_designs()` with `surveycore::get_*()` as reference |
| Edge case data | Inline in tests |

### Edge case data: inline

```r
test_that("export_topline() handles a single-value variable", {
  skip_if_not_installed("surveycore")
  d <- make_all_designs(seed = 42)$taylor
  d@data$constant <- "Agree"
  out <- withr::local_tempfile(fileext = ".xlsx")
  # ...
})
```

Do not add edge case parameters to `make_all_designs()` or
`make_survey_data()`. Their column set is fixed; build the edge case in the
test body by assigning into `d@data`.

`all_na_var` is already a column in `make_survey_data()`. Use it rather than
adding a second all-NA column.

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

### `test-export-topline.R`
```
# 1. Happy paths — a non-empty file with the expected sheet, all design types
# 2. Multiple variables — every variable name appears in the workbook
# 3. survey_collection wave columns — one column per wave
# 4. var_type dispatch — SATA and battery blocks
# 5. Variance options — variance = NULL, "se", "ci"
# 6. show_n and show_eff_n — the columns appear and disappear
# 7. Missing metadata warning — one warning listing every affected variable
# 8. Error paths — non-survey object, var not found
# 9. Edge cases — all-NA variable, single-row data, single-value variable
# 10. Numerical accuracy — .build_freq_frame() matches surveycore::get_freqs()
```

### `test-export-crosstab.R`
```
# 1. Happy paths — a non-empty file with the expected sheet, all design types
# 2. Multiple variables — every variable name appears in the workbook
# 3. Layout — per_question and stacked
# 4. Banner columns — one column group per banner level, plus Total
# 5. Interactions — crossed banner variables
# 6. Self-banner — a variable used as its own banner
# 7. var_type dispatch — SATA and battery blocks
# 8. Variance options — variance = NULL, "se", "ci"
# 9. show_n and show_eff_n — the columns appear and disappear
# 10. Suppression — pub_type = "external" and "internal", warning class
# 11. Error paths — non-survey object, var not found, a collection
# 12. Numerical accuracy — cell percentages match surveycore::get_freqs()
```

### `test-pool-pvals.R`
```
# 1. Happy paths — result tibble structure, S3 class, .meta attribute
# 2. Per-upstream-function happy paths
# 3. Multiple inputs — column union, id_col, named vs unnamed list
# 4. strip_within_adj — rename-to-within vs. drop behavior, warning class
# 5. Error paths — not a list, empty, invalid method, missing p_col
# 6. Edge cases — all-NA p_value column, single-element list, partial NA
# 7. Numerical accuracy — adjusted values match stats::p.adjust()
```

Number the sections in the file with comment banners and keep them in order.
`pool_pvals()` has no design, so it has no cross-design section.
