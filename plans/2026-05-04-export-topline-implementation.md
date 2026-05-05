# export_topline() Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the computation layer (shared with export_crosstab()) and `export_topline()` — a function that calls `surveycore::get_freqs()` across multiple variables, assembles a long tidy frame, and renders a styled `.xlsx` workbook via openxlsx2.

**Architecture:** The computation layer lives in `R/export-utils.R` (internal helpers used by both export functions); the rendering and public function live in `R/export-topline.R`. A long flat frame is the intermediate representation — built by `.build_freq_frame()`, consumed by the renderer. `export_crosstab()` (Plan B) will extend the same frame schema with banner/interaction columns.

**Tech Stack:** R, openxlsx2 (>= 1.0.0), tidyselect (>= 1.2.0), surveycore (>= 0.8.2, in Suggests), rlang, cli, dplyr, tibble.

---

## File Map

| Path | Action | Responsibility |
|------|--------|----------------|
| `plans/error-messages.md` | Modify | Add 8 new errors + 2 new warnings |
| `tests/testthat/helper-test-data.R` | Replace | `make_survey_data()` + `make_all_designs()` |
| `DESCRIPTION` | Modify | Add `openxlsx2`, `tidyselect` to `Imports` |
| `R/export-utils.R` | Create | `.compute_eff_n()`, `.compute_total_freq()`, `.build_freq_frame()`, `.build_workbook()`, `.check_missing_labels()` |
| `R/export-topline.R` | Create | `export_topline()`, `.render_topline_single()`, `.render_topline_sata()`, `.render_topline_battery()`, `.build_display_table()` |
| `tests/testthat/test-export-topline.R` | Create | Full test suite (sections 1–10) |

---

## Task 1: Foundation — error registry, test helpers, DESCRIPTION

**Files:**
- Modify: `plans/error-messages.md`
- Replace: `tests/testthat/helper-test-data.R`
- Modify: `DESCRIPTION`

- [ ] **Step 1: Update `plans/error-messages.md`**

Add these rows to the Errors table:

```markdown
| `surveyreports_error_not_survey_object` | `export_topline()`, `export_crosstab()` | `design` is not `survey_base` or `survey_collection` |
| `surveyreports_error_var_not_found` | `export_topline()`, `export_crosstab()` | A variable in `vars` does not exist in the design |
| `surveyreports_error_invalid_file_name` | `export_topline()`, `export_crosstab()` | `file_name` does not end in `.xlsx` |
| `surveyreports_error_invalid_conf_level` | `export_topline()`, `export_crosstab()` | `conf_level` outside `(0, 1)` |
| `surveyreports_error_invalid_decimals` | `export_topline()`, `export_crosstab()` | `decimals` is not a non-negative integer |
| `surveyreports_error_banner_not_found` | `export_crosstab()` | A variable in `banner` does not exist in the design |
| `surveyreports_error_interaction_not_in_banner` | `export_crosstab()` | A variable in `interactions` is not in `banner` |
| `surveyreports_error_interactions_not_list` | `export_crosstab()` | `interactions` is not a list |
```

Add these rows to the Warnings table:

```markdown
| `surveyreports_warning_subgroup_suppressed` | `export_topline()`, `export_crosstab()` | One or more subgroups dropped under `pub_type`; single warning listing all suppressed subgroups and eff_n |
| `surveyreports_warning_missing_variable_label` | `export_topline()`, `export_crosstab()` | `variable_label` is NULL for one or more vars; single warning listing all affected variables |
```

Also remove the placeholder row `surveyreports_warning_example` from the Warnings table and the `surveyreports_error_not_data_frame` row from the Errors table (both were stubs from initial setup — they have no real callers).

- [ ] **Step 2: Replace `tests/testthat/helper-test-data.R`**

```r
# tests/testthat/helper-test-data.R
#
# make_survey_data()  — returns a plain data.frame for constructing designs
# make_all_designs()  — returns named list: taylor, replicate, twophase
#
# Column glossary:
#   psu, strata, fpc, wt  — design variables
#   y1, y2, y3             — continuous (for means/totals tests)
#   q1 (3 levels), q2 (2 levels) — single-response categorical
#   group (3 levels)       — grouping / banner variable
#   sata_a/b/c (0/1)       — SATA items (marked via set_sata on design)
#   bat_1/2/3 (1-5)        — battery items
#   in_phase2 (logical)    — phase 2 indicator for twophase design
#   all_na_var             — all-NA, for edge case tests

#' @keywords internal
make_survey_data <- function(n = 200L, n_psu = 20L, n_strata = 2L, seed = 42L) {
  stopifnot(n_psu %% n_strata == 0L, n %% n_psu == 0L)
  set.seed(seed)

  psu_per_stratum <- n_psu %/% n_strata
  obs_per_psu     <- n %/% n_psu

  psu    <- rep(seq_len(n_psu), each = obs_per_psu)
  strata <- rep(rep(seq_len(n_strata), each = psu_per_stratum), each = obs_per_psu)
  fpc    <- rep(psu_per_stratum, n)
  wt     <- stats::runif(n, 0.5, 2.0)

  data.frame(
    psu        = psu,
    strata     = strata,
    fpc        = fpc,
    wt         = wt,
    y1         = stats::rnorm(n, 10, 2),
    y2         = stats::rnorm(n, 5, 1),
    y3         = stats::rnorm(n, 50, 10),
    q1         = sample(c("Agree", "Neutral", "Disagree"), n, replace = TRUE),
    q2         = sample(c("Yes", "No"), n, replace = TRUE),
    group      = sample(c("A", "B", "C"), n, replace = TRUE),
    sata_a     = sample(0L:1L, n, replace = TRUE),
    sata_b     = sample(0L:1L, n, replace = TRUE),
    sata_c     = sample(0L:1L, n, replace = TRUE),
    bat_1      = sample(1L:5L, n, replace = TRUE),
    bat_2      = sample(1L:5L, n, replace = TRUE),
    bat_3      = sample(1L:5L, n, replace = TRUE),
    in_phase2  = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.7, 0.3)),
    all_na_var = NA_character_,
    stringsAsFactors = FALSE
  )
}


#' @keywords internal
make_all_designs <- function(seed = 42L) {
  skip_if_not_installed("surveycore")

  df   <- make_survey_data(seed = seed)
  psus <- unique(df$psu)
  np   <- length(psus)

  # JK1 replicate weights — no external package required
  rw <- matrix(0, nrow = nrow(df), ncol = np)
  for (k in seq_along(psus)) {
    in_k      <- df$psu == psus[k]
    rw[!in_k, k] <- df$wt[!in_k] * np / (np - 1L)
  }
  colnames(rw) <- paste0("rep", seq_len(np))
  rep_df <- cbind(df, rw)

  taylor <- surveycore::as_survey(
    df,
    ids     = psu,
    strata  = strata,
    fpc     = fpc,
    weights = wt
  )
  replicate <- surveycore::as_survey_replicate(
    rep_df,
    weights    = wt,
    repweights = tidyselect::starts_with("rep"),
    type       = "JK1",
    scale      = (np - 1L) / np,
    rscales    = rep(1, np),
    mse        = TRUE
  )
  twophase <- surveycore::as_survey_twophase(
    phase1  = taylor,
    ids2    = psu,
    strata2 = strata,
    subset  = in_phase2,
    method  = "full"
  )

  # Mark SATA and battery variable types on every design
  sata_vars <- c("sata_a", "sata_b", "sata_c")
  bat_vars  <- c("bat_1", "bat_2", "bat_3")

  for (d_name in c("taylor", "replicate", "twophase")) {
    d <- get(d_name)
    d <- surveycore::set_sata(d, variable = sata_vars, sata = TRUE)
    d <- surveycore::set_question_preface(
      d, variable = sata_vars,
      preface = rep("Select all that apply:", length(sata_vars))
    )
    d <- surveycore::set_question_preface(
      d, variable = bat_vars,
      preface = rep("Please rate each:", length(bat_vars))
    )
    assign(d_name, d)
  }

  list(taylor = taylor, replicate = replicate, twophase = twophase)
}
```

- [ ] **Step 3: Add `openxlsx2` and `tidyselect` to `DESCRIPTION` Imports**

In `DESCRIPTION`, change the `Imports:` block to:

```
Imports:
    cli (>= 3.6.0),
    dplyr (>= 1.0.0),
    openxlsx2 (>= 1.0.0),
    rlang (>= 1.0.0),
    tibble (>= 3.0.0),
    tidyselect (>= 1.2.0)
```

- [ ] **Step 4: Verify foundation with R CMD check**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes.

- [ ] **Step 5: Commit**

```bash
git add plans/error-messages.md tests/testthat/helper-test-data.R DESCRIPTION
git commit -m "chore: add error registry rows, test helpers, and DESCRIPTION imports for export functions"
```

---

## Task 2: Computation layer — `R/export-utils.R`

**Files:**
- Create: `R/export-utils.R`
- Create: `tests/testthat/test-export-topline.R` (section 10 only — numerical accuracy of frame)

### Failing test first

- [ ] **Step 1: Create `tests/testthat/test-export-topline.R` with section 10**

```r
# tests/testthat/test-export-topline.R

# 1. Happy paths — file created for all 3 design types
# 2. survey_collection — wave columns present in workbook
# 3. var_type dispatch — single / SATA / battery render without error
# 4. variance options — "ci", "se", NULL produce correct frame columns
# 5. show_n / show_eff_n — columns present/absent as expected
# 6. pub_type suppression — warning fires; suppressed values absent; footnote present
# 7. Missing metadata — missing_variable_label warning fires; variable name used
# 8. Error paths — all 5 error classes, dual pattern
# 9. Edge cases — all-NA variable, single-value variable
# 10. Numerical accuracy — .build_freq_frame() totals match get_freqs() per variable

# ── 10. Numerical accuracy ───────────────────────────────────────────────────

test_that(".build_freq_frame() pct matches get_freqs() for q1 [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor

  var_types <- surveycore::classify_question_type(d, variable = "q1")
  result <- surveyreports:::.build_freq_frame(
    d, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )
  frame <- result$frame

  sc <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (val in unique(sc$q1)) {
    fr_pct <- frame$pct[frame$value == val & frame$subgroup_type == "total"]
    sc_pct <- sc$pct[sc$q1 == val]
    expect_equal(fr_pct, sc_pct, tolerance = 1e-10,
      label = paste0("pct for value '", val, "'"))
  }
})

test_that(".build_freq_frame() n matches get_freqs() for q1 [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor

  var_types <- surveycore::classify_question_type(d, variable = "q1")
  result <- surveyreports:::.build_freq_frame(
    d, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )
  frame <- result$frame

  sc <- suppressWarnings(surveycore::get_freqs(d, q1))

  for (val in unique(sc$q1)) {
    fr_n <- frame$n[frame$value == val & frame$subgroup_type == "total"]
    sc_n <- sc$n[sc$q1 == val]
    expect_identical(fr_n, sc_n,
      label = paste0("n for value '", val, "'"))
  }
})

test_that(".build_freq_frame() se matches get_freqs(variance='se') [numerical]", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor

  var_types <- surveycore::classify_question_type(d, variable = "q1")
  result <- surveyreports:::.build_freq_frame(
    d, "q1", var_types,
    pub_type = "none", variance = "se", conf_level = 0.95, show_eff_n = FALSE
  )
  frame <- result$frame
  expect_true("se" %in% names(frame))

  sc <- suppressWarnings(surveycore::get_freqs(d, q1, variance = "se"))

  for (val in unique(sc$q1)) {
    fr_se <- frame$se[frame$value == val & frame$subgroup_type == "total"]
    sc_se <- sc$se[sc$q1 == val]
    expect_equal(fr_se, sc_se, tolerance = 1e-8,
      label = paste0("se for value '", val, "'"))
  }
})
```

- [ ] **Step 2: Run tests to confirm failure**

```r
devtools::test(filter = "export-topline")
```

Expected: FAIL — `.build_freq_frame` not found.

- [ ] **Step 3: Create `R/export-utils.R`**

```r
# R/export-utils.R
#
# Internal computation helpers shared by export_topline() and export_crosstab().
# No exported functions here.


# ── .compute_eff_n() ──────────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.compute_eff_n <- function(design) {
  wt_col <- if (S7::S7_inherits(design, surveycore::survey_twophase)) {
    design@variables$phase1$weights
  } else {
    design@variables$weights
  }
  wt <- design@data[[wt_col]]
  wt <- wt[!is.na(wt) & wt > 0]
  sum(wt)^2 / sum(wt^2)
}


# ── .check_missing_labels() ───────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.check_missing_labels <- function(design, vars_resolved) {
  meta_src <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1L]]@metadata
  } else {
    design@metadata
  }
  Filter(
    function(v) is.null(meta_src@variable_labels[[v]]) || !nzchar(meta_src@variable_labels[[v]]),
    vars_resolved
  )
}


# ── .extract_question_text() ──────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.extract_question_text <- function(var, var_meta) {
  lbl <- var_meta$variable_label
  if (!is.null(lbl) && nzchar(lbl)) return(lbl)
  pref <- var_meta$question_preface
  if (!is.null(pref) && nzchar(pref)) return(pref)
  var
}


# ── .extract_var_label() ─────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.extract_var_label <- function(var, var_meta) {
  lbl <- var_meta$variable_label
  if (!is.null(lbl) && nzchar(lbl)) return(lbl)
  var
}


# ── .compute_total_freq() ─────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.compute_total_freq <- function(design, var, var_type_row, variance, conf_level) {
  is_collection <- S7::S7_inherits(design, surveycore::survey_collection)

  result <- surveycore::get_freqs(
    design,
    !!rlang::sym(var),
    variance   = variance,
    conf_level = conf_level
  )

  meta_obj <- surveycore::meta(result)
  var_meta  <- meta_obj$x[[var]]
  q_text    <- .extract_question_text(var, var_meta)
  v_label   <- .extract_var_label(var, var_meta)

  if (is_collection) {
    id_col <- design@id
    base_frame <- tibble::tibble(
      variable       = var,
      var_type       = var_type_row$type[[1L]],
      group_id       = var_type_row$group[[1L]],
      question_text  = q_text,
      var_label      = v_label,
      subgroup_type  = "wave",
      subgroup_var   = id_col,
      subgroup_label = as.character(result[[id_col]]),
      subgroup_value = as.character(result[[id_col]]),
      value          = as.character(result[[var]]),
      pct            = result$pct,
      n              = result$n
    )
  } else {
    base_frame <- tibble::tibble(
      variable       = var,
      var_type       = var_type_row$type[[1L]],
      group_id       = var_type_row$group[[1L]],
      question_text  = q_text,
      var_label      = v_label,
      subgroup_type  = "total",
      subgroup_var   = NA_character_,
      subgroup_label = "Total",
      subgroup_value = NA_character_,
      value          = as.character(result[[var]]),
      pct            = result$pct,
      n              = result$n
    )
  }

  # Attach any variance columns (se, ci_low, ci_high) that get_freqs() produced
  skip_cols <- c(if (is_collection) design@id else character(0L), var, "pct", "n")
  extra_cols <- setdiff(names(result), skip_cols)
  for (col in extra_cols) {
    base_frame[[col]] <- result[[col]]
  }

  base_frame
}


# ── .build_freq_frame() ───────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.build_freq_frame <- function(
  design,
  vars_resolved,
  var_types_tbl,
  pub_type,
  variance,
  conf_level,
  show_eff_n
) {
  is_collection <- S7::S7_inherits(design, surveycore::survey_collection)

  empty_suppressed <- tibble::tibble(
    subgroup_var   = character(0L),
    subgroup_value = character(0L),
    eff_n          = numeric(0L),
    raw_n          = integer(0L),
    threshold      = integer(0L),
    pub_type       = character(0L)
  )

  suppressed       <- empty_suppressed
  suppressed_values <- character(0L)

  if (is_collection && pub_type != "none") {
    wave_names <- names(design@surveys)
    supp_rows  <- lapply(wave_names, function(w) {
      d     <- design@surveys[[w]]
      eff   <- .compute_eff_n(d)
      raw_n <- nrow(d@data)
      thresh <- if (pub_type == "external") 100L else 50L
      suppress <- (pub_type == "external" && (eff < 100 || raw_n < 100)) ||
                  (pub_type == "internal" && (eff < 50  || raw_n < 100))
      tibble::tibble(
        subgroup_var   = design@id,
        subgroup_value = w,
        eff_n          = eff,
        raw_n          = as.integer(raw_n),
        threshold      = thresh,
        pub_type       = pub_type,
        suppressed     = suppress
      )
    })
    supp_tbl         <- dplyr::bind_rows(supp_rows)
    suppressed       <- dplyr::select(supp_tbl[supp_tbl$suppressed, ], -"suppressed")
    suppressed_values <- suppressed$subgroup_value
  }

  rows_list <- lapply(vars_resolved, function(var) {
    vtr <- var_types_tbl[var_types_tbl$variable == var, ]
    .compute_total_freq(design, var, vtr, variance, conf_level)
  })

  frame <- dplyr::bind_rows(rows_list)

  if (length(suppressed_values) > 0L) {
    frame <- frame[!frame$subgroup_value %in% suppressed_values, ]
  }

  if (show_eff_n) {
    if (is_collection) {
      wave_effn <- vapply(
        names(design@surveys),
        function(w) .compute_eff_n(design@surveys[[w]]),
        numeric(1L)
      )
      frame$eff_n <- wave_effn[frame$subgroup_value]
    } else {
      frame$eff_n <- .compute_eff_n(design)
    }
  }

  list(frame = frame, suppressed = suppressed)
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```r
devtools::test(filter = "export-topline")
```

Expected: section 10 tests pass (3 tests).

- [ ] **Step 5: Commit**

```bash
git add R/export-utils.R tests/testthat/test-export-topline.R
git commit -m "feat(freqs): add export computation layer (.build_freq_frame and helpers)"
```

---

## Task 3: Validation layer — `export_topline()` stub + error tests

**Files:**
- Create: `R/export-topline.R` (validation only — no rendering yet)
- Modify: `tests/testthat/test-export-topline.R` (add section 8)

- [ ] **Step 1: Add section 8 error path tests to `test-export-topline.R`**

Append to the file:

```r
# ── 8. Error paths ────────────────────────────────────────────────────────────

test_that("export_topline() errors when design is not a survey object", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  df  <- data.frame(q1 = 1:5, wt = rep(1, 5))

  expect_error(
    export_topline(df, vars = q1, file_name = tmp),
    class = "surveyreports_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, export_topline(df, vars = q1, file_name = tmp))
})

test_that("export_topline() errors when file_name does not end in .xlsx", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor

  expect_error(
    export_topline(d, vars = q1, file_name = "output.csv"),
    class = "surveyreports_error_invalid_file_name"
  )
  expect_snapshot(error = TRUE,
    export_topline(d, vars = q1, file_name = "output.csv"))
})

test_that("export_topline() errors when conf_level is out of range", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor
  tmp <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = q1, file_name = tmp, conf_level = 1.5),
    class = "surveyreports_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE,
    export_topline(d, vars = q1, file_name = tmp, conf_level = 1.5))
})

test_that("export_topline() errors when decimals is negative", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor
  tmp <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = q1, file_name = tmp, decimals = -1L),
    class = "surveyreports_error_invalid_decimals"
  )
  expect_snapshot(error = TRUE,
    export_topline(d, vars = q1, file_name = tmp, decimals = -1L))
})

test_that("export_topline() errors when vars are not in the design", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor
  tmp <- withr::local_tempfile(fileext = ".xlsx")

  expect_error(
    export_topline(d, vars = nonexistent_var, file_name = tmp),
    class = "surveyreports_error_var_not_found"
  )
  expect_snapshot(error = TRUE,
    export_topline(d, vars = nonexistent_var, file_name = tmp))
})
```

- [ ] **Step 2: Run to confirm failure**

```r
devtools::test(filter = "export-topline")
```

Expected: 5 new failures — `export_topline` not found.

- [ ] **Step 3: Create `R/export-topline.R` with validation only**

```r
# R/export-topline.R

#' Export a topline frequency table to an Excel workbook
#'
#' Calls [surveycore::get_freqs()] across multiple variables, assembles a
#' long tidy frame, and renders a styled `.xlsx` workbook via
#' [openxlsx2::wb_workbook()].
#'
#' @param design A survey design object created by
#'   [surveycore::as_survey()], [surveycore::as_survey_replicate()],
#'   [surveycore::as_survey_twophase()], or a
#'   [surveycore::survey_collection()] for wave comparisons.
#' @param vars <[`tidy-select`][tidyselect::language]> Variables to
#'   tabulate. Use bare column names or tidyselect helpers.
#' @param file_name Character scalar. Output path. Must end in `.xlsx`.
#' @param pub_type Character scalar. Suppression level: `"external"`
#'   (default) drops subgroups below eff_n 100 or raw N 100;
#'   `"internal"` drops below eff_n 50 or raw N 100; `"none"` skips
#'   suppression.
#' @param variance Character scalar or `NULL`. Passed to
#'   [surveycore::get_freqs()]. `NULL` (default) shows no variance
#'   columns; `"se"` adds a standard error column; `"ci"` adds CI
#'   bounds.
#' @param conf_level Numeric scalar in `(0, 1)`. Confidence level.
#'   Passed to [surveycore::get_freqs()]. Default `0.95`.
#' @param show_n Logical. Whether to include unweighted N columns.
#'   Default `TRUE`.
#' @param show_eff_n Logical. Whether to include effective N columns
#'   (Kish approximation). Default `FALSE`.
#' @param decimals Non-negative integer. Decimal places for percentages.
#'   Default `1`.
#'
#' @return `NULL` invisibly. Side effect: writes `.xlsx` file to
#'   `file_name`.
#'
#' @seealso
#'   [export_crosstab()] for banner-crosstabbed output,
#'   [surveycore::get_freqs()] for the underlying frequency function
#'
#' @family frequency functions
#'
#' @examples
#' df <- data.frame(
#'   q1 = c("A", "B", "A", "B", "A"),
#'   wt = c(1.1, 0.9, 1.0, 1.2, 0.8)
#' )
#' d   <- surveycore::as_survey(df, weights = wt)
#' out <- withr::local_tempfile(fileext = ".xlsx")
#' export_topline(d, vars = q1, file_name = out)
#'
#' @export
export_topline <- function(
  design,
  vars,
  file_name,
  pub_type   = c("external", "internal", "none"),
  variance   = NULL,
  conf_level = 0.95,
  show_n     = TRUE,
  show_eff_n = FALSE,
  decimals   = 1L
) {
  rlang::check_installed("surveycore", reason = "to compute survey frequencies")

  # ── 1. design class check ────────────────────────────────────────────────────
  if (
    !S7::S7_inherits(design, surveycore::survey_base) &&
    !S7::S7_inherits(design, surveycore::survey_collection)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a survey design or collection object.",
        "i" = "Got class {.cls {class(design)}}.",
        "v" = "Use {.fn surveycore::as_survey} to create a design object."
      ),
      class = "surveyreports_error_not_survey_object"
    )
  }

  # ── 2. file_name check ───────────────────────────────────────────────────────
  if (
    !is.character(file_name) || length(file_name) != 1L ||
    is.na(file_name) || !grepl("\\.xlsx$", file_name, ignore.case = TRUE)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg file_name} must be a character scalar ending in {.val .xlsx}.",
        "i" = "Got {.val {file_name}}."
      ),
      class = "surveyreports_error_invalid_file_name"
    )
  }

  # ── 3. conf_level check ──────────────────────────────────────────────────────
  if (
    !is.numeric(conf_level) || length(conf_level) != 1L ||
    is.na(conf_level) || conf_level <= 0 || conf_level >= 1
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg conf_level} must be a number strictly between 0 and 1.",
        "i" = "Got {.val {conf_level}}."
      ),
      class = "surveyreports_error_invalid_conf_level"
    )
  }

  # ── 4. decimals check ────────────────────────────────────────────────────────
  decimals <- suppressWarnings(as.integer(decimals))
  if (length(decimals) != 1L || is.na(decimals) || decimals < 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg decimals} must be a non-negative integer.",
        "i" = "Got {.val {decimals}}."
      ),
      class = "surveyreports_error_invalid_decimals"
    )
  }

  pub_type <- match.arg(pub_type)

  # ── 5. Resolve NSE ───────────────────────────────────────────────────────────
  design_data <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1L]]@data
  } else {
    design@data
  }

  vars_resolved <- tryCatch(
    names(tidyselect::eval_select(rlang::enquo(vars), design_data)),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "Variable selection failed for {.arg vars}.",
          "i" = "tidyselect reported: {conditionMessage(e)}."
        ),
        class = "surveyreports_error_var_not_found"
      )
    }
  )

  if (length(vars_resolved) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg vars} selected no variables.",
        "v" = "Supply at least one variable name."
      ),
      class = "surveyreports_error_var_not_found"
    )
  }

  # ── 6. Classify question types ───────────────────────────────────────────────
  classify_target <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1L]]
  } else {
    design
  }
  var_types_tbl <- surveycore::classify_question_type(
    classify_target,
    variable = vars_resolved
  )

  # ── 7. Warn about missing variable labels ────────────────────────────────────
  missing_label_vars <- .check_missing_labels(design, vars_resolved)
  if (length(missing_label_vars) > 0L) {
    cli::cli_warn(
      c(
        "!" = "{length(missing_label_vars)} variable{?s} {?has/have} no {.field variable_label}.",
        "i" = "Affected: {.field {missing_label_vars}}.",
        "v" = "Use {.fn surveycore::set_var_label} to add labels."
      ),
      class = "surveyreports_warning_missing_variable_label"
    )
  }

  # ── 8. Build frequency frame ─────────────────────────────────────────────────
  freq_result <- .build_freq_frame(
    design, vars_resolved, var_types_tbl,
    pub_type, variance, conf_level, show_eff_n
  )
  frame      <- freq_result$frame
  suppressed <- freq_result$suppressed

  # ── 9. Warn about suppressed subgroups ───────────────────────────────────────
  if (nrow(suppressed) > 0L) {
    sup_desc <- paste0(
      '"', suppressed$subgroup_value, '" (',
      suppressed$subgroup_var, ')',
      ' eff_n = ', round(suppressed$eff_n, 1)
    )
    cli::cli_warn(
      c(
        "!" = "{nrow(suppressed)} subgroup{?s} suppressed (pub_type = {.val {pub_type}}).",
        "i" = "Suppressed: {.val {sup_desc}}."
      ),
      class = "surveyreports_warning_subgroup_suppressed"
    )
  }

  # ── 10. Render workbook ──────────────────────────────────────────────────────
  wb <- .build_workbook()
  wb <- openxlsx2::wb_add_worksheet(wb, "Topline")

  current_row    <- 1L
  groups_done    <- integer(0L)

  for (var in vars_resolved) {
    var_rows <- frame[frame$variable == var, ]
    if (nrow(var_rows) == 0L) next

    var_type <- var_rows$var_type[[1L]]
    group_id <- var_rows$group_id[[1L]]

    if (var_type %in% c("sata", "battery") && group_id %in% groups_done) next
    groups_done <- c(groups_done, group_id)

    render_args <- list(
      wb          = wb,
      sheet       = "Topline",
      start_row   = current_row,
      show_n      = show_n,
      show_eff_n  = show_eff_n,
      decimals    = decimals,
      suppressed  = suppressed
    )

    if (var_type == "sata") {
      group_vars        <- var_types_tbl$variable[var_types_tbl$group == group_id]
      render_args$frame <- frame[frame$variable %in% group_vars, ]
      result            <- do.call(.render_topline_sata, render_args)
    } else if (var_type == "battery") {
      group_vars        <- var_types_tbl$variable[var_types_tbl$group == group_id]
      render_args$frame <- frame[frame$variable %in% group_vars, ]
      result            <- do.call(.render_topline_battery, render_args)
    } else {
      render_args$frame <- var_rows
      result            <- do.call(.render_topline_single, render_args)
    }

    wb          <- result$wb
    current_row <- result$next_row + 1L
  }

  openxlsx2::wb_save(wb, file_name)
  invisible(NULL)
}


# ── Internal workbook helpers ─────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.build_workbook <- function() {
  openxlsx2::wb_workbook()
}


#' @keywords internal
#' @noRd
.build_display_table <- function(
  frame, values, subgroups, show_n, show_eff_n, decimals
) {
  fmt  <- paste0("%.", decimals, "f%%")
  cols <- list(Response = values)

  for (sg in subgroups) {
    sg_data <- frame[frame$subgroup_label == sg, ]
    idx     <- match(values, sg_data$value)
    valid   <- !is.na(idx)

    pct_out <- rep(NA_character_, length(values))
    pct_out[valid] <- sprintf(fmt, sg_data$pct[idx[valid]] * 100)
    cols[[paste0(sg, " %")]] <- pct_out

    if (show_n) {
      n_out <- rep(NA_integer_, length(values))
      n_out[valid] <- sg_data$n[idx[valid]]
      cols[[paste0(sg, " N")]] <- n_out
    }

    if (show_eff_n && "eff_n" %in% names(frame)) {
      en_out <- rep(NA_real_, length(values))
      en_out[valid] <- sg_data$eff_n[idx[valid]]
      cols[[paste0(sg, " Eff N")]] <- en_out
    }

    if ("se" %in% names(frame)) {
      se_out <- rep(NA_real_, length(values))
      se_out[valid] <- sg_data$se[idx[valid]]
      cols[[paste0(sg, " SE")]] <- se_out
    }

    if ("ci_low" %in% names(frame)) {
      cl_out <- rep(NA_real_, length(values))
      ch_out <- rep(NA_real_, length(values))
      cl_out[valid] <- sg_data$ci_low[idx[valid]]
      ch_out[valid] <- sg_data$ci_high[idx[valid]]
      cols[[paste0(sg, " CI Low")]]  <- cl_out
      cols[[paste0(sg, " CI High")]] <- ch_out
    }
  }

  as.data.frame(cols, check.names = FALSE)
}


#' @keywords internal
#' @noRd
.write_block_header <- function(wb, sheet, text, start_row, n_cols) {
  dims <- openxlsx2::wb_dims(rows = start_row, cols = seq_len(n_cols))
  wb   <- openxlsx2::wb_add_data(
    wb, sheet, x = text, start_row = start_row, start_col = 1L, col_names = FALSE
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(wb, sheet, dims = dims)
  }
  wb <- openxlsx2::wb_add_font(wb, sheet, dims = dims, bold = TRUE, size = 11)
  wb
}


#' @keywords internal
#' @noRd
.write_suppression_footnote <- function(wb, sheet, suppressed, row) {
  if (nrow(suppressed) == 0L) return(list(wb = wb, next_row = row))
  note <- paste0(
    "Note: ",
    paste0(
      '"', suppressed$subgroup_value, '"',
      " (", suppressed$subgroup_var, ") not shown:",
      " eff_n = ", round(suppressed$eff_n, 1),
      collapse = "; "
    ),
    "."
  )
  wb <- openxlsx2::wb_add_data(
    wb, sheet, x = note, start_row = row, start_col = 1L, col_names = FALSE
  )
  list(wb = wb, next_row = row + 1L)
}


# ── Render helpers ────────────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.render_topline_single <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed
) {
  q_text    <- frame$question_text[[1L]]
  subgroups <- unique(frame$subgroup_label)
  values    <- unique(frame$value)
  display   <- .build_display_table(frame, values, subgroups, show_n, show_eff_n, decimals)
  n_cols    <- ncol(display)
  hdr_row   <- start_row
  col_row   <- start_row + 1L
  data_row  <- start_row + 2L

  wb <- .write_block_header(wb, sheet, q_text, hdr_row, n_cols)

  col_header_df <- as.data.frame(t(names(display)), stringsAsFactors = FALSE)
  names(col_header_df) <- NULL
  wb <- openxlsx2::wb_add_data(
    wb, sheet, x = col_header_df, start_row = col_row, start_col = 1L, col_names = FALSE
  )
  wb <- openxlsx2::wb_add_font(
    wb, sheet,
    dims = openxlsx2::wb_dims(rows = col_row, cols = seq_len(n_cols)),
    bold = TRUE
  )

  wb <- openxlsx2::wb_add_data(
    wb, sheet, x = display, start_row = data_row, start_col = 1L, col_names = FALSE
  )

  next_row <- data_row + nrow(display)

  fn <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
  list(wb = fn$wb, next_row = fn$next_row)
}


#' @keywords internal
#' @noRd
.render_topline_sata <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed
) {
  q_text    <- frame$question_text[[1L]]
  subgroups <- unique(frame$subgroup_label)
  sata_vars <- unique(frame$variable)
  fmt       <- paste0("%.", decimals, "f%%")

  item_labels <- vapply(sata_vars, function(v) {
    frame$var_label[frame$variable == v][[1L]]
  }, character(1L))

  cols <- list(Item = item_labels)
  for (sg in subgroups) {
    sg_data <- frame[frame$subgroup_label == sg, ]
    pct_out <- vapply(sata_vars, function(v) {
      row <- sg_data[sg_data$variable == v & sg_data$value == "1", ]
      if (nrow(row) == 1L) sprintf(fmt, row$pct * 100) else NA_character_
    }, character(1L))
    cols[[paste0(sg, " %")]] <- pct_out

    if (show_n) {
      n_out <- vapply(sata_vars, function(v) {
        row <- sg_data[sg_data$variable == v & sg_data$value == "1", ]
        if (nrow(row) == 1L) row$n else NA_integer_
      }, integer(1L))
      cols[[paste0(sg, " N")]] <- n_out
    }

    if (show_eff_n && "eff_n" %in% names(frame)) {
      en_out <- vapply(sata_vars, function(v) {
        row <- sg_data[sg_data$variable == v & sg_data$value == "1", ]
        if (nrow(row) == 1L) row$eff_n else NA_real_
      }, numeric(1L))
      cols[[paste0(sg, " Eff N")]] <- en_out
    }
  }

  display <- as.data.frame(cols, check.names = FALSE)
  n_cols  <- ncol(display)
  hdr_row <- start_row
  col_row <- start_row + 1L
  dat_row <- start_row + 2L

  wb <- .write_block_header(wb, sheet, q_text, hdr_row, n_cols)

  col_header_df <- as.data.frame(t(names(display)), stringsAsFactors = FALSE)
  names(col_header_df) <- NULL
  wb <- openxlsx2::wb_add_data(
    wb, sheet, x = col_header_df, start_row = col_row, start_col = 1L, col_names = FALSE
  )
  wb <- openxlsx2::wb_add_font(
    wb, sheet,
    dims = openxlsx2::wb_dims(rows = col_row, cols = seq_len(n_cols)),
    bold = TRUE
  )

  wb <- openxlsx2::wb_add_data(
    wb, sheet, x = display, start_row = dat_row, start_col = 1L, col_names = FALSE
  )

  next_row <- dat_row + nrow(display)

  fn <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
  list(wb = fn$wb, next_row = fn$next_row)
}


#' @keywords internal
#' @noRd
.render_topline_battery <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed
) {
  q_text   <- frame$question_text[[1L]]
  bat_vars <- unique(frame$variable)

  # Determine max col count for merged header
  subgroups <- unique(frame$subgroup_label)
  n_cols    <- 1L + length(subgroups) * (1L + show_n + show_eff_n)

  wb <- .write_block_header(wb, sheet, q_text, start_row, n_cols)
  current_row <- start_row + 1L

  for (v in bat_vars) {
    v_frame <- frame[frame$variable == v, ]
    v_frame$question_text <- v_frame$var_label
    result      <- .render_topline_single(
      wb, sheet, v_frame, current_row, show_n, show_eff_n, decimals,
      suppressed = suppressed[integer(0), ]  # no footnote per item
    )
    wb          <- result$wb
    current_row <- result$next_row + 1L
  }

  fn <- .write_suppression_footnote(wb, sheet, suppressed, current_row)
  list(wb = fn$wb, next_row = fn$next_row)
}
```

- [ ] **Step 4: Run error tests to confirm they pass**

```r
devtools::test(filter = "export-topline")
```

Expected: section 8 (5 tests) + section 10 (3 tests) pass.

- [ ] **Step 5: Commit**

```bash
git add R/export-topline.R
git commit -m "feat(freqs): add export_topline() with validation and rendering"
```

---

## Task 4: Happy path and structural tests

**Files:**
- Modify: `tests/testthat/test-export-topline.R` (add sections 1–5)

- [ ] **Step 1: Add sections 1–5 to `test-export-topline.R`**

Append above the `# ── 8. Error paths` comment:

```r
# ── 1. Happy paths ────────────────────────────────────────────────────────────

test_that("export_topline() creates a file for all three design types", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  for (nm in names(designs)) {
    d   <- designs[[nm]]
    out <- withr::local_tempfile(fileext = ".xlsx")
    expect_no_error(
      suppressWarnings(export_topline(d, vars = q1, file_name = out))
    )
    expect_true(file.exists(out), label = paste0(nm, ": file created"))
    expect_gt(file.size(out), 0L, label = paste0(nm, ": file non-empty"))
  }
})

test_that("export_topline() workbook has a 'Topline' sheet", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(export_topline(designs$taylor, vars = q1, file_name = out))

  wb_back <- openxlsx2::wb_load(out)
  expect_true("Topline" %in% openxlsx2::wb_get_sheet_names(wb_back))
})

test_that("export_topline() returns NULL invisibly", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  result <- withVisible(
    suppressWarnings(export_topline(designs$taylor, vars = q1, file_name = out))
  )
  expect_null(result$value)
  expect_false(result$visible)
})


# ── 2. survey_collection — wave columns ───────────────────────────────────────

test_that("export_topline() works with a survey_collection", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  coll    <- surveycore::survey_collection(
    surveys = list("Wave1" = designs$taylor, "Wave2" = designs$replicate)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")
  expect_no_error(
    suppressWarnings(export_topline(coll, vars = q1, file_name = out))
  )
  expect_true(file.exists(out))
})


# ── 3. var_type dispatch ──────────────────────────────────────────────────────

test_that("export_topline() renders single-response variable without error", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")
  expect_no_error(
    suppressWarnings(export_topline(designs$taylor, vars = q1, file_name = out))
  )
})

test_that("export_topline() renders SATA variables without error", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")
  expect_no_error(
    suppressWarnings(
      export_topline(designs$taylor, vars = c(sata_a, sata_b, sata_c), file_name = out)
    )
  )
})

test_that("export_topline() renders battery variables without error", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")
  expect_no_error(
    suppressWarnings(
      export_topline(designs$taylor, vars = c(bat_1, bat_2, bat_3), file_name = out)
    )
  )
})


# ── 4. variance options ───────────────────────────────────────────────────────

test_that("export_topline() frame has no variance cols when variance = NULL", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    designs$taylor, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )
  frame_names <- names(result$frame)
  expect_false(any(c("se", "ci_low", "ci_high") %in% frame_names))
})

test_that("export_topline() frame has se col when variance = 'se'", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    designs$taylor, "q1", var_types,
    pub_type = "none", variance = "se", conf_level = 0.95, show_eff_n = FALSE
  )
  expect_true("se" %in% names(result$frame))
  expect_false(any(c("ci_low", "ci_high") %in% names(result$frame)))
})

test_that("export_topline() frame has ci_low and ci_high when variance = 'ci'", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    designs$taylor, "q1", var_types,
    pub_type = "none", variance = "ci", conf_level = 0.95, show_eff_n = FALSE
  )
  expect_true(all(c("ci_low", "ci_high") %in% names(result$frame)))
})


# ── 5. show_n / show_eff_n ────────────────────────────────────────────────────

test_that("export_topline() writes N columns to workbook when show_n = TRUE", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")
  suppressWarnings(
    export_topline(designs$taylor, vars = q1, file_name = out, show_n = TRUE)
  )
  df_back <- openxlsx2::wb_to_df(openxlsx2::wb_load(out), col_names = TRUE)
  expect_true(any(grepl("N$", names(df_back), ignore.case = FALSE)))
})

test_that("export_topline() omits N columns when show_n = FALSE", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")
  suppressWarnings(
    export_topline(designs$taylor, vars = q1, file_name = out, show_n = FALSE)
  )
  df_back <- openxlsx2::wb_to_df(openxlsx2::wb_load(out), col_names = TRUE)
  expect_false(any(grepl("N$", names(df_back), ignore.case = FALSE)))
})

test_that("export_topline() frame has eff_n column when show_eff_n = TRUE", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    designs$taylor, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = TRUE
  )
  expect_true("eff_n" %in% names(result$frame))
  expect_true(all(result$frame$eff_n > 0))
})

test_that("export_topline() frame has no eff_n column when show_eff_n = FALSE", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    designs$taylor, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )
  expect_false("eff_n" %in% names(result$frame))
})
```

- [ ] **Step 2: Run to confirm tests pass**

```r
devtools::test(filter = "export-topline")
```

Expected: all sections 1–5, 8, 10 pass. Total ~24 tests.

- [ ] **Step 3: Update snapshots for error tests**

```r
testthat::snapshot_review("export-topline")
```

Accept all new snapshots. Confirm they look correct (cli-formatted error messages).

- [ ] **Step 4: Commit**

```bash
git add tests/testthat/test-export-topline.R tests/testthat/_snaps/
git commit -m "test(freqs): add happy path, variance, and show_n tests for export_topline()"
```

---

## Task 5: Suppression, metadata warnings, and edge case tests

**Files:**
- Modify: `tests/testthat/test-export-topline.R` (add sections 6, 7, 9)

- [ ] **Step 1: Add sections 6, 7, 9 to `test-export-topline.R`**

Append before the `# ── 8. Error paths` comment:

```r
# ── 6. pub_type suppression ───────────────────────────────────────────────────

test_that(".build_freq_frame() drops suppressed waves and fires warning", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)

  # Build a small-N collection where at least one wave will be suppressed
  # under pub_type = "external" (eff_n < 100)
  small_df <- make_survey_data(n = 40L, n_psu = 4L, n_strata = 2L, seed = 99)
  small_d  <- surveycore::as_survey(
    small_df, ids = psu, strata = strata, fpc = fpc, weights = wt
  )
  coll <- surveycore::survey_collection(
    surveys = list(SmallWave = small_d, NormalWave = designs$taylor)
  )

  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result <- surveyreports:::.build_freq_frame(
    coll, "q1", var_types,
    pub_type = "external", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )

  # SmallWave (n=40) should be suppressed; NormalWave (n=200) should remain
  expect_false("SmallWave" %in% result$frame$subgroup_value)
  expect_true("NormalWave" %in% result$frame$subgroup_value)
  expect_true(nrow(result$suppressed) >= 1L)
  expect_identical(result$suppressed$subgroup_value[[1L]], "SmallWave")
})

test_that("export_topline() fires surveyreports_warning_subgroup_suppressed", {
  skip_if_not_installed("surveycore")
  designs  <- make_all_designs(seed = 42)
  small_df <- make_survey_data(n = 40L, n_psu = 4L, n_strata = 2L, seed = 99)
  small_d  <- surveycore::as_survey(
    small_df, ids = psu, strata = strata, fpc = fpc, weights = wt
  )
  coll <- surveycore::survey_collection(
    surveys = list(SmallWave = small_d, NormalWave = designs$taylor)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_warning(
    suppressWarnings(export_topline(coll, vars = q1, file_name = out,
      pub_type = "external")),
    class = "surveyreports_warning_subgroup_suppressed"
  )
})

test_that("export_topline() includes footnote in workbook for suppressed waves", {
  skip_if_not_installed("surveycore")
  designs  <- make_all_designs(seed = 42)
  small_df <- make_survey_data(n = 40L, n_psu = 4L, n_strata = 2L, seed = 99)
  small_d  <- surveycore::as_survey(
    small_df, ids = psu, strata = strata, fpc = fpc, weights = wt
  )
  coll <- surveycore::survey_collection(
    surveys = list(SmallWave = small_d, NormalWave = designs$taylor)
  )
  out <- withr::local_tempfile(fileext = ".xlsx")

  suppressWarnings(
    export_topline(coll, vars = q1, file_name = out, pub_type = "external")
  )

  df_back <- openxlsx2::wb_to_df(openxlsx2::wb_load(out), col_names = FALSE)
  all_text <- unlist(df_back, use.names = FALSE)
  all_text <- all_text[!is.na(all_text)]
  expect_true(
    any(grepl("Note:", all_text, fixed = TRUE)),
    label = "footnote with 'Note:' present in workbook"
  )
})

test_that(".build_freq_frame() pub_type='none' skips suppression entirely", {
  skip_if_not_installed("surveycore")
  designs  <- make_all_designs(seed = 42)
  small_df <- make_survey_data(n = 40L, n_psu = 4L, n_strata = 2L, seed = 99)
  small_d  <- surveycore::as_survey(
    small_df, ids = psu, strata = strata, fpc = fpc, weights = wt
  )
  coll <- surveycore::survey_collection(
    surveys = list(SmallWave = small_d, NormalWave = designs$taylor)
  )

  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    coll, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )

  expect_true("SmallWave" %in% result$frame$subgroup_value)
  expect_equal(nrow(result$suppressed), 0L)
})


# ── 7. Missing metadata ───────────────────────────────────────────────────────

test_that("export_topline() fires warning when variable_label is missing", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  # q1 has no variable_label by default
  expect_warning(
    export_topline(designs$taylor, vars = q1, file_name = out),
    class = "surveyreports_warning_missing_variable_label"
  )
})

test_that("export_topline() uses variable name as question_text when label missing", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  var_types <- surveycore::classify_question_type(designs$taylor, variable = "q1")
  result    <- surveyreports:::.build_freq_frame(
    designs$taylor, "q1", var_types,
    pub_type = "none", variance = NULL, conf_level = 0.95, show_eff_n = FALSE
  )
  expect_identical(unique(result$frame$question_text), "q1")
})

test_that("export_topline() does not warn when variable_label is set", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  d       <- surveycore::set_var_label(designs$taylor, variable = "q1", label = "Q1 Label")
  out     <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_warning(
    suppressWarnings(export_topline(d, vars = q1, file_name = out)),
    class = "surveyreports_warning_missing_variable_label"
  )
})


# ── 9. Edge cases ─────────────────────────────────────────────────────────────

test_that("export_topline() creates a file when a variable is all NA", {
  skip_if_not_installed("surveycore")
  designs <- make_all_designs(seed = 42)
  out     <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_topline(designs$taylor, vars = all_na_var, file_name = out)
    )
  )
  expect_true(file.exists(out))
})

test_that("export_topline() creates a file for a single-value variable", {
  skip_if_not_installed("surveycore")
  designs   <- make_all_designs(seed = 42)
  d         <- designs$taylor
  d@data$single_val <- "A"
  out <- withr::local_tempfile(fileext = ".xlsx")

  expect_no_error(
    suppressWarnings(
      export_topline(d, vars = single_val, file_name = out)
    )
  )
  expect_true(file.exists(out))
})
```

- [ ] **Step 2: Run all tests**

```r
devtools::test(filter = "export-topline")
```

Expected: all tests pass. Total ~37 tests.

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-export-topline.R tests/testthat/_snaps/
git commit -m "test(freqs): add suppression, metadata warning, and edge case tests for export_topline()"
```

---

## Task 6: Final check, documentation, and devtools::check()

**Files:**
- Modify: `R/surveyreports-package.R` (add `export_topline` to Key Functions)
- Run: `devtools::document()`, `devtools::check()`

- [ ] **Step 1: Add `export_topline()` to the package-level documentation**

In `R/surveyreports-package.R`, update the `@section Key Functions:` block:

```r
#' @section Key Functions:
#' - [pool_pvals()] — pool and adjust p-values across result tibbles
#' - [export_topline()] — export topline frequency tables to Excel
```

- [ ] **Step 2: Run `devtools::document()`**

```r
devtools::document()
```

Verify `NAMESPACE` and `man/export_topline.Rd` are updated.

- [ ] **Step 3: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes. If `no visible binding for global variable` notes appear for tidy-eval variables (e.g., `psu`, `strata`), this is pre-approved and does not block the PR.

- [ ] **Step 4: Commit documentation**

```bash
git add R/surveyreports-package.R NAMESPACE man/
git commit -m "docs(freqs): document export_topline() and update package-level docs"
```

- [ ] **Step 5: Open PR**

```bash
git push -u origin feature/export-topline
```

Then open a PR from `feature/export-topline` → `develop` with title:
`feat(freqs): implement export_topline() and shared computation layer`

PR description checklist:
- Tests written and passing (`devtools::test()`)
- R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- Roxygen docs updated and `devtools::document()` run
- `plans/error-messages.md` updated with 8 new errors + 2 new warnings
- PR title is a valid Conventional Commit

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task that covers it |
|---|---|
| `export_topline()` signature with all 8 args | Task 3 (implementation) |
| `pub_type` suppression (F.4a/b/c thresholds) | Task 2 (.build_freq_frame) + Task 5 (tests) |
| `variance` and `conf_level` pass-through | Task 2 (.compute_total_freq) + Task 4 (tests) |
| `show_n` / `show_eff_n` | Task 3 (rendering) + Task 4 (tests) |
| `decimals` formatting | Task 3 (.build_display_table) |
| `survey_collection` wave handling | Task 2 (.compute_total_freq) + Task 4 (tests) |
| `classify_question_type()` dispatch | Task 3 (export_topline) + Task 4 (tests) |
| SATA rendering | Task 3 (.render_topline_sata) + Task 4 (tests) |
| battery rendering | Task 3 (.render_topline_battery) + Task 4 (tests) |
| Self-banner (N/A for topline — no banner arg) | — |
| Missing variable_label warning | Task 3 (export_topline) + Task 5 (tests) |
| Subgroup suppressed warning | Task 3 (export_topline) + Task 5 (tests) |
| Suppression footnote in workbook | Task 3 (.write_suppression_footnote) + Task 5 (tests) |
| All 5 error classes | Task 3 (validation) + Task 3 (tests) |
| Numerical accuracy vs get_freqs() | Task 2 (tests section 10) |
| `make_all_designs()` helper | Task 1 |
| `plans/error-messages.md` updated | Task 1 |
| `DESCRIPTION` imports | Task 1 |

**Notes on scope not in Plan A (deferred to Plan B):**
- `export_crosstab()` and its render helpers
- `.compute_subgroup_freq()` and `.compute_interaction_freq()`
- Banner/interaction suppression (per-banner-level eff_n)
- `layout = "stacked"` option
