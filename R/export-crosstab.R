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
#' @param pub_type One of `"none"` (default), `"external"`, or
#'   `"internal"`. Controls suppression thresholds for small subgroups.
#'   `"none"` disables suppression; `"external"` suppresses subgroups with
#'   effective or raw N < 100; `"internal"` uses a threshold of 50 effective
#'   N or 100 raw N.
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
#' @return `invisible(file_name)` -- the path supplied in `file_name`.
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
  pub_type     = c("none", "external", "internal"),
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

  # 4. NSE resolution for vars only
  vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), design@data))

  # 5. Shared input validation (errors 3-8)
  .validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)

  # 6. Banner NSE resolution (AFTER validate, so banner_not_found is error #9)
  banner_quo      <- rlang::enquo(banner)
  banner_resolved <- tryCatch(
    names(tidyselect::eval_select(banner_quo, design@data)),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "Banner variable not found in the design.",
          "i" = "The tidyselect expression for {.arg banner} failed: {conditionMessage(e)}",
          "v" = "Use bare column names that exist in the design."
        ),
        class = "surveyreports_error_banner_not_found"
      )
    }
  )

  # 7. Interactions validation
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

  layout   <- match.arg(layout)
  pub_type <- match.arg(pub_type)

  classify_out <- surveycore::classify_question_type(design, vars_resolved)

  freq_result <- .build_freq_frame(
    design,
    vars_resolved,
    classify_out,
    banner_resolved = banner_resolved,
    interactions    = interactions,
    variance        = variance,
    conf_level      = conf_level,
    show_eff_n      = show_eff_n,
    pub_type        = pub_type
  )

  wb <- .build_workbook()

  if (layout == "per_question") {
    groups_done <- character(0)
    for (var in vars_resolved) {
      row_info <- classify_out[classify_out$variable == var, ]
      vtype    <- row_info$type
      group_id <- row_info$group

      if (vtype != "single" && as.character(group_id) %in% groups_done) next

      if (vtype == "single") {
        sheet_name <- substr(var, 1L, 31L)
        var_frame  <- freq_result$frame[freq_result$frame$variable == var, ]
        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
        result <- .render_crosstab_single(
          wb, sheet_name, var_frame, 1L,
          show_n, show_eff_n, decimals, freq_result$suppressed,
          banner_resolved, interactions
        )
      } else if (vtype == "sata") {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        sheet_name <- substr(group_vars[[1L]], 1L, 31L)
        var_frame  <- freq_result$frame[freq_result$frame$variable %in% group_vars, ]
        groups_done <- c(groups_done, as.character(group_id))
        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
        result <- .render_crosstab_sata(
          wb, sheet_name, var_frame, 1L,
          show_n, show_eff_n, decimals, freq_result$suppressed,
          banner_resolved, interactions
        )
      } else {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        sheet_name <- substr(group_vars[[1L]], 1L, 31L)
        var_frame  <- freq_result$frame[freq_result$frame$variable %in% group_vars, ]
        groups_done <- c(groups_done, as.character(group_id))
        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
        result <- .render_crosstab_battery(
          wb, sheet_name, var_frame, 1L,
          show_n, show_eff_n, decimals, freq_result$suppressed,
          banner_resolved, interactions
        )
      }

      wb <- result$wb
    }
  } else {
    # stacked
    wb <- openxlsx2::wb_add_worksheet(wb, "Crosstab")
    current_row <- 1L
    groups_done <- character(0)

    for (var in vars_resolved) {
      row_info <- classify_out[classify_out$variable == var, ]
      vtype    <- row_info$type
      group_id <- row_info$group

      if (vtype != "single" && as.character(group_id) %in% groups_done) next

      if (vtype == "single") {
        var_frame <- freq_result$frame[freq_result$frame$variable == var, ]
        result <- .render_crosstab_single(
          wb, "Crosstab", var_frame, current_row,
          show_n, show_eff_n, decimals, freq_result$suppressed,
          banner_resolved, interactions
        )
      } else if (vtype == "sata") {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        var_frame  <- freq_result$frame[freq_result$frame$variable %in% group_vars, ]
        groups_done <- c(groups_done, as.character(group_id))
        result <- .render_crosstab_sata(
          wb, "Crosstab", var_frame, current_row,
          show_n, show_eff_n, decimals, freq_result$suppressed,
          banner_resolved, interactions
        )
      } else {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        var_frame  <- freq_result$frame[freq_result$frame$variable %in% group_vars, ]
        groups_done <- c(groups_done, as.character(group_id))
        result <- .render_crosstab_battery(
          wb, "Crosstab", var_frame, current_row,
          show_n, show_eff_n, decimals, freq_result$suppressed,
          banner_resolved, interactions
        )
      }

      wb          <- result$wb
      current_row <- result$next_row + 1L
    }
  }

  openxlsx2::wb_save(wb, file_name)
  invisible(file_name)
}

# -- Shared column-group helpers --------------------------------------------------

#' @keywords internal
#' @noRd
.build_col_groups <- function(frame, banner_resolved, interactions) {
  col_groups <- list()

  for (bv in banner_resolved) {
    bv_rows <- frame[
      frame$subgroup_type == "banner" & frame$subgroup_var == bv,
    ]
    levels_present <- unique(bv_rows$subgroup_value)
    if (length(levels_present) == 0L) next
    col_groups[[length(col_groups) + 1L]] <- list(
      spanner      = bv,
      levels       = levels_present,
      type         = "banner",
      subgroup_var = bv
    )
  }

  if (!is.null(interactions)) {
    for (int_vars in interactions) {
      int_label <- paste(int_vars, collapse = " \u00d7 ")
      int_rows  <- frame[
        frame$subgroup_type == "interaction" &
          frame$subgroup_var == int_label,
      ]
      levels_present <- unique(int_rows$subgroup_value)
      if (length(levels_present) == 0L) next
      col_groups[[length(col_groups) + 1L]] <- list(
        spanner      = int_label,
        levels       = levels_present,
        type         = "interaction",
        subgroup_var = int_label
      )
    }
  }

  col_groups
}

#' @keywords internal
#' @noRd
.write_crosstab_headers <- function(
  wb, sheet, spanner_row, header_row, col_groups, label_col1
) {
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = label_col1,
    start_row = header_row, start_col = 1L
  )

  current_col <- 2L
  for (cg in col_groups) {
    span_start <- current_col
    span_end   <- span_start + length(cg$levels) - 1L

    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = cg$spanner,
      start_row = spanner_row, start_col = span_start
    )
    if (span_end > span_start) {
      wb <- openxlsx2::wb_merge_cells(
        wb, sheet = sheet,
        dims = openxlsx2::wb_dims(rows = spanner_row, cols = span_start:span_end)
      )
    }

    for (k in seq_along(cg$levels)) {
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = cg$levels[[k]],
        start_row = header_row, start_col = current_col
      )
      current_col <- current_col + 1L
    }
  }

  wb
}

# -- Render helpers ---------------------------------------------------------------

#' @keywords internal
#' @noRd
.render_crosstab_single <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed,
  banner_resolved, interactions
) {
  if (nrow(frame) == 0L) return(list(wb = wb, next_row = start_row))

  question_text <- frame$question_text[[1L]]

  # Get value order from total rows
  total_rows <- frame[frame$subgroup_type == "total", ]
  values     <- unique(total_rows$value)

  col_groups <- .build_col_groups(frame, banner_resolved, interactions)

  # Total column count: 1 (response label) + sum of all level counts
  n_data_cols <- sum(
    vapply(col_groups, function(cg) length(cg$levels), integer(1L))
  )
  n_cols <- 1L + n_data_cols

  # Row 1: question text merged across all columns (bold)
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = question_text,
    start_row = start_row, start_col = 1L
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(
      wb, sheet = sheet,
      dims = openxlsx2::wb_dims(rows = start_row, cols = 1L:n_cols)
    )
  }
  wb <- openxlsx2::wb_add_font(
    wb, sheet = sheet,
    dims = openxlsx2::wb_dims(rows = start_row, cols = 1L),
    bold = TRUE
  )

  spanner_row <- start_row + 1L
  header_row  <- start_row + 2L

  # Row 2 (spanner) + Row 3 (column headers)
  wb <- .write_crosstab_headers(
    wb, sheet, spanner_row, header_row, col_groups, "Response"
  )

  # Data rows: one per response value
  data_start <- header_row + 1L
  for (j in seq_along(values)) {
    val     <- values[[j]]
    row_num <- data_start + j - 1L

    # Row label
    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = val,
      start_row = row_num, start_col = 1L
    )

    current_col <- 2L
    for (cg in col_groups) {
      for (level in cg$levels) {
        pct_rows <- frame[
          frame$subgroup_type == cg$type &
            frame$subgroup_var == cg$subgroup_var &
            frame$subgroup_value == level &
            frame$value == val,
        ]
        pct_val <- if (nrow(pct_rows) > 0L) {
          round(pct_rows$pct[[1L]] * 100, decimals)
        } else {
          NA_real_
        }
        wb <- openxlsx2::wb_add_data(
          wb, sheet = sheet, x = pct_val,
          start_row = row_num, start_col = current_col
        )
        current_col <- current_col + 1L
      }
    }
  }

  # Total row
  total_row_num <- data_start + length(values)
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = "Total",
    start_row = total_row_num, start_col = 1L
  )
  current_col <- 2L
  for (cg in col_groups) {
    for (level in cg$levels) {
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = "100%",
        start_row = total_row_num, start_col = current_col
      )
      current_col <- current_col + 1L
    }
  }

  # Suppression footnote
  next_row <- total_row_num + 1L
  if (nrow(suppressed) > 0L) {
    wb       <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
    next_row <- next_row + nrow(suppressed)
  }

  list(wb = wb, next_row = next_row)
}

#' @keywords internal
#' @noRd
.render_crosstab_sata <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed,
  banner_resolved, interactions
) {
  if (nrow(frame) == 0L) return(list(wb = wb, next_row = start_row))

  question_text <- frame$question_text[[1L]]
  sata_vars     <- unique(frame$variable)

  col_groups <- .build_col_groups(frame, banner_resolved, interactions)

  n_data_cols <- sum(
    vapply(col_groups, function(cg) length(cg$levels), integer(1L))
  )
  n_cols <- 1L + n_data_cols

  # Row 1: question preface (merged, bold)
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = question_text,
    start_row = start_row, start_col = 1L
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(
      wb, sheet = sheet,
      dims = openxlsx2::wb_dims(rows = start_row, cols = 1L:n_cols)
    )
  }
  wb <- openxlsx2::wb_add_font(
    wb, sheet = sheet,
    dims = openxlsx2::wb_dims(rows = start_row, cols = 1L),
    bold = TRUE
  )

  spanner_row <- start_row + 1L
  header_row  <- start_row + 2L

  # Row 2 (spanner) + Row 3 (column headers) \u2014 "Item" in col 1
  wb <- .write_crosstab_headers(
    wb, sheet, spanner_row, header_row, col_groups, "Item"
  )

  # Data rows: one row per SATA item; pct where value == "1"
  data_start <- header_row + 1L
  for (j in seq_along(sata_vars)) {
    var     <- sata_vars[[j]]
    row_num <- data_start + j - 1L

    item_label <- frame$var_label[frame$variable == var][[1L]]

    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = item_label,
      start_row = row_num, start_col = 1L
    )

    current_col <- 2L
    for (cg in col_groups) {
      for (level in cg$levels) {
        pct_rows <- frame[
          frame$variable == var &
            frame$subgroup_type == cg$type &
            frame$subgroup_var == cg$subgroup_var &
            frame$subgroup_value == level &
            frame$value == "1",
        ]
        pct_val <- if (nrow(pct_rows) > 0L) {
          round(pct_rows$pct[[1L]] * 100, decimals)
        } else {
          NA_real_
        }
        wb <- openxlsx2::wb_add_data(
          wb, sheet = sheet, x = pct_val,
          start_row = row_num, start_col = current_col
        )
        current_col <- current_col + 1L
      }
    }
  }

  next_row <- data_start + length(sata_vars)
  if (nrow(suppressed) > 0L) {
    wb       <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
    next_row <- next_row + nrow(suppressed)
  }

  list(wb = wb, next_row = next_row)
}

#' @keywords internal
#' @noRd
.render_crosstab_battery <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed,
  banner_resolved, interactions
) {
  if (nrow(frame) == 0L) return(list(wb = wb, next_row = start_row))

  question_text <- frame$question_text[[1L]]
  bat_vars      <- unique(frame$variable)

  col_groups <- .build_col_groups(frame, banner_resolved, interactions)

  n_data_cols <- sum(
    vapply(col_groups, function(cg) length(cg$levels), integer(1L))
  )
  n_cols <- 1L + n_data_cols

  # Row 1: battery preface (merged, bold)
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = question_text,
    start_row = start_row, start_col = 1L
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(
      wb, sheet = sheet,
      dims = openxlsx2::wb_dims(rows = start_row, cols = 1L:n_cols)
    )
  }
  wb <- openxlsx2::wb_add_font(
    wb, sheet = sheet,
    dims = openxlsx2::wb_dims(rows = start_row, cols = 1L),
    bold = TRUE
  )

  spanner_row <- start_row + 1L
  header_row  <- start_row + 2L

  # Row 2 (spanner) + Row 3 (column headers) \u2014 "Item" in col 1
  wb <- .write_crosstab_headers(
    wb, sheet, spanner_row, header_row, col_groups, "Item"
  )

  # Data rows: one row per battery sub-item \u00d7 scale value
  data_start  <- header_row + 1L
  current_row <- data_start

  for (var in bat_vars) {
    var_frame  <- frame[frame$variable == var, ]
    item_label <- var_frame$var_label[[1L]]

    # Scale values from total rows for this sub-item
    total_sub <- var_frame[var_frame$subgroup_type == "total", ]
    values    <- unique(total_sub$value)

    for (val in values) {
      row_label <- paste0(item_label, " (", val, ")")
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = row_label,
        start_row = current_row, start_col = 1L
      )

      current_col <- 2L
      for (cg in col_groups) {
        for (level in cg$levels) {
          pct_rows <- frame[
            frame$variable == var &
              frame$subgroup_type == cg$type &
              frame$subgroup_var == cg$subgroup_var &
              frame$subgroup_value == level &
              frame$value == val,
          ]
          pct_val <- if (nrow(pct_rows) > 0L) {
            round(pct_rows$pct[[1L]] * 100, decimals)
          } else {
            NA_real_
          }
          wb <- openxlsx2::wb_add_data(
            wb, sheet = sheet, x = pct_val,
            start_row = current_row, start_col = current_col
          )
          current_col <- current_col + 1L
        }
      }
      current_row <- current_row + 1L
    }
  }

  next_row <- current_row
  if (nrow(suppressed) > 0L) {
    wb       <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
    next_row <- next_row + nrow(suppressed)
  }

  list(wb = wb, next_row = next_row)
}
