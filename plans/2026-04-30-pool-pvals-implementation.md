# pool_pvals() Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `pool_pvals()` and its three internal helpers from `surveycore` into `surveyreports`, renaming all `surveycore_*` error/warning classes to `surveyreports_*`, rewriting the example, and porting the full test suite (~495 lines).

**Architecture:** Copy `surveycore/R/analysis-pool-pvals.R` and the three helpers (`.is_plain_list`, `.validate_pval_adjustment_method`, `.validate_list_columns`) from `surveycore/R/analysis-helpers.R` into a single new file `R/pool-pvals.R`. All class strings are renamed mechanically (8 substitutions). Tests live in `tests/testthat/test-pool-pvals.R` and use the dual `expect_error` + `expect_snapshot` pattern for every error path.

**Tech Stack:** R, testthat 3, cli, dplyr, tibble, surveycore (already in Imports)

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `R/pool-pvals.R` | **Create** | `pool_pvals()`, `print.survey_pooled_pvals()`, 3 internal helpers |
| `tests/testthat/test-pool-pvals.R` | **Create** | Full ported + adapted test suite |
| `tests/testthat/_snaps/pool-pvals.md` | **Auto-generated** | Snapshot file — committed after first run |
| `DESCRIPTION` | **Modify** | Add `dplyr (>= 1.0.0)` and `tibble (>= 3.0.0)` to `Imports` |
| `plans/error-messages.md` | **Modify** | Add 6 error rows and 2 warning rows |

---

## Task 1: Create feature branch

- [ ] **Step 1: Create and check out feature branch**

```bash
git checkout develop
git checkout -b feature/pool-pvals
```

- [ ] **Step 2: Verify branch**

```bash
git branch --show-current
```

Expected: `feature/pool-pvals`

---

## Task 2: Update DESCRIPTION with new Imports

**Files:**
- Modify: `DESCRIPTION`

- [ ] **Step 1: Add `dplyr` and `tibble` to Imports in DESCRIPTION**

Open `DESCRIPTION`. The current `Imports:` block is:

```
Imports:
    cli (>= 3.6.0),
    rlang (>= 1.0.0),
    surveycore (>= 0.8.2)
```

Change it to:

```
Imports:
    cli (>= 3.6.0),
    dplyr (>= 1.0.0),
    rlang (>= 1.0.0),
    surveycore (>= 0.8.2),
    tibble (>= 3.0.0)
```

- [ ] **Step 2: Verify the package still loads**

```r
devtools::load_all()
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add DESCRIPTION
git commit -m "chore: add dplyr and tibble to Imports for pool_pvals()"
```

---

## Task 3: Update plans/error-messages.md

**Files:**
- Modify: `plans/error-messages.md`

- [ ] **Step 1: Add the 6 error rows and 2 warning rows**

Replace the current content of `plans/error-messages.md` with:

```markdown
# Error and Warning Classes

All `cli_abort()` and `cli_warn()` calls must use a class from this table.

## Errors

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_error_not_data_frame` | `my_fn()` | `data` is not a data.frame |
| `surveyreports_error_pool_pvals_not_list` | `pool_pvals()` | `results` is not a plain list |
| `surveyreports_error_pool_pvals_empty` | `pool_pvals()` | `results` has length 0 |
| `surveyreports_error_pool_pvals_invalid_method` | `pool_pvals()` | `method` not in `stats::p.adjust.methods` |
| `surveyreports_error_pool_pvals_missing_pcol` | `pool_pvals()` | One or more list elements missing `p_col` column |
| `surveyreports_error_pool_pvals_id_col_collision` | `pool_pvals()` | `id_col` name already exists in one or more elements |
| `surveyreports_error_pool_pvals_invalid_pvalues` | `pool_pvals()` | Pooled `p_col` contains values outside `[0, 1]` |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyreports_warning_example` | `my_fn()` | Example warning condition |
| `surveyreports_warning_pool_pvals_input_pre_adjusted` | `pool_pvals()` | One or more elements already contain a `new_col` column |
| `surveyreports_warning_pool_pvals_no_pvalues_available` | `pool_pvals()` | All pooled p-values are `NA` |
```

- [ ] **Step 2: Commit**

```bash
git add plans/error-messages.md
git commit -m "docs: add pool_pvals error and warning classes to error-messages.md"
```

---

## Task 4: Create R/pool-pvals.R

**Files:**
- Create: `R/pool-pvals.R`

This task ports the source from `surveycore` verbatim except for:
1. Renaming 8 `surveycore_*` class strings → `surveyreports_*`
2. Rewriting the `@examples` block to use an inline data frame
3. Adding the `split_output` future-work comment near the return value

- [ ] **Step 1: Create R/pool-pvals.R with the full implementation**

Create `/Users/jacobdennen/surveyreports/R/pool-pvals.R` with the following content (note: the file header comment references `analysis-helpers.R` in surveycore; update it to reflect the new location):

```r
# R/pool-pvals.R
#
# Cross-DV multiplicity correction across a list of survey analysis
# result tibbles. Exported functions: pool_pvals(),
# print.survey_pooled_pvals(). Internal helpers live at the bottom of
# this file: .is_plain_list, .validate_pval_adjustment_method,
# .validate_list_columns.

#' Pool p-values across a list of analysis results and apply a single
#' family-wise multiplicity correction
#'
#' Row-binds a list of analysis result tibbles (each carrying a
#' `p_value` column produced by `surveycore::get_diffs()`,
#' `surveycore::get_t_test()`, `surveycore::get_pairwise()`,
#' `surveycore::get_anova()`, `surveycore::clean.survey_glm_fit()`, or
#' any future `get_*()` carrying a `p_value` column) into a single
#' family and applies `stats::p.adjust()` once across the entire pool.
#'
#' @param results A list (named or unnamed) of tibbles / data frames.
#'   Every element must contain a column named per `p_col`. Length
#'   must be at least one. List elements may have heterogeneous column
#'   sets; missing columns are NA-filled on bind.
#' @param method Character(1). Adjustment method, passed verbatim to
#'   `stats::p.adjust()`. One of `stats::p.adjust.methods`. Default
#'   `"BH"`.
#' @param p_col Character(1). Name of the column holding raw p-values
#'   to be pooled. Default `"p_value"`. Must exist in every list
#'   element.
#' @param new_col Character(1). Name of the column where pooled-
#'   adjusted p-values are written. Default `"p_value_adj"`.
#' @param id_col Character(1). Name of the source-identifier column
#'   added to the bound output. Default `"source"`. Filled from list
#'   names; for unnamed elements the integer index is coerced to
#'   character (matching `dplyr::bind_rows(.id = ...)` semantics).
#' @param strip_within_adj Logical(1). If `FALSE` (default) and any
#'   input contains a column named per `new_col`, that column is
#'   renamed to `paste0(new_col, "_within")` per element before
#'   binding, and a warning is emitted. If `TRUE`, any pre-existing
#'   `new_col` column is silently dropped from each element before
#'   binding; no warning.
#'
#' @return An object of S3 class `c("survey_pooled_pvals", "tbl_df",
#'   "tbl", "data.frame")` -- a tibble with an additional class tag.
#'   Column ordering: (1) the union of input columns in input-union
#'   order; (2) `id_col`; (3) `new_col`; (4) `paste0(new_col,
#'   "_within")` if applicable. The result carries a `.meta` attribute
#'   (a list) with keys `method`, `family_size`, `n_total`, `n_na`,
#'   `n_significant_05`, `id_col`, `p_col`, and `new_col`.
#'
#' @details
#'
#' ## Method choice
#'
#' `pool_pvals()` dispatches verbatim to `stats::p.adjust()`; the
#' adjustment formula is determined entirely by `method`.
#'
#' - `"BH"` (Benjamini-Hochberg, 1995) -- controls the false discovery
#'   rate (FDR) under independence or positive regression dependency
#'   (PRDS). Recommended default for multi-DV survey families.
#' - `"BY"` (Benjamini-Yekutieli, 2001) -- controls FDR under arbitrary
#'   dependence; strictly more conservative than BH. Use when the
#'   dependence structure across DVs is unknown or arbitrary.
#' - `"fdr"` -- alias for `"BH"` per `stats::p.adjust()` source. The
#'   two are identical.
#' - `"holm"` (Holm, 1979) -- controls the family-wise error rate
#'   (FWER) under arbitrary dependence. Uniformly more powerful than
#'   Bonferroni.
#' - `"hochberg"` (Hochberg, 1988) -- controls FWER, requires
#'   independence or MTP_2 dependence (not just PRDS). Use Holm
#'   instead when DVs are correlated and FWER control is desired.
#' - `"hommel"` (Hommel, 1988) -- controls FWER, requires independence
#'   or MTP_2 dependence. Same caveat as Hochberg.
#' - `"bonferroni"` -- controls FWER under any dependence structure
#'   (Bonferroni's inequality). Most conservative of the FWER
#'   procedures; preferred for tiny families.
#' - `"none"` -- pass-through; raw p-values returned in `new_col`.
#'
#' ## Default method
#'
#' The default `method = "BH"` reflects the typical structure of
#' survey p-values across DVs, which are usually positively dependent
#' (PRDS) but rarely independent. When the dependence structure is
#' unknown or known to be arbitrary, switch to `method = "BY"` for a
#' robust FDR-controlling alternative.
#'
#' ## Recommended workflow
#'
#' Set `pval_adj = NULL` on every upstream `get_*()` call when planning
#' to pool, so within-call adjustment is not produced and
#' `pool_pvals()` applies the global correction once. Note that
#' attributes carried on input tibbles (e.g., `variable_label` from
#' `get_diffs()` results) are NOT preserved on the output; this matches
#' `dplyr::bind_rows()` default behavior. Users who need attribute
#' preservation must re-attach the attribute after pooling.
#'
#' ## Statistical caveat about double-adjustment
#'
#' surveycore's `get_t_test()`, `get_pairwise()` (default
#' `pval_adj = "holm"`), and `get_diffs()` overwrite the `p_value`
#' column in place when `pval_adj != NULL`. `pool_pvals()` cannot
#' detect this by column inspection alone -- the
#' `surveyreports_warning_pool_pvals_input_pre_adjusted` warning class
#' only fires when a separate column matching `new_col` is present.
#' Pass `pval_adj = NULL` upstream to avoid silent double-adjustment.
#'
#' ## Worked NA-denominator example
#'
#' With pooled p-values `(0.01, 0.02, 0.05, NA, NA)` and
#' `method = "BH"`, the BH denominator is `n = sum(!is.na(p)) = 3`
#' (not 5); adjusted values are `(0.03, 0.03, 0.05, NA, NA)`.
#'
#' ## Column-shape user-owned risk
#'
#' Column shapes and the semantic coherence of any `group` column
#' must be checked by the user; `pool_pvals()` does not validate
#' semantic coherence across input elements.
#'
#' ## Cross-design pooling caveat
#'
#' When results come from different surveys, sampling frames, or
#' weighting schemes, the user is responsible for ensuring
#' exchangeability across the pool.
#'
#' ## Small-m regime
#'
#' BH and related step-up methods become very conservative when
#' `m < 5` (the family size). Consider `method = "bonferroni"` or
#' unadjusted-with-exploratory-framing for tiny families.
#'
#' ## `"fdr"` alias note
#'
#' `"fdr"` is a dispatch alias for `"BH"` per `stats::p.adjust()`
#' source; the two produce identical output.
#'
#' ## Discrete p-value caveat
#'
#' Classical BH assumes continuous p-values. Chi-square tests of
#' small contingency tables can produce ties that violate this. See
#' the `DiscreteFDR` package on CRAN for that regime.
#'
#' ## Collection workflow
#'
#' Users with results from a collection-dispatched `get_*()` call (a
#' single tibble carrying a `.id` / `.survey` column) should split
#' into per-`.id` tibbles via `dplyr::group_split()` before passing
#' to `pool_pvals()`.
#'
#' ## See also
#'
#' Storey (2002) q-values, Romano-Wolf (2005) bootstrap stepdown, and
#' the `multcomp` / `mutoss` packages provide multiplicity machinery
#' surveyreports does not implement.
#'
#' @references
#' Benjamini, Y. and Hochberg, Y. (1995). Controlling the False
#' Discovery Rate: A Practical and Powerful Approach to Multiple
#' Testing. *Journal of the Royal Statistical Society, Series B*
#' 57(1), 289-300. \doi{10.1111/j.2517-6161.1995.tb02031.x}
#'
#' Benjamini, Y. and Yekutieli, D. (2001). The control of the false
#' discovery rate in multiple testing under dependency. *Annals of
#' Statistics* 29(4), 1165-1188. \doi{10.1214/aos/1013699998}
#'
#' Holm, S. (1979). A simple sequentially rejective multiple test
#' procedure. *Scandinavian Journal of Statistics* 6(2), 65-70.
#'
#' Hochberg, Y. (1988). A sharper Bonferroni procedure for multiple
#' tests of significance. *Biometrika* 75(4), 800-802.
#' \doi{10.1093/biomet/75.4.800}
#'
#' Hommel, G. (1988). A stagewise rejective multiple test procedure
#' based on a modified Bonferroni test. *Biometrika* 75(2), 383-386.
#' \doi{10.1093/biomet/75.2.383}
#'
#' @examples
#' df <- data.frame(
#'   y1 = c(1.2, 0.8, 2.1, 1.5, 0.9, 1.8),
#'   y2 = c(2.3, 1.1, 2.8, 0.7, 1.9, 2.2),
#'   sex = c("M", "F", "M", "F", "M", "F"),
#'   wt = c(1.1, 0.9, 1.2, 0.8, 1.0, 1.1)
#' )
#' d <- surveycore::as_survey(df, weights = wt)
#' r1 <- surveycore::get_diffs(d, y1, sex, pval_adj = NULL)
#' r2 <- surveycore::get_diffs(d, y2, sex, pval_adj = NULL)
#' pool_pvals(list(y1 = r1, y2 = r2))
#'
#' @export
pool_pvals <- function(
  results,
  method = "BH",
  p_col = "p_value",
  new_col = "p_value_adj",
  id_col = "source",
  strip_within_adj = FALSE
) {
  # 1. Non-list / data.frame guard
  if (!.is_plain_list(results)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg results} must be a list of tibbles, ",
          "not {.cls {class(results)[[1L]]}}."
        ),
        "i" = "Got {.cls {class(results)}}.",
        "v" = paste0(
          "Wrap a single result in {.code list()} (e.g., ",
          "{.code pool_pvals(list(get_diffs(...)))}). For multiple ",
          "results, supply a named or unnamed list."
        )
      ),
      class = "surveyreports_error_pool_pvals_not_list"
    )
  }

  # 2. Empty list check
  if (length(results) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg results} must be a list of length >= 1.",
        "i" = "Got an empty list."
      ),
      class = "surveyreports_error_pool_pvals_empty"
    )
  }

  # 3. Method validation (delegated to shared helper)
  .validate_pval_adjustment_method(
    method,
    arg_name = "method",
    class = "surveyreports_error_pool_pvals_invalid_method"
  )

  # 4 & 5. Per-element p_col presence + id_col collision
  checks <- .validate_list_columns(
    results,
    col_names = p_col,
    id_col = id_col
  )

  if (length(checks$missing_pcol) > 0L) {
    bad <- checks$missing_pcol
    cli::cli_abort(
      c(
        "x" = paste0(
          "All elements of {.arg results} must contain a column ",
          "named {.val {p_col}}."
        ),
        "i" = "Element{?s} missing the column: {.val {bad}}.",
        "v" = "Add the column or pass a different {.arg p_col}."
      ),
      class = "surveyreports_error_pool_pvals_missing_pcol"
    )
  }

  if (length(checks$id_collision) > 0L) {
    bad <- checks$id_collision
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg id_col} {.val {id_col}} collides with an existing ",
          "column in {length(bad)} input element{?s}."
        ),
        "i" = "Offending element{?s}: {.val {bad}}.",
        "v" = paste0(
          "Rename the offending column, or supply a different ",
          "{.arg id_col}."
        )
      ),
      class = "surveyreports_error_pool_pvals_id_col_collision"
    )
  }

  # 6. Per-element pre-existing new_col detection
  bad_pre <- vapply(
    seq_along(results),
    function(i) new_col %in% names(results[[i]]),
    logical(1L)
  )
  pre_ids <- character(0)
  if (any(bad_pre)) {
    nm <- names(results)
    if (is.null(nm)) {
      nm <- as.character(seq_along(results))
    } else {
      blank <- !nzchar(nm)
      if (any(blank)) {
        nm[blank] <- as.character(seq_along(results))[blank]
      }
    }
    pre_ids <- nm[bad_pre]

    within_col <- paste0(new_col, "_within")
    if (isTRUE(strip_within_adj)) {
      for (i in which(bad_pre)) {
        results[[i]][[new_col]] <- NULL
      }
    } else {
      for (i in which(bad_pre)) {
        elem <- results[[i]]
        elem[[within_col]] <- elem[[new_col]]
        elem[[new_col]] <- NULL
        results[[i]] <- elem
      }
      bad <- pre_ids
      cli::cli_warn(
        c(
          "!" = paste0(
            "{length(bad)} input element{?s} already contained a ",
            "column named {.val {new_col}}."
          ),
          "i" = paste0(
            "Renamed to {.val {within_col}} per element before ",
            "binding. Double-adjustment does not formally maintain ",
            "FDR control."
          ),
          "v" = paste0(
            "Set {.arg strip_within_adj = TRUE} to drop pre-existing ",
            "within-call adjustments, or pass {.code pval_adj = NULL} ",
            "to upstream {.fn get_*} calls."
          )
        ),
        class = "surveyreports_warning_pool_pvals_input_pre_adjusted"
      )
    }
  }

  # 7. bind_rows
  bound <- dplyr::bind_rows(results, .id = id_col)

  # 8. Post-bind range check on pooled p_col
  pooled <- bound[[p_col]]
  bad_idx <- which(!is.na(pooled) & (pooled < 0 | pooled > 1))
  if (length(bad_idx) > 0L) {
    n_bad <- length(bad_idx)
    src_vals <- bound[[id_col]][bad_idx]
    within_idx <- integer(n_bad)
    for (k in seq_along(bad_idx)) {
      same_src <- which(bound[[id_col]] == src_vals[[k]])
      within_idx[[k]] <- match(bad_idx[[k]], same_src)
    }
    bad_locs <- paste0(src_vals, "/", within_idx)
    cli::cli_abort(
      c(
        "x" = paste0(
          "Pooled column {.val {p_col}} contains {n_bad} value(s) ",
          "outside {.code [0, 1]}."
        ),
        "i" = paste0(
          "Offending row{?s} (source / row-within-source): ",
          "{.val {bad_locs}}."
        ),
        "v" = paste0(
          "Verify that {.arg p_col} names a p-value column, not a ",
          "coefficient or test statistic."
        )
      ),
      class = "surveyreports_error_pool_pvals_invalid_pvalues"
    )
  }

  # 9. p.adjust over pool
  adj <- stats::p.adjust(pooled, method = method)
  bound[[new_col]] <- adj

  # 10. All-NA pool warning
  if (length(pooled) > 0L && all(is.na(pooled))) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "All values of pooled column {.val {p_col}} are ",
          "{.code NA}."
        ),
        "i" = paste0(
          "Returning the bound tibble with all-{.code NA} ",
          "{.val {new_col}}."
        )
      ),
      class = "surveyreports_warning_pool_pvals_no_pvalues_available"
    )
  }

  # Column ordering: input union, then id_col, new_col, optional within_col
  input_union <- character(0)
  for (i in seq_along(results)) {
    input_union <- union(input_union, names(results[[i]]))
  }
  within_col <- paste0(new_col, "_within")
  trailing <- c(id_col, new_col)
  if (within_col %in% names(bound)) {
    trailing <- c(trailing, within_col)
  }
  input_union <- setdiff(input_union, trailing)
  ordered_cols <- c(input_union, trailing)
  ordered_cols <- ordered_cols[ordered_cols %in% names(bound)]
  out <- bound[, ordered_cols, drop = FALSE]
  out <- tibble::as_tibble(out)

  # S3 class + .meta attribute
  # Future: a `split_output` argument that splits the bound result back
  # into a named list by `id_col` after adjustment would be a natural
  # addition for the internal report_*() pipeline. Users can perform
  # the split themselves with split(result, result[[id_col]]) for now.
  meta <- list(
    method = method,
    family_size = sum(!is.na(out[[p_col]])),
    n_total = nrow(out),
    n_na = sum(is.na(out[[p_col]])),
    n_significant_05 = sum(out[[new_col]] < 0.05, na.rm = TRUE),
    id_col = id_col,
    p_col = p_col,
    new_col = new_col
  )
  meta$family_size <- as.integer(meta$family_size)
  meta$n_total <- as.integer(meta$n_total)
  meta$n_na <- as.integer(meta$n_na)
  meta$n_significant_05 <- as.integer(meta$n_significant_05)
  attr(out, ".meta") <- meta
  class(out) <- c("survey_pooled_pvals", class(out))
  out
}


#' Print a `survey_pooled_pvals` object
#'
#' Prints a one-line `cli` header summarizing the adjustment method,
#' family size, and number of significant rows; delegates the body to
#' tibble's print method via `NextMethod()`; and prints a one-line
#' footer when any p-values were excluded as NA.
#'
#' @param x A `survey_pooled_pvals` object.
#' @param n Integer(1). Maximum number of rows to print. Passed
#'   through to `print.tbl_df`. Default `10`.
#' @param ... Additional arguments passed to `print.tbl_df`.
#'
#' @return `invisible(x)`.
#'
#' @export
#' @method print survey_pooled_pvals
print.survey_pooled_pvals <- function(x, n = 10, ...) {
  meta <- attr(x, ".meta")
  cli::cli_text(
    paste0(
      "<survey_pooled_pvals: method = {.val {meta$method}}, ",
      "family_size = {meta$family_size}, ",
      "{meta$n_significant_05} significant at alpha = 0.05>"
    )
  )
  NextMethod()
  if (!is.null(meta$n_na) && meta$n_na > 0L) {
    cli::cli_text(
      "# {meta$n_na} p-value{?s} {?was/were} NA and excluded from the family"
    )
  }
  invisible(x)
}


# ── Internal helpers ──────────────────────────────────────────────────────────

.is_plain_list <- function(x) {
  is.list(x) && !inherits(x, "data.frame")
}


#' @keywords internal
#' @noRd
.validate_pval_adjustment_method <- function(
  method,
  arg_name = "method",
  call = rlang::caller_env(),
  class = "surveyreports_error_invalid_pval_adj",
  include_received = TRUE
) {
  valid_methods <- stats::p.adjust.methods
  is_bad <- !is.character(method) ||
    length(method) != 1L ||
    is.na(method) ||
    !method %in% valid_methods
  if (!is_bad) {
    return(invisible(TRUE))
  }
  msg <- c(
    "x" = paste0(
      "{.arg {arg_name}} must be a valid method for ",
      "{.fn stats::p.adjust}."
    ),
    "i" = "Valid methods: {.or {.val {valid_methods}}}."
  )
  if (isTRUE(include_received)) {
    msg <- c(msg, "i" = "Got {.val {method}}.")
  }
  cli::cli_abort(msg, class = class, call = call)
}


#' @keywords internal
#' @noRd
.validate_list_columns <- function(results, col_names, id_col) {
  ids <- names(results)
  if (is.null(ids)) {
    ids <- as.character(seq_along(results))
  } else {
    blank <- !nzchar(ids)
    if (any(blank)) {
      ids[blank] <- as.character(seq_along(results))[blank]
    }
  }
  missing_pcol <- character(0)
  id_collision <- character(0)
  for (i in seq_along(results)) {
    elem <- results[[i]]
    elem_names <- names(elem)
    if (!all(col_names %in% elem_names)) {
      missing_pcol <- c(missing_pcol, ids[[i]])
    }
    if (id_col %in% elem_names) {
      id_collision <- c(id_collision, ids[[i]])
    }
  }
  list(
    missing_pcol = missing_pcol,
    id_collision = id_collision
  )
}
```

- [ ] **Step 2: Run devtools::document() to generate NAMESPACE and man/ entries**

```r
devtools::document()
```

Expected: `man/pool_pvals.Rd` and `man/print.survey_pooled_pvals.Rd` created; `NAMESPACE` updated with `export(pool_pvals)` and `S3method(print,survey_pooled_pvals)`.

- [ ] **Step 3: Verify the package loads**

```r
devtools::load_all()
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add R/pool-pvals.R NAMESPACE man/pool_pvals.Rd man/print.survey_pooled_pvals.Rd
git commit -m "feat(pool-pvals): implement pool_pvals() and print method with internal helpers"
```

---

## Task 5: Write the test file (no snapshots yet — just code)

**Files:**
- Create: `tests/testthat/test-pool-pvals.R`

- [ ] **Step 1: Create the test file**

Create `/Users/jacobdennen/surveyreports/tests/testthat/test-pool-pvals.R`:

```r
# tests/testthat/test-pool-pvals.R

# 1. Happy paths — result tibble structure, S3 class, .meta attribute
# 2. Per-upstream-function happy paths
# 3. Multiple inputs — column union, id_col, named vs unnamed list
# 4. strip_within_adj — rename-to-within vs. drop behavior, warning class
# 5. Error paths — not_list, empty, invalid_method, missing_pcol,
#    id_col_collision, invalid_pvalues (dual: expect_error + expect_snapshot)
# 6. Edge cases — all-NA p_value column, single-element list, partially-NA pool
# 7. Numerical accuracy — adjusted values match stats::p.adjust() directly

# ── 1. Happy paths ────────────────────────────────────────────────────────────

test_that("pool_pvals() returns a tibble with expected row count and columns", {
  res <- list(
    a = tibble::tibble(term = c("x", "y"), p_value = c(0.01, 0.04)),
    b = tibble::tibble(term = "z", p_value = 0.5)
  )
  out <- pool_pvals(res)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 3L)
  expect_true(all(c("term", "source", "p_value", "p_value_adj") %in% names(out)))
})

test_that("pool_pvals() result has expected S3 class hierarchy", {
  res <- list(tibble::tibble(p_value = c(0.01, 0.05)))
  out <- pool_pvals(res)
  expect_identical(
    class(out),
    c("survey_pooled_pvals", "tbl_df", "tbl", "data.frame")
  )
})

test_that("pool_pvals() attaches a .meta attribute with the eight required keys", {
  res <- list(
    a = tibble::tibble(p_value = c(0.001, 0.04, NA_real_)),
    b = tibble::tibble(p_value = c(0.01, 0.2))
  )
  out <- pool_pvals(res)
  meta <- attr(out, ".meta")
  expect_true(is.list(meta))
  expect_setequal(
    names(meta),
    c(
      "method", "family_size", "n_total", "n_na",
      "n_significant_05", "id_col", "p_col", "new_col"
    )
  )
  expect_identical(meta$method, "BH")
  expect_identical(meta$family_size, 4L)
  expect_identical(meta$n_total, 5L)
  expect_identical(meta$n_na, 1L)
  expect_identical(meta$id_col, "source")
  expect_identical(meta$p_col, "p_value")
  expect_identical(meta$new_col, "p_value_adj")
  expect_true(is.integer(meta$n_significant_05))
})

test_that("pool_pvals() column ordering: union, then id_col, new_col, within", {
  res <- list(
    a = tibble::tibble(
      term = c("x", "y"),
      p_value = c(0.01, 0.04),
      p_value_adj = c(0.02, 0.05)
    ),
    b = tibble::tibble(term = "z", p_value = 0.5)
  )
  suppressWarnings(out <- pool_pvals(res))
  nm <- names(out)
  expect_equal(tail(nm, 3L), c("source", "p_value_adj", "p_value_adj_within"))
  expect_equal(head(nm, 2L), c("term", "p_value"))
})


# ── 2. Per-upstream-function happy paths ─────────────────────────────────────

test_that("pool_pvals() works with get_diffs() output", {
  df <- data.frame(
    y = c(1.2, 0.8, 2.1, 1.5, 0.9, 1.8),
    sex = c("M", "F", "M", "F", "M", "F"),
    wt = c(1.1, 0.9, 1.2, 0.8, 1.0, 1.1)
  )
  d <- surveycore::as_survey(df, weights = wt)
  r1 <- surveycore::get_diffs(d, y, sex, pval_adj = NULL)
  out <- pool_pvals(list(y = r1))
  expect_s3_class(out, "survey_pooled_pvals")
  expect_true(all(c("source", "p_value_adj") %in% names(out)))
  meta <- attr(out, ".meta")
  expect_identical(meta$method, "BH")
  expect_true(is.integer(meta$family_size))
  expect_true(is.integer(meta$n_total))
  expect_true(is.integer(meta$n_na))
  expect_true(is.integer(meta$n_significant_05))
})

test_that("pool_pvals() works with get_t_test() output", {
  df <- data.frame(
    y = c(1.2, 0.8, 2.1, 1.5, 0.9, 1.8),
    sex = c("M", "F", "M", "F", "M", "F"),
    wt = c(1.1, 0.9, 1.2, 0.8, 1.0, 1.1)
  )
  d <- surveycore::as_survey(df, weights = wt)
  r1 <- surveycore::get_t_test(d, y, sex, pval_adj = NULL)
  out <- pool_pvals(list(y = r1))
  expect_s3_class(out, "survey_pooled_pvals")
  expect_true(all(c("source", "p_value_adj") %in% names(out)))
  meta <- attr(out, ".meta")
  expect_true(is.integer(meta$n_total))
})

test_that("pool_pvals() works with get_pairwise() output", {
  df <- data.frame(
    y = c(1.2, 0.8, 2.1, 1.5, 0.9, 1.8, 2.0, 1.3),
    grp = c("A", "B", "C", "A", "B", "C", "A", "B"),
    wt = rep(1, 8)
  )
  d <- surveycore::as_survey(df, weights = wt)
  r1 <- surveycore::get_pairwise(d, y, grp, pval_adj = NULL)
  out <- pool_pvals(list(y = r1))
  expect_s3_class(out, "survey_pooled_pvals")
  expect_true(all(c("source", "p_value_adj") %in% names(out)))
})

test_that("pool_pvals() works with get_anova() output", {
  df <- data.frame(
    y = c(1.2, 0.8, 2.1, 1.5, 0.9, 1.8, 2.0, 1.3),
    grp = c("A", "B", "C", "A", "B", "C", "A", "B"),
    wt = rep(1, 8)
  )
  d <- surveycore::as_survey(df, weights = wt)
  r1 <- surveycore::get_anova(d, y, grp)
  out <- pool_pvals(list(y = r1))
  expect_s3_class(out, "survey_pooled_pvals")
  expect_true(all(c("source", "p_value_adj") %in% names(out)))
})


# ── 3. Multiple inputs — column union, id_col, named vs unnamed ──────────────

test_that("pool_pvals() NA-fills heterogeneous columns across elements", {
  res <- list(
    tibble::tibble(term = c("x", "y"), p_value = c(0.01, 0.04)),
    tibble::tibble(group = c("g1", "g2"), p_value = c(0.5, 0.2))
  )
  out <- pool_pvals(res)
  expect_true(all(c("term", "group") %in% names(out)))
  expect_true(all(is.na(out$group[1:2])))
  expect_true(all(is.na(out$term[3:4])))
})

test_that("pool_pvals() unnamed list yields character indices in source", {
  res <- list(
    tibble::tibble(p_value = c(0.01, 0.04)),
    tibble::tibble(p_value = 0.5),
    tibble::tibble(p_value = c(0.1, 0.2))
  )
  out <- pool_pvals(res)
  expect_identical(out$source, c("1", "1", "2", "3", "3"))
})

test_that("pool_pvals() mixed-named list interleaves names and indices", {
  res <- list(
    a = tibble::tibble(p_value = c(0.01, 0.04)),
    tibble::tibble(p_value = 0.5)
  )
  out <- pool_pvals(res)
  expect_identical(out$source, c("a", "a", "2"))
})

test_that("pool_pvals() honors custom p_col, new_col, and id_col", {
  res <- list(
    tibble::tibble(pval = c(0.01, 0.04)),
    tibble::tibble(pval = c(0.5, 0.2))
  )
  out <- pool_pvals(
    res,
    p_col = "pval",
    new_col = "pval_adj",
    id_col = ".source"
  )
  expect_true(all(c("pval", "pval_adj", ".source") %in% names(out)))
  expect_equal(
    out$pval_adj,
    stats::p.adjust(c(0.01, 0.04, 0.5, 0.2), "BH"),
    tolerance = 1e-12
  )
})


# ── 4. strip_within_adj ───────────────────────────────────────────────────────

test_that(
  "pool_pvals() warns and renames pre-existing new_col when strip_within_adj = FALSE",
  {
    res <- list(
      a = tibble::tibble(
        p_value = c(0.01, 0.04),
        p_value_adj = c(0.02, 0.04)
      ),
      b = tibble::tibble(p_value = c(0.02, 0.05))
    )
    expect_warning(
      out <- pool_pvals(res),
      class = "surveyreports_warning_pool_pvals_input_pre_adjusted"
    )
    expect_true("p_value_adj" %in% names(out))
    expect_true("p_value_adj_within" %in% names(out))
    expect_true(all(is.na(out$p_value_adj_within[out$source == "b"])))
    expect_equal(
      out$p_value_adj_within[out$source == "a"],
      c(0.02, 0.04)
    )
  }
)

test_that(
  "pool_pvals() silently drops pre-existing new_col when strip_within_adj = TRUE",
  {
    res <- list(
      a = tibble::tibble(
        p_value = c(0.01, 0.04),
        p_value_adj = c(0.02, 0.04)
      ),
      b = tibble::tibble(p_value = c(0.02, 0.05))
    )
    expect_no_warning(
      out <- pool_pvals(res, strip_within_adj = TRUE)
    )
    expect_true("p_value_adj" %in% names(out))
    expect_false("p_value_adj_within" %in% names(out))
    expect_equal(
      out$p_value_adj,
      stats::p.adjust(c(0.01, 0.04, 0.02, 0.05), "BH")
    )
  }
)

test_that(
  "pool_pvals() collision pattern works with custom new_col name",
  {
    res <- list(
      a = tibble::tibble(p_value = c(0.01, 0.04), fdr_q = c(0.02, 0.04)),
      b = tibble::tibble(p_value = c(0.5, 0.2))
    )
    expect_warning(
      out <- pool_pvals(res, new_col = "fdr_q"),
      class = "surveyreports_warning_pool_pvals_input_pre_adjusted"
    )
    expect_true(all(c("fdr_q", "fdr_q_within") %in% names(out)))
  }
)


# ── 5. Error paths ───────────────────────────────────────────────────────────

test_that("pool_pvals() rejects NULL with not_list class", {
  expect_error(
    pool_pvals(NULL),
    class = "surveyreports_error_pool_pvals_not_list"
  )
  expect_snapshot(error = TRUE, pool_pvals(NULL))
})

test_that("pool_pvals() rejects a bare tibble with not_list class", {
  expect_error(
    pool_pvals(tibble::tibble(p_value = 0.05)),
    class = "surveyreports_error_pool_pvals_not_list"
  )
  expect_snapshot(
    error = TRUE,
    pool_pvals(tibble::tibble(p_value = 0.05))
  )
})

test_that("pool_pvals() rejects an atomic vector with not_list class", {
  expect_error(
    pool_pvals(c(0.01, 0.05)),
    class = "surveyreports_error_pool_pvals_not_list"
  )
  expect_snapshot(error = TRUE, pool_pvals(c(0.01, 0.05)))
})

test_that("pool_pvals() rejects empty list with empty class", {
  expect_error(
    pool_pvals(list()),
    class = "surveyreports_error_pool_pvals_empty"
  )
  expect_snapshot(error = TRUE, pool_pvals(list()))
})

test_that("pool_pvals() rejects invalid method (string) with invalid_method", {
  res <- list(tibble::tibble(p_value = 0.5))
  expect_error(
    pool_pvals(res, method = "fancy"),
    class = "surveyreports_error_pool_pvals_invalid_method"
  )
  expect_snapshot(error = TRUE, pool_pvals(res, method = "fancy"))
})

test_that(
  "pool_pvals() rejects invalid method (length > 1) with invalid_method",
  {
    res <- list(tibble::tibble(p_value = 0.5))
    expect_error(
      pool_pvals(res, method = c("BH", "holm")),
      class = "surveyreports_error_pool_pvals_invalid_method"
    )
    expect_snapshot(
      error = TRUE,
      pool_pvals(res, method = c("BH", "holm"))
    )
  }
)

test_that(
  "pool_pvals() reports element missing p_col with missing_pcol class",
  {
    res <- list(
      a = tibble::tibble(p_value = c(0.01, 0.04)),
      b = tibble::tibble(other = c(0.02, 0.05))
    )
    expect_error(
      pool_pvals(res),
      class = "surveyreports_error_pool_pvals_missing_pcol"
    )
    expect_snapshot(error = TRUE, pool_pvals(res))
  }
)

test_that(
  "pool_pvals() reports id_col collision with id_col_collision class",
  {
    res <- list(
      tibble::tibble(p_value = c(0.01, 0.04), source = "a"),
      tibble::tibble(p_value = c(0.02, 0.05))
    )
    expect_error(
      pool_pvals(res),
      class = "surveyreports_error_pool_pvals_id_col_collision"
    )
    expect_snapshot(error = TRUE, pool_pvals(res))
  }
)

test_that(
  "pool_pvals() reports out-of-range pooled p-values with invalid_pvalues",
  {
    res <- list(
      tibble::tibble(p_value = c(0.5, 1.5)),
      tibble::tibble(p_value = c(0.1, 0.2))
    )
    expect_error(
      pool_pvals(res),
      class = "surveyreports_error_pool_pvals_invalid_pvalues"
    )
    expect_snapshot(error = TRUE, pool_pvals(res))
  }
)


# ── 6. Edge cases ─────────────────────────────────────────────────────────────

test_that(
  "pool_pvals() warns and returns when all pooled p-values are NA",
  {
    res <- list(
      tibble::tibble(p_value = c(NA_real_, NA_real_)),
      tibble::tibble(p_value = NA_real_)
    )
    expect_warning(
      out <- pool_pvals(res),
      class = "surveyreports_warning_pool_pvals_no_pvalues_available"
    )
    expect_true(all(is.na(out$p_value_adj)))
    expect_equal(nrow(out), 3L)
  }
)

test_that("pool_pvals() handles a single-element list", {
  res <- list(tibble::tibble(p_value = c(0.01, 0.05, 0.2)))
  out <- pool_pvals(res)
  expect_s3_class(out, "survey_pooled_pvals")
  expect_equal(nrow(out), 3L)
  expect_equal(
    out$p_value_adj,
    stats::p.adjust(c(0.01, 0.05, 0.2), "BH"),
    tolerance = 1e-12
  )
})

test_that("pool_pvals() handles a zero-row tibble in input", {
  res <- list(
    tibble::tibble(p_value = numeric(0)),
    tibble::tibble(p_value = c(0.01, 0.05))
  )
  out <- pool_pvals(res)
  expect_equal(nrow(out), 2L)
  expect_equal(out$source, c("2", "2"))
})

test_that("pool_pvals() preserves NA positions in pooled p_col", {
  res <- list(
    tibble::tibble(p_value = c(0.01, NA_real_, 0.05)),
    tibble::tibble(p_value = c(NA_real_, 0.5))
  )
  out <- pool_pvals(res)
  expect_true(is.na(out$p_value_adj[2]))
  expect_true(is.na(out$p_value_adj[4]))
  expect_false(is.na(out$p_value_adj[1]))
})

test_that("pool_pvals() does NOT preserve column attributes across bind", {
  x <- tibble::tibble(p_value = c(0.01, 0.04))
  attr(x$p_value, "variable_label") <- "Outcome 1"
  y <- tibble::tibble(p_value = c(0.5, 0.2))
  out <- pool_pvals(list(x, y))
  expect_null(attr(out$p_value, "variable_label"))
})

test_that("pool_pvals() coerces heterogeneous p_col types via bind_rows", {
  res <- list(
    tibble::tibble(p_value = c(0L, 1L)),
    tibble::tibble(p_value = c(0.5, 0.25))
  )
  out <- pool_pvals(res)
  expect_true(is.numeric(out$p_value))
})


# ── 7. Numerical accuracy ─────────────────────────────────────────────────────

test_that("pool_pvals() pooled p_value_adj equals stats::p.adjust(pooled, BH)", {
  res <- list(
    tibble::tibble(p_value = c(0.001, 0.04, 0.5)),
    tibble::tibble(p_value = c(0.01, 0.2))
  )
  out <- pool_pvals(res)
  expect_equal(
    out$p_value_adj,
    stats::p.adjust(c(0.001, 0.04, 0.5, 0.01, 0.2), "BH"),
    tolerance = 1e-12
  )
})

test_that("pool_pvals() round-trip oracle holds for every p.adjust method", {
  res <- list(
    a = tibble::tibble(p_value = c(0, 0.001, 0.5)),
    b = tibble::tibble(p_value = c(0.01, NA_real_, 1)),
    c = tibble::tibble(p_value = c(0.04, 0.2, 0.99))
  )
  pooled_raw <- c(0, 0.001, 0.5, 0.01, NA_real_, 1, 0.04, 0.2, 0.99)
  for (m in stats::p.adjust.methods) {
    out <- pool_pvals(res, method = m)
    expect_equal(
      out$p_value_adj,
      stats::p.adjust(pooled_raw, method = m),
      tolerance = 1e-12,
      info = paste0("method = ", m)
    )
  }
})

test_that("pool_pvals() m = 1 identity holds for every p.adjust method", {
  res <- list(tibble::tibble(p_value = 0.04))
  for (m in stats::p.adjust.methods) {
    expect_no_warning(out <- pool_pvals(res, method = m))
    expect_equal(out$p_value_adj, 0.04, info = paste0("method = ", m))
  }
})

test_that("pool_pvals() with method = 'none' returns raw p-values", {
  res <- list(
    tibble::tibble(p_value = c(0.01, 0.04, 0.5))
  )
  out <- pool_pvals(res, method = "none")
  expect_equal(out$p_value_adj, c(0.01, 0.04, 0.5), tolerance = 1e-12)
})

test_that("pool_pvals() sequential calls with different methods are independent", {
  res <- list(tibble::tibble(p_value = c(0.001, 0.04, 0.5)))
  out_bh <- pool_pvals(res, method = "BH")
  out_bonf <- pool_pvals(res, method = "bonferroni")
  expect_false(identical(out_bh$p_value_adj, out_bonf$p_value_adj))
  out_bh_again <- pool_pvals(res, method = "BH")
  expect_equal(out_bh$p_value_adj, out_bh_again$p_value_adj)
})

test_that(
  "pool_pvals() pools heterogeneous-shape get_diffs() and get_pairwise() rows",
  {
    diffs_shape <- tibble::tibble(
      term = c("a", "b"),
      estimate = c(0.5, -0.2),
      p_value = c(0.04, 0.2)
    )
    pairwise_shape <- tibble::tibble(
      level_a = c("g1", "g1"),
      level_b = c("g2", "g3"),
      estimate = c(0.1, 0.3),
      p_value = c(0.01, 0.5)
    )
    out <- pool_pvals(list(diffs = diffs_shape, pair = pairwise_shape))
    nm <- names(out)
    expect_true(all(
      c("term", "level_a", "level_b", "estimate", "p_value") %in% nm
    ))
    expect_equal(tail(nm, 2L), c("source", "p_value_adj"))
    expect_true(all(is.na(out$level_a[1:2])))
    expect_true(all(is.na(out$term[3:4])))
  }
)


# ── print.survey_pooled_pvals() ───────────────────────────────────────────────

test_that("print.survey_pooled_pvals() snapshot for a representative input", {
  res <- list(
    a = tibble::tibble(term = c("x", "y"), p_value = c(0.001, 0.04)),
    b = tibble::tibble(term = "z", p_value = 0.5),
    c = tibble::tibble(term = "w", p_value = NA_real_)
  )
  out <- pool_pvals(res)
  expect_snapshot(print(out))
})

test_that(
  "print.survey_pooled_pvals() prints NA footer only when n_na > 0",
  {
    res_no_na <- list(
      a = tibble::tibble(p_value = c(0.01, 0.04)),
      b = tibble::tibble(p_value = 0.5)
    )
    out_no_na <- pool_pvals(res_no_na)
    expect_snapshot(print(out_no_na))

    res_with_na <- list(
      a = tibble::tibble(p_value = c(0.01, NA_real_)),
      b = tibble::tibble(p_value = c(NA_real_, 0.5))
    )
    out_with_na <- pool_pvals(res_with_na)
    expect_snapshot(print(out_with_na))
  }
)

test_that("print.survey_pooled_pvals() returns invisible(x)", {
  out <- pool_pvals(list(tibble::tibble(p_value = c(0.01, 0.05))))
  expect_invisible(print(out))
})


# ── .is_plain_list() ─────────────────────────────────────────────────────────

test_that(".is_plain_list() distinguishes plain lists from data frames", {
  expect_true(surveyreports:::.is_plain_list(list()))
  expect_true(surveyreports:::.is_plain_list(list(a = 1, b = 2)))
  expect_false(surveyreports:::.is_plain_list(tibble::tibble()))
  expect_false(surveyreports:::.is_plain_list(data.frame(a = 1)))
  expect_false(surveyreports:::.is_plain_list(c(1, 2)))
  expect_false(surveyreports:::.is_plain_list(NULL))
  expect_false(surveyreports:::.is_plain_list("a"))
})
```

- [ ] **Step 2: Run the tests — they should fail with "pool_pvals not found" until Task 4 is done**

This step is a sanity check only. If Task 4 is already done (it should be), run:

```r
devtools::test(filter = "pool-pvals")
```

Expected: tests pass except snapshot tests which show "new snapshots" (see Task 6).

- [ ] **Step 3: Commit the test file**

```bash
git add tests/testthat/test-pool-pvals.R
git commit -m "test(pool-pvals): port full test suite from surveycore"
```

---

## Task 6: Generate and commit snapshots

**Files:**
- Auto-generate: `tests/testthat/_snaps/pool-pvals.md`

Snapshot tests (`expect_snapshot`) must be run once to create the reference files. After creation, verify them visually, then commit.

- [ ] **Step 1: Run tests to generate snapshots**

```r
devtools::test(filter = "pool-pvals")
```

Expected: All non-snapshot tests pass. Snapshot tests show "Adding new snapshot" — this is correct first-run behavior. The file `tests/testthat/_snaps/pool-pvals.md` is created.

- [ ] **Step 2: Review generated snapshots**

```r
testthat::snapshot_review("pool-pvals")
```

Review each snapshot. Check:
- Error messages include the correct `surveyreports_*` class name in the condition message
- The `print.survey_pooled_pvals()` header line reads correctly (method, family_size, n_significant_05)
- The NA footer appears when expected and is absent when not

Accept all snapshots that look correct. If any message references `surveycore_*` instead of `surveyreports_*`, there is a class rename miss — fix `R/pool-pvals.R` and re-run.

- [ ] **Step 3: Run tests again to confirm all pass (including snapshots)**

```r
devtools::test(filter = "pool-pvals")
```

Expected: all tests pass with 0 failures and 0 warnings.

- [ ] **Step 4: Commit snapshots**

```bash
git add tests/testthat/_snaps/pool-pvals.md
git commit -m "test(pool-pvals): commit generated snapshots"
```

---

## Task 7: Run R CMD check and fix any issues

- [ ] **Step 1: Run devtools::check()**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes (pre-approved: `no visible binding for global variable` and `checking CRAN incoming feasibility`).

- [ ] **Step 2: If there are errors or warnings, fix them**

Common issues and fixes:
- `pool_pvals not found in examples` — verify `@export` is present and `devtools::document()` was run
- `no visible global function definition for 'dplyr::bind_rows'` — this is the pre-approved "no visible binding" note; do NOT suppress with `utils::globalVariables()`
- `\dontrun{}` in examples — the example must be fully runnable; if `surveycore::as_survey()` or `surveycore::get_diffs()` aren't available, add `surveycore` as a `Suggests` dependency and wrap in `if (requireNamespace("surveycore", quietly = TRUE)) { ... }` — but since `surveycore` is already in `Imports`, the example should run unconditionally
- Example failure due to small dataset — verify the inline `data.frame` in `@examples` has columns `y1`, `y2`, `sex`, `wt` as defined in the example block in Task 4

- [ ] **Step 3: Commit any fixes**

```bash
git add -u
git commit -m "fix(pool-pvals): address R CMD check issues"
```

---

## Task 8: Final check and open PR

- [ ] **Step 1: Run the full test suite one final time**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 2: Run R CMD check one final time**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin feature/pool-pvals
gh pr create \
  --base develop \
  --title "feat(pool-pvals): migrate pool_pvals() from surveycore" \
  --body "$(cat <<'EOF'
## Summary

- Adds \`pool_pvals()\` and \`print.survey_pooled_pvals()\` to surveyreports
- Ports 3 internal helpers (\`.is_plain_list\`, \`.validate_pval_adjustment_method\`, \`.validate_list_columns\`) into \`R/pool-pvals.R\`
- Renames all 8 \`surveycore_*\` error/warning classes to \`surveyreports_*\`
- Rewrites \`@examples\` to use an inline data frame (no \`\\dontrun{}\`)
- Ports full test suite (~35 tests) from surveycore with class string substitutions
- Adds \`dplyr\` and \`tibble\` to DESCRIPTION Imports
- Updates \`plans/error-messages.md\` with 6 errors and 2 warnings

## Test plan

- [ ] \`devtools::test(filter = "pool-pvals")\` passes with 0 failures
- [ ] \`devtools::check()\` passes with 0 errors, 0 warnings
- [ ] All snapshot tests reviewed and accepted via \`snapshot_review()\`
- [ ] \`plans/error-messages.md\` updated

🤖 Generated with [Claude Code](https://claude.ai/claude-code)
EOF
)"
```

---

## Self-Review Against Spec

**Spec section coverage:**

| Spec requirement | Covered by |
|-----------------|------------|
| New file `R/pool-pvals.R` | Task 4 |
| New file `tests/testthat/test-pool-pvals.R` | Task 5 |
| New file `tests/testthat/_snaps/pool-pvals.md` | Task 6 |
| Add `dplyr (>= 1.0.0)` and `tibble (>= 3.0.0)` to Imports | Task 2 |
| Update `plans/error-messages.md` | Task 3 |
| 3 helpers in same file (single call site) | Task 4 — all 3 at bottom of `R/pool-pvals.R` |
| 8 class string renames (`surveycore_*` → `surveyreports_*`) | Task 4 — all 8 renamed in implementation |
| S3 class `survey_pooled_pvals` unchanged | Task 4 — confirmed, no package prefix |
| Example rewritten using inline data frame, no `\dontrun{}` | Task 4 — uses inline df with `surveycore::as_survey()` and `surveycore::get_diffs()` |
| `split_output` future comment near return value | Task 4 — comment added above `meta` block |
| Test class strings use `surveyreports_*` | Task 5 — all updated |
| Test calls use `surveycore::as_survey()` / `surveycore::get_diffs()` | Task 5 — all qualified |
| Dual `expect_error` + `expect_snapshot` for all 6 error classes | Task 5 — all 6 error paths have both assertions |
| Test sections 1–7 from spec | Task 5 — all 7 sections present |
| Feature branch | Task 1 |
| PR to `develop` | Task 8 |
