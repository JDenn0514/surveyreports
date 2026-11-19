# 07: House style B1 on the topline sheet

**What to build:** The `"Topline"` sheet takes house style B1: the navy
title band, the heading fill, zebra stripes, the rule above the `Total`
row, the block box, the navy edge at column B, bold navy battery item
headings, widths of 44 and 10, and computed heights on the merged rows. No
freeze pane. The content stays: a percentage cell is still a number, and
the `N` column and the `Total` row of `100%` stay. User decision of
2026-11-19, gap 22: the topline style lands now.

**Blocked by:** 06 (House style B1 on the crosstab sheets and the About
sheet). Ticket 06 builds the three style helpers of spec 3.21.7 and the
base font. Spec 3.21.7 requires one definition in `R/export-utils.R`, so a
parallel branch would duplicate the helpers or collide in that file.

**Status:** ready-for-agent

**Branch:** `feature/house-style-topline`

## Spec

Spec v0.29.0: 3.21.1, 3.21.2, 3.21.4, 3.21.6, 3.21.7, 4.1, 4.2, VIII, 8.1.

## Scenarios

- Own: TY-01, TY-02, TY-03, TY-04, TY-05, TY-06, TY-07, TY-08, TY-09,
  TY-11.
- Must still pass unchanged (no topline value moves): TP-09, TP-10, TP-11,
  TP-12, TN-04.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)`, labelled with the design name, except
      `TY-09`, which runs on the two-wave collection.
- [ ] Each topline route builds a layout record and calls
      `.write_block_style()` once per table. No cell value changes.
- [ ] All three greps of spec VIII for the house style pass in full, now
      including `R/export-topline.R`, and every `wb_add_worksheet()` call
      passes `grid_lines = FALSE`.
- [ ] `devtools::document()` leaves `NAMESPACE` and `man/` unchanged, and
      no snapshot moved.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/feature-house-style-topline.md` exists.

## Notes

- Spec 3.21.4 and the test-spec name `feature/house-style` as the branch
  for the topline style. The work is split across two tickets so each fits
  one session. Say so in the PR description.
- `TY-10`, the About sheet of a collection, moved to ticket 06 with the
  rest of the About styling. `.write_cover_sheet()` is one writer for both
  functions.
- `.render_topline_battery()` tells `.render_topline_single()` that its
  title is an item heading. The preface and its base note stand alone with
  no box and no rule. Each item table is boxed from its item heading.
- Set the topline widths once, in `export_topline()`, after the render
  loop: column A 44, every data column 10.
- On the collection path, column B alone takes the left navy edge, one per
  table.
- Remove every `wb_add_font()` call in `R/export-topline.R`. Change no
  value. The three inline `* 100` sites that spec 4.1 names stay.
- Only the title, base-note and item heading rows store a height. The
  heading, body and `Total` rows store none, the `%\n(Eff N=…)` header
  included.
