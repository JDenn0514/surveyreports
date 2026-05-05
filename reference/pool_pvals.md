# Pool p-values across a list of analysis results and apply a single family-wise multiplicity correction

Row-binds a list of analysis result tibbles (each carrying a `p_value`
column produced by
[`surveycore::get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.html),
[`surveycore::get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.html),
[`surveycore::get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.html),
[`surveycore::get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.html),
`surveycore::clean.survey_glm_fit()`, or any future `get_*()` carrying a
`p_value` column) into a single family and applies
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) once across
the entire pool.

## Usage

``` r
pool_pvals(
  results,
  method = "BH",
  p_col = "p_value",
  new_col = "p_value_adj",
  id_col = "source",
  strip_within_adj = FALSE
)
```

## Arguments

- results:

  A list (named or unnamed) of tibbles / data frames. Every element must
  contain a column named per `p_col`. Length must be at least one. List
  elements may have heterogeneous column sets; missing columns are
  NA-filled on bind.

- method:

  Character(1). Adjustment method, passed verbatim to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). One of
  [`stats::p.adjust.methods`](https://rdrr.io/r/stats/p.adjust.html).
  Default `"BH"`.

- p_col:

  Character(1). Name of the column holding raw p-values to be pooled.
  Default `"p_value"`. Must exist in every list element.

- new_col:

  Character(1). Name of the column where pooled- adjusted p-values are
  written. Default `"p_value_adj"`.

- id_col:

  Character(1). Name of the source-identifier column added to the bound
  output. Default `"source"`. Filled from list names; for unnamed
  elements the integer index is coerced to character (matching
  `dplyr::bind_rows(.id = ...)` semantics).

- strip_within_adj:

  Logical(1). If `FALSE` (default) and any input contains a column named
  per `new_col`, that column is renamed to `paste0(new_col, "_within")`
  per element before binding, and a warning is emitted. If `TRUE`, any
  pre-existing `new_col` column is silently dropped from each element
  before binding; no warning.

## Value

An object of S3 class
`c("survey_pooled_pvals", "tbl_df", "tbl", "data.frame")` – a tibble
with an additional class tag. Column ordering: (1) the union of input
columns in input-union order; (2) `id_col`; (3) `new_col`; (4)
`paste0(new_col, "_within")` if applicable. The result carries a `.meta`
attribute (a list) with keys `method`, `family_size`, `n_total`, `n_na`,
`n_significant_05`, `id_col`, `p_col`, and `new_col`.

## Details

### Method choice

`pool_pvals()` dispatches verbatim to
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html); the
adjustment formula is determined entirely by `method`.

- `"BH"` (Benjamini-Hochberg, 1995) – controls the false discovery rate
  (FDR) under independence or positive regression dependency (PRDS).
  Recommended default for multi-DV survey families.

- `"BY"` (Benjamini-Yekutieli, 2001) – controls FDR under arbitrary
  dependence; strictly more conservative than BH. Use when the
  dependence structure across DVs is unknown or arbitrary.

- `"fdr"` – alias for `"BH"` per
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) source.
  The two are identical.

- `"holm"` (Holm, 1979) – controls the family-wise error rate (FWER)
  under arbitrary dependence. Uniformly more powerful than Bonferroni.

- `"hochberg"` (Hochberg, 1988) – controls FWER, requires independence
  or MTP_2 dependence (not just PRDS). Use Holm instead when DVs are
  correlated and FWER control is desired.

- `"hommel"` (Hommel, 1988) – controls FWER, requires independence or
  MTP_2 dependence. Same caveat as Hochberg.

- `"bonferroni"` – controls FWER under any dependence structure
  (Bonferroni's inequality). Most conservative of the FWER procedures;
  preferred for tiny families.

- `"none"` – pass-through; raw p-values returned in `new_col`.

### Default method

The default `method = "BH"` reflects the typical structure of survey
p-values across DVs, which are usually positively dependent (PRDS) but
rarely independent. When the dependence structure is unknown or known to
be arbitrary, switch to `method = "BY"` for a robust FDR-controlling
alternative.

### Recommended workflow

Set `pval_adj = NULL` on every upstream `get_*()` call when planning to
pool, so within-call adjustment is not produced and `pool_pvals()`
applies the global correction once. Note that attributes carried on
input tibbles (e.g., `variable_label` from `get_diffs()` results) are
NOT preserved on the output; this matches
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
default behavior. Users who need attribute preservation must re-attach
the attribute after pooling.

### Statistical caveat about double-adjustment

surveycore's `get_t_test()`, `get_pairwise()` (default
`pval_adj = "holm"`), and `get_diffs()` overwrite the `p_value` column
in place when `pval_adj != NULL`. `pool_pvals()` cannot detect this by
column inspection alone – the
`surveyreports_warning_pool_pvals_input_pre_adjusted` warning class only
fires when a separate column matching `new_col` is present. Pass
`pval_adj = NULL` upstream to avoid silent double-adjustment.

### Worked NA-denominator example

With pooled p-values `(0.01, 0.02, 0.05, NA, NA)` and `method = "BH"`,
the BH denominator is `n = sum(!is.na(p)) = 3` (not 5); adjusted values
are `(0.03, 0.03, 0.05, NA, NA)`.

### Column-shape user-owned risk

Column shapes and the semantic coherence of any `group` column must be
checked by the user; `pool_pvals()` does not validate semantic coherence
across input elements.

### Cross-design pooling caveat

When results come from different surveys, sampling frames, or weighting
schemes, the user is responsible for ensuring exchangeability across the
pool.

### Small-m regime

BH and related step-up methods become very conservative when `m < 5`
(the family size). Consider `method = "bonferroni"` or
unadjusted-with-exploratory-framing for tiny families.

### `"fdr"` alias note

`"fdr"` is a dispatch alias for `"BH"` per
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) source; the
two produce identical output.

### Discrete p-value caveat

Classical BH assumes continuous p-values. Chi-square tests of small
contingency tables can produce ties that violate this. See the
`DiscreteFDR` package on CRAN for that regime.

### Collection workflow

Users with results from a collection-dispatched `get_*()` call (a single
tibble carrying a `.id` / `.survey` column) should split into per-`.id`
tibbles via
[`dplyr::group_split()`](https://dplyr.tidyverse.org/reference/group_split.html)
before passing to `pool_pvals()`.

### See also

Storey (2002) q-values, Romano-Wolf (2005) bootstrap stepdown, and the
`multcomp` / `mutoss` packages provide multiplicity machinery
surveyreports does not implement.

## References

Benjamini, Y. and Hochberg, Y. (1995). Controlling the False Discovery
Rate: A Practical and Powerful Approach to Multiple Testing. *Journal of
the Royal Statistical Society, Series B* 57(1), 289-300.
[doi:10.1111/j.2517-6161.1995.tb02031.x](https://doi.org/10.1111/j.2517-6161.1995.tb02031.x)

Benjamini, Y. and Yekutieli, D. (2001). The control of the false
discovery rate in multiple testing under dependency. *Annals of
Statistics* 29(4), 1165-1188.
[doi:10.1214/aos/1013699998](https://doi.org/10.1214/aos/1013699998)

Holm, S. (1979). A simple sequentially rejective multiple test
procedure. *Scandinavian Journal of Statistics* 6(2), 65-70.

Hochberg, Y. (1988). A sharper Bonferroni procedure for multiple tests
of significance. *Biometrika* 75(4), 800-802.
[doi:10.1093/biomet/75.4.800](https://doi.org/10.1093/biomet/75.4.800)

Hommel, G. (1988). A stagewise rejective multiple test procedure based
on a modified Bonferroni test. *Biometrika* 75(2), 383-386.
[doi:10.1093/biomet/75.2.383](https://doi.org/10.1093/biomet/75.2.383)

## See also

[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) for the
underlying adjustment engine,
[`surveycore::get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.html)
and
[`surveycore::get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.html)
for upstream functions that produce the `p_value` column

Other multiplicity correction:
[`print.survey_pooled_pvals()`](https://jdenn0514.github.io/surveyreports/reference/print.survey_pooled_pvals.md)

## Examples

``` r
df <- data.frame(
  y1 = c(1.2, 0.8, 2.1, 1.5, 0.9, 1.8),
  y2 = c(2.3, 1.1, 2.8, 0.7, 1.9, 2.2),
  sex = c("M", "F", "M", "F", "M", "F"),
  wt = c(1.1, 0.9, 1.2, 0.8, 1.0, 1.1)
)
d <- surveycore::as_survey(df, weights = wt)
r1 <- surveycore::get_diffs(d, y1, sex, pval_adj = NULL)
#> Warning: ! sex coerced to factor.
#> Warning: ! Treatment level "F" has only 3 observations (threshold: 30).
#> Warning: ! Treatment level "M" has only 3 observations (threshold: 30).
r2 <- surveycore::get_diffs(d, y2, sex, pval_adj = NULL)
#> Warning: ! sex coerced to factor.
#> Warning: ! Treatment level "F" has only 3 observations (threshold: 30).
#> Warning: ! Treatment level "M" has only 3 observations (threshold: 30).
pool_pvals(list(y1 = r1, y2 = r2))
#> <survey_pooled_pvals: method = "BH", family_size = 2, 0 significant at alpha =
#> 0.05>
#> # A tibble: 4 × 10
#>   sex   estimate  mean     n ci_low ci_high p_value stars source p_value_adj
#>   <fct>    <dbl> <dbl> <int>  <dbl>   <dbl>   <dbl> <chr> <chr>        <dbl>
#> 1 F       0       1.39     3 NA       NA     NA     ""    y1          NA    
#> 2 M       0.0435  1.44     3 -1.15     1.24   0.924 ""    y1           0.924
#> 3 F       0       1.42     3 NA       NA     NA     ""    y2          NA    
#> 4 M       0.943   2.36     3 -0.391    2.28   0.121 ""    y2           0.242
#> # 2 p-values were NA and excluded from the family
```
