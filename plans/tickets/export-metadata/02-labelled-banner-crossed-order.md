# 02: Crossed columns on a value-labelled banner follow code order

**What to build:** When a banner column holds numeric codes with value
labels, its crossed column group lists the levels in code order, the same
order as the banner's own group. Today the crossed group sorts the labels
alphabetically, so one sheet lists the same levels in two orders. A factor
banner already keeps its order and does not change. User decision of
2026-11-19, gap 15.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

**Branch:** `fix/labelled-banner-crossed-order`

## Spec

Spec v0.29.0: 2.2 (`.banner_levels_labelled()`), 3.8 (the gap 15
decision and its example), 3.19.

## Scenarios

- Own: XH-05a.
- Must still pass: XH-04, XH-05, XH-06, XW-06, XW-07, XX-07, XX-08.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)`, labelled with the design name.
- [ ] `.banner_levels_labelled()` returns a factor for a labelled column,
      with the labels as levels in ascending order of their codes. A
      factor still comes back unchanged, and any other column as
      character.
- [ ] A code with no label still becomes `NA`.
- [ ] A crossed cell with no rows still has no column and no withheld line.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/fix-labelled-banner-crossed-order.md` exists.

## Notes

- The only caller is `.build_interaction_design()`. The banner's own
  column group does not read this helper. Its order comes from
  `get_freqs()`, which already returns code order.
- The direct test ".banner_levels_labelled() translates codes to value
  labels" asserts a character result. Rewrite it to assert a factor, its
  level order and the per-row values.
- The inline fixtures of the test-spec include a duplicate value label (one
  label, two codes). `factor()` aborts on duplicate levels. Keep each label
  once, at the position of its lowest code.
- A label whose code holds no row becomes an unused level. `interaction()`
  then builds crossed levels with no rows. surveycore drops them, so no
  column appears. No scenario crosses the `Other = 3` fixture of `XX-07`,
  so check that case once in the `XH-05a` block.
- The withheld frame for a crossed cell reads the same synthetic column, so
  its level strings do not change. Only their order can move.
