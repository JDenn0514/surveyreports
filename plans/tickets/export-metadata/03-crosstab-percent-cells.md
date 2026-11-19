# 03: A crosstab percentage cell becomes a string

**What to build:** Every estimate cell that `export_crosstab()` writes is
text in one of five forms: a rounded percentage such as `41.2%`, `0%`, the
floor string (`<0.1%` at one decimal), the ceiling string (`>99.9%`), or
`-`. The whole banner column decides between `0%` and `-` (gap 17): `0%`
when people in that column answered and nobody chose the category, `-` when
nobody there answered or the question was never asked there. The rule is
the same in single-response, SATA and battery blocks. `export_topline()`
does not change.

**Blocked by:** the branch `fix/sata-chosen-code-1` (SATA items: code 1 is
the chosen value) must merge to `develop` first. It is not a ticket here.

**Status:** ready-for-agent

**Branch:** `feature/crosstab-percent-cells`

## Spec

Spec v0.29.0: 2.2 (`.fmt_pct()`), 2.3, 3.3 (with the gap 17 rule and the
code-1 rule that `fix/sata-chosen-code-1` adds), 4.1, 4.2, VIII (the `* 100`
grep), 8.1.

## Scenarios

XC-01, XC-02, XC-03, XC-04, XC-05, XC-05a, XC-05b, XC-06, XC-06a, XC-07,
XC-07a, XC-08.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)` where its row says "all four".
- [ ] Every written cell string matches `surveycore::get_freqs()` after
      rounding, built in the test and not with `.fmt_pct()`.
- [ ] No estimate cell is numeric, and none reads `100.0%`.
- [ ] `R/export-crosstab.R` holds no inline `* 100`. Every estimate reaches
      `.fmt_pct()` as a proportion.
- [ ] No `export_topline()` snapshot moved. Every moved crosstab snapshot
      was reviewed with `testthat::snapshot_review()`.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/feature-crosstab-percent-cells.md` exists.

## Notes

- Compute `has_rows` over every `get_freqs()` row of the variable (the
  question, or the SATA or battery item) in that banner column. When it is
  `TRUE` and the cell's own row is absent or has `n = 0`, pass `p = 0`. The
  old plan's per-cell test, `nrow(rows) > 0 && rows$n > 0`, is the rule
  gap 17 replaced. Do not use it.
- A column whose every row has `n = 0` still gives `-`: `get_freqs()` emits
  placeholder rows.
- The SATA route stops calling `.sata_pct_cell()`. Read the chosen row from
  the `sata_chosen` column that `fix/sata-chosen-code-1` adds to the frame.
  Do not test for a literal `"1"`. `.sata_pct_cell()` stays unchanged for
  `export_topline()`.
- Spec VIII expects `grep -rn "\* 100" R/` to return four lines after this
  ticket. One of them is `pp <- p * 100` inside `.fmt_pct()`, which is
  correct. Do not rewrite `.fmt_pct()` to remove it.
- No variance is written yet, so the gap 17 variance rule (a `0%` cell with
  no row of its own carries no variance) lands in ticket 04.
- The `Percentages` glossary entry stays absent until ticket 05 passes
  `string_cells = TRUE`. That lag is expected.
- No formal argument changes, so no `man/` file moves.
