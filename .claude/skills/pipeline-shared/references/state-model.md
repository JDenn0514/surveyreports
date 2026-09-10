# State Model

Hard-gated per-request state machine. Each request has a run directory under
`.surveyreports-workspace/runs/{request-id}/` (see `workspace-layout.md`) with
a `status.md` file recording transitions.

## States

```
NEW → COMPREHENDED → SPEC_READY → PLAN_READY → PIPELINES_COMPLETE → REVIEW_PASSED → DONE
```

## Transitions and preconditions

Every transition must satisfy ALL preconditions. A skill that attempts to
advance without them MUST refuse and report to the user.

| From | To | Preconditions |
|------|----|----|
| NEW | COMPREHENDED | `request.md` exists. If methods-heavy (see `planner.md`), `comprehension.md` exists and is non-empty. For non-methods requests, auto-entered with no artifact. |
| COMPREHENDED | SPEC_READY | `spec-{id}.md` exists. `test-spec-{id}.md` exists. `spec-review-{id}.md` verdict = PASS. If methods-heavy: `spec-methodology-{id}.md` verdict = PASS. |
| SPEC_READY | PLAN_READY | `impl-{id}.md` exists with a PR map. `plan-review-{id}.md` verdict = PASS. |
| PLAN_READY | PIPELINES_COMPLETE | For every PR in the plan: `implementation.md` exists AND `audit.md` exists AND audit verdict = PASS. |
| PIPELINES_COMPLETE | REVIEW_PASSED | `review.md` exists with verdict = PASS. |
| REVIEW_PASSED | DONE | PR merged to `develop`. Plan checkbox `[x]` marked. Branch deleted. |

`pipeline-spec` owns `NEW → SPEC_READY`. `pipeline-implement` owns
`SPEC_READY → PLAN_READY`. `/r-implement` and `/commit-and-pr` own the states
after that.

## Simplified workflow

A Tier 3 change that edits R code or a test runs a shorter chain, driven by
`/pipeline-simplified`:

```
NEW → PLANNED → DONE
```

| From | To | Preconditions |
|------|----|----|
| — | NEW | `request.md` exists. `impact.md` exists with the tier result `tier-3`. The change edits R code or a test file. |
| NEW | PLANNED | `request.md` carries the four planner-lite sections: Change, Acceptance criteria, Write surface, Validation. |
| PLANNED | DONE | `implementation.md` exists. `audit.md` exists with verdict = PASS. PR merged to `develop`. Branch deleted. |

The two chains differ in three ways:

1. **No spec artifacts.** `request.md` is the contract for both the builder and
   the tester. There is no `spec-{id}.md` and no `test-spec-{id}.md`, so no
   COMPREHENDED, SPEC_READY, or PLAN_READY state exists.
2. **The tester is the quality gate.** No reviewer runs, so there is no
   REVIEW_PASSED state and no STOP signal. `audit.md` verdict = PASS is what
   the shipper reads.
3. **Escalation replaces a BLOCK loop that will not close.** The chain has no
   way to absorb a growing change. `status.md` records
   `ESCALATED — {reason}`, and the request restarts on the full chain at
   `pipeline-spec` Stage 0. Triggers are in `pipeline-simplified/SKILL.md`,
   Escalation section.

A Tier 3 change that edits only documentation runs no pipeline at all — branch,
implement, PR. Tier 0 commits straight to `develop`. See
`.claude/rules/github-strategy.md`, Workflow Tiers.

## Rules

1. **`status.md` is append-only.** Every transition appends a line:
   ```
   2026-09-09T14:32:11Z  SPEC_READY  (spec-review PASS, methods-review PASS)
   ```
2. **Only orchestrating skills mutate `status.md`.** Agents never write to it.
3. **BLOCK reverts one state.** A tester BLOCK reverts
   `PIPELINES_COMPLETE → PLAN_READY` for that PR. Builder is re-dispatched.
   Maximum 3 BLOCK cycles per PR; at 3, escalate to the user (HOLD).
4. **STOP halts the pipeline.** A reviewer STOP terminates processing; the user
   must explicitly authorize resume.
5. **HOLD pauses the current state.** Recorded in `decisions-{id}.md`; the user
   resolves; the pipeline resumes from where it paused.

## Refusal protocol

If a skill or agent is invoked when preconditions are not met, it MUST:

1. Read `status.md`
2. Identify the missing precondition
3. Return to the user with:
   - Current state
   - Target state requested
   - Which precondition is missing
   - What artifact or verdict is needed to satisfy it

No silent downgrades. No partial advancement.
