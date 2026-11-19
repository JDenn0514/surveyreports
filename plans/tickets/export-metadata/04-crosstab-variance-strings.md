# 04: Variance strings, the legend row and the room a variance needs

**What to build:** Under `variance = "se"` or `"ci"`, each crosstab estimate
cell shows the standard error or the interval in parentheses, with one `%`
per number. The new argument `variance_display` puts that value on a second
line of the cell (`"cell"`, the default) or on its own row under the
estimate (`"row"`). A legend row under the question title says what the
parentheses hold. The sheet makes room: wider data columns under `"ci"`,
and wrapped 30-point estimate rows when the value shares the cell. A `-`
cell, and a `0%` cell with no row of its own, carry no variance.

**Blocked by:** 03 (A crosstab percentage cell becomes a string).

**Status:** ready-for-agent

**Branch:** `feature/crosstab-variance-strings`

## Spec

Spec v0.29.0: 2.2 (`.fmt_variance()`), 3.1, 3.2, 3.12, 3.16 (row 3, the
sheet-property rows, and "Where `15 + 2 * decimals` comes from"), 8.1.

## Scenarios

XH-15, XH-16, XH-16a, XH-17, XH-18, XH-19, XH-20, XN-09, XN-10, XB-05,
XB-06, XB-07, XB-08, XB-09, XB-10, XB-14.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)` where its row says "all four".
- [ ] Every written variance string matches `surveycore::get_freqs()` after
      rounding, built in the test and not with `.fmt_variance()`.
- [ ] A `0%` cell whose own row is absent or has `n = 0` reads `0%` alone,
      under both displays. A new test asserts it. No scenario id covers it.
- [ ] `variance_display` sits right after `variance` and before
      `conf_level` in `names(formals(export_crosstab))`. Its `@param` entry
      lists both values, and `devtools::document()` was run.
- [ ] `grep -n "fmt_variance" R/export-crosstab.R` shows one call site per
      render route, and `R/export-crosstab.R` still holds no inline `* 100`.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/feature-crosstab-variance-strings.md` exists.

## Notes

- `.fmt_variance()` is merged, and it lacks the gap 17 guard. Add it: an
  empty string when `rows` is empty or its `n` is 0. This reading is the
  agent's, logged for the user's check in the decision entry "Spec gaps
  settled from the decision page". If the user rejects it, spec 3.12
  changes first.
- The data column width comes from `variance` and `decimals` alone, set
  where the fixed widths are already set. Never read cell content.
- `XB-14` needs no new code once the width variable changes: column B on a
  stacked sheet already takes the larger of 20 and the data width.
- The interval line is 9 points, `#595959` (spec 3.12). Ticket 06 moves
  that colour into `.build_house_style()`. Until then the literal may sit
  in `R/export-crosstab.R`.
- Set the 30-point estimate row height and the wrap in each of the three
  render routes. Ticket 06 later moves both into `.write_block_style()`.
- The legend row is written by `.render_block_preamble()`, at row 3 of
  spec 3.16. A comment there says the legend "comes in a later change".
  Remove it.
- `XB-10` is written here under the older rule. Ticket 06 rewrites it.
