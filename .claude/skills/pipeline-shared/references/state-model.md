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

Note: surveywts also defines a shorter chain for small changes
(`NEW → PLANNED → …`), driven by a `pipeline-simplified` skill. That skill is
not ported here. For a change of that size, use workflow Tier 3 or Tier 0 from
`.claude/rules/github-strategy.md §Workflow Tiers` instead.

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
