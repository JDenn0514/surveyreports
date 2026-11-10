# docs(docs): finish the export-metadata plan review and mark the plan ready

**Date**: 2026-11-09
**Branch**: docs/export-metadata-plan-pass-3

## Changes

- Resolve plan review Pass 2: PR 1 declares the six extra files that
  `air format .` reformats, and test-spec `XE-07` also passes `show_eff_n`.
- Fit variance cells in the crosstab sheet: under `variance = "ci"` a data
  column is `15 + 2 * decimals` characters wide, and under
  `variance_display = "cell"` the estimate cells wrap at a fixed 30-point
  row height. Width oracles compare the integer part of the stored width.
- Freeze only the first block on the stacked `"Crosstab"` sheet.
- Set the battery `Response` column to 20 characters, and the larger of 20
  and the data width for column B on a stacked sheet with a battery.
- Drop an all-NA variable from both export functions before the render
  loop, with one `surveyreports_warning_all_na_dropped` warning. Every
  variable all-NA aborts with `surveyreports_error_vars_all_na`. The rule
  holds under `na.rm = FALSE` too.
- Muffle `surveycore_warning_all_na_freqs`, and raise the withholding
  warnings after the drop.
- Append plan review Passes 3 to 6 and apply their required fixes. The plan
  is v4.9.0 at `PLAN_READY`; spec v0.27.0, test-spec v0.22.0, 200 scenarios.

## Files Modified

- `plans/spec-export-metadata.md` — the sheet-property, freeze-pane and
  all-NA rules, and the warning order.
- `plans/test-spec-export-metadata.md` — new and changed scenarios, from
  `XB-05` to `XX-17`.
- `plans/impl-export-metadata.md` — the PR tasks and criteria for each rule,
  and the status `PLAN_READY`.
- `plans/plan-review-export-metadata.md` — plan review Passes 3 to 6.
- `plans/decisions-export-metadata.md` — one entry per decision.
