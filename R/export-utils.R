# Shared utilities for export_topline() and export_crosstab()

# -- Validation ----------------------------------------------------------------

#' @keywords internal
#' @noRd
.validate_export_inputs <- function(
  design,
  vars_resolved,
  file_name,
  conf_level,
  decimals
) {
  # 1. Design type
  if (
    !(S7::S7_inherits(design, surveycore::survey_base) ||
        S7::S7_inherits(design, surveycore::survey_collection))
  ) {
    # nocov start
    # Defensive: callers perform an inline design-type check before calling this
    # helper (per spec), so this branch is unreachable via the public API.
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a survey design object.",
        "i" = "Got class {.cls {class(design)}}.",
        "v" = "Use {.fn surveycore::as_survey} to create a design object."
      ),
      class = "surveyreports_error_not_survey_object"
    )
    # nocov end
  }

  data_for_check <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1L]]@data
  } else {
    design@data
  }

  # 2. vars_resolved non-empty
  if (length(vars_resolved) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg vars} did not select any columns.",
        "i" = "The tidyselect expression resolved to an empty set.",
        "v" = "Use bare column names or a tidyselect helper that matches existing columns."
      ),
      class = "surveyreports_error_vars_empty_selection"
    )
  }

  # 3. All vars exist in data
  missing_vars <- vars_resolved[!vars_resolved %in% names(data_for_check)]
  if (length(missing_vars) > 0L) {
    n_mv <- length(missing_vars)
    cli::cli_abort(
      c(
        "x" = "{n_mv} variable{?s} not found in the design: {.field {missing_vars}}.",
        "i" = "Check for typos or use {.fn names} on the design data.",
        "v" = "Remove or rename the missing variable before calling this function."
      ),
      class = "surveyreports_error_var_not_found"
    )
  }

  # 4. Domain has at least one row
  if (nrow(data_for_check) == 0L) {
    cli::cli_abort(
      c(
        "x" = "The design contains zero rows.",
        "i" = "No data is available to compute frequencies.",
        "v" = "Supply a design with at least one observation."
      ),
      class = "surveyreports_error_empty_domain"
    )
  }

  # 5. file_name ends in .xlsx
  if (!grepl("\\.xlsx$", file_name, ignore.case = TRUE)) {
    cli::cli_abort(
      c(
        "x" = "{.arg file_name} must end in {.val .xlsx}.",
        "i" = "Got {.val {file_name}}.",
        "v" = "Change the file extension to {.val .xlsx}."
      ),
      class = "surveyreports_error_invalid_file_name"
    )
  }

  # 6. conf_level in (0, 1)
  if (
    !is.numeric(conf_level) ||
      length(conf_level) != 1L ||
      is.na(conf_level) ||
      conf_level <= 0 ||
      conf_level >= 1
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg conf_level} must be a single numeric value in (0, 1).",
        "i" = "Got {.val {conf_level}}.",
        "v" = "Use a value such as {.val 0.95} for a 95% confidence interval."
      ),
      class = "surveyreports_error_invalid_conf_level"
    )
  }

  # 7. decimals is a positive integer scalar
  if (
    !is.numeric(decimals) ||
      length(decimals) != 1L ||
      is.na(decimals) ||
      decimals < 1 ||
      decimals != as.integer(decimals)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg decimals} must be a positive integer scalar.",
        "i" = "Got {.val {decimals}}.",
        "v" = "Use a whole number such as {.val 1} or {.val 2}."
      ),
      class = "surveyreports_error_invalid_decimals"
    )
  }

  invisible(TRUE)
}

# -- Effective N ---------------------------------------------------------------

#' @keywords internal
#' @noRd
.compute_eff_n <- function(design, col = NULL, level = NULL) {
  data   <- design@data
  wt_col <- design@variables$weights
  if (is.null(wt_col) || length(wt_col) == 0L) {
    wt_col <- design@variables$phase1$weights  # nocov
  }
  if (is.null(wt_col) || length(wt_col) == 0L || !wt_col %in% names(data)) {
    return(NA_real_)  # nocov
  }

  if (!is.null(col)) {
    data <- data[data[[col]] == level, , drop = FALSE]
  }

  wi   <- data[[wt_col]]
  n    <- nrow(data)
  # nocov start
  # Defensive: levels iterated via unique(col_vals[!is.na(col_vals)]), so n == 0
  # cannot occur via the public API.
  if (n == 0L || sum(wi, na.rm = TRUE) == 0) return(NA_real_)
  # nocov end
  deff <- (n * sum(wi^2, na.rm = TRUE)) / sum(wi, na.rm = TRUE)^2
  n / deff
}

# -- Frequency computation helpers ---------------------------------------------

# Extract question_text and var_label from get_freqs meta.
.extract_var_meta <- function(m, var) {
  vm      <- m$x[[var]]
  vlabel  <- vm$variable_label
  preface <- vm$question_preface

  question_text <- if (!is.null(vlabel) && nchar(vlabel) > 0L) {
    vlabel
  } else if (!is.null(preface) && nchar(preface) > 0L) {
    preface
  } else {
    var
  }

  var_label <- if (!is.null(vlabel) && nchar(vlabel) > 0L) vlabel else var

  list(question_text = question_text, var_label = var_label)
}

#' @keywords internal
#' @noRd
.compute_total_freq <- function(design, var, ...) {
  result <- withCallingHandlers(
    surveycore::get_freqs(design, !!rlang::sym(var), ...),
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )
  lm     <- .extract_var_meta(surveycore::meta(result), var)

  # First column is the response value column (named after `var`)
  names(result)[1L] <- "value"
  result$value      <- as.character(result$value)

  result$variable      <- var
  result$question_text <- lm$question_text
  result$var_label     <- lm$var_label
  result$subgroup_type  <- "total"
  result$subgroup_var   <- NA_character_
  result$subgroup_value <- NA_character_
  result$subgroup_label <- "Total"

  result
}

#' @keywords internal
#' @noRd
.compute_subgroup_freq <- function(design, var, banner_var, ...) {
  result <- withCallingHandlers(
    surveycore::get_freqs(
      design, !!rlang::sym(var), group = !!rlang::sym(banner_var), ...
    ),
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )
  lm <- .extract_var_meta(surveycore::meta(result), var)

  # First col: banner var (-> subgroup_value); second: response (-> value)
  names(result)[1L] <- "subgroup_value"
  names(result)[2L] <- "value"
  result$subgroup_value <- as.character(result$subgroup_value)
  result$value          <- as.character(result$value)

  result$variable      <- var
  result$question_text <- lm$question_text
  result$var_label     <- lm$var_label
  result$subgroup_type  <- "banner"
  result$subgroup_var   <- banner_var
  result$subgroup_label <- banner_var

  result
}

#' @keywords internal
#' @noRd
.compute_interaction_freq <- function(design, var, banner_vars, ...) {
  interact_col <- "..interaction.."
  design@data[[interact_col]] <- do.call(
    interaction,
    c(design@data[banner_vars], list(sep = " \u00d7 "))
  )

  result <- withCallingHandlers(
    surveycore::get_freqs(
      design, !!rlang::sym(var), group = !!rlang::sym(interact_col), ...
    ),
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )
  lm <- .extract_var_meta(surveycore::meta(result), var)

  names(result)[1L] <- "subgroup_value"
  names(result)[2L] <- "value"
  result$subgroup_value <- as.character(result$subgroup_value)
  result$value          <- as.character(result$value)

  interact_label <- paste(banner_vars, collapse = " \u00d7 ")
  result$variable      <- var
  result$question_text <- lm$question_text
  result$var_label     <- lm$var_label
  result$subgroup_type  <- "interaction"
  result$subgroup_var   <- interact_label
  result$subgroup_label <- interact_label

  result
}

# -- Frequency frame builder ---------------------------------------------------

#' @keywords internal
#' @noRd
.build_freq_frame <- function(
  design,
  vars_resolved,
  classify_out,
  banner_resolved = NULL,
  interactions    = NULL,
  variance        = NULL,
  conf_level      = 0.95,
  show_eff_n      = FALSE,
  pub_type        = "none"
) {
  freq_args <- list(variance = variance, conf_level = conf_level)

  # survey_collection path
  if (S7::S7_inherits(design, surveycore::survey_collection)) {
    wave_names <- names(design@surveys)

    # Pooled "Total": n-weighted average of per-wave estimates
    total_rows <- lapply(vars_resolved, function(var) {
      wave_freq_list <- lapply(wave_names, function(wn) {
        wd <- design@surveys[[wn]]
        if (!var %in% names(wd@data)) return(NULL)
        do.call(.compute_total_freq, c(list(design = wd, var = var), freq_args))
      })
      wave_freq_list <- wave_freq_list[
        !vapply(wave_freq_list, is.null, logical(1L))
      ]

      if (length(wave_freq_list) == 0L) {
        # nocov start
        # Defensive: the validator checks vars against design@surveys[[1L]]@data,
        # so at least one wave always has the variable.
        return(tibble::tibble(
          value         = NA_character_,
          pct           = NA_real_,
          n             = NA_integer_,
          variable      = var,
          question_text = var,
          var_label     = var,
          subgroup_type  = "total",
          subgroup_var   = NA_character_,
          subgroup_value = NA_character_,
          subgroup_label = "Total"
        ))
        # nocov end
      }

      combined <- dplyr::bind_rows(wave_freq_list)
      first    <- wave_freq_list[[1L]]

      pooled <- combined |>
        dplyr::group_by(value) |>
        dplyr::summarise(
          pct = sum(pct * n, na.rm = TRUE) / sum(n, na.rm = TRUE),
          n   = sum(n, na.rm = TRUE),
          .groups = "drop"
        )
      pooled$variable      <- var
      pooled$question_text <- first$question_text[[1L]]
      pooled$var_label     <- first$var_label[[1L]]
      pooled$subgroup_type  <- "total"
      pooled$subgroup_var   <- NA_character_
      pooled$subgroup_value <- NA_character_
      pooled$subgroup_label <- "Total"
      pooled
    })

    # Per-wave rows
    wave_rows <- lapply(wave_names, function(wn) {
      wd <- design@surveys[[wn]]
      lapply(vars_resolved, function(var) {
        if (!var %in% names(wd@data)) {
          return(tibble::tibble(
            value         = NA_character_,
            pct           = NA_real_,
            n             = NA_integer_,
            variable      = var,
            question_text = var,
            var_label     = var,
            subgroup_type  = "wave",
            subgroup_var   = wn,
            subgroup_value = NA_character_,
            subgroup_label = paste0(wn, " (n/a)")
          ))
        }
        r <- do.call(.compute_total_freq, c(list(design = wd, var = var), freq_args))
        r$subgroup_type  <- "wave"
        r$subgroup_var   <- wn
        r$subgroup_label <- wn
        r
      }) |> dplyr::bind_rows()
    }) |> dplyr::bind_rows()

    all_rows <- dplyr::bind_rows(
      dplyr::bind_rows(total_rows),
      wave_rows
    )

    if (show_eff_n) {
      all_rows$eff_n <- mapply(
        function(stype, svar) {
          if (stype == "total") return(NA_real_)
          wd <- design@surveys[[svar]]
          if (is.null(wd)) return(NA_real_)  # nocov
          .compute_eff_n(wd)
        },
        all_rows$subgroup_type,
        all_rows$subgroup_var,
        SIMPLIFY = TRUE
      )
    }

    all_rows <- dplyr::left_join(
      all_rows,
      classify_out[, c("variable", "type", "group", "question_preface")],
      by = "variable"
    )
    names(all_rows)[names(all_rows) == "type"]  <- "var_type"
    names(all_rows)[names(all_rows) == "group"] <- "group_id"

    .emit_missing_label_warning(all_rows)
    return(list(frame = all_rows, suppressed = .empty_suppressed()))
  }

  # Standard path
  suppressed <- .empty_suppressed()

  # Suppression evaluation
  if (pub_type != "none" && !is.null(banner_resolved)) {
    for (banner_var in banner_resolved) {
      col_vals <- design@data[[banner_var]]
      levels   <- unique(col_vals[!is.na(col_vals)])
      for (level in levels) {
        level_chr <- as.character(level)
        eff_n_val <- .compute_eff_n(design, col = banner_var, level = level_chr)
        raw_n_val <- as.integer(sum(col_vals == level, na.rm = TRUE))
        threshold <- if (pub_type == "external") 100L else 50L

        suppress <- if (pub_type == "external") {
          eff_n_val < 100 || raw_n_val < 100L
        } else {
          eff_n_val < 50 || raw_n_val < 100L
        }

        if (suppress) {
          suppressed <- dplyr::bind_rows(suppressed, tibble::tibble(
            subgroup_var   = banner_var,
            subgroup_value = level_chr,
            eff_n          = eff_n_val,
            raw_n          = raw_n_val,
            threshold      = threshold,
            pub_type       = pub_type
          ))
        }
      }
    }

    if (nrow(suppressed) > 0L) {
      dropped <- paste(
        suppressed$subgroup_var,
        suppressed$subgroup_value,
        sep = "=", collapse = ", "
      )
      cli::cli_warn(
        c(
          "!" = "{nrow(suppressed)} subgroup{?s} suppressed due to small sample size.",
          "i" = "Suppressed: {dropped}."
        ),
        class = "surveyreports_warning_subgroup_suppressed"
      )
    }
  }

  # Frame building
  all_rows <- lapply(vars_resolved, function(var) {
    rows <- list(
      do.call(.compute_total_freq, c(list(design = design, var = var), freq_args))
    )

    if (!is.null(banner_resolved)) {
      for (banner_var in banner_resolved) {
        if (var == banner_var) next  # self-banner drop

        sup_vals <- suppressed$subgroup_value[suppressed$subgroup_var == banner_var]
        r <- do.call(
          .compute_subgroup_freq,
          c(list(design = design, var = var, banner_var = banner_var), freq_args)
        )
        if (length(sup_vals) > 0L) {
          r <- r[!r$subgroup_value %in% sup_vals, , drop = FALSE]
        }
        rows[[length(rows) + 1L]] <- r
      }
    }

    if (!is.null(interactions)) {
      for (banner_vars in interactions) {
        rows[[length(rows) + 1L]] <- do.call(
          .compute_interaction_freq,
          c(list(design = design, var = var, banner_vars = banner_vars), freq_args)
        )
      }
    }

    dplyr::bind_rows(rows)
  }) |> dplyr::bind_rows()

  if (show_eff_n) {
    all_rows$eff_n <- mapply(
      function(stype, svar, sval) {
        if (stype == "total") {
          .compute_eff_n(design)
        } else if (stype == "banner") {
          .compute_eff_n(design, col = svar, level = sval)
        } else {
          NA_real_
        }
      },
      all_rows$subgroup_type,
      all_rows$subgroup_var,
      all_rows$subgroup_value,
      SIMPLIFY = TRUE
    )
  }

  all_rows <- dplyr::left_join(
    all_rows,
    classify_out[, c("variable", "type", "group", "question_preface")],
    by = "variable"
  )
  names(all_rows)[names(all_rows) == "type"]  <- "var_type"
  names(all_rows)[names(all_rows) == "group"] <- "group_id"

  .emit_missing_label_warning(all_rows)
  list(frame = all_rows, suppressed = suppressed)
}

# Empty suppressed tibble with correct schema
.empty_suppressed <- function() {
  tibble::tibble(
    subgroup_var   = character(0L),
    subgroup_value = character(0L),
    eff_n          = numeric(0L),
    raw_n          = integer(0L),
    threshold      = integer(0L),
    pub_type       = character(0L)
  )
}

# Row-1 header for a sata/battery block: the group's shared question_preface,
# falling back to the first member's question_text when no preface exists.
.group_header_text <- function(frame) {
  preface <- frame$question_preface[[1L]]
  if (!is.na(preface) && nchar(preface) > 0L) {
    preface
  } else {
    frame$question_text[[1L]]
  }
}

# Emit missing-variable-label warning for vars that fell back to the var name
.emit_missing_label_warning <- function(frame) {
  vars_fallback <- unique(
    frame$variable[!is.na(frame$variable) & frame$question_text == frame$variable]
  )
  if (length(vars_fallback) > 0L) {
    cli::cli_warn(
      c(
        "!" = "Variable{?s} {.field {vars_fallback}} {?has/have} no {.field variable_label}.",
        "i" = "Variable name used as question text."
      ),
      class = "surveyreports_warning_missing_variable_label"
    )
  }
  invisible(NULL)
}

# -- Workbook builder ----------------------------------------------------------

#' @keywords internal
#' @noRd
.build_workbook <- function() {
  openxlsx2::wb_workbook()
}

# -- Suppression footnote writer -----------------------------------------------

#' @keywords internal
#' @noRd
.write_suppression_footnote <- function(wb, sheet, suppressed, start_row) {
  # nocov start
  # Defensive: all callers guard with nrow(suppressed) > 0L before calling.
  if (nrow(suppressed) == 0L) return(invisible(wb))
  # nocov end

  for (i in seq_len(nrow(suppressed))) {
    row  <- suppressed[i, ]
    text <- sprintf(
      "* %s: %s suppressed (n=%d, threshold=%d)",
      row$subgroup_var, row$subgroup_value, row$raw_n, row$threshold
    )
    wb <- openxlsx2::wb_add_data(
      wb, sheet = sheet, x = text,
      start_row = start_row + i - 1L, start_col = 1L
    )
  }

  invisible(wb)
}
