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
#' @param min_eff_n Numeric scalar, at or above `0`. `100` is the default.
#'   A subgroup whose effective sample size is below `min_eff_n` is not
#'   shown: its column is left out of every table. A subgroup is a banner
#'   level or a crossed cell of `interactions`. A subgroup whose effective
#'   sample size equals `min_eff_n` is shown. The test reads the effective
#'   sample size, not the unweighted count. `0` shows every subgroup.
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
#' @param show_total Logical. Whether to render a `Total` column (the
#'   full-sample distribution) before the banner columns in every table.
#'   Default `TRUE`.
#' @param withheld_note One of `"once"` (default), `"every"`, or `"none"`.
#'   Where the list of withheld subgroups is written. `"once"` writes it on
#'   the `"About"` sheet. `"every"` writes it under each table. `"none"`
#'   writes it nowhere. The argument does not change which subgroups are
#'   withheld, and the console warning is raised at every value.
#' @param base_notes Optional named character vector mapping variable names
#'   to base descriptions (e.g.
#'   `c(q5 = "Base: adults who donated (n=425)")`). When a rendered table's
#'   first variable has an entry, its text is written as an italic row
#'   directly under the question title. For sata/battery groups the lookup
#'   key is the group's first member. Default `NULL` (no base rows).
#'
#' @returns `invisible(file_name)` -- the path supplied in `file_name`.
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
  layout = c("per_question", "stacked"),
  interactions = NULL,
  min_eff_n = 100,
  variance = NULL,
  conf_level = 0.95,
  show_n = TRUE,
  show_eff_n = FALSE,
  decimals = 1L,
  show_total = TRUE,
  withheld_note = c("once", "every", "none"),
  base_notes = NULL
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

  # Check surveycore is installed
  rlang::check_installed("surveycore")

  # 2. Inline design-type check
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

  # 3. NSE resolution for vars only
  vars_resolved <- names(tidyselect::eval_select(
    rlang::enquo(vars),
    design@data
  ))

  # 4. Shared input validation (errors 3-8)
  .validate_export_inputs(
    design,
    vars_resolved,
    file_name,
    conf_level,
    decimals
  )

  # 5. Banner NSE resolution (AFTER validate, so banner_not_found is error #9)
  banner_quo <- rlang::enquo(banner)
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
    .validate_interactions_in_banner(interactions, banner_resolved)
  }

  # 7. base_notes validation, on the caller's vector alone, then the merge
  # with the design's universe. surveycore metadata is not the caller's error
  # to fix, so it is never validated here (spec 3.6).
  .validate_base_notes(base_notes)
  resolved_notes <- .resolve_base_notes(design, base_notes)

  # 8. min_eff_n validation, before the role guard, so an invalid floor
  # aborts before any workbook is built (spec 3.11, spec 3.17).
  .validate_min_eff_n(min_eff_n)

  # 9. The design-variable check, on `vars` and then on `banner`, so a call
  # naming a design column in both reports `vars`. It runs before the role
  # guard, so a design column that also carries role = "weight" errors and
  # is not dropped with a warning (spec 3.11, spec 3.17).
  .reject_design_vars(design, vars_resolved, "vars")
  .reject_design_vars(design, banner_resolved, "banner")

  # 10. The role guard, on `vars` and then on `banner`. A dropped column never
  # reaches classification, so it forms no question group of its own
  # (spec 3.10).
  vars_resolved <- .apply_role_guard(
    design,
    vars_resolved,
    "vars",
    "surveyreports_error_vars_all_dropped"
  )
  banner_resolved <- .apply_role_guard(
    design,
    banner_resolved,
    "banner",
    "surveyreports_error_banner_empty_selection"
  )

  # 11. `interactions` again, against the surviving banner: an element that
  # names a dropped banner column passed step 7 and fails here (spec 3.10).
  .validate_interactions_in_banner(interactions, banner_resolved)

  # 12. The banner label checks, on the banner columns the role guard kept and
  # before any estimate runs (spec 3.7).
  .validate_banner_labels(design, banner_resolved)

  layout <- match.arg(layout)
  withheld_note <- match.arg(withheld_note)

  # The heading of each surviving banner column: its variable label, or its
  # name when no label is set (spec 3.8). A column that falls back is named
  # in the missing-label warning after estimation.
  heading_info <- lapply(banner_resolved, function(col) {
    .banner_heading(design, col)
  })
  banner_headings <- stats::setNames(
    vapply(heading_info, function(h) h$heading, character(1L)),
    banner_resolved
  )
  banner_fell_back <- banner_resolved[
    vapply(heading_info, function(h) h$fell_back, logical(1L))
  ]

  # 13. all_of() passes the resolved names as a selection, so tidyselect
  # raises no external-vector deprecation warning (spec 2.1).
  classify_out <- surveycore::classify_question_type(
    design,
    tidyselect::all_of(vars_resolved)
  )

  # 14. Estimation. The missing-label warning is raised here, after the frame
  # is built and before the all-NA drop: one warning for the `vars` columns,
  # read from the frame, and the banner columns together (spec 3.11,
  # spec 3.18).
  freq_result <- .build_freq_frame(
    design,
    vars_resolved,
    classify_out,
    banner_resolved = banner_resolved,
    interactions = interactions,
    variance = variance,
    conf_level = conf_level,
    show_eff_n = show_eff_n,
    min_eff_n = min_eff_n,
    emit_label_warning = FALSE
  )
  .warn_missing_label(
    .missing_label_vars(freq_result$frame),
    banner_fell_back
  )

  # 15. The all-NA drop. A variable with no non-missing value leaves `vars`
  # and `classify_out` before the workbook build, so no block, sheet or
  # cursor move is written for it (spec 3.11).
  kept <- .apply_all_na_drop(freq_result$frame, vars_resolved, classify_out)
  vars_resolved <- kept$vars
  classify_out <- kept$classify_out

  # 16. The withholding warnings, from the withheld frame that estimation
  # returned. They come after the all-NA drop, so a call whose every variable
  # is all-NA aborts at step 15 and raises none of them (spec 3.11).
  # The full-sample test reuses .build_withheld(), the one owner of the floor
  # comparison, on the full sample's own counts. It does not read the
  # subgroup frame, and it removes nothing (spec 3.5).
  full_sample <- .build_withheld(.resolve_eff_n(design), min_eff_n, "")
  .emit_withholding_warnings(
    freq_result$withheld,
    freq_result$emptied_groups,
    full_sample,
    min_eff_n
  )

  # 17. The workbook build. The "About" cover sheet comes first. The caller
  # owns the withheld_note decision: the withheld frame reaches the cover
  # sheet only at "once", and NULL tells it to write no withheld block
  # (spec 3.14). min_eff_n and has_banner decide the glossary entry
  # `Why a column is missing` (spec 3.15).
  wb <- .build_workbook(
    design,
    withheld = if (withheld_note == "once") freq_result$withheld else NULL,
    min_eff_n = min_eff_n,
    has_banner = TRUE,
    string_cells = FALSE,
    decimals = decimals,
    variance = variance
  )

  # The lines written at the end of each block, at "every" only (spec 3.16).
  withheld_lines <- if (withheld_note == "every") {
    .format_withheld_lines(freq_result$withheld, min_eff_n)
  } else {
    character(0)
  }

  if (layout == "per_question") {
    groups_done <- character(0)
    for (var in vars_resolved) {
      row_info <- classify_out[classify_out$variable == var, ]
      vtype <- row_info$type
      group_id <- row_info$group

      if (vtype != "single" && as.character(group_id) %in% groups_done) {
        next
      }

      # Each per-question sheet name goes through .unique_sheet_name() and is
      # assigned back before the sheet is added and rendered into, so a
      # variable named "About" cannot overwrite the cover sheet (spec 3.14).
      if (vtype == "single") {
        sheet_name <- .unique_sheet_name(wb, var)
        var_frame <- freq_result$frame[freq_result$frame$variable == var, ]
        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
        result <- .render_crosstab_single(
          wb,
          sheet_name,
          var_frame,
          1L,
          show_n,
          show_eff_n,
          decimals,
          withheld_lines,
          banner_resolved,
          interactions,
          banner_headings,
          show_total,
          resolved_notes
        )
      } else if (vtype == "sata") {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        sheet_name <- .unique_sheet_name(wb, group_vars[[1L]])
        var_frame <- freq_result$frame[
          freq_result$frame$variable %in% group_vars,
        ]
        groups_done <- c(groups_done, as.character(group_id))
        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
        result <- .render_crosstab_sata(
          wb,
          sheet_name,
          var_frame,
          1L,
          show_n,
          show_eff_n,
          decimals,
          withheld_lines,
          banner_resolved,
          interactions,
          banner_headings,
          show_total,
          resolved_notes
        )
      } else {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        sheet_name <- .unique_sheet_name(wb, group_vars[[1L]])
        var_frame <- freq_result$frame[
          freq_result$frame$variable %in% group_vars,
        ]
        groups_done <- c(groups_done, as.character(group_id))
        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
        result <- .render_crosstab_battery(
          wb,
          sheet_name,
          var_frame,
          1L,
          show_n,
          show_eff_n,
          decimals,
          withheld_lines,
          banner_resolved,
          interactions,
          banner_headings,
          show_total,
          resolved_notes
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
      vtype <- row_info$type
      group_id <- row_info$group

      if (vtype != "single" && as.character(group_id) %in% groups_done) {
        next
      }

      if (vtype == "single") {
        var_frame <- freq_result$frame[freq_result$frame$variable == var, ]
        result <- .render_crosstab_single(
          wb,
          "Crosstab",
          var_frame,
          current_row,
          show_n,
          show_eff_n,
          decimals,
          withheld_lines,
          banner_resolved,
          interactions,
          banner_headings,
          show_total,
          resolved_notes
        )
      } else if (vtype == "sata") {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        var_frame <- freq_result$frame[
          freq_result$frame$variable %in% group_vars,
        ]
        groups_done <- c(groups_done, as.character(group_id))
        result <- .render_crosstab_sata(
          wb,
          "Crosstab",
          var_frame,
          current_row,
          show_n,
          show_eff_n,
          decimals,
          withheld_lines,
          banner_resolved,
          interactions,
          banner_headings,
          show_total,
          resolved_notes
        )
      } else {
        group_vars <- classify_out$variable[classify_out$group == group_id]
        var_frame <- freq_result$frame[
          freq_result$frame$variable %in% group_vars,
        ]
        groups_done <- c(groups_done, as.character(group_id))
        result <- .render_crosstab_battery(
          wb,
          "Crosstab",
          var_frame,
          current_row,
          show_n,
          show_eff_n,
          decimals,
          withheld_lines,
          banner_resolved,
          interactions,
          banner_headings,
          show_total,
          resolved_notes
        )
      }

      wb <- result$wb
      current_row <- result$next_row + 1L
    }
  }

  openxlsx2::wb_save(wb, file_name)
  invisible(file_name)
}

# -- Withholding warnings ------------------------------------------------------

# The withholding warnings of step 16 of spec 3.11, in the order of that
# section. export_crosstab() calls it after the all-NA drop and before the
# workbook build.
# - surveyreports_warning_subgroup_withheld: once per call when the withheld
#   frame has rows. Its bullets are the lines of .format_withheld_lines(), so
#   the console, the About sheet and the block footer use one wording
#   (spec 3.14).
# - surveyreports_warning_banner_all_withheld: when `emptied_groups` names a
#   banner column or an interaction whose every level is withheld.
# - surveyreports_warning_full_sample_below_min: when `full_sample`, the
#   .build_withheld() frame of the full sample's own counts, has a row.
#   Nothing is removed for it (spec 3.5).
# Each bullet is interpolated from the vector and not parsed as cli markup, so
# a level label holding a brace prints as written.
#' @keywords internal
#' @noRd
.emit_withholding_warnings <- function(
  withheld,
  emptied_groups,
  full_sample,
  min_eff_n
) {
  lines <- .format_withheld_lines(withheld, min_eff_n)
  n_lines <- length(lines)
  if (n_lines > 0L) {
    bullets <- stats::setNames(
      paste0("{lines[[", seq_len(n_lines), "]]}"),
      rep("*", n_lines)
    )
    cli::cli_warn(
      c(
        "!" = paste0(
          "{n_lines} subgroup{?s} {?is/are} below {.arg min_eff_n} and ",
          "{?is/are} withheld."
        ),
        bullets,
        "i" = "Each withheld subgroup has no column in any table."
      ),
      class = "surveyreports_warning_subgroup_withheld"
    )
  }

  n_groups <- length(emptied_groups)
  if (n_groups > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Every subgroup of {n_groups} column group{?s} is below ",
          "{.arg min_eff_n}: {.field {emptied_groups}}."
        ),
        "i" = paste0(
          "{cli::qty(n_groups)}The tables are written without ",
          "{?that column group/those column groups}."
        )
      ),
      class = "surveyreports_warning_banner_all_withheld"
    )
  }

  if (nrow(full_sample) > 0L) {
    full_eff_n <- formatC(full_sample$n_eff[[1L]], format = "f", digits = 1L)
    floor_text <- format(min_eff_n, scientific = FALSE, trim = TRUE)
    cli::cli_warn(
      c(
        "!" = paste0(
          "The effective sample size of the full sample, {full_eff_n}, is ",
          "below {.arg min_eff_n} ({floor_text})."
        ),
        "i" = "The full sample is not a subgroup, so its column is still written."
      ),
      class = "surveyreports_warning_full_sample_below_min"
    )
  }
  invisible(TRUE)
}

# -- min_eff_n -----------------------------------------------------------------

# `min_eff_n` is one finite number at or above 0 (spec 3.17). export_crosstab()
# calls it at step 8 of spec 3.11, after the base_notes check and before the
# design-variable check. Each test closes one silent failure: a negative floor
# withholds nothing, NA makes every comparison NA, Inf withholds every
# subgroup, a length-2 vector recycles, and "100" compares as a string. The
# error is raised in the caller's frame, so its message names
# export_crosstab().
#' @keywords internal
#' @noRd
.validate_min_eff_n <- function(min_eff_n, call = rlang::caller_env()) {
  valid <- is.numeric(min_eff_n) &&
    length(min_eff_n) == 1L &&
    is.finite(min_eff_n) &&
    min_eff_n >= 0
  if (!valid) {
    cli::cli_abort(
      c(
        "x" = "{.arg min_eff_n} must be a single finite number at or above 0.",
        "i" = "Got {.val {min_eff_n}}.",
        "v" = "Use a single number at or above 0, such as the default 100."
      ),
      class = "surveyreports_error_invalid_min_eff_n",
      call = call
    )
  }
  invisible(TRUE)
}

# -- Interactions --------------------------------------------------------------

# Every variable of every `interactions` element must be in the banner.
#
# export_crosstab() calls it twice: at step 7 of spec 3.11, against the
# resolved banner, and at step 11, against the banner that survives the role
# guard (spec 3.10). A NULL `interactions` passes. The error is raised in the
# caller's frame, so its message names export_crosstab().
#' @keywords internal
#' @noRd
.validate_interactions_in_banner <- function(
  interactions,
  banner_resolved,
  call = rlang::caller_env()
) {
  for (elem in interactions) {
    not_in_banner <- elem[!elem %in% banner_resolved]
    if (length(not_in_banner) > 0L) {
      n_not_in <- length(not_in_banner)
      cli::cli_abort(
        c(
          "x" = paste0(
            "{cli::qty(n_not_in)}Interaction variable{?s} ",
            "{.field {not_in_banner}} not found in {.arg banner}."
          ),
          "i" = paste0(
            "All variables in each interactions element must also appear ",
            "in {.arg banner}."
          ),
          "v" = paste0(
            "{cli::qty(n_not_in)}Add the missing variable{?s} to ",
            "{.arg banner}, or remove them from {.arg interactions}."
          )
        ),
        class = "surveyreports_error_interaction_not_in_banner",
        call = call
      )
    }
  }
  invisible(TRUE)
}

# -- Banner labels -------------------------------------------------------------

# The banner label checks of spec 3.7. export_crosstab() calls it at step 12
# of spec 3.11, on the banner columns that survive the role guard, so no
# check runs on a column that is about to be dropped. Two conditions abort:
# - one value label on 2 or more codes. get_freqs() would otherwise abort
#   with the base R message "factor level is duplicated".
# - 2 or more observed codes with no value label. Each one keys as a missing
#   value, so two subgroups would share one heading.
# A column with no value labels passes, and so does a column with exactly
# one unlabelled observed code: that code is a real subgroup whose level is
# NA. An unlabelled code held by no row does not count. "Observed" reads
# every row of @data. The error is raised in the caller's frame, so its
# message names export_crosstab().
#' @keywords internal
#' @noRd
.validate_banner_labels <- function(design, cols, call = rlang::caller_env()) {
  for (col in cols) {
    labels <- surveycore::extract_val_labels(
      design,
      tidyselect::all_of(col)
    )[[col]]
    if (is.null(labels)) {
      next
    }

    repeated <- unique(names(labels)[duplicated(names(labels))])
    if (length(repeated) > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Banner column {.field {col}} uses one value label for 2 or ",
            "more codes."
          ),
          "i" = "Repeated label{?s}: {.val {repeated}}.",
          "v" = paste0(
            "Use {.fn surveycore::set_val_labels} to give each code its ",
            "own label."
          )
        ),
        class = "surveyreports_error_duplicate_value_label",
        call = call
      )
    }

    observed <- unique(stats::na.omit(as.vector(design@data[[col]])))
    unlabelled <- sort(setdiff(observed, unname(labels)))
    if (length(unlabelled) >= 2L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Banner column {.field {col}} has {length(unlabelled)} observed ",
            "codes with no value label."
          ),
          "i" = "Codes with no label: {.val {unlabelled}}.",
          "v" = paste0(
            "Use {.fn surveycore::set_val_labels} to label these codes, so ",
            "at most one is left without a label."
          )
        ),
        class = "surveyreports_error_multiple_unlabelled_codes",
        call = call
      )
    }
  }
  invisible(TRUE)
}

# -- Sheet names -------------------------------------------------------------------

# A sheet name that does not collide with one already in `wb` (spec 2.2,
# spec 3.14). The comparison folds case, because Excel and openxlsx2 treat
# sheet names case-insensitively. The name is truncated to 31 characters
# first; when it is taken, the suffix _2, _3, ... is added until it is free.
# The spec says "truncate, then suffix" but does not say how long the result
# may be. This reads it as: the result is never longer than 31 characters,
# because Excel and openxlsx2 reject a longer name, and the spec names two
# variables whose names share their first 31 characters as a case this helper
# closes. So a suffixed name shortens its base until base + suffix fits.
#' @keywords internal
#' @noRd
.unique_sheet_name <- function(wb, name) {
  max_chars <- 31L
  taken <- tolower(openxlsx2::wb_get_sheet_names(wb))
  candidate <- substr(name, 1L, max_chars)
  k <- 1L
  while (tolower(candidate) %in% taken) {
    k <- k + 1L
    suffix <- paste0("_", k)
    candidate <- paste0(
      substr(name, 1L, max_chars - nchar(suffix)),
      suffix
    )
  }
  candidate
}

# -- Shared column-group helpers --------------------------------------------------

# The column groups of one block. A group's `subgroup_var` is the key into
# the frame, built from column names. Its `spanner` is the display text, built
# from banner_headings, a character vector of headings named by banner column
# (spec 3.8): `Gender`, and `Gender x Region` for an interaction.
#' @keywords internal
#' @noRd
.build_col_groups <- function(
  frame,
  banner_resolved,
  interactions,
  banner_headings
) {
  col_groups <- list()

  for (bv in banner_resolved) {
    bv_rows <- frame[
      frame$subgroup_type == "banner" & frame$subgroup_var == bv,
    ]
    levels_present <- unique(bv_rows$subgroup_value)
    if (length(levels_present) == 0L) {
      next
    }
    col_groups[[length(col_groups) + 1L]] <- list(
      spanner = banner_headings[[bv]],
      levels = levels_present,
      type = "banner",
      subgroup_var = bv
    )
  }

  if (!is.null(interactions)) {
    for (int_vars in interactions) {
      int_label <- .interaction_label(int_vars)
      int_rows <- frame[
        frame$subgroup_type == "interaction" &
          frame$subgroup_var == int_label,
      ]
      levels_present <- unique(int_rows$subgroup_value)
      if (length(levels_present) == 0L) {
        next
      } # nocov
      col_groups[[length(col_groups) + 1L]] <- list(
        spanner = paste(
          unname(banner_headings[int_vars]),
          collapse = " \u00d7 "
        ),
        levels = levels_present,
        type = "interaction",
        subgroup_var = int_label
      )
    }
  }

  col_groups
}

#' @keywords internal
#' @noRd
.count_render_cols <- function(col_groups) {
  1L + sum(vapply(col_groups, function(cg) length(cg$levels), integer(1L)))
}

#' @keywords internal
#' @noRd
.write_question_title <- function(wb, sheet, question_text, start_row, n_cols) {
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = question_text,
    start_row = start_row,
    start_col = 1L
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(
      wb,
      sheet = sheet,
      dims = openxlsx2::wb_dims(rows = start_row, cols = 1L:n_cols)
    )
  }
  wb <- openxlsx2::wb_add_font(
    wb,
    sheet = sheet,
    dims = openxlsx2::wb_dims(rows = start_row, cols = 1L),
    bold = TRUE
  )
  wb
}

#' @keywords internal
#' @noRd
.write_crosstab_headers <- function(
  wb,
  sheet,
  spanner_row,
  header_row,
  col_groups,
  label_col1
) {
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = label_col1,
    start_row = header_row,
    start_col = 1L
  )

  current_col <- 2L
  for (cg in col_groups) {
    span_start <- current_col
    span_end <- span_start + length(cg$levels) - 1L

    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = cg$spanner,
      start_row = spanner_row,
      start_col = span_start
    )
    if (span_end > span_start) {
      wb <- openxlsx2::wb_merge_cells(
        wb,
        sheet = sheet,
        dims = openxlsx2::wb_dims(
          rows = spanner_row,
          cols = span_start:span_end
        )
      )
    }

    for (k in seq_along(cg$levels)) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = cg$levels[[k]],
        start_row = header_row,
        start_col = current_col
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
  wb,
  sheet,
  frame,
  start_row,
  show_n,
  show_eff_n,
  decimals,
  withheld_lines,
  banner_resolved,
  interactions,
  banner_headings,
  show_total = TRUE,
  base_notes = NULL
) {
  question_text <- frame$question_text[[1L]]

  # Get value order from total rows
  total_rows <- frame[frame$subgroup_type == "total", ]
  values <- unique(total_rows$value)

  col_groups <- .build_col_groups(
    frame,
    banner_resolved,
    interactions,
    banner_headings
  )
  if (show_total) {
    col_groups <- c(list(.total_col_group()), col_groups)
  }

  # n_cols includes an extra column when show_n = TRUE
  n_pct_cols <- .count_render_cols(col_groups)
  n_cols <- n_pct_cols + if (show_n) 1L else 0L

  # Row 1: question text merged across all columns (bold)
  wb <- .write_question_title(wb, sheet, question_text, start_row, n_cols)

  # Optional italic base-note row directly under the title
  base_note <- .base_note_for(frame, base_notes)
  note_shift <- if (is.null(base_note)) 0L else 1L
  if (note_shift == 1L) {
    wb <- .write_base_note(wb, sheet, base_note, start_row + 1L, n_cols)
  }

  spanner_row <- start_row + note_shift + 1L
  header_row <- start_row + note_shift + 2L

  # Spanner row + column headers
  wb <- .write_crosstab_headers(
    wb,
    sheet,
    spanner_row,
    header_row,
    col_groups,
    "Response"
  )

  # Write "N" column header when show_n = TRUE
  n_col <- n_pct_cols + 1L
  if (show_n) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = "N",
      start_row = header_row,
      start_col = n_col
    )
  }

  # Data rows: one per response value
  data_start <- header_row + 1L
  for (j in seq_along(values)) {
    val <- values[[j]]
    row_num <- data_start + j - 1L

    # Row label
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = val,
      start_row = row_num,
      start_col = 1L
    )

    current_col <- 2L
    for (cg in col_groups) {
      for (level in cg$levels) {
        pct_rows <- .cell_rows(frame, cg, level, val = val)
        pct_val <- if (nrow(pct_rows) > 0L) {
          round(pct_rows$pct[[1L]] * 100, decimals)
        } else {
          NA_real_
        }
        wb <- openxlsx2::wb_add_data(
          wb,
          sheet = sheet,
          x = pct_val,
          start_row = row_num,
          start_col = current_col
        )
        current_col <- current_col + 1L
      }
    }

    # Write total n for this row when show_n = TRUE
    if (show_n) {
      n_val <- if (nrow(total_rows[total_rows$value == val, ]) > 0L) {
        total_rows$n[total_rows$value == val][[1L]]
      } else {
        NA_integer_
      }
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = n_val,
        start_row = row_num,
        start_col = n_col
      )
    }
  }

  # Total row
  total_row_num <- data_start + length(values)
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = "Total",
    start_row = total_row_num,
    start_col = 1L
  )
  current_col <- 2L
  for (cg in col_groups) {
    for (level in cg$levels) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = "100%",
        start_row = total_row_num,
        start_col = current_col
      )
      current_col <- current_col + 1L
    }
  }

  .write_withheld_lines(wb, sheet, withheld_lines, total_row_num + 1L)
}

#' @keywords internal
#' @noRd
.render_crosstab_sata <- function(
  wb,
  sheet,
  frame,
  start_row,
  show_n,
  show_eff_n,
  decimals,
  withheld_lines,
  banner_resolved,
  interactions,
  banner_headings,
  show_total = TRUE,
  base_notes = NULL
) {
  question_text <- .group_header_text(frame)
  sata_vars <- unique(frame$variable)

  col_groups <- .build_col_groups(
    frame,
    banner_resolved,
    interactions,
    banner_headings
  )
  if (show_total) {
    col_groups <- c(list(.total_col_group()), col_groups)
  }

  n_pct_cols <- .count_render_cols(col_groups)
  n_cols <- n_pct_cols + if (show_n) 1L else 0L

  # Row 1: question preface (merged, bold)
  wb <- .write_question_title(wb, sheet, question_text, start_row, n_cols)

  # Optional italic base-note row directly under the title
  base_note <- .base_note_for(frame, base_notes)
  note_shift <- if (is.null(base_note)) 0L else 1L
  if (note_shift == 1L) {
    wb <- .write_base_note(wb, sheet, base_note, start_row + 1L, n_cols)
  }

  spanner_row <- start_row + note_shift + 1L
  header_row <- start_row + note_shift + 2L

  # Spanner row + column headers — "Item" in col 1
  wb <- .write_crosstab_headers(
    wb,
    sheet,
    spanner_row,
    header_row,
    col_groups,
    "Item"
  )

  # Write "N" column header when show_n = TRUE
  n_col <- n_pct_cols + 1L
  if (show_n) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = "N",
      start_row = header_row,
      start_col = n_col
    )
  }

  # Data rows: one row per SATA item; pct where value == "1", with
  # true-zero handling (see .sata_pct_cell())
  data_start <- header_row + 1L
  for (j in seq_along(sata_vars)) {
    var <- sata_vars[[j]]
    row_num <- data_start + j - 1L

    item_label <- frame$var_label[frame$variable == var][[1L]]

    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = item_label,
      start_row = row_num,
      start_col = 1L
    )

    current_col <- 2L
    for (cg in col_groups) {
      for (level in cg$levels) {
        pct_val <- .sata_pct_cell(frame, var, cg, level, decimals)
        wb <- openxlsx2::wb_add_data(
          wb,
          sheet = sheet,
          x = pct_val,
          start_row = row_num,
          start_col = current_col
        )
        current_col <- current_col + 1L
      }
    }

    # Write total n for this item when show_n = TRUE
    if (show_n) {
      n_val <- .sata_n_cell(frame, var)
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = n_val,
        start_row = row_num,
        start_col = n_col
      )
    }
  }

  .write_withheld_lines(
    wb,
    sheet,
    withheld_lines,
    data_start + length(sata_vars)
  )
}

#' @keywords internal
#' @noRd
.render_crosstab_battery <- function(
  wb,
  sheet,
  frame,
  start_row,
  show_n,
  show_eff_n,
  decimals,
  withheld_lines,
  banner_resolved,
  interactions,
  banner_headings,
  show_total = TRUE,
  base_notes = NULL
) {
  question_text <- .group_header_text(frame)
  bat_vars <- unique(frame$variable)

  col_groups <- .build_col_groups(
    frame,
    banner_resolved,
    interactions,
    banner_headings
  )
  if (show_total) {
    col_groups <- c(list(.total_col_group()), col_groups)
  }

  n_pct_cols <- .count_render_cols(col_groups)
  # Item + Response label columns replace the flattened "item (value)"
  # single label column, so the battery table is one column wider than
  # .count_render_cols() (which assumes one label column) accounts for.
  n_cols <- n_pct_cols + 1L + if (show_n) 1L else 0L

  # Row 1: battery preface (merged, bold)
  wb <- .write_question_title(wb, sheet, question_text, start_row, n_cols)

  # Optional italic base-note row directly under the title
  base_note <- .base_note_for(frame, base_notes)
  note_shift <- if (is.null(base_note)) 0L else 1L
  if (note_shift == 1L) {
    wb <- .write_base_note(wb, sheet, base_note, start_row + 1L, n_cols)
  }

  spanner_row <- start_row + note_shift + 1L
  header_row <- start_row + note_shift + 2L

  # Two label columns; banner spanners start at column 3
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = "Item",
    start_row = header_row,
    start_col = 1L
  )
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = "Response",
    start_row = header_row,
    start_col = 2L
  )

  current_col <- 3L
  for (cg in col_groups) {
    span_start <- current_col
    span_end <- span_start + length(cg$levels) - 1L
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = cg$spanner,
      start_row = spanner_row,
      start_col = span_start
    )
    if (span_end > span_start) {
      wb <- openxlsx2::wb_merge_cells(
        wb,
        sheet = sheet,
        dims = openxlsx2::wb_dims(
          rows = spanner_row,
          cols = span_start:span_end
        )
      )
    }
    for (k in seq_along(cg$levels)) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = cg$levels[[k]],
        start_row = header_row,
        start_col = current_col
      )
      current_col <- current_col + 1L
    }
  }

  n_col <- current_col
  if (show_n) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = "N",
      start_row = header_row,
      start_col = n_col
    )
  }

  # Data rows: one row per battery sub-item × scale value
  current_row <- header_row + 1L
  for (var in bat_vars) {
    var_frame <- frame[frame$variable == var, ]
    item_label <- var_frame$var_label[[1L]]

    # Scale values from total rows for this sub-item
    total_sub <- var_frame[var_frame$subgroup_type == "total", ]
    values <- unique(total_sub$value)

    # Item label once, on its first value row
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = item_label,
      start_row = current_row,
      start_col = 1L
    )

    for (val in values) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = val,
        start_row = current_row,
        start_col = 2L
      )

      current_col <- 3L
      for (cg in col_groups) {
        for (level in cg$levels) {
          pct_rows <- .cell_rows(frame, cg, level, val = val, var = var)
          pct_val <- if (nrow(pct_rows) > 0L) {
            round(pct_rows$pct[[1L]] * 100, decimals)
          } else {
            NA_real_
          }
          wb <- openxlsx2::wb_add_data(
            wb,
            sheet = sheet,
            x = pct_val,
            start_row = current_row,
            start_col = current_col
          )
          current_col <- current_col + 1L
        }
      }

      # Write total n for this row when show_n = TRUE
      if (show_n) {
        n_rows <- total_sub[total_sub$value == val, ]
        n_val <- if (nrow(n_rows) > 0L) n_rows$n[[1L]] else NA_integer_
        wb <- openxlsx2::wb_add_data(
          wb,
          sheet = sheet,
          x = n_val,
          start_row = current_row,
          start_col = n_col
        )
      }

      current_row <- current_row + 1L
    }
  }

  .write_withheld_lines(wb, sheet, withheld_lines, current_row)
}

# The withheld lines at the end of one block, one per row in column A, from
# `start_row` (spec 3.16). The caller passes character(0) unless
# withheld_note is "every", and then nothing is written. Returns
# list(wb = , next_row = ).
#' @keywords internal
#' @noRd
.write_withheld_lines <- function(wb, sheet, lines, start_row) {
  for (i in seq_along(lines)) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = lines[[i]],
      start_row = start_row + i - 1L,
      start_col = 1L
    )
  }
  list(wb = wb, next_row = start_row + length(lines))
}
