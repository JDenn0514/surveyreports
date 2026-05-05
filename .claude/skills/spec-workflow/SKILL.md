---
name: spec-workflow
description: >
  Use this skill for any surveyreports spec work — drafting a new spec,
  running a methodology review, or resolving spec issues interactively. Trigger
  whenever the user says "draft spec", "review the spec", "resolve spec issues",
  or "start planning" for a report_*() function or feature.
  Five-stage workflow: draft → methodology review → resolve → spec review →
  resolve + log. After Stage 4 is complete, move to /implementation-workflow.
---

# surveyreports Spec Workflow

**Announce at start:** "Running spec-workflow Stage N — [stage name]."

This skill governs spec work for surveyreports. Five stages, always in order:

1. **Stage 1 — Draft:** Write the spec sheet
2. **Stage 2 — Methodology Review:** Adversarial reporting-layer pass; flags every
   statistical specification flaw — output column contracts, CI formula and df,
   cross-design consistency, domain estimation behavior, and delegation accuracy
   *(conditional — self-assesses applicability)*
3. **Stage 2 Resolve — Lock Methodology:** Resolve all methodology issues; spec is
   methodology-locked after this
4. **Stage 3 — Spec Review:** Adversarial code-quality pass; flags gaps in contracts,
   test plans, engineering level, and API coherence
5. **Stage 4 — Resolve:** Interactively work through all issues and log decisions

Stages 2 and 2 Resolve are conditional — skip them if the spec contains no
statistical output (e.g., a pure utility, a print method, or a documentation change).

```dot
digraph spec_stages {
    rankdir=LR;
    S1 [label="Stage 1\nDraft", shape=box];
    S2 [label="Stage 2\nMethodology", shape=box];
    S2R [label="Stage 2 Resolve\nLock Methodology", shape=box];
    S3 [label="Stage 3\nSpec Review", shape=box];
    S4 [label="Stage 4\nResolve + Log", shape=box];
    done [label="→ /implementation-workflow", shape=doublecircle];

    S1 -> S2;
    S2 -> S2R [label="issues found"];
    S2 -> S3 [label="N/A"];
    S2R -> S3;
    S3 -> S4 [label="issues found"];
    S3 -> done [label="clean"];
    S4 -> done;
}
```

<HARD-GATE>
Do not hand off to `/implementation-workflow` until Stage 4 is complete, all issues
are resolved, and `plans/decisions-{id}.md` is populated. The spec must be
methodology-locked and code-quality-reviewed before any R code is written.
</HARD-GATE>

---

## Stage Routing

Determine which stage the user wants from context. If unclear, use the
`AskUserQuestion` tool:

```
question: "Which stage of the spec workflow do you want to run?"
header: "Stage"
multiSelect: false
options:
  - label: "Stage 1 — Draft the spec"
    description: "Write a new spec sheet from scratch."
  - label: "Stage 2 — Methodology review"
    description: "Reporting-layer methodology pass: output column contracts, CI formula, cross-design consistency, statistical delegation. Self-assesses applicability — declares N/A and skips to Stage 3 for non-statistical features."
  - label: "Stage 2 Resolve — Resolve methodology issues"
    description: "Work through the methodology review file issue by issue. Methodology-locks the spec after completion."
  - label: "Stage 3 — Adversarial spec review"
    description: "Full batch pass over code quality, contracts, test plans, engineering level, and API coherence. Can run multiple times if new issues are discovered."
  - label: "Stage 4 — Resolve issues"
    description: "Interactively work through all open issues (from Stage 2 and/or Stage 3) and log decisions."
```

Then read the corresponding reference file before doing anything else:

| Stage | Reference file |
|---|---|
| 1 | `.claude/skills/spec-workflow/references/stage-1-draft.md` |
| 2 | `.claude/skills/spec-workflow/references/stage-2-methodology.md` |
| 2 Resolve | `.claude/skills/spec-workflow/references/stage-2-resolve.md` |
| 3 | `.claude/skills/spec-workflow/references/stage-3-review.md` |
| 4 | `.claude/skills/spec-workflow/references/stage-4-resolve.md` |

## Common Shortcuts to Resist

| Rationalization | Why it fails |
|---|---|
| "This function just wraps surveycore — Stage 2 is N/A" | Stage 2 self-assesses; don't skip it yourself. The delegation contract and output column definitions are exactly where errors hide. |
| "The spec is clear enough, Stage 3 would just nitpick" | Stage 3 catches missing test categories, wrong error class names, and underspecified edge cases before code is written. |
| "We can resolve that ambiguity in implementation" | Ambiguity discovered in implementation is a spec bug. Resolve it here. |
| "All issues are minor, I'll log decisions later" | `plans/decisions-{id}.md` must be populated before handing off. Log them now. |

---

## Rules in Context

Every stage works alongside — never instead of — these rule files:

| Rule file | What it governs |
|---|---|
| `code-style.md` | Indentation, pipe, air formatter, S7 patterns, cli error structure, argument order, helper placement |
| `package-conventions.md` | `::` usage, NAMESPACE, roxygen2, `@return`, `@examples`, export policy, function naming |
| `testing.md` | `test_that()` scope, 98%+ coverage, cross-design testing, numerical accuracy against `surveycore::get_*()` |
| `github-strategy.md` | Branch naming, PR granularity, commit format, merge strategy |

When a spec decision touches one of these rules, cite the rule file. When the
spec is silent on something these rules already define, note that the rule is
authoritative — the spec doesn't need to repeat it.

---

## File Locations

The `{id}` matches the feature branch identifier (e.g., `report-freqs`, `report-means`).

```
Spec:                     plans/spec-{id}.md
Methodology review:       plans/spec-methodology-{id}.md
Spec review:              plans/spec-review-{id}.md
Decisions log:            plans/decisions-{id}.md
```

**Determining `{id}`:** Infer from user context first (e.g., "report_freqs spec" →
`report-freqs`, "means spec" → `report-means`). If the spec file already exists,
derive `{id}` from its filename. If ambiguous, ask the user before reading or
writing any file.
