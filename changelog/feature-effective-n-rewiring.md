# fix(export): take the reported effective N from surveycore

**Date**: 2026-11-13
**Branch**: feature/effective-n-rewiring

## Changes

PR 7 of `plans/impl-export-metadata.md`. `.compute_eff_n()` reported an
effective N larger than the rows of the table it labelled, on a two-phase
design and on a design restricted to a domain. On the test designs the
topline header read `Eff N=185` where surveycore gives 110 (two-phase) and
69 (restricted to one group). `.resolve_eff_n()`, which wraps
`surveycore::get_effective_n()`, now supplies the number at every call site.

- `.build_freq_frame()`, single design: calls `.resolve_eff_n(design)` once
  and puts its `n_eff` on the total rows.
- `.build_freq_frame()`, collection: calls `.resolve_eff_n()` once and joins
  on the wave name. The pooled Total has no wave name, so it carries no
  effective N. `export_topline(collection, show_eff_n = TRUE)` now returns
  the path.
- The `pub_type` suppression loop: a holding change. It reads each banner
  level's effective N from `.resolve_eff_n(design, group_var = banner_var)`.
  The thresholds do not change. `feature/crosstab-min-eff-n` rewrites the
  loop.
- Deleted: `.compute_eff_n()` with its three `# nocov` markers; the subgroup
  branch that joined its values onto banner rows, which no code read; the
  effective-N branch of the collection `Total` heading in
  `export_topline()`; and the `NA` fallback of the single-design `%`
  heading, which can no longer be reached.

`grep -rn "compute_eff_n" R/` returns nothing.

Readings the plan leaves open:

- TN-02's "reported N". The N cell of the Total row was already right on
  every design. The test also asserts that the effective N in the `%`
  heading equals `round(get_effective_n(d)$n_eff)`, and that assertion is
  the one that failed first.
- In the `pub_type` loop, a banner level with no in-scope row gets an
  effective N of 0.

## Tests

`tests/testthat/test-export-topline.R`, new section 14: TN-01 (two blocks,
one on a 2,000-row design so the thousands separator shows), TN-02, TN-03,
TN-04 and TC-08. TN-02 loops over the four designs, each unrestricted and
restricted to one group. One existing block is renamed, because the
collection Total heading no longer carries an effective N.

No snapshot moved: `_snaps/export-topline.md` holds no `show_eff_n`
snapshot. Coverage rose from 99.46% to 99.77%. The seven uncovered lines in
`R/export-topline.R` and `R/export-utils.R` were deleted with the dead code.

## Files Modified

- `R/export-utils.R` — every call site moved to `.resolve_eff_n()`;
  `.compute_eff_n()` deleted
- `R/export-topline.R` — the dead effective-N branches deleted
- `tests/testthat/test-export-topline.R` — section 14; one block renamed
- `changelog/feature-effective-n-rewiring.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 7 complete
