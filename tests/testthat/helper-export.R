# Shared helpers for test-export-topline.R and test-export-crosstab.R.

# surveycore 1.2.0 warns on every survey_nonprob estimate when the design has
# no bootstrap replicate weights: its standard errors then use an SRS
# approximation. The fixture's nonprob design has no replicate weights, so
# every estimate on it raises that warning. No test here is about it.
#
# quiet_nonprob() evaluates `expr` and muffles that one class and no other.
# Every surveyreports warning still reaches an expect_warning() around the
# call, and an expect_no_warning() still sees any other warning.
quiet_nonprob <- function(expr) {
  suppressWarnings(
    expr,
    classes = "surveycore_warning_nonprob_srs_fallback"
  )
}

# export_topline() and export_crosstab() with that one warning muffled. A
# snapshot calls the export function directly, on the taylor design, which
# raises no such warning.
topline_quiet <- function(...) {
  quiet_nonprob(export_topline(...))
}

crosstab_quiet <- function(...) {
  quiet_nonprob(export_crosstab(...))
}

# The About sheet as a data frame of columns A and B, one row per sheet row.
# Blank rows stay in the frame, so a row index is a sheet row minus 1.
about_sheet <- function(path) {
  df <- openxlsx2::wb_to_df(
    path,
    sheet = "About",
    col_names = FALSE,
    cols = 1:2
  )
  data.frame(
    A = as.character(df[[1L]]),
    B = as.character(df[[2L]]),
    stringsAsFactors = FALSE
  )
}

# The glossary of an About sheet, term = text, in sheet order: the rows below
# the "What these numbers mean" heading.
about_glossary <- function(about) {
  start <- match("What these numbers mean", about$A)
  rows <- about[seq.int(start + 1L, nrow(about)), ]
  stats::setNames(rows$B, rows$A)
}

# A design whose q1, q2 and group carry variable labels, so the missing-label
# warning does not fire in a test about the cover sheet.
cover_design <- function(d) {
  surveycore::set_var_label(
    d,
    q1 = "Question one",
    q2 = "Question two",
    group = "Group"
  )
}
