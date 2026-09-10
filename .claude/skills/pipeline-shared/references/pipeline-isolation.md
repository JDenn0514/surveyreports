# Pipeline Isolation

Information barriers between the code, test, and convergence roles. The
orchestrating skill enforces these at dispatch time — if an agent is given the
wrong artifact, the barrier has been violated.

## Why isolation matters

If the builder knows exactly which scenarios the tester will run, it can teach
to the test — ship code that passes the specified inputs without implementing
the behavior correctly. If the tester knows how the code works internally, it
cannot provide independent verification. The separation forces each side to
reach the same answer from independent premises.

surveyreports delegates variance estimation to `surveycore::get_*()`, so the
risk is not a wrong variance formula. It is a wrong *contract*: a column named
`prop_low` that actually holds the upper bound, a domain filter applied after
the estimate instead of before, a Total column computed over the wrong base, a
cross-design difference that goes unnoticed because only the Taylor design was
tested. Those errors produce plausible-looking numbers. Independent verification
is the protection.

## Who receives what

| Agent | Reads | Never reads | Writes |
|-------|-------|-------------|--------|
| planner | `request.md`, `impact.md`, `comprehension.md` (its own), target repo | `implementation.md`, `audit.md` | `comprehension.md`, `spec-{id}.md`, `test-spec-{id}.md`, `impl-{id}.md` |
| extractor | one attached paper | every other paper, every workspace artifact | `extraction-{slug}.md` |
| builder | `spec-{id}.md`, `impact.md`, `request.md`, the auto-loaded rule files, `.claude/standards/function-documentation.md` (its own Step 0 Read) | `test-spec-{id}.md`, `audit.md`, `review.md` | code, `implementation.md` |
| tester | `test-spec-{id}.md`, `impact.md`, `request.md`, the auto-loaded rule files | `spec-{id}.md`, `implementation.md`, `review.md` | `audit.md` |
| reviewer | ALL artifacts | — | `review.md` |
| shipper | `review.md` (verdict=PASS), `implementation.md`, `impl-{id}.md`, branch metadata | `spec-{id}.md`, `test-spec-{id}.md`, `audit.md` | a SHIP READY handoff block, `shipper.md` |

The four `.claude/rules/*.md` files are auto-loaded into every session,
including subagents. They carry no scenario-specific information, so they do
not breach any barrier.

## Enforcement rules

1. **The planner produces two independent documents.** `spec-{id}.md` and
   `test-spec-{id}.md` must each be sufficient on its own. No cross-references
   such as "see test-spec for scenarios" or "see spec for the function
   contract". Each reader must be able to do their job with only the artifact
   they were given.

2. **Orchestrating skills include only the permitted artifacts in the dispatch
   prompt.** When dispatching the builder, the skill MUST include the
   `spec-{id}.md` path and MUST NOT mention that `test-spec-{id}.md` exists.
   Same for the tester in reverse.

3. **The tester writes what it observed, not what it expected the code to do.**
   `audit.md` describes the behavior of the system under test against
   `test-spec-{id}.md` scenarios. It does not say "the function probably calls
   `surveycore::get_freqs()`" — that would require knowing the implementation.

4. **The builder does not read `audit.md` after a BLOCK.** Only the BLOCK
   message itself — failing scenario, observed vs. expected, design type,
   classification — is passed back. See `signals.md §BLOCK`.

5. **The reviewer is the single convergence point.** Only the reviewer may read
   `implementation.md` AND `audit.md` together. That is what makes the
   convergence checks meaningful.

## Violations

If an agent is found to have read a forbidden artifact — inferred from its
output naming specifics only available there — the orchestrating skill MUST:

1. Discard the agent's output
2. Re-dispatch with a fresh session (no continued context)
3. Log the violation in `decisions-{id}.md`

## When isolation is not worth its friction

Isolation costs two documents and two dispatches. A Tier 3 or Tier 0 change in
`.claude/rules/github-strategy.md`, Workflow Tiers, does not earn that cost.
Never run a half-isolated pipeline: either the two artifacts are independent,
or the barrier is theatre.

Two paths drop the barrier honestly.

**Tier 0, and Tier 3 with a docs-only change.** No pipeline runs. Branch,
implement, PR — or commit straight to `develop` for Tier 0.

**Tier 3 with a change to R code or a test.** `/pipeline-simplified` runs, and
it writes no `spec-{id}.md` and no `test-spec-{id}.md`. `request.md` is the
contract both the builder and the tester read. Two barriers come down and two
stay up:

| Barrier | In simplified |
|---|---|
| The builder never reads the test-spec | Down — no test-spec exists. The builder may read and edit `tests/testthat/` |
| The tester never reads the spec | Down — both read `request.md` |
| The tester never reads `implementation.md` | Up |
| The tester never relaxes a tolerance, and never skips a design type | Up |

The two that stay up are what makes the tester an independent gate once the
reviewer is gone. A change that would make either one costly — a new estimator,
a moved number, a new exported contract — is above Tier 3 and belongs on the
full chain.
