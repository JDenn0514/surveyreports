#' Export a crosstab frequency table to an Excel workbook
#'
#' Produces a publication-quality crosstab frequency table for one or more
#' survey variables cross-tabulated against one or more banner variables,
#' written to a styled `.xlsx` workbook. Variables are auto-classified
#' (single-choice, SATA, or battery) via
#' [surveycore::classify_question_type()] and rendered according to
#' `layout`.
#'
#' @param design A survey design object created by
#'   [surveycore::as_survey()], [surveycore::as_survey_replicate()], or
#'   [surveycore::as_survey_twophase()]. A
#'   [surveycore::survey_collection] is **not** accepted; use
#'   [export_topline()] for wave-comparison (trend) output.
#' @param vars <[`tidy-select`][tidyselect::language]> Variable(s) to
#'   tabulate. Use bare column names (`q1`), `c(q1, q2)`, or tidyselect
#'   helpers such as `starts_with("q")`.
#' @param banner <[`tidy-select`][tidyselect::language]> Banner (column)
#'   variable(s). Each unique level of each banner variable becomes a
#'   column in the crosstab table. Use bare column names or tidyselect
#'   helpers.
#' @param file_name Path to the output `.xlsx` file. Must end in `.xlsx`.
#' @param layout One of `"per_question"` (default) or `"stacked"`.
#'   Controls whether each question gets its own worksheet or all questions
#'   are stacked on a single sheet.
#' @param interactions Optional list of character vectors. Each element
#'   names two or more variables from `banner` whose levels will be crossed
#'   (interacted) to form additional crosstab columns. Default `NULL`.
#' @param pub_type One of `"external"` (default), `"internal"`, or
#'   `"none"`. Controls suppression thresholds for small subgroups.
#'   `"external"` suppresses subgroups with effective or raw N < 100;
#'   `"internal"` uses a threshold of 50 effective N or 100 raw N;
#'   `"none"` disables suppression.
#' @param variance One of `NULL`, `"se"`, or `"ci"`. Controls whether
#'   standard errors or confidence intervals are shown. Default `NULL`.
#' @param conf_level Numeric scalar in `(0, 1)`. Confidence level for
#'   intervals when `variance = "ci"`. Default `0.95`.
#' @param show_n Logical. Whether to include an unweighted count row.
#'   Default `TRUE`.
#' @param show_eff_n Logical. Whether to display the effective N in column
#'   headers. Default `FALSE`.
#' @param decimals Positive integer. Number of decimal places for displayed
#'   percentages. Default `1L`.
#'
#' @return `invisible(file_name)` — the path supplied in `file_name`.
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   q1    = sample(c("Agree", "Neutral", "Disagree"), 200, replace = TRUE),
#'   group = sample(c("A", "B"), 200, replace = TRUE),
#'   wt    = runif(200, 0.5, 1.5)
#' )
#' d <- surveycore::as_survey(df, weights = wt)
#' export_crosstab(d, vars = q1, banner = group, file_name = "crosstab.xlsx")
#' }
#'
#' @family frequency functions
#' @seealso [export_topline()] for topline (no banner) output,
#'   [surveycore::get_freqs()] for the underlying frequency function.
#' @export
export_crosstab <- function(
  design,
  vars,
  banner,
  file_name,
  layout       = c("per_question", "stacked"),
  interactions = NULL,
  pub_type     = c("external", "internal", "none"),
  variance     = NULL,
  conf_level   = 0.95,
  show_n       = TRUE,
  show_eff_n   = FALSE,
  decimals     = 1L
) {
  # 1. survey_collection rejection FIRST
  if (S7::S7_inherits(design, surveycore::survey_collection)) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a single survey design, not a collection.",
        "i" = "Got class {.cls {class(design)}}.",
        "v" = "Use {.fn export_topline} for wave-comparison (trend) output."
      ),
      class = "surveyreports_error_collection_not_supported_for_crosstab"
    )
  }

  # 2. Check surveycore is installed
  rlang::check_installed("surveycore")

  # 3. Inline design-type check
  if (!S7::S7_inherits(design, surveycore::survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a survey design object.",
        "i" = "Got class {.cls {class(design)}}.",
        "v" = "Use {.fn surveycore::as_survey} to create a design object."
      ),
      class = "surveyreports_error_not_survey_object"
    )
  }

  # 4. NSE resolution
  vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), design@data))

  banner_quo      <- rlang::enquo(banner)
  banner_resolved <- tryCatch(
    names(tidyselect::eval_select(banner_quo, design@data)),
    error = function(e) {
      # Extract the bare column name(s) that failed so we can report them
      missing_nm <- tryCatch(
        as.character(rlang::get_expr(banner_quo)),
        error = function(e2) "unknown"
      )
      cli::cli_abort(
        c(
          "x" = "1 banner variable not found in the design: {.field {missing_nm}}.",
          "i" = "Check for typos or use {.fn names} on the design data.",
          "v" = "Remove or rename the missing banner variable before calling this function."
        ),
        class = "surveyreports_error_banner_not_found"
      )
    }
  )

  # 5. Shared input validation (errors 3–8)
  .validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)

  # 6. Interactions validation
  if (!is.null(interactions)) {
    if (!is.list(interactions)) {
      cli::cli_abort(
        c(
          "x" = "{.arg interactions} must be a list or {.val NULL}.",
          "i" = "Got class {.cls {class(interactions)}}.",
          "v" = "Pass a list of character vectors, each naming 2+ variables from {.arg banner}."
        ),
        class = "surveyreports_error_interactions_not_list"
      )
    }
    for (elem in interactions) {
      not_in_banner <- elem[!elem %in% banner_resolved]
      if (length(not_in_banner) > 0L) {
        n_not_in <- length(not_in_banner)
        cli::cli_abort(
          c(
            "x" = "{cli::qty(n_not_in)}Interaction variable{?s} {.field {not_in_banner}} not found in {.arg banner}.",
            "i" = "All variables in each interactions element must also appear in {.arg banner}.",
            "v" = "{cli::qty(n_not_in)}Add the missing variable{?s} to {.arg banner}, or remove them from {.arg interactions}."
          ),
          class = "surveyreports_error_interaction_not_in_banner"
        )
      }
    }
  }

  # 8. Stub body
  invisible(file_name)
}
