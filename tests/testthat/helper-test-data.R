#' @keywords internal
make_surveyreports_data <- function(n = 100L, seed = 42L) {
  set.seed(seed)
  data.frame(
    x = rnorm(n),
    y = rnorm(n),
    g = sample(c("A", "B"), n, replace = TRUE)
  )
}

#' @keywords internal
test_invariants <- function(obj) {
  expect_true(!is.null(obj))
}
