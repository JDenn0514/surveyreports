---
name: pipeline-implement
description: >
  Orchestrates the implementation plan for surveyreports — from SPEC_READY
  through PLAN_READY. Adds a state machine and a review-loop budget on top of
  the existing implementation-workflow stages. Use when a user says "draft the
  plan", "build the plan", "implementation plan", "PR map", or when
  pipeline-spec has just reached SPEC_READY. The result is impl-{id}.md — a PR
  map whose acceptance criteria carry both the spec contract items and the
  test-spec scenarios, so the builder and the tester each get a complete
  target.
---

# Skill: pipeline-implement

**Announce at start:** "Running pipeline-implement — Stage N."

Drive a request from SPEC_READY to PLAN_READY. Produce `plans/impl-{id}.md`
with a PR map that `/r-implement` executes PR by PR.

## When to use

- `pipeline-spec` has reached SPEC_READY and the work needs more than one PR
- A finalized `spec-{id}.md` and `test-spec-{id}.md` exist and no plan does yet
- An existing `impl-{id}.md` needs a review pass or a resolve pass

## When NOT to use

Check `.claude/rules/github-strategy.md`, Workflow Tiers section, first. This
skill is the Tier 1 plan stage. For anything at Tier 2 or below, use that tier
instead:

| Change | Use |
|---|---|
| A clear bug fix in 1–2 functions, or a test addition | Tier 3, code — `/pipeline-simplified` |
| A roxygen change, or any Tier 3 change that edits no R code | Tier 3, docs — branch, implement, PR |
| A typo, a comment, `.gitignore`, a README tweak | Tier 0 — commit to `develop` |
| A medium bug fix, a new argument, an edge case that fits in one PR | `/implementation-workflow` on its own |

The pipeline wrapper buys a state machine, a capped review loop, and a
verified handoff. A single-PR change gets none of that value and still pays
three stages.

## Preconditions

- The current state in `.surveyreports-workspace/runs/{request-id}/status.md`
  is SPEC_READY
- `plans/spec-{id}.md` and `plans/test-spec-{id}.md` both exist
- Every HOLD from the spec phase is resolved in `plans/decisions-{id}.md`

If a precondition fails, follow the refusal protocol in
`.claude/skills/pipeline-shared/references/state-model.md`. Report the current
state, the missing precondition, and the artifact needed. Do not advance.

## Stage routing

| Stage | Purpose | Output | Next state |
|-------|---------|--------|------------|
| 1 | Draft the PR map | `plans/impl-{id}.md` | DRAFT |
| 2 | Plan review (5 lenses) | `plans/plan-review-{id}.md` | REVIEWED |
| 2r | Resolve findings | updated plan | DRAFT (loop) |
| 3 | Freeze and advance | status → PLAN_READY | PLAN_READY |

Stages 2 and 2r loop until the verdict is PASS, subject to the review-loop
budget below.

Infer the stage from the user's message. If it is unclear, ask with
`AskUserQuestion`:

```
question: "Which stage of the implementation plan do you want to run?"
header: "Stage"
options:
  - label: "Stage 1 — Draft the plan"
    description: "Write the PR map from the finalized spec and test-spec."
  - label: "Stage 2 — Adversarial review"
    description: "Full pass over the plan; writes the findings to a file."
  - label: "Stage 2r — Resolve findings"
    description: "Work through the findings and log the decisions."
```

## Stage 1 — Draft

Invoke `.claude/skills/implementation-workflow/references/stage-1-draft.md`.
Write the plan to the schema in
`.claude/skills/pipeline-shared/references/artifact-schemas.md`,
`impl-{id}.md` section.

The pipeline adds three constraints to that reference:

1. **Two verification tracks per PR.** Each PR's acceptance criteria list both
   the contract items from `spec-{id}.md` and the test scenarios from
   `test-spec-{id}.md`. The builder reads only the spec; the tester reads only
   the test-spec. A criterion that appears in neither artifact is unverifiable
   by either agent. See
   `.claude/skills/pipeline-shared/references/pipeline-isolation.md`.
2. **No shared write surface between concurrent PRs.** Two PRs that can run at
   the same time must not name the same file. `NAMESPACE`, `man/`, and
   `tests/testthat/_snaps/` are generated files and count as write surface.
3. **Tasks are one action each, 2–5 minutes.** TDD sub-steps are separate
   numbered tasks: write the failing test, confirm it fails for the right
   reason, write the code, confirm it passes.

Verify before advancing:

- Every PR has a branch name, a `Depends on:` field, tasks, acceptance
  criteria, and a Files touched list
- Every acceptance criterion names an observable outcome
- Every PR that adds an error or warning class lists
  `plans/error-messages.md` in its write surface
- No two concurrent PRs share a file

Append `DRAFT` to `status.md`.

## Review-loop budget (applies to Stages 2 and 2r)

Measured cost of an unbounded loop: one surveycore feature ran 7 review
passes, about $300 of API-equivalent usage. These rules cap the loop:

1. **Maximum 3 passes.** If findings are still open after pass 3, HOLD. Ask
   the user. Do not run pass 4.
2. **Pass 1 is the only full pass** — all five lenses, the whole document.
3. **Pass 2 and later are delta passes.** Review only the sections the
   resolver changed, plus the specific findings you verify. The resolver lists
   the changed section headings at the top of its response. Do not re-read the
   whole document.
4. **Early exit.** A pass whose findings need no change to the plan ends the
   loop. The verdict is PASS.

## Stage 2 — Plan review

Run the adversarial pass per
`.claude/skills/implementation-workflow/references/stage-2-review.md`. That
file holds the five lenses — PR Granularity, Dependency Ordering, Acceptance
Criteria, Spec Coverage, File Completeness — in their surveyreports form. Use
it as written; this skill does not restate them.

The pipeline adds two checks on top:

- **Acceptance Criteria lens** — every criterion maps to either a function
  contract item in `spec-{id}.md` or a scenario row in `test-spec-{id}.md`.
  Name the source for each. A criterion with no source is a finding.
- **File Completeness lens** — the union of all write surfaces covers every
  file the spec implies: `R/`, `tests/testthat/`, `NAMESPACE`, `man/`,
  `plans/error-messages.md`, and the changelog.

If you fan the lenses out to subagents instead of running them inline, pass
`model: "sonnet"` on every lens dispatch. A lens agent scans one document
against one named criterion. It does not need the session model.

Write the result to `plans/plan-review-{id}.md` with the verdict PASS, BLOCK,
or HOLD. Append `REVIEWED` to `status.md`.

## Stage 2r — Resolve findings

Invoke `.claude/skills/implementation-workflow/references/stage-3-resolve.md`.
Use BIG mode (more than 8 findings) or SMALL mode (8 or fewer). Record every
judgment call in `plans/decisions-{id}.md`.

Loop back to Stage 2 until the `plan-review-{id}.md` verdict is PASS. Respect
the review-loop budget.

## Stage 3 — Freeze and advance

On PASS:

1. Verify `plans/impl-{id}.md` holds a complete PR map with acceptance
   criteria and write surfaces for every PR.
2. Verify `plans/decisions-{id}.md` is populated. The
   `implementation-workflow` HARD-GATE requires it.
3. Append `PLAN_READY` to `status.md`.
4. Return to the user with a summary:

   > "impl-{id}.md is PLAN_READY — {n} PRs. Next step: run `/r-implement` to
   > execute PR 1 with builder and tester isolation."

## Signal handling

- **HOLD** from any stage → pause, write to `decisions-{id}.md`, ask the user
  with `AskUserQuestion`, resume
- **BLOCK** from the plan review → route to Stage 2r
- Signal bodies and the resume protocol:
  `.claude/skills/pipeline-shared/references/signals.md`

## Common shortcuts to resist

| Rationalization | Why it fails |
|---|---|
| "The spec passed its review, so the plan does not need one" | The spec review checks the contract. The plan review checks PR boundaries, dependency order, and write-surface overlap — none of which the spec describes. |
| "One PR covers it, so skip the PR map" | A one-PR change is Tier 2. Route to `/implementation-workflow` and skip this skill. |
| "The builder can work out which tests to write" | The builder never reads `test-spec-{id}.md`. A scenario the plan omits reaches no one. |

## Downstream

`pipeline-implement` owns SPEC_READY through PLAN_READY. After that:

| State | Skill |
|---|---|
| PLAN_READY → PIPELINES_COMPLETE | `/r-implement` |
| REVIEW_PASSED → DONE | `/commit-and-pr` |

There is no `pipeline-ship` skill in this repo. The `shipper` agent gates the
PR and hands a SHIP READY block back to the main session; `/commit-and-pr` then
opens the PR and monitors CI.

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/skills/pipeline-shared/references/workspace-layout.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md`
- `.claude/skills/implementation-workflow/references/stage-1-draft.md`
- `.claude/skills/implementation-workflow/references/stage-2-review.md`
- `.claude/skills/implementation-workflow/references/stage-3-resolve.md`
