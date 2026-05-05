#' @keywords internal
make_survey_data <- function(n = 200L, n_psu = 10L, n_strata = 5L, seed = 42L) {
  set.seed(seed)
  data.frame(
    psu     = rep(seq_len(n_psu), each = n %/% n_psu),
    strata  = rep(seq_len(n_strata), length.out = n),
    fpc     = rep(500L, n),
    wt      = runif(n, 0.5, 1.5),
    y1      = rnorm(n),
    y2      = rnorm(n, 5, 2),
    y3      = rnorm(n, 10, 3),
    q1      = sample(c("Agree", "Neutral", "Disagree"), n, replace = TRUE),
    q2      = sample(c("Yes", "No"), n, replace = TRUE),
    group   = sample(c("A", "B", "C"), n, replace = TRUE),
    sata_a  = sample(0L:1L, n, replace = TRUE),
    sata_b  = sample(0L:1L, n, replace = TRUE),
    sata_c  = sample(0L:1L, n, replace = TRUE),
    bat_1   = sample(1L:5L, n, replace = TRUE),
    bat_2   = sample(1L:5L, n, replace = TRUE),
    bat_3   = sample(1L:5L, n, replace = TRUE),
    in_phase2  = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.6, 0.4)),
    all_na_var = NA_character_
  )
}

#' @keywords internal
make_all_designs <- function(seed = 42L) {
  skip_if_not_installed("surveycore")

  df <- make_survey_data(seed = seed)
  n_psu <- length(unique(df$psu))
  psus  <- unique(df$psu)

  # Taylor series design
  taylor <- surveycore::as_survey(
    df,
    ids     = psu,
    strata  = strata,
    weights = wt,
    nest    = TRUE
  )

  # JK1 replicate design: delete-one-PSU jackknife
  df_rep <- df
  for (i in seq_along(psus)) {
    df_rep[[paste0("rwt", i)]] <-
      df_rep$wt * ifelse(df_rep$psu == psus[[i]], 0, n_psu / (n_psu - 1L))
  }
  rw_cols   <- paste0("rwt", seq_along(psus))
  replicate <- surveycore::as_survey_replicate(
    df_rep,
    weights    = wt,
    repweights = tidyselect::all_of(rw_cols),
    type       = "JK1",
    scale      = (n_psu - 1L) / n_psu,
    rscales    = rep(1, n_psu)
  )

  # Two-phase design (approx method — no phase-2 design variables required)
  twophase <- surveycore::as_survey_twophase(
    phase1 = taylor,
    subset = in_phase2,
    method = "approx"
  )

  # Apply SATA and battery metadata to all three designs
  sata_vars    <- c("sata_a", "sata_b", "sata_c")
  bat_vars     <- c("bat_1", "bat_2", "bat_3")
  sata_preface <- rep("Which of the following apply to you?", length(sata_vars))
  bat_preface  <- rep("Please rate the following items:", length(bat_vars))

  apply_meta <- function(d) {
    d <- surveycore::set_sata(d, variable = sata_vars)
    d <- surveycore::set_question_preface(d, variable = sata_vars, preface = sata_preface)
    d <- surveycore::set_question_preface(d, variable = bat_vars, preface = bat_preface)
    d
  }

  list(
    taylor    = apply_meta(taylor),
    replicate = apply_meta(replicate),
    twophase  = apply_meta(twophase)
  )
}
