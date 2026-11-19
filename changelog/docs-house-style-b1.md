# docs(docs): write house style B1 into the spec and the plan

**Date**: 2026-11-19
**Branch**: docs/house-style-b1

## Changes

The user chose a new house style for `export_crosstab()` and
`export_topline()` from mockup workbooks. This PR writes it into the plans.
No R code or test changes.

### How the style was chosen

- A mockup built from the spec alone (`plans/mockups/`) showed that the spec
  had no fills, no borders and little wrapping or merging. It also found 22
  places where the spec was silent or contradicted itself
  (`plans/mockups/spec-gaps.md`).
- Four style directions (A to D) were built on the same content. The user
  picked B and asked for changes: shading to set rows apart, a rule between
  column groups, the navy band on the question text only, the interval on its
  own line in the cell, and frozen label columns and group rows.
- Three revisions (B1 to B3) followed. The user picked B1 and confirmed in
  desktop Excel that the freeze panes and two-line cells show.

### Spec (`plans/spec-export-metadata.md`, v0.28.0)

- New section 3.21, "House style": named colours, workbook rules, the crosstab
  block for both layouts, the topline sheet, the About sheet, the row-height
  formula, and where the style code lives (`R/export-utils.R`).
- Older rules replaced, each marked in place: 3.4 (no fill or border on the
  sample-size rows), 3.12 (the estimate row height and wrap), 3.14 (About
  sheet styling), 3.16 (wrapping, row heights, and the freeze pane, which now
  also freezes the label columns), and the "no presentation change" lines for
  `export_topline()` in 1.3, 2.1 and 4.1.
- Gaps 1 to 7, 10, 11, 13 and 20 of `spec-gaps.md` are closed by B1.

### Plan and test-spec

- New PR 19, `feature/house-style`, after PR 18: 33 scenarios (XY-01 to
  XY-23 for the crosstab and About sheet, TY-01 to TY-10 for the topline).
  The tests load the saved workbook and check fonts, fills, borders, merges,
  wrap, row heights, widths and freeze panes on all four designs.
- The docs PR becomes PR 20. Every reference is updated.
- The topline rows depend on open gap 22 (whether the style reaches
  `export_topline()` now). The user decides it with the other open gaps.
- XB-03, XB-04 and XB-09 to XB-13 say what holds after the house style.

### Decisions log

- New entry "[2026-11-19] — House style B1".

### Reference files

- `plans/mockups/build-mockups.R` builds every variant from one style list.
- `plans/mockups/variants/B1-*.xlsx` are the reference workbooks, and
  `plans/mockups/variants/README.md` holds the style tables.
- `plans/mockups/spec-gaps.md` lists the 22 gaps. The other variant files
  stay out of git.

### Spec gaps settled, and tickets (second commit)

- The user answered 13 open questions on a decision page. Spec v0.29.0 and
  test-spec v0.24.0 hold the answers. The decisions log has the entry "Spec
  gaps settled from the decision page". Gap 16 is closed by the user's chat
  answer (code 1 is the chosen SATA value).
- New and changed scenarios include XC-06a, XH-05a, XA-05b, TY-11 and XY-24.
  TP-06a now asserts that no topline "Confidence intervals" entry exists.
- Spec VIII: the `* 100` grep now expects four lines, not three.
- Eight tickets in `plans/tickets/export-metadata/` replace plan PRs 16 to
  20. Each ticket names its spec sections, scenario ids and blockers. The
  plan (v4.11.0) keeps the old PR text for history and points to the tickets.

## Files Modified

- `plans/spec-export-metadata.md`
- `plans/test-spec-export-metadata.md`
- `plans/impl-export-metadata.md`
- `plans/decisions-export-metadata.md`
- `plans/mockups/build-mockups.R` — new
- `plans/mockups/spec-gaps.md` — new
- `plans/mockups/variants/B1-crosstab.xlsx`, `B1-crosstab-stacked.xlsx`,
  `B1-topline.xlsx`, `README.md` — new
- `plans/tickets/export-metadata/` — new; README and tickets 01 to 08
- `changelog/docs-house-style-b1.md` — new; this file
