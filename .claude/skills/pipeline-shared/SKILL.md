---
name: pipeline-shared
description: >
  Shared reference infrastructure for the surveyreports pipeline skills. Not
  invoked directly — loaded by pipeline-spec and by the pipeline agents
  (planner, extractor, builder, tester, reviewer, shipper) as needed.
---

# Pipeline Shared References

This skill is a reference library, not a workflow. Pipeline orchestrating skills
and agents load specific reference files from here as needed.

## Reference files

| File | Used by |
|------|---------|
| `references/state-model.md` | pipeline-spec |
| `references/artifact-schemas.md` | planner, reviewer, pipeline-spec |
| `references/pipeline-isolation.md` | builder, tester, reviewer, shipper |
| `references/signals.md` | all agents |
| `references/workspace-layout.md` | pipeline-spec, all agents |
| `references/r-package-profile.md` | builder, tester, reviewer |

## Relationship to the rule files

`.claude/rules/code-style.md`, `package-conventions.md`, `testing.md`, and
`github-strategy.md` are auto-loaded into every session — the pipeline never
restates them. Where a pipeline reference and a rule file overlap, the rule
file wins and the reference cites it.

`.claude/standards/function-documentation.md` is NOT auto-loaded. It is large
and only three agents need it (planner, builder, reviewer). Those agents Read
it explicitly in their Step 0.
