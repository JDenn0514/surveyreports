# chore(pipeline): fix three rule-file contradictions

**Date**: 2026-09-22
**Branch**: chore/pipeline-rule-contradictions

Closes #9, #10 and #11.

## Changes

- Extend the dual test pattern to warnings. `.claude/rules/testing.md` defined
  it for errors alone: its warning section gave the class assertion and the
  file-still-written assertion, and it snapshotted no warning. The rule now
  covers both condition types — the class assertion plus one snapshot of the
  message, per class, for an error and for a warning alike.
- Carry the argument-wording exception into that rule. A class whose message
  names the argument it was raised for has one wording per argument, so it
  takes one snapshot per wording, and not one per class.
- Swap groups 4 and 5 of the argument-order list in
  `.claude/rules/code-style.md`. The list put an optional tidy-select argument
  ahead of an optional scalar; the worked example for `export_crosstab()` put
  them the other way round, and the example matches the shipped signature. An
  optional scalar now comes first. No function signature changed.
- List each export function under one documentation tier.
  `.claude/standards/function-documentation.md` named `export_topline()` and
  `export_crosstab()` under Tier 2 and again under Tier 4, and the two tiers
  ask for different roxygen blocks. Both stay under Tier 4: each routes blocks
  by question structure and runs no algorithm of its own. The Tier 2 entry had
  asked `export_topline()` for an Algorithm section covering a CI
  construction that the source does not perform — `R/` holds no `qnorm()` and
  no `qt()`.
- Give Tier 2 an example that fits: `.build_freq_frame()`, which delegates each
  estimate to `surveycore::get_freqs()`, computes the Total row itself, and
  invents no statistic.
- Remove the three artifact sections that existed only to record the three
  contradictions, and move the spec to v0.20.0 and the test-spec to v0.15.0.
  Both stay at `SPEC_READY`.

No R source file, roxygen comment, or test file changed, so this branch
triggers no `devtools::document()` and no `devtools::check()` run.

## Files Modified

- `.claude/rules/testing.md` — renamed the **Error testing: dual pattern**
  section to cover both condition types, added the one-snapshot-per-class rule
  and the argument-wording exception, added the snapshot call to the
  **Warning capture** example, and updated the two Quick Reference rows
- `.claude/rules/code-style.md` — swapped groups 4 and 5 of the argument-order
  list, and completed the Quick Reference row to match
- `.claude/standards/function-documentation.md` — replaced the Tier 2
  illustrative examples with `.build_freq_frame()`; the two export functions
  now appear under Tier 4 alone
- `plans/spec-export-metadata.md` — v0.20.0; section 3.1 lost the
  contradiction note and now states the deviation that remains, section 7.1
  lost the two-tier block
- `plans/test-spec-export-metadata.md` — v0.15.0; the **Assertion
  conventions** section now reads the dual pattern from `testing.md` and keeps
  only the mapping of the argument-wording exception to its scenarios
- `plans/decisions-export-metadata.md` — appended the 2026-09-22 entry
- `changelog/chore-pipeline-rule-contradictions.md` — new; this file
