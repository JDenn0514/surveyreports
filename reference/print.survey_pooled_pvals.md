# Print a `survey_pooled_pvals` object

Prints a one-line `cli` header summarizing the adjustment method, family
size, and number of significant rows; delegates the body to tibble's
print method via
[`NextMethod()`](https://rdrr.io/r/base/UseMethod.html); and prints a
one-line footer when any p-values were excluded as NA.

## Usage

``` r
# S3 method for class 'survey_pooled_pvals'
print(x, n = 10, ...)
```

## Arguments

- x:

  A `survey_pooled_pvals` object.

- n:

  Integer(1). Maximum number of rows to print. Passed through to
  `print.tbl_df`. Default `10`.

- ...:

  Additional arguments passed to `print.tbl_df`.

## Value

`invisible(x)`.

## See also

Other multiplicity correction:
[`pool_pvals()`](https://jdenn0514.github.io/surveyreports/reference/pool_pvals.md)

## Examples

``` r
res <- list(
  a = tibble::tibble(p_value = c(0.01, 0.04)),
  b = tibble::tibble(p_value = 0.5)
)
out <- pool_pvals(res)
print(out)
#> <survey_pooled_pvals: method = "BH", family_size = 3, 1 significant at alpha =
#> 0.05>
#> # A tibble: 3 × 3
#>   p_value source p_value_adj
#>     <dbl> <chr>        <dbl>
#> 1    0.01 a             0.03
#> 2    0.04 a             0.06
#> 3    0.5  b             0.5 
```
