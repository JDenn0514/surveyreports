# 05: The Total column, missing data and the block row order

**What to build:** The Total column of a crosstab takes the heading
`total_label`. Its default reads `Full Sample` on an unrestricted design and
`Total` on a domain-restricted one, and its spanner cell is empty.
`show_total = FALSE` removes the group. `na.rm = FALSE` adds a response row
and a banner level labelled `na_label`, and that banner level faces the
floor like any other. An all-NA variable is still dropped with a warning
under `na.rm = FALSE`. The glossary gains its `Percentages` entry, and the
whole block row order and the final argument order are pinned.

**Blocked by:** 04 (Variance strings, the legend row and the room a variance
needs) and 01 (About sheet glossary text). `XA-05` asserts the glossary
texts that ticket 01 writes.

**Status:** ready-for-agent

**Branch:** `feature/crosstab-total-and-missing`

## Spec

Spec v0.29.0: 2.2 (`.has_domain()`, `.resolve_eff_n()`), 2.3
(`.total_col_group()` and the three frequency helpers), 3.1, 3.2, 3.5,
3.9, 3.11 (step 15), 3.13, 3.15, 3.16, 3.18, 3.19, VIII.

## Scenarios

XH-08, XH-08a, XH-08b, XH-09, XH-09a, XH-11, XH-12, XH-13, XH-14, XX-13,
XX-17, XA-05, XA-05a, XR-01, XR-02, XN-06, XN-07, XN-08.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)` where its row says "all four".
- [ ] Every Total, banner and interaction cell string matches
      `surveycore::get_freqs()` after rounding (`XN-06` to `XN-08`).
- [ ] `names(formals(export_crosstab))` is identical to the order of spec
      3.1. `show_total` has not moved.
- [ ] `@param total_label`, `@param na.rm` and `@param na_label` are
      written, `@param show_total` is corrected, and `devtools::document()`
      was run.
- [ ] `surveycore_error_all_na` never reaches the caller.
- [ ] No `export_topline()` snapshot moved. Every moved crosstab snapshot
      was reviewed with `testthat::snapshot_review()`.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/feature-crosstab-total-and-missing.md` exists.

## Notes

- `.total_col_group()` gains `total_label` and `spanner`, both defaulting to
  `"Total"`. `export_crosstab()` passes the resolved label and
  `spanner = ""` at its three call sites. `export_topline()` and
  `.sata_n_cell()` keep calling it with no arguments.
- Resolve the `NULL` default of `total_label` before the counts frame is
  built: the frame's Total row carries the resolved label, never `NULL`.
- Pass the same `na.rm` to `.compute_total_freq()`,
  `.compute_subgroup_freq()`, `.compute_interaction_freq()` and
  `.resolve_eff_n()`. If `.resolve_eff_n()` misses it, the missing-value
  column has no counts row and escapes the floor. The fifth site of spec
  3.13, the topline collection path, is out of scope: `export_topline()`
  takes no `na.rm`.
- Under `na.rm = FALSE` the three frequency helpers catch
  `surveycore_error_all_na` by class with `tryCatch()` and return the
  zero-row frame. Catch no other class, and nothing under `na.rm = TRUE`.
  Tests must not use `tryCatch()`.
- `XH-09a` runs on the single-response route alone. State the reason in the
  block description, as the row says.
- `XX-13` raises exactly two warnings. Assert that no third one arrives.
- Pass `string_cells = TRUE` to `.build_workbook()`. The `Percentages`
  entry then appears for the first time in a real workbook.
- `XR-01` and `XR-02`: an unwritten cell reads back as `NA`. Normalise `NA`
  and `""` before the comparison.
