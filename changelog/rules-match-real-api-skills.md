# docs(pipeline): align the workflow skills and agents with the real package API

**Date**: 2026-09-10
**Branch**: docs/rules-match-real-api

## Changes

- Replace the remaining `report_*()` references across 13 skill, reference, and
  agent files. Where the meaning was "an exported function of this package",
  the text now says that; `export_*()` appears only where the file-writing
  behavior matters
- Replace the restated "all three design types" claim with a citation of
  `.claude/rules/testing.md`, so the count lives in one place. It appeared in
  12 files, each of which would have needed editing again when the rule changed
- Replace the "all 7 test categories" claim with a reference to the per-file
  section template in `testing.md`. There is no single 7-category list
- Replace `ci = TRUE`, `ci = FALSE`, and `ci_level` with the real arguments
  `variance` and `conf_level`
- Replace the `group` argument with `banner` and `interactions`
- Rewrite the stale function menu in the spec Stage 1 reference. It offered
  `report_freqs()`, `report_means()`, and `report_totals()` as the three
  choices; it now asks what kind of change the spec covers, so it does not go
  stale as the package grows
- Rewrite methodology Lens 1 against the real internal frame columns, Lens 3
  to cover question-type dispatch, and Lens 5 to cover banner splits and
  `pub_type` suppression
- Note in the tester and reviewer agents that `pool_pvals()` takes no design
  and that the nonprob column is a known gap, so neither agent BLOCKs on it
- Update the `{id}` and branch-name examples, the changelog example, and the
  commit-message example to real functions
- Point shared-infrastructure PRs at `R/export-utils.R`

## Files Modified

- `.claude/skills/spec-workflow/references/stage-2-methodology.md` — Lenses 1,
  3, 4, and 5 rewritten against the real output contract and arguments
- `.claude/skills/spec-workflow/references/stage-1-draft.md` — the opening
  question, the `{id}` derivation, and the cross-design rule
- `.claude/skills/spec-workflow/references/stage-3-review.md` — test
  categories, the variance check, and the DRY lens wording
- `.claude/skills/spec-workflow/SKILL.md` — description trigger and `{id}`
  examples
- `.claude/skills/implementation-workflow/references/stage-1-draft.md`,
  `stage-2-review.md` — PR granularity, acceptance criteria, and
  `R/export-utils.R`
- `.claude/skills/implementation-workflow/SKILL.md` — `{id}` examples
- `.claude/skills/pipeline-shared/references/artifact-schemas.md` — test-spec
  dataset lines, the cross-design rule, and the acceptance criteria
- `.claude/skills/pipeline-shared/references/workspace-layout.md`,
  `r-package-profile.md` — example filenames
- `.claude/skills/pipeline-spec/SKILL.md` — `{id}` example and the Stage 1
  verification
- `.claude/skills/r-implement/SKILL.md`,
  `references/mode-c-subagent.md` — the cross-design review question
- `.claude/skills/changelog-workflow.md` — the worked example
- `.claude/skills/commit-and-pr/SKILL.md` — the commit-message example
- `.claude/agents/tester.md` — cross-design rule, the no-design exemption, the
  nonprob gap, and the result-table example
- `.claude/agents/reviewer.md` — cross-design check and the `@seealso` rule
- `.claude/agents/builder.md`, `planner.md` — the cross-design rule
