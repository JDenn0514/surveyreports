#' Export a topline frequency table to an Excel workbook
#'
#' Produces a publication-quality topline frequency table for one or more
#' survey variables, written to a styled `.xlsx` workbook. Each variable is
#' auto-classified (single-choice, SATA, or battery) via
#' [surveycore::classify_question_type()] and rendered to its appropriate
#' table block on a single sheet named `"Topline"`.
#'
#' @param design A survey design object created by
#'   [surveycore::as_survey()], [surveycore::as_survey_replicate()], or
#'   [surveycore::as_survey_twophase()]. A [surveycore::survey_collection]
#'   is also accepted; the output will include a pooled "Total" column and
#'   one column per wave.
#' @param vars <[`tidy-select`][tidyselect::language]> Variable(s) to
#'   tabulate. Use bare column names (`q1`), `c(q1, q2)`, or tidyselect
#'   helpers such as `starts_with("q")`.
#' @param file_name Path to the output `.xlsx` file. Must end in `.xlsx`.
#' @param conf_level Numeric scalar in `(0, 1)`. Confidence level for
#'   intervals when `variance = "ci"`. Default `0.95`.
#' @param decimals Positive integer. Number of decimal places for displayed
#'   percentages. Default `1L`.
#' @param variance One of `NULL`, `"se"`, or `"ci"`. Controls whether
#'   standard errors or confidence intervals are included in the output.
#'   Default `NULL` (neither).
#' @param show_n Logical. Whether to include an unweighted count column.
#'   Default `TRUE`.
#' @param show_eff_n Logical. Whether to display the effective N in the
#'   percentage column header. Default `FALSE`.
#'
#' @return `invisible(file_name)` — the path supplied in `file_name`.
#'
#' @examples
#' \dontrun{
#' d <- surveycore::as_survey(
#'   data.frame(
#'     q1 = sample(c("Agree", "Neutral", "Disagree"), 200, replace = TRUE),
#'     wt = runif(200, 0.5, 1.5)
#'   ),
#'   weights = wt
#' )
#' export_topline(d, vars = q1, file_name = "topline.xlsx")
#' }
#'
#' @family frequency functions
#' @seealso [surveycore::get_freqs()] for the underlying frequency function.
#' @export
export_topline <- function(
  design,
  vars,
  file_name,
  conf_level = 0.95,
  decimals   = 1L,
  variance   = NULL,
  show_n     = TRUE,
  show_eff_n = FALSE
) {
  rlang::check_installed("surveycore")

  # Inline design-type check BEFORE NSE resolution
  if (
    !(S7::S7_inherits(design, surveycore::survey_base) ||
        S7::S7_inherits(design, surveycore::survey_collection))
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a survey design object.",
        "i" = "Got class {.cls {class(design)}}.",
        "v" = "Use {.fn surveycore::as_survey} to create a design object."
      ),
      class = "surveyreports_error_not_survey_object"
    )
  }

  # NSE resolution
  data_for_select <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1L]]@data
  } else {
    design@data
  }
  vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), data_for_select))

  .validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)

  # Classify variables (collection: use first wave's design)
  design_for_classify <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1L]]
  } else {
    design
  }
  classify_out <- surveycore::classify_question_type(design_for_classify, vars_resolved)

  # Build frequency frame
  freq_result <- .build_freq_frame(
    design,
    vars_resolved,
    classify_out,
    variance   = variance,
    conf_level = conf_level,
    show_eff_n = show_eff_n
  )

  # Build workbook
  wb <- .build_workbook()
  wb <- openxlsx2::wb_add_worksheet(wb, "Topline")

  # Render loop
  groups_done <- character(0)
  current_row <- 1L

  for (var in vars_resolved) {
    row_info <- classify_out[classify_out$variable == var, ]
    vtype    <- row_info$type
    group_id <- row_info$group

    # Skip if this group was already rendered (sata/battery only)
    if (vtype != "single" && as.character(group_id) %in% groups_done) next

    if (vtype == "single") {
      var_frame <- freq_result$frame[freq_result$frame$variable == var, ]
      result    <- .render_topline_single(
        wb, "Topline", var_frame, current_row,
        show_n, show_eff_n, decimals, freq_result$suppressed
      )
    } else if (vtype == "sata") {
      group_vars <- classify_out$variable[classify_out$group == group_id]
      var_frame  <- freq_result$frame[freq_result$frame$variable %in% group_vars, ]
      result     <- .render_topline_sata(
        wb, "Topline", var_frame, current_row,
        show_n, show_eff_n, decimals, freq_result$suppressed
      )
      groups_done <- c(groups_done, as.character(group_id))
    } else {
      # battery
      group_vars <- classify_out$variable[classify_out$group == group_id]
      var_frame  <- freq_result$frame[freq_result$frame$variable %in% group_vars, ]
      result     <- .render_topline_battery(
        wb, "Topline", var_frame, current_row,
        show_n, show_eff_n, decimals, freq_result$suppressed
      )
      groups_done <- c(groups_done, as.character(group_id))
    }

    wb          <- result$wb
    current_row <- result$next_row + 1L
  }

  openxlsx2::wb_save(wb, file_name)
  invisible(file_name)
}

# -- Render helpers ---------------------------------------------------------------

#' @keywords internal
#' @noRd
.render_topline_single <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed
) {
  if (nrow(frame) == 0L) return(list(wb = wb, next_row = start_row))

  question_text <- frame$question_text[[1L]]

  # Detect collection mode (wave columns present)
  has_waves <- any(frame$subgroup_type == "wave")

  # Ordered subgroup labels
  all_labels    <- unique(frame$subgroup_label)
  non_total     <- all_labels[all_labels != "Total"]
  sub_labels    <- c("Total", non_total)

  # Response values (from total rows, in order)
  total_rows <- frame[frame$subgroup_type == "total", ]
  values     <- unique(total_rows$value)

  # Column count
  if (has_waves) {
    n_cols <- 1L + length(sub_labels)
  } else {
    n_cols <- 1L + 1L + as.integer(show_n)
  }

  # Row 1: question text (merged, bold)
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

  # Row 2: column headers
  header_row <- start_row + 1L
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = "Response",
    start_row = header_row, start_col = 1L
  )

  if (has_waves) {
    for (i in seq_along(sub_labels)) {
      label    <- sub_labels[[i]]
      data_col <- 1L + i

      if (label == "Total") {
        header_txt <- if (show_eff_n && "eff_n" %in% names(frame)) {
          eff_val <- frame$eff_n[frame$subgroup_type == "total"][[1L]]
          if (!is.na(eff_val)) {
            paste0("Total\n(Eff N=", formatC(round(eff_val), format = "d", big.mark = ","), ")")
          } else "Total"
        } else "Total"
      } else {
        wave_n <- sum(frame$n[frame$subgroup_label == label], na.rm = TRUE)
        header_txt <- paste0(label, "\n(n=", formatC(wave_n, format = "d", big.mark = ","), ")")
      }

      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = header_txt,
        start_row = header_row, start_col = data_col
      )
    }
  } else {
    pct_header <- if (show_eff_n && "eff_n" %in% names(frame)) {
      eff_val <- frame$eff_n[frame$subgroup_type == "total"][[1L]]
      if (!is.na(eff_val)) {
        paste0("%\n(Eff N=", formatC(round(eff_val), format = "d", big.mark = ","), ")")
      } else "%" # nocov
    } else "%"

    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = pct_header,
      start_row = header_row, start_col = 2L
    )
    if (show_n) {
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = "N",
        start_row = header_row, start_col = 3L
      )
    }
  }

  # Data rows
  data_start <- header_row + 1L

  for (j in seq_along(values)) {
    val     <- values[[j]]
    row_num <- data_start + j - 1L

    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = val,
      start_row = row_num, start_col = 1L
    )

    if (has_waves) {
      for (i in seq_along(sub_labels)) {
        label    <- sub_labels[[i]]
        data_col <- 1L + i
        if (label == "Total") {
          pct_row <- total_rows[total_rows$value == val, ]
        } else {
          pct_row <- frame[frame$subgroup_label == label & frame$value == val, ]
        }
        pct_val <- if (nrow(pct_row) > 0L) {
          round(pct_row$pct[[1L]] * 100, decimals)
        } else NA_real_
        wb <- openxlsx2::wb_add_data(
          wb, sheet = sheet, x = pct_val,
          start_row = row_num, start_col = data_col
        )
      }
    } else {
      pct_row <- total_rows[total_rows$value == val, ]
      pct_val <- if (nrow(pct_row) > 0L) {
        round(pct_row$pct[[1L]] * 100, decimals)
      } else NA_real_
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = pct_val,
        start_row = row_num, start_col = 2L
      )
      if (show_n) {
        n_val <- if (nrow(pct_row) > 0L) pct_row$n[[1L]] else NA_integer_
        wb <- openxlsx2::wb_add_data(
          wb, sheet = sheet, x = n_val,
          start_row = row_num, start_col = 3L
        )
      }
    }
  }

  # Total row
  total_row_num <- data_start + length(values)
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = "Total",
    start_row = total_row_num, start_col = 1L
  )
  if (has_waves) {
    for (i in seq_along(sub_labels)) {
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = "100%",
        start_row = total_row_num, start_col = 1L + i
      )
    }
  } else {
    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = "100%",
      start_row = total_row_num, start_col = 2L
    )
    if (show_n) {
      total_n <- sum(total_rows$n[!duplicated(total_rows$value)], na.rm = TRUE)
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = total_n,
        start_row = total_row_num, start_col = 3L
      )
    }
  }

  # Suppression footnote (unreachable from export_topline(); used by export_crosstab())
  next_row <- total_row_num + 1L
  # nocov start
  if (nrow(suppressed) > 0L) {
    wb       <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
    next_row <- next_row + nrow(suppressed)
  }
  # nocov end

  list(wb = wb, next_row = next_row)
}

#' @keywords internal
#' @noRd
.render_topline_sata <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed
) {
  if (nrow(frame) == 0L) return(list(wb = wb, next_row = start_row))

  question_text <- frame$question_text[[1L]]
  sata_vars     <- unique(frame$variable)

  n_cols <- 1L + 1L + as.integer(show_n)

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

  # Row 2: column headers
  header_row <- start_row + 1L
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = "Item",
    start_row = header_row, start_col = 1L
  )
  wb <- openxlsx2::wb_add_data(
    wb, sheet = sheet, x = "%",
    start_row = header_row, start_col = 2L
  )
  if (show_n) {
    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = "N",
      start_row = header_row, start_col = 3L
    )
  }

  # Data rows: one row per SATA item, pct for value == "1"
  data_start <- header_row + 1L
  for (j in seq_along(sata_vars)) {
    var     <- sata_vars[[j]]
    row_num <- data_start + j - 1L

    item_label <- frame$var_label[frame$variable == var][[1L]]
    item_rows  <- frame[
      frame$variable == var &
        frame$subgroup_type == "total" &
        frame$value == "1",
    ]

    pct_val <- if (nrow(item_rows) > 0L) {
      round(item_rows$pct[[1L]] * 100, decimals)
    } else NA_real_

    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = item_label,
      start_row = row_num, start_col = 1L
    )
    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = pct_val,
      start_row = row_num, start_col = 2L
    )
    if (show_n) {
      n_val <- if (nrow(item_rows) > 0L) item_rows$n[[1L]] else NA_integer_
      wb <- openxlsx2::wb_add_data(
        wb, sheet = sheet, x = n_val,
        start_row = row_num, start_col = 3L
      )
    }
  }

  next_row <- data_start + length(sata_vars)
  # nocov start
  if (nrow(suppressed) > 0L) {
    wb       <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
    next_row <- next_row + nrow(suppressed)
  }
  # nocov end

  list(wb = wb, next_row = next_row)
}

#' @keywords internal
#' @noRd
.render_topline_battery <- function(
  wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed
) {
  if (nrow(frame) == 0L) return(list(wb = wb, next_row = start_row))

  question_text <- frame$question_text[[1L]]
  bat_vars      <- unique(frame$variable)

  # Row 1: battery preface (merged, bold)
  n_cols <- 1L + 1L + as.integer(show_n)
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

  current_row <- start_row + 1L

  for (var in bat_vars) {
    var_frame <- frame[frame$variable == var, ]

    # Use var_label as the question_text for each sub-item
    var_label_val              <- var_frame$var_label[[1L]]
    var_frame$question_text    <- var_label_val

    result <- .render_topline_single(
      wb, sheet, var_frame, current_row,
      show_n, show_eff_n, decimals,
      suppressed[integer(0), ]  # no per-item footnote
    )
    wb          <- result$wb
    current_row <- result$next_row + 1L
  }

  next_row <- current_row
  # nocov start
  if (nrow(suppressed) > 0L) {
    wb       <- .write_suppression_footnote(wb, sheet, suppressed, next_row)
    next_row <- next_row + nrow(suppressed)
  }
  # nocov end

  list(wb = wb, next_row = next_row)
}
