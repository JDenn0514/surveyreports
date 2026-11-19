# fix(export): keep the code order of a labelled banner in crossed columns

**Date**: 2026-11-19
**Branch**: fix/labelled-banner-crossed-order

## Changes

Ticket 02 of `plans/tickets/export-metadata/`, spec v0.29.0 sections 2.2, 3.8
(gap 15) and 3.19. A crossed column group on a banner of numeric codes with
value labels now lists its levels in code order, the same order as the
banner's own group. Before, the crossed group sorted the labels
alphabetically, so one sheet listed the same levels in two orders. A factor
banner keeps its order, as before. No formal argument changes, so no `man/`
file moves.

### `R/export-utils.R`

- `.banner_levels_labelled()`: a column with value labels comes back as a
  factor. Its levels are the labels in ascending order of their codes.
  - A label on two codes is one level, at the position of its lowest code.
    `factor()` rejects a duplicate level.
  - A label whose code holds no row is an unused level. `interaction()` then
    builds crossed levels with no rows, and surveycore drops them, so no
    column and no withheld line appears.
  - A code with no label still becomes `NA`. A factor still comes back
    unchanged, and any other column as character.
- `.build_interaction_design()`: comment only. Its one caller of the helper
  is unchanged.

The withheld frame of a crossed cell reads the same synthetic column, so its
level strings do not change. Only their order can move.

## Tests

- `tests/testthat/test-export-crosstab.R`:
  - Section 27, after XH-05: new XH-05a. It builds the
    expected crossed order from the codes, less the empty `Female x North`
    cell, and compares an ordered character vector. It checks the `Gender`
    group order, and the `Male x South` cells (second in code order, third
    in alphabetical order) against `surveycore::get_freqs()` on the
    interaction subgroup. It also checks the XX-07 `Other = 3` fixture once,
    crossed, at `min_eff_n = 50`: no `Other` or `Female x North` column or
    withheld line, and `Female x South` is withheld.
  - Section 19: three new direct tests of `.banner_levels_labelled()`: code
    order against label and row order, a duplicate label, and an unused
    label.
- Every block loops all four designs.
- Failed first: XH-05a, on all four designs, with the alphabetical order
  `Male x North`, `Female x South`, `Male x South`.
- Still pass: XH-03, XH-04, XH-05, XH-06, XW-06, XW-07, XX-07, XX-08.

Existing tests changed, because the spec now asks for a factor:

- ".banner_levels_labelled() translates codes to value labels" asserted a
  character result. It now asserts a factor, the level order `Male`,
  `Female`, and the per-row values through `as.character()`.
- ".banner_levels_labelled() maps an unlabelled code to NA, as get_freqs()
  does" compared `unique(result)` with a character vector. It now compares
  `as.character(unique(result))`. The assertion is the same set test.

No snapshot is new or moved.

Gate runner (`.claude/scripts/run-gates.sh`), all gates pass:

- Tests: 0 failures, 0 warnings, 0 skips, 4060 expectations
- Coverage: 99.85%. `R/export-utils.R` has one uncovered line (85), outside
  this change.
- R CMD check: 0 errors, 0 warnings, 3 notes. Two are approved (CRAN
  incoming, no visible binding). The third names a hidden `.git`: in a git
  worktree `.git` is a file, and R CMD build drops only a `.git` folder.
- `document()`, R CMD build and `check_pkgdown()` pass
- `air format --check` passes

## Files Modified

- `R/export-utils.R` — `.banner_levels_labelled()` returns a factor in code
  order for a labelled column
- `tests/testthat/test-export-crosstab.R` — XH-05a, three direct tests, two
  test edits
- `changelog/fix-labelled-banner-crossed-order.md` — new; this file
