# fix(export): state the minimum and the dash cases in the About glossary

**Date**: 2026-11-19
**Branch**: fix/about-glossary-text

## Changes

Ticket 01 of `plans/tickets/export-metadata/`. The glossary on the `"About"`
sheet now says only what is true of the workbook. Three user decisions of
2026-11-19 (gaps 14, 17 and 19 of spec v0.29.0) change the merged text.

### `R/export-utils.R`

- `.write_cover_sheet()`, `Why a column is missing` (gap 14): the entry
  states the minimum as a number, as `The minimum for this workbook is an
  effective sample size of 50.` The number is written with
  `format(min_eff_n, scientific = FALSE, trim = TRUE)`, the form of the
  withheld line and of the minimum row. The old text, "is listed above",
  was false under `withheld_note = "every"` and `"none"`, which write no
  withheld block. The helper still takes no `withheld_note` argument.
- `.write_cover_sheet()`, `Percentages` (gap 17): the dash sentence reads
  `A dash means nobody in that column answered the question, or it was never
  asked there.` Under the whole-column test of spec 3.3, an answer nobody
  chose reads `0%`, so the old sentence named a case that does not read `-`.

### `R/export-topline.R`

- `export_topline()` no longer passes `variance` to `.build_workbook()`
  (gap 19). The `NULL` default reaches the cover sheet, so a topline
  workbook carries the two sample-size entries and no `Confidence
  intervals` entry at any `variance` value. `variance` still reaches
  `get_freqs()`. The comment above the call is corrected.
- `@param variance` says the value has no visible effect yet (spec 7.2).
  `man/export_topline.Rd` is regenerated.

No cell of the `"Topline"` sheet or of a crosstab data sheet changes.

## Tests

- `tests/testthat/test-export-crosstab.R`:
  - New `XA-05b`: the entry states the minimum at `withheld_note = "once"`,
    `"every"` and `"none"` (floor 50), and at floor 12.5. No About cell
    holds `listed above`.
  - `XW-10` and `XW-11` gain the glossary assertions: the entry states the
    minimum, and no About cell holds `listed above`.
  - New direct `.write_cover_sheet()` test with `string_cells = TRUE` at
    `decimals` 0, 1 and 2: the `Percentages` entry ends with the dash
    sentence of spec 3.15, word for word.
  - Re-check rows: `XW-07` now asserts `Not shown` in column A on every line
    of the withheld block. `XA-06` now asserts `Not shown` beside `None`.
    `XW-08`, `XA-03` and `XA-04` already held every clause of their v0.24.0
    rows; no change.
  - New helpers `glossary_missing_text()`, `glossary_dash_sentence`,
    `about_withheld_rows()` and `about_holds()`.
- `tests/testthat/test-export-topline.R`: `TP-06a` rewritten.
- Every block loops all four designs.

Existing tests changed, because they held the old text (the ticket names
them):

- `glossary_text$missing` held "listed above". It is now
  `glossary_missing_text(100)`.
- `glossary_text$pct` and the two `decimals = 0` and `decimals = 2`
  expected strings held "not chosen ... never offered there". They now end
  with `glossary_dash_sentence`.
- `TP-06a` asserted the `Confidence intervals` entry present. It now
  asserts the two sample-size entries and no other.
- `topline_glossary_text$ci` is deleted: no topline test reads it now.

No snapshot is new or moved.

Failed first, on the old code: XA-05b, XW-10, XW-11, the five-term test,
the three `Percentages` tests and the new dash-sentence test. The XW-07 and
XA-06 additions passed on the old code, as re-check rows should.

## Readings the spec leaves open

- XA-05b: the test-spec row says the `XA-05` call at `min_eff_n = 50`
  withholds nothing and raises no warning. On the `make_all_designs(seed =
  42)` fixture it withholds `B` (effective N 47.7) on taylor, replicate and
  nonprob, and every `group` level on twophase. The entry text does not
  depend on this, so the test keeps the floor at 50 and absorbs the two
  withholding warning classes. `XA-05` (ticket 05) uses the same call and
  will meet the same fact.

Gate runner (`.claude/scripts/run-gates.sh`):

- Tests: 0 failures, 0 warnings, 4094 expectations
- R CMD check: 0 errors, 0 warnings, 3 notes. Two are the approved notes.
  The third names the `.git` file of the git worktree the check ran in.
- Coverage: 99.85%. The one uncovered line in a changed file,
  `R/export-utils.R:85`, is outside this change.
- `document()`, R CMD build and `check_pkgdown()` pass
- `air format --check` passes

## Files Modified

- `R/export-utils.R` — the two glossary texts
- `R/export-topline.R` — the `.build_workbook()` call, its comment, and
  `@param variance`
- `man/export_topline.Rd` — regenerated
- `tests/testthat/test-export-crosstab.R` — the scenarios and helpers above
- `tests/testthat/test-export-topline.R` — `TP-06a`, the `ci` constant
- `changelog/fix-about-glossary-text.md` — new; this file
