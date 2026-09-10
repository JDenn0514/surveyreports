# chore(pipeline): port the pipeline-simplified skill

**Date**: 2026-09-10
**Branch**: chore/port-pipeline-simplified

## Changes

- Add `pipeline-simplified`, a fast path that drives a small change from NEW to
  DONE in four dispatches: planner-lite, builder, tester, shipper. It writes no
  `spec-{id}.md` and no `test-spec-{id}.md`, and no reviewer runs — the tester
  is the quality gate.
- Split workflow Tier 3 on the write surface. A Tier 3 change that edits R code
  or a test runs `/pipeline-simplified`. A Tier 3 change that edits only
  roxygen comments, `man/`, the README, a vignette, `_pkgdown.yml`, or `plans/`
  keeps the direct path: branch, implement, PR.
- Reuse the `impact.md` tier result as the entry test. The skill adds no second
  smallness field.
- Wire the ship step to the pair this repo has: the `shipper` agent hands a
  SHIP READY block back to the main session, and `/commit-and-pr` opens the PR
  and monitors CI. Drop the two stale notes that pointed at an unported
  `pipeline-ship`.
- State the three gates the fast path still owes: a changelog entry, cross-design
  testing, and a Conventional Commit title with a branch prefix.

## Files Modified

- `.claude/skills/pipeline-simplified/SKILL.md` — new; the ported skill,
  adapted to the surveyreports workspace, agents, and tier table
- `.claude/rules/github-strategy.md` — split Tier 3 on the write surface
- `.claude/skills/pipeline-shared/references/state-model.md` — replaced the
  "not ported here" note with a Simplified workflow section: the
  `NEW → PLANNED → DONE` chain, its preconditions, and how it differs from the
  full chain
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md` — rewrote
  "When isolation is not worth its friction" to say which two barriers drop in
  the simplified workflow and which two hold
- `.claude/skills/pipeline-shared/references/artifact-schemas.md` — turned the
  `impact.md` stop line into a routing table over the five tier results
- `.claude/skills/pipeline-shared/references/workspace-layout.md` — added the
  `logs/baseline/` directory the baseline capture writes to
- `.claude/skills/pipeline-shared/SKILL.md` — listed pipeline-simplified as a
  consumer of four reference files
- `.claude/skills/pipeline-spec/SKILL.md` — Setup step 4 now routes instead of
  stopping; updated the "When NOT to use" and Downstream sections
- `.claude/skills/pipeline-implement/SKILL.md` — same treatment for its
  "When NOT to use" table and its ship note
