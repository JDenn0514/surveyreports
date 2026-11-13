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

  data_for_check <- if (
    S7::S7_inherits(design, surveycore::survey_collection)
  ) {
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
    # nocov start
    # Defensive: surveycore >= 1.2.0 rejects zero-row @data in its S7
    # validator. An empty filter() domain keeps every row, so it does not
    # reach this check. The check stays because DESCRIPTION still allows
    # surveycore < 1.2.0. The export-metadata work
    # (plans/spec-export-metadata.md) plans to raise this class for an
    # all-FALSE domain; remove these markers then.
    cli::cli_abort(
      c(
        "x" = "The design contains zero rows.",
        "i" = "No data is available to compute frequencies.",
        "v" = "Supply a design with at least one observation."
      ),
      class = "surveyreports_error_empty_domain"
    )
    # nocov end
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
  data <- design@data
  wt_col <- design@variables$weights
  if (is.null(wt_col) || length(wt_col) == 0L) {
    wt_col <- design@variables$phase1$weights # nocov
  }
  if (is.null(wt_col) || length(wt_col) == 0L || !wt_col %in% names(data)) {
    return(NA_real_) # nocov
  }

  if (!is.null(col)) {
    data <- data[data[[col]] == level, , drop = FALSE]
  }

  wi <- data[[wt_col]]
  n <- nrow(data)
  # nocov start
  # Defensive: levels iterated via unique(col_vals[!is.na(col_vals)]), so n == 0
  # cannot occur via the public API.
  if (n == 0L || sum(wi, na.rm = TRUE) == 0) {
    return(NA_real_)
  }
  # nocov end
  deff <- (n * sum(wi^2, na.rm = TRUE)) / sum(wi, na.rm = TRUE)^2
  n / deff
}

# Raw N and effective N per subgroup, delegated to
# surveycore::get_effective_n(). One source for both counts.
#
# Returns a tibble of `level` (chr), `n` (int) and `n_eff` (dbl):
# - group_var = NULL on a single design: one row, level = NA_character_.
# - group_var = NULL on a survey_collection: one row per member, and level is
#   the wave name from the `.survey` column. The caller joins on the wave name.
# - group_var set: one row per observed level. Levels are labels, in the
#   vocabulary of surveycore::get_freqs(). group_var may name a banner column
#   or the synthetic interaction column.
# na.rm goes to get_effective_n() unchanged. The caller passes the value it
# passes to get_freqs(), so a missing-value banner level has a row here when
# it has a column there.
# Muffles surveycore_warning_small_cell, as the frequency helpers do, and
# raises no warning of its own.
#' @keywords internal
#' @noRd
.resolve_eff_n <- function(design, group_var = NULL, na.rm = TRUE) {
  out <- withCallingHandlers(
    if (is.null(group_var)) {
      surveycore::get_effective_n(design, na.rm = na.rm)
    } else {
      surveycore::get_effective_n(
        design,
        group = !!rlang::sym(group_var),
        na.rm = na.rm
      )
    },
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )

  level <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    as.character(out[[".survey"]])
  } else if (is.null(group_var)) {
    rep(NA_character_, nrow(out))
  } else {
    as.character(out[[group_var]])
  }

  tibble::tibble(
    level = level,
    n = as.integer(out$n),
    n_eff = as.double(out$n_eff)
  )
}

# -- Metadata readers ----------------------------------------------------------

# TRUE when the design is restricted to a domain. surveycore exports no domain
# accessor, so this is a direct test of the column name. A domain that selects
# every row still counts as a restriction.
#' @keywords internal
#' @noRd
.has_domain <- function(design) {
  surveycore::SURVEYCORE_DOMAIN_COL %in% names(design@data)
}

# A banner column translated from codes to value labels, so its levels match
# the vocabulary of surveycore::get_freqs().
#
# Returns a vector of length nrow(design@data), with NA kept:
# - a factor comes back unchanged, with its level order intact. A character
#   return would let interaction() sort the levels alphabetically.
# - a column with value labels comes back as character labels. A code with no
#   label becomes NA_character_, as it does in get_freqs().
# - any other column comes back as character.
#' @keywords internal
#' @noRd
.banner_levels_labelled <- function(design, col) {
  x <- design@data[[col]]
  if (is.factor(x)) {
    return(x)
  }

  labels <- surveycore::extract_val_labels(
    design,
    tidyselect::all_of(col)
  )[[col]]
  if (is.null(labels)) {
    return(as.character(x))
  }

  names(labels)[match(as.vector(x), unname(labels))]
}

# The display heading for a banner column: its variable label, or the column
# name when no label is set.
#
# Returns list(heading = chr(1), fell_back = lgl(1)). It raises no warning.
# The caller collects fell_back across columns and raises one warning.
#' @keywords internal
#' @noRd
.banner_heading <- function(design, col) {
  label <- unname(
    surveycore::extract_var_label(design, tidyselect::all_of(col))[col]
  )
  has_label <- !is.na(label) && nzchar(label)

  list(
    heading = if (has_label) label else col,
    fell_back = !has_label
  )
}

# The keys whose value is the same, and not missing, in every member.
#
# entries is a list of named character vectors, one per member. A key that
# disagrees anywhere, or is missing or NA in any member, is omitted. Returns a
# named character vector, in the key order of the first member.
# For a battery, the shape is transposed (one vector, several variables).
# Reshape it so every member shares one key before the call.
#' @keywords internal
#' @noRd
.unanimous_across <- function(entries) {
  empty <- structure(character(0), names = character(0))
  if (length(entries) == 0L) {
    return(empty)
  }

  first <- entries[[1L]]
  keys <- names(first)
  if (is.null(keys)) {
    return(empty)
  }

  agrees <- vapply(
    keys,
    function(key) {
      all(vapply(
        entries,
        function(e) {
          key %in%
            names(e) &&
            !is.na(e[[key]]) &&
            identical(e[[key]], first[[key]])
        },
        logical(1)
      ))
    },
    logical(1),
    USE.NAMES = FALSE
  )

  first[agrees]
}

# -- Metadata resolvers ---------------------------------------------------------

# The designs to read: every member of a survey_collection, or the one
# survey_base design in a list of length 1. The surveycore metadata readers
# abort on a collection, so this is the only route to them for one.
#' @keywords internal
#' @noRd
.design_members <- function(design) {
  if (S7::S7_inherits(design, surveycore::survey_collection)) {
    return(design@surveys)
  }
  list(design)
}

# The role of each column in cols, for one survey_base design.
#
# Applies the per-variable coercion rule of spec section 3.10 to the `role` key
# of each extract_var_extra() payload. A length-1 character comes back as that
# string, known role or not. An absent entry, an absent key, a length-0 value,
# a length-2 or longer vector and a non-character value all become
# NA_character_. The coercion runs before vapply(), so vapply() only ever sees
# one string and cannot abort on a foreign payload.
# The result carries attr(, "malformed"): the cols whose payload is a length-2
# or longer vector, or a length-1 non-character value. An absent key and a
# length-0 value are not malformed. It is character(0) when there are none.
#' @keywords internal
#' @noRd
.extract_roles_single <- function(design, cols) {
  extra <- surveycore::extract_var_extra(design)
  payloads <- lapply(cols, function(col) {
    entry <- extra[[col]]
    if (is.list(entry)) entry[["role"]] else NULL
  })
  is_role <- vapply(
    payloads,
    function(p) is.character(p) && length(p) == 1L,
    logical(1)
  )

  roles <- vapply(
    seq_along(cols),
    function(i) if (is_role[[i]]) unname(payloads[[i]]) else NA_character_,
    character(1)
  )
  names(roles) <- cols
  attr(roles, "malformed") <- cols[lengths(payloads) > 0L & !is_role]
  roles
}

# The universe text of every variable that has one, for one survey_base
# design, as a named character vector keyed by variable.
#
# An empty string or an NA counts as no universe and is omitted: neither one
# is text a base-note row can show. extract_universe() returns an unnamed
# character(0) when nothing is set, so the empty result is built here with
# names.
#' @keywords internal
#' @noRd
.extract_universe_single <- function(design) {
  universe <- surveycore::extract_universe(design)
  keep <- !is.na(universe) & nzchar(universe)
  if (!any(keep)) {
    return(structure(character(0), names = character(0)))
  }
  universe[keep]
}

# The role lookup for a set of columns. A lookup only: it does not classify,
# warn or drop.
#
# Returns a named character vector, one entry per element of cols, in the
# order of cols. An entry is NA_character_ when no role is set or the payload
# is not a length-1 character (spec section 3.10). It never aborts.
# On a survey_collection it reads each member and keeps a role only when every
# member carries the same one (spec section 3.6). A role that disagrees, or
# that is missing in any member, becomes NA_character_.
#
# The result carries attr(, "malformed"), the cols whose payload is a length-2
# or longer vector or a non-character value, in the order of cols. It is
# character(0) when there are none. On a collection, a column is malformed
# when it is malformed in ANY member. The value of a malformed column stays
# NA_character_: only the attribute tells .apply_role_guard() which NA columns
# warn, because an absent role and a malformed one give the same NA.
# Each member is read once, for the roles and the malformed flags together.
# .unanimous_across() drops the attribute, so it is rebuilt here.
#' @keywords internal
#' @noRd
.resolve_roles <- function(design, cols) {
  per_member <- lapply(
    .design_members(design),
    function(d) .extract_roles_single(d, cols)
  )
  found <- .unanimous_across(per_member)
  malformed <- unlist(lapply(per_member, attr, "malformed"))

  result <- stats::setNames(unname(found[cols]), cols)
  attr(result, "malformed") <- cols[cols %in% malformed]
  result
}

# The caller's base_notes and the design's universe, kept SEPARATE.
#
# Returns list(caller = <named chr or NULL>, universe = <named chr>), or NULL
# when both sources are empty. universe is keyed by variable and is an empty
# named character vector when nothing is set.
# - caller is base_notes as supplied, with no validation here:
#   .validate_base_notes() checks it before this call. A zero-length
#   base_notes counts as empty and comes back as NULL.
# - The text of both sources is verbatim. No "Base:" prefix is added.
# - On a survey_collection, the universe follows the wave unanimity rule of
#   spec section 3.6: a variable whose universe disagrees across members, or
#   is missing in any member, is omitted. This helper applies that rule and no
#   other. The battery rule runs later, in .base_note_for().
#' @keywords internal
#' @noRd
.resolve_base_notes <- function(design, base_notes) {
  caller <- if (length(base_notes) > 0L) base_notes else NULL
  # On a single design, .unanimous_across() of one member returns that
  # member's entries unchanged.
  universe <- .unanimous_across(
    lapply(.design_members(design), .extract_universe_single)
  )

  if (is.null(caller) && length(universe) == 0L) {
    return(NULL)
  }
  list(caller = caller, universe = universe)
}

# -- Selection guards -----------------------------------------------------------

# The warn-and-drop policy of spec section 3.10, for one argument.
#
# Both export functions call it for `vars`; export_crosstab() calls it again
# for `banner`. arg ("vars" or "banner") names the argument in every message.
# empty_class is the error class raised when nothing survives.
# - A column with a non-substantive role is dropped. One
#   surveyreports_warning_role_dropped lists every dropped column and its role.
# - A column with a length-1 role outside the seven known values, or with a
#   malformed payload, is kept. One surveyreports_warning_unknown_role lists
#   every such column. The drop warning comes first (spec section 3.11).
# - A column with no role (NA and not malformed) is kept with no warning.
# - When every column is dropped, it aborts with empty_class and raises no
#   drop warning: the error lists every dropped column and its role.
# It reads var_extra through .resolve_roles() and never reads @variables.
# A design-named column is .reject_design_vars()'s case, which runs first.
# Returns the surviving names as a character vector, in the order of cols.
#' @keywords internal
#' @noRd
.apply_role_guard <- function(design, cols, arg, empty_class) {
  non_substantive <- c("weight", "identifier", "paradata", "free_text")
  substantive <- c("item", "demographic", "treatment")

  roles <- .resolve_roles(design, cols)
  malformed <- cols %in% attr(roles, "malformed")
  roles <- unname(roles)

  dropped <- !is.na(roles) & roles %in% non_substantive
  unknown <- malformed |
    (!is.na(roles) & !roles %in% c(non_substantive, substantive))
  kept <- cols[!dropped]
  dropped_roles <- paste0(cols[dropped], " (", roles[dropped], ")")

  if (length(kept) == 0L) {
    cli::cli_abort(
      c(
        "x" = "Every column in {.arg {arg}} has a non-substantive role.",
        "i" = "Dropped: {dropped_roles}.",
        "v" = paste0(
          "Select a column with a substantive role, or clear the ",
          "{.field role} of a column to keep it."
        )
      ),
      class = empty_class
    )
  }

  if (any(dropped)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Dropped {sum(dropped)} column{?s} from {.arg {arg}} for a ",
          "non-substantive role."
        ),
        "i" = "Dropped: {dropped_roles}."
      ),
      class = "surveyreports_warning_role_dropped"
    )
  }

  if (any(unknown)) {
    unknown_roles <- paste0(
      cols[unknown],
      " (",
      ifelse(malformed[unknown], "not a single string", roles[unknown]),
      ")"
    )
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.arg {arg}} has {sum(unknown)} column{?s} with an unrecognized ",
          "{.field role}: {unknown_roles}."
        ),
        "i" = paste0(
          "Each one is kept as a substantive column. The known roles are ",
          "{.val {c(substantive, non_substantive)}}."
        )
      ),
      class = "surveyreports_warning_unknown_role"
    )
  }

  kept
}

# Every column the design itself names, checked against one selection.
#
# cols is the resolved `vars` or `banner`, in input order; arg ("vars" or
# "banner") names the argument in the message. Returns invisible(TRUE) when no
# column matches. Otherwise it aborts with
# surveyreports_error_design_variable_selected for the first match in the
# order of cols, naming the column, arg and the slot (spec section 3.17).
# It runs before the role guard (spec section 3.11). It reads @variables and
# never reads var_extra.
# On a survey_collection, every member is checked: export_topline() accepts a
# collection, and a column any wave uses as a design variable is not a
# question in that wave. The message then names the member.
#
# The reader, design_columns(), returns the column names one survey_base
# design holds in @variables, as a named character vector: the value is a
# column name, the name is its slot. @variables is not a flat list of column
# names, and its slots differ by subclass (surveycore 1.2.0). The reader takes
# only the slots that can hold a column name, and keeps only character values,
# so no comparison runs against TRUE, 0.9 or "JK1":
# - survey_taylor: ids, weights, strata, fpc.
# - survey_replicate: weights, repweights, fpc. Its fpc is a number, never a
#   column, so the character filter removes it.
# - survey_twophase: ids, weights, strata, fpc nested in phase1; ids, strata,
#   probs, fpc nested in phase2; and subset. A flat read finds none of them.
# - survey_nonprob: weights, repweights, ids, strata, fpc.
# Skipped, because they hold no column name: nest, probs_provided,
# visible_vars, type, scale, rscales, fpctype, fpc_applied, fpc_fraction, mse,
# rho, method. A NULL slot is dropped.
# A Taylor design built from probs stores an internal weight column, not the
# probs column, so the probs column is not reachable from @variables.
#' @keywords internal
#' @noRd
.reject_design_vars <- function(design, cols, arg) {
  design_columns <- function(d) {
    v <- d@variables
    slots <- if (S7::S7_inherits(d, surveycore::survey_twophase)) {
      c(
        stats::setNames(
          v$phase1[c("ids", "weights", "strata", "fpc")],
          paste0("phase1$", c("ids", "weights", "strata", "fpc"))
        ),
        stats::setNames(
          v$phase2[c("ids", "strata", "probs", "fpc")],
          paste0("phase2$", c("ids", "strata", "probs", "fpc"))
        ),
        list(subset = v$subset)
      )
    } else if (S7::S7_inherits(d, surveycore::survey_replicate)) {
      v[c("weights", "repweights", "fpc")]
    } else if (S7::S7_inherits(d, surveycore::survey_nonprob)) {
      v[c("weights", "repweights", "ids", "strata", "fpc")]
    } else {
      # survey_taylor, the fourth subclass of the cross-design table.
      v[c("ids", "weights", "strata", "fpc")]
    }

    slots <- slots[vapply(slots, is.character, logical(1))]
    stats::setNames(
      unlist(slots, use.names = FALSE),
      rep(names(slots), lengths(slots))
    )
  }

  members <- .design_members(design)
  is_collection <- S7::S7_inherits(design, surveycore::survey_collection)
  design_cols <- lapply(members, design_columns)

  for (col in cols) {
    for (m in seq_along(design_cols)) {
      hit <- match(col, design_cols[[m]])
      if (is.na(hit)) {
        next
      }
      slot <- names(design_cols[[m]])[[hit]]
      where <- if (is_collection) {
        member <- names(members)[[m]]
        "Member {.val {member}} names it in its {.field {slot}} slot."
      } else {
        "The design names it in its {.field {slot}} slot."
      }
      cli::cli_abort(
        c(
          "x" = paste0(
            "Column {.field {col}} in {.arg {arg}} is a design variable, ",
            "not a question."
          ),
          "i" = where,
          "v" = "Remove {.field {col}} from {.arg {arg}}."
        ),
        class = "surveyreports_error_design_variable_selected"
      )
    }
  }

  invisible(TRUE)
}

# -- Frequency computation helpers ---------------------------------------------

# Extract question_text and var_label from get_freqs meta.
.extract_var_meta <- function(m, var) {
  vm <- m$x[[var]]
  vlabel <- vm$variable_label
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
  lm <- .extract_var_meta(surveycore::meta(result), var)

  # First column is the response value column (named after `var`)
  names(result)[1L] <- "value"
  result$value <- as.character(result$value)

  result$variable <- var
  result$question_text <- lm$question_text
  result$var_label <- lm$var_label
  result$subgroup_type <- "total"
  result$subgroup_var <- NA_character_
  result$subgroup_value <- NA_character_
  result$subgroup_label <- "Total"

  result
}

#' @keywords internal
#' @noRd
.compute_subgroup_freq <- function(design, var, banner_var, ...) {
  result <- withCallingHandlers(
    surveycore::get_freqs(
      design,
      !!rlang::sym(var),
      group = !!rlang::sym(banner_var),
      ...
    ),
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )
  lm <- .extract_var_meta(surveycore::meta(result), var)

  # First col: banner var (-> subgroup_value); second: response (-> value)
  names(result)[1L] <- "subgroup_value"
  names(result)[2L] <- "value"
  result$subgroup_value <- as.character(result$subgroup_value)
  result$value <- as.character(result$value)

  result$variable <- var
  result$question_text <- lm$question_text
  result$var_label <- lm$var_label
  result$subgroup_type <- "banner"
  result$subgroup_var <- banner_var
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
      design,
      !!rlang::sym(var),
      group = !!rlang::sym(interact_col),
      ...
    ),
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )
  lm <- .extract_var_meta(surveycore::meta(result), var)

  names(result)[1L] <- "subgroup_value"
  names(result)[2L] <- "value"
  result$subgroup_value <- as.character(result$subgroup_value)
  result$value <- as.character(result$value)

  interact_label <- paste(banner_vars, collapse = " \u00d7 ")
  result$variable <- var
  result$question_text <- lm$question_text
  result$var_label <- lm$var_label
  result$subgroup_type <- "interaction"
  result$subgroup_var <- interact_label
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
  interactions = NULL,
  variance = NULL,
  conf_level = 0.95,
  show_eff_n = FALSE,
  pub_type = "none"
) {
  freq_args <- list(variance = variance, conf_level = conf_level)

  # survey_collection path
  if (S7::S7_inherits(design, surveycore::survey_collection)) {
    wave_names <- names(design@surveys)

    # Pooled "Total": n-weighted average of per-wave estimates
    total_rows <- lapply(vars_resolved, function(var) {
      wave_freq_list <- lapply(wave_names, function(wn) {
        wd <- design@surveys[[wn]]
        if (!var %in% names(wd@data)) {
          return(NULL)
        }
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
          value = NA_character_,
          pct = NA_real_,
          n = NA_integer_,
          variable = var,
          question_text = var,
          var_label = var,
          subgroup_type = "total",
          subgroup_var = NA_character_,
          subgroup_value = NA_character_,
          subgroup_label = "Total"
        ))
        # nocov end
      }

      combined <- dplyr::bind_rows(wave_freq_list)
      first <- wave_freq_list[[1L]]

      pooled <- combined |>
        dplyr::group_by(value) |>
        dplyr::summarise(
          pct = sum(pct * n, na.rm = TRUE) / sum(n, na.rm = TRUE),
          n = sum(n, na.rm = TRUE),
          .groups = "drop"
        )
      pooled$variable <- var
      pooled$question_text <- first$question_text[[1L]]
      pooled$var_label <- first$var_label[[1L]]
      pooled$subgroup_type <- "total"
      pooled$subgroup_var <- NA_character_
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
            value = NA_character_,
            pct = NA_real_,
            n = NA_integer_,
            variable = var,
            question_text = var,
            var_label = var,
            subgroup_type = "wave",
            subgroup_var = wn,
            subgroup_value = NA_character_,
            subgroup_label = paste0(wn, " (n/a)")
          ))
        }
        r <- do.call(
          .compute_total_freq,
          c(list(design = wd, var = var), freq_args)
        )
        r$subgroup_type <- "wave"
        r$subgroup_var <- wn
        r$subgroup_label <- wn
        r
      }) |>
        dplyr::bind_rows()
    }) |>
      dplyr::bind_rows()

    all_rows <- dplyr::bind_rows(
      dplyr::bind_rows(total_rows),
      wave_rows
    )

    if (show_eff_n) {
      all_rows$eff_n <- mapply(
        function(stype, svar) {
          if (stype == "total") {
            return(NA_real_)
          }
          wd <- design@surveys[[svar]]
          if (is.null(wd)) {
            return(NA_real_)
          } # nocov
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
    names(all_rows)[names(all_rows) == "type"] <- "var_type"
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
      levels <- unique(col_vals[!is.na(col_vals)])
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
          suppressed <- dplyr::bind_rows(
            suppressed,
            tibble::tibble(
              subgroup_var = banner_var,
              subgroup_value = level_chr,
              eff_n = eff_n_val,
              raw_n = raw_n_val,
              threshold = threshold,
              pub_type = pub_type
            )
          )
        }
      }
    }

    if (nrow(suppressed) > 0L) {
      dropped <- paste(
        suppressed$subgroup_var,
        suppressed$subgroup_value,
        sep = "=",
        collapse = ", "
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
      do.call(
        .compute_total_freq,
        c(list(design = design, var = var), freq_args)
      )
    )

    if (!is.null(banner_resolved)) {
      for (banner_var in banner_resolved) {
        if (var == banner_var) {
          next
        } # self-banner drop

        sup_vals <- suppressed$subgroup_value[
          suppressed$subgroup_var == banner_var
        ]
        r <- do.call(
          .compute_subgroup_freq,
          c(
            list(design = design, var = var, banner_var = banner_var),
            freq_args
          )
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
          c(
            list(design = design, var = var, banner_vars = banner_vars),
            freq_args
          )
        )
      }
    }

    dplyr::bind_rows(rows)
  }) |>
    dplyr::bind_rows()

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
  names(all_rows)[names(all_rows) == "type"] <- "var_type"
  names(all_rows)[names(all_rows) == "group"] <- "group_id"

  .emit_missing_label_warning(all_rows)
  list(frame = all_rows, suppressed = suppressed)
}

# Empty suppressed tibble with correct schema
.empty_suppressed <- function() {
  tibble::tibble(
    subgroup_var = character(0L),
    subgroup_value = character(0L),
    eff_n = numeric(0L),
    raw_n = integer(0L),
    threshold = integer(0L),
    pub_type = character(0L)
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
    frame$variable[
      !is.na(frame$variable) & frame$question_text == frame$variable
    ]
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

# The workbook both export functions write into (spec 2.3). It adds the
# "About" cover sheet before any question sheet, so "About" is sheet 1 by
# insertion order (spec 3.14). The last six arguments go to
# .write_cover_sheet() unchanged. The defaults are the export_topline() case
# for has_banner and string_cells; `decimals` and `variance` come from the
# caller in both export functions, because the glossary reads them.
#' @keywords internal
#' @noRd
.build_workbook <- function(
  design,
  withheld = NULL,
  min_eff_n = NULL,
  has_banner = FALSE,
  string_cells = FALSE,
  decimals = 1L,
  variance = NULL
) {
  wb <- openxlsx2::wb_workbook()
  wb <- openxlsx2::wb_add_worksheet(wb, "About")
  .write_cover_sheet(
    wb,
    design,
    withheld,
    min_eff_n,
    has_banner,
    string_cells,
    decimals,
    variance
  )
}

# -- Cover sheet ---------------------------------------------------------------

# Writes the "About" sheet, which .build_workbook() has already added
# (spec 3.14). Row 1 is a `Key` / `Value` header. Three blocks follow, with one
# blank row between two blocks and none after the last:
# - Survey metadata: one row per set dataset key, in surveycore's canonical
#   key order, then the `Restricted to` row when .has_domain() is TRUE.
#   Written when any key is set or the design has the domain column. A
#   survey_collection writes one block per wave instead, in @surveys order:
#   the wave name alone in column A, then that wave's rows. A wave with no
#   keys still gets its heading.
# - Subgroups not shown: the minimum in force, then one row per line of
#   .format_withheld_lines(), or one `None` row for a zero-row frame. Written
#   only when `withheld` is not NULL and `min_eff_n` is above 0. NULL is the
#   caller's instruction to write no block; it never means "nothing withheld".
# - What these numbers mean: the glossary of spec 3.15, always written.
# This helper takes no withheld_note argument and reads none (spec 3.14).
#
# Readings where the spec is open:
# - The key column shows the display label of the v0.7.0 spec, section 6.2
#   (survey_name -> Survey, ...), which the test-spec (XA-03) still names as
#   "display labels". A key with no label shows its own name.
# - A single design's survey block has no heading row: the `Key` / `Value`
#   header heads it. A collection's blocks are headed by the wave names, and
#   the header row comes directly before the first one (test-spec TC-05).
# - On a collection, the domain row is written per wave, in that wave's block,
#   because .has_domain() reads one design's @data and a collection has none.
# - The block headings are the block names of the spec 3.14 table.
# - The withheld rows put `Minimum effective sample size` and `Not shown` in
#   column A and the value or line in column B, as Key / Value pairs.
# - Column A is 44 characters wide and column B is 12, the label and data
#   widths of spec 3.16, which spec 3.14 cites. Text in column B overflows
#   into the empty columns to its right. No cell is merged and none wraps.
# - The `Percentages` entry quotes the floor and ceiling strings of
#   .fmt_pct_limits() at `decimals`, so its examples match the cells (spec
#   3.15). Spec 2.2 gives a seven-argument signature with no `decimals`; this
#   helper adds it. No caller sets string_cells = TRUE yet.
# Returns wb.
#' @keywords internal
#' @noRd
.write_cover_sheet <- function(
  wb,
  design,
  withheld,
  min_eff_n,
  has_banner,
  string_cells,
  decimals,
  variance
) {
  sheet <- "About"
  key_labels <- c(
    survey_name = "Survey",
    data_name = "Dataset",
    vendor = "Vendor",
    field_start = "Field start",
    field_end = "Field end",
    field_period = "Field period"
  )

  cover_rows <- function(a, b = NA_character_, bold = FALSE) {
    data.frame(
      A = a,
      B = b,
      bold = rep(bold, length(a)),
      stringsAsFactors = FALSE
    )
  }

  # The set keys of one survey_base design, then its domain row.
  survey_rows <- function(d) {
    meta <- surveycore::extract_dataset_metadata(d, format = "data_frame")
    labels <- unname(key_labels[meta$key])
    labels[is.na(labels)] <- meta$key[is.na(labels)]
    rows <- cover_rows(labels, meta$value)
    if (.has_domain(d)) {
      n_in <- .resolve_eff_n(d)$n
      rows <- rbind(
        rows,
        cover_rows(
          "Restricted to",
          paste0(n_in, " of ", nrow(d@data), " rows")
        )
      )
    }
    rows
  }

  blocks <- list()

  if (S7::S7_inherits(design, surveycore::survey_collection)) {
    for (wave in names(design@surveys)) {
      blocks[[length(blocks) + 1L]] <- rbind(
        cover_rows(wave, bold = TRUE),
        survey_rows(design@surveys[[wave]])
      )
    }
  } else {
    survey <- survey_rows(design)
    if (nrow(survey) > 0L) {
      blocks[[length(blocks) + 1L]] <- survey
    }
  }

  if (!is.null(withheld) && !is.null(min_eff_n) && min_eff_n > 0) {
    lines <- .format_withheld_lines(withheld, min_eff_n)
    if (length(lines) == 0L) {
      lines <- "None"
    }
    blocks[[length(blocks) + 1L]] <- rbind(
      cover_rows("Subgroups not shown", bold = TRUE),
      cover_rows(
        "Minimum effective sample size",
        format(min_eff_n, scientific = FALSE, trim = TRUE)
      ),
      cover_rows("Not shown", lines)
    )
  }

  # The glossary, in the order of spec 3.15. Each entry is written only when
  # it is true of this workbook. Five terms and three conditions: the
  # issue-66 decision of spec 3.15 keeps the count at five, so
  # variance = "se" adds no entry. The legend row of spec 3.12 names that
  # statistic instead. The em-dash is built from its code point, because
  # R CMD check warns on non-ASCII characters in R code and `air format`
  # rewrites a backslash-u escape as the literal character.
  glossary <- c(
    "Unweighted sample size" = paste(
      "The number of people who answered. It does not change when weights are",
      "applied. Report text writes this as N for the full sample and n for a",
      "subgroup."
    ),
    "Effective sample size (ESS)" = paste(
      "The sample size left after weighting. Weights make some people count",
      "for more than others, and that costs precision, so this number is",
      "smaller than the unweighted sample size",
      intToUtf8(0x2014L),
      "the more the weights vary, the smaller it gets. It adjusts for the",
      "weights alone. It does not adjust for clustered sampling, so on a",
      "clustered survey the true precision is lower than this number",
      "suggests."
    )
  )
  if (!is.null(min_eff_n) && min_eff_n > 0 && has_banner) {
    glossary[["Why a column is missing"]] <- paste(
      "A subgroup whose effective sample size falls below the minimum is not",
      "shown. The minimum for this workbook is listed above. The test is on",
      "the size of the subgroup itself, not on how many of its members",
      "answered any one question, so a question that many people skipped can",
      "still be shown for a subgroup that clears the minimum."
    )
  }
  if (string_cells) {
    limits <- .fmt_pct_limits(decimals)
    glossary[["Percentages"]] <- paste(
      "Each percentage is based on the people who answered that question,",
      "which can be fewer than the sample size shown above the table. A value",
      "that is not zero but rounds to zero at the shown precision reads",
      paste0(limits[["floor"]], "."),
      "A value below 100 that rounds to 100 reads",
      paste0(limits[["ceiling"]], "."),
      "A true zero reads 0%. A dash means the answer was not chosen in that",
      "column, or was never offered there."
    )
  }
  if (identical(variance, "ci")) {
    glossary[["Confidence intervals"]] <- paste(
      "The interval is a normal approximation. For a very rare or a",
      "near-unanimous answer a bound can fall below 0 percent or rise above",
      "100 percent. That is a property of the approximation, not a count of",
      "people."
    )
  }
  blocks[[length(blocks) + 1L]] <- rbind(
    cover_rows("What these numbers mean", bold = TRUE),
    cover_rows(names(glossary), unname(glossary))
  )

  # One blank row between two blocks, none after the last.
  body <- blocks[[1L]]
  for (block in blocks[-1L]) {
    body <- rbind(body, cover_rows(NA_character_), block)
  }
  rows <- rbind(cover_rows("Key", "Value", bold = TRUE), body)

  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = rows[, c("A", "B")],
    start_row = 1L,
    start_col = 1L,
    col_names = FALSE,
    na.strings = NULL
  )
  wb <- openxlsx2::wb_add_font(
    wb,
    sheet = sheet,
    dims = "A1:B1",
    bold = TRUE
  )
  for (row in which(rows$bold)[-1L]) {
    wb <- openxlsx2::wb_add_font(
      wb,
      sheet = sheet,
      dims = openxlsx2::wb_dims(rows = row, cols = 1L),
      bold = TRUE
    )
  }
  openxlsx2::wb_set_col_widths(
    wb,
    sheet = sheet,
    cols = 1:2,
    widths = c(44, 12)
  )
}

# -- Suppression footnote writer -----------------------------------------------

#' @keywords internal
#' @noRd
.write_suppression_footnote <- function(wb, sheet, suppressed, start_row) {
  # nocov start
  # Defensive: all callers guard with nrow(suppressed) > 0L before calling.
  if (nrow(suppressed) == 0L) {
    return(invisible(wb))
  }
  # nocov end

  for (i in seq_len(nrow(suppressed))) {
    row <- suppressed[i, ]
    text <- sprintf(
      "* %s: %s suppressed (n=%d, threshold=%d)",
      row$subgroup_var,
      row$subgroup_value,
      row$raw_n,
      row$threshold
    )
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = text,
      start_row = start_row + i - 1L,
      start_col = 1L
    )
  }

  invisible(wb)
}

# -- Base-note support (export_topline() / export_crosstab()) -------------------

#' @keywords internal
#' @noRd
.validate_base_notes <- function(base_notes) {
  if (is.null(base_notes)) {
    return(invisible(TRUE))
  }
  nms <- names(base_notes)
  valid <- is.character(base_notes) &&
    !is.null(nms) &&
    all(!is.na(nms)) &&
    all(nzchar(nms))
  if (!valid) {
    cli::cli_abort(
      c(
        "x" = "{.arg base_notes} must be a fully named character vector or {.val NULL}.",
        "i" = "Got {.cls {class(base_notes)}} of length {length(base_notes)}.",
        "v" = "Name every element after the variable whose table it annotates."
      ),
      class = "surveyreports_error_base_notes_invalid"
    )
  }
  invisible(TRUE)
}

# Base-note text for a rendered table, keyed by the frame's first variable
# (the sole variable of a single-choice table; the first member of a
# sata/battery group). NULL when no note is configured for it.
#' @keywords internal
#' @noRd
.base_note_for <- function(frame, base_notes) {
  if (is.null(base_notes)) {
    return(NULL)
  }
  var <- frame$variable[[1L]]
  if (!var %in% names(base_notes)) {
    return(NULL)
  }
  base_notes[[var]]
}

# Italic base-note row directly under a table title, merged across the
# table's columns.
#' @keywords internal
#' @noRd
.write_base_note <- function(wb, sheet, text, row, n_cols) {
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = text,
    start_row = row,
    start_col = 1L
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(
      wb,
      sheet = sheet,
      dims = openxlsx2::wb_dims(rows = row, cols = 1L:n_cols)
    )
  }
  openxlsx2::wb_add_font(
    wb,
    sheet = sheet,
    dims = openxlsx2::wb_dims(rows = row, cols = 1L),
    italic = TRUE
  )
}

# -- Total column + true-zero SATA cells -----------------------------------------

# Synthetic column group for the crosstab Total column: rendered from the
# frequency frame's already-computed subgroup_type == "total" rows instead
# of a real banner/interaction subgroup.
#' @keywords internal
#' @noRd
.total_col_group <- function() {
  list(
    spanner = "Total",
    levels = "Total",
    type = "total_col",
    subgroup_var = NA_character_
  )
}

# Frequency-frame rows for one rendered cell: a column group + level,
# optionally narrowed to one variable (sata/battery tables) and/or one
# response value. The synthetic Total group maps to the frame's
# subgroup_type == "total" rows.
#' @keywords internal
#' @noRd
.cell_rows <- function(frame, cg, level, val = NULL, var = NULL) {
  keep <- if (identical(cg$type, "total_col")) {
    frame$subgroup_type == "total"
  } else {
    frame$subgroup_type == cg$type &
      frame$subgroup_var == cg$subgroup_var &
      frame$subgroup_value == level
  }
  if (!is.null(var)) {
    keep <- keep & frame$variable == var
  }
  if (!is.null(val)) {
    keep <- keep & frame$value == val
  }
  frame[keep, ]
}

# SATA "true zero" percentage cell: an item whose value == "1" row is
# missing but whose base exists (a row for this var + column with a
# genuinely positive n) prints 0 instead of blank -- blank stays reserved
# for "not asked". get_freqs() emits a placeholder row (n = 0, pct = NA)
# for a subgroup with zero non-NA observations even when the item was
# never asked there at all, so "a row exists" alone is not sufficient:
# the row's own n must be > 0.
#' @keywords internal
#' @noRd
.sata_pct_cell <- function(frame, var, cg, level, decimals) {
  one_rows <- .cell_rows(frame, cg, level, val = "1", var = var)
  if (nrow(one_rows) > 0L && !is.na(one_rows$pct[[1L]])) {
    return(round(one_rows$pct[[1L]] * 100, decimals))
  }
  any_rows <- .cell_rows(frame, cg, level, var = var)
  has_base <- nrow(any_rows) > 0L && any(any_rows$n > 0L, na.rm = TRUE)
  if (has_base) 0 else NA_real_
}

# SATA N cell: the overall total N for the item (never per-banner),
# matching the single "N" column layout; same true-zero rule as
# .sata_pct_cell().
#' @keywords internal
#' @noRd
.sata_n_cell <- function(frame, var) {
  total_one <- .cell_rows(
    frame,
    .total_col_group(),
    "Total",
    val = "1",
    var = var
  )
  if (nrow(total_one) > 0L && !is.na(total_one$n[[1L]])) {
    return(total_one$n[[1L]])
  }
  total_any <- .cell_rows(frame, .total_col_group(), "Total", var = var)
  has_base <- nrow(total_any) > 0L && any(total_any$n > 0L, na.rm = TRUE)
  if (has_base) 0L else NA_integer_
}

# -- Cell formatters -----------------------------------------------------------
# .fmt_pct() and .fmt_variance() have one call-site file, R/export-crosstab.R,
# but sit here because the spec places them with the shared helpers (spec 2.1).

# One percentage cell, as a string (spec 3.3). `p` is a proportion, as
# surveycore returns it. This helper multiplies by 100, so no call site does
# the arithmetic. The five forms:
# - `-` when the cell has no rows (`has_rows` is FALSE), or when `p` is NA.
#   The spec allows NA in `p` but names no form for NA with rows present;
#   this reads NA as "no estimate" and writes the no-rows form.
# - `0%` when the estimate is exactly 0.
# - the floor string (`<0.1%` at decimals = 1) for 0 < pp < half a unit.
# - the ceiling string (`>99.9%` at decimals = 1) for a value below 100 that
#   rounds to 100.
# - otherwise round(pp, decimals) with a `%`. round() rounds half to even and
#   drops a decimal part that rounds away, so 41.01 prints `41%`.
# A negative value (a lower interval bound, spec 3.12) takes the last form and
# prints with a hyphen-minus. A negative value that rounds to zero prints `0%`,
# because the spec defines the floor only for 0 < pp and R prints -0 as 0.
#' @keywords internal
#' @noRd
.fmt_pct <- function(p, decimals, has_rows) {
  if (!has_rows || is.na(p)) {
    return("-")
  }
  pp <- p * 100
  if (pp == 0) {
    return("0%")
  }
  half_unit <- 0.5 * 10^-decimals
  if (pp > 0 && pp < half_unit) {
    return(.fmt_pct_limits(decimals)[["floor"]])
  }
  if (pp > 100 - half_unit && pp < 100) {
    return(.fmt_pct_limits(decimals)[["ceiling"]])
  }
  paste0(round(pp, decimals), "%")
}

# The floor and ceiling strings at `decimals` places, as a named character
# vector: c(floor = "<0.1%", ceiling = ">99.9%") at decimals = 1. .fmt_pct()
# writes them in a cell, and .write_cover_sheet() quotes them in the
# `Percentages` glossary entry, so the two always agree.
#' @keywords internal
#' @noRd
.fmt_pct_limits <- function(decimals) {
  unit <- 10^-decimals
  c(
    floor = paste0("<", formatC(unit, format = "f", digits = decimals), "%"),
    ceiling = paste0(
      ">",
      formatC(100 - unit, format = "f", digits = decimals),
      "%"
    )
  )
}

# One variance string, as it appears beside an estimate (spec 3.12). `rows`
# holds the get_freqs() row for this cell, with `se` or `ci_low` and `ci_high`
# as proportions. Every number goes through .fmt_pct(), so this helper does no
# arithmetic and inherits the rounding mode and both threshold strings. The
# interval separator is an en-dash (U+2013) with one space on each side. A
# negative lower bound prints with the hyphen-minus that .fmt_pct() writes.
# Returns "" when `variance` is NULL or the cell has no rows. The exported
# function validates `variance`, so any value other than "se" is "ci" here.
#' @keywords internal
#' @noRd
.fmt_variance <- function(rows, variance, decimals, has_rows) {
  if (is.null(variance) || !has_rows) {
    return("")
  }
  if (identical(variance, "se")) {
    se <- .fmt_pct(rows$se[[1L]], decimals, has_rows)
    return(paste0("(", se, ")"))
  }
  low <- .fmt_pct(rows$ci_low[[1L]], decimals, has_rows)
  high <- .fmt_pct(rows$ci_high[[1L]], decimals, has_rows)
  # The en-dash is built from its code point. `air format` rewrites a
  # backslash-u escape as the literal character, and R CMD check warns on
  # non-ASCII characters in R code.
  en_dash <- intToUtf8(0x2013L)
  paste0("(", low, " ", en_dash, " ", high, ")")
}

# -- Withholding ---------------------------------------------------------------
# .build_withheld() has one call-site file, R/export-crosstab.R, but sits here
# because the spec places it with the shared helpers (spec 2.1).

# The withheld-subgroup frame for one banner column or one interaction
# (spec 3.5). `counts` is a .resolve_eff_n() frame of level, n and n_eff.
# Returns a tibble of level (chr), banner_var (chr) and n_eff (dbl), one row
# per subgroup whose n_eff is strictly below `min_eff_n`, in the order of
# `counts`. Returns a zero-row tibble of the same columns when no subgroup is
# below the floor, and never NULL.
# THIS IS THE ONLY FLOOR TEST. No other code compares an effective N against
# `min_eff_n`; the caller takes the kept levels as a set difference on level.
# A level whose n_eff is NA is not withheld: an NA comparison is not TRUE, and
# the spec states the test as a strict less-than and nothing more.
#' @keywords internal
#' @noRd
.build_withheld <- function(counts, min_eff_n, banner_var) {
  idx <- which(counts$n_eff < min_eff_n)
  tibble::tibble(
    level = as.character(counts$level[idx]),
    banner_var = rep(as.character(banner_var), length(idx)),
    n_eff = as.numeric(counts$n_eff[idx])
  )
}

# The withheld lines, as text (spec 3.14). One element per row of the
# .build_withheld() frame, in frame order. Each line names the subgroup, its
# banner variable and its effective N at one decimal, and no raw N. Returns
# character(0) for a zero-row frame and for NULL.
# The spec fixes what a line names but gives no exact sentence. This wording
# uses the word "withheld" (spec VI) and the label "effective sample size" of
# the sample-size row (spec 3.4), and states the floor so a line read alone in
# a block footer or a console warning still explains itself.
#' @keywords internal
#' @noRd
.format_withheld_lines <- function(withheld, min_eff_n) {
  if (is.null(withheld) || nrow(withheld) == 0L) {
    return(character(0))
  }
  paste0(
    "\"",
    withheld$level,
    "\" (",
    withheld$banner_var,
    ") withheld: effective sample size ",
    formatC(withheld$n_eff, format = "f", digits = 1L),
    ", below the minimum of ",
    format(min_eff_n, scientific = FALSE, trim = TRUE),
    "."
  )
}

# -- Sample-size rows ----------------------------------------------------------
# .write_sample_size_rows() has one call-site file, R/export-crosstab.R, but
# sits here because the spec places it with the shared helpers (spec 2.1).

# The two sample-size rows of one block (spec 3.4). Writes the row label in
# column A, leaves any other label column blank, and writes one cell per row
# of `counts` from column label_cols + 1, in the order of `counts`. The
# unweighted row carries n; the effective row carries n_eff at one decimal and
# is written only when `show_ess` is TRUE. A zero-row `counts` frame writes the
# labels and no data cell. Returns list(wb = , next_row = ).
#' @keywords internal
#' @noRd
.write_sample_size_rows <- function(
  wb,
  sheet,
  start_row,
  label_cols,
  counts,
  show_ess
) {
  rows <- list(list(label = "Unweighted sample size", values = counts$n))
  if (show_ess) {
    rows[[2L]] <- list(
      label = "Effective sample size",
      values = round(counts$n_eff, 1L)
    )
  }

  row <- start_row
  for (r in rows) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = r$label,
      start_row = row,
      start_col = 1L,
      col_names = FALSE
    )
    if (length(r$values) > 0L) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = as.data.frame(matrix(r$values, nrow = 1L)),
        start_row = row,
        start_col = label_cols + 1L,
        col_names = FALSE
      )
    }
    row <- row + 1L
  }

  list(wb = wb, next_row = row)
}
