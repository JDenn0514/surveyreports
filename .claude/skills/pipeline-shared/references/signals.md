# Signal System

Three named signals govern all inter-agent and agent-to-user communication.
Every pause, block, or halt in the pipeline MUST use one of these. No ad-hoc
`AskUserQuestion` calls from inside an agent.

## HOLD

**Emitted by:** any agent (planner, builder, tester, reviewer, shipper)
**Means:** I cannot proceed without a decision from the user.
**Outcome:** the pipeline pauses at the current state. The user resolves. The
pipeline resumes.

### Valid triggers

- **planner**: the spec forces a choice between two defensible output contracts
  (e.g., long vs. wide result shape; whether a Total column is a row or a
  column) and the request does not settle it
- **builder**: the spec is silent on a behavioral decision the implementation
  forces
- **tester**: the test-spec is silent on how to interpret an unanticipated
  numerical result, or a `surveycore::get_*()` oracle call errors
- **reviewer**: reviewer never emits HOLD — see STOP category
  `insufficient-inputs`
- **shipper**: a CI failure whose cause is unclear (flake vs. real); user
  approval needed

### Required body

Write to `decisions-{id}.md` AND return to the leader:

```
## HOLD — {agent} — {YYYY-MM-DD HH:MM}

**Where**: {stage, file, PR, test name as applicable}
**What**: One-sentence description of the open question
**Why I can't decide**: Which authority or input is missing
**Options** (if any): Enumerate with tradeoffs
**What I need**: One sentence — the exact input required to resume
```

## BLOCK

**Emitted by:** tester only
**Means:** the code does not satisfy the test-spec.
**Outcome:** the builder is re-dispatched for this PR with the `audit.md` BLOCK
body — NOT the full `audit.md`, NOT the test-spec. Isolation is preserved.
Maximum 3 BLOCK cycles per PR.

### Valid triggers

- A numerical test failed outside the tolerance from `test-spec-{id}.md`
- A named error class test failed (wrong class thrown, or no error thrown)
- A snapshot test failed and the message change was not intended
- `R CMD check --as-cran` has an ERROR or a WARNING
- `devtools::run_examples()` errored
- `pkgdown::build_site()` errored (when not skipped)
- Coverage dropped below 95%
- `air format --check .` reports an unformatted file
- A cross-design test passed for one design type and failed for another

### Required body

The tester writes `audit.md` with verdict=BLOCK and:

```
## BLOCK — {YYYY-MM-DD HH:MM}

**Failing scenario**: {name from test-spec, or gate command}
**Observed**: {value, class, message}
**Expected**: {value, class, tolerance}
**Design type**: taylor | replicate | twophase | all | n/a
**Classification**: numerical-miss | contract-miss | gate-fail | coverage-drop | format-fail
**What builder must fix**: One sentence
```

The tester does NOT tell the builder *how* to fix it. The tester does NOT
suggest code. The tester reports what failed against what was specified.

### Escalation

After 3 BLOCKs on the same PR, the tester escalates to HOLD with the
classification `repeated-block`. The user decides: extend cycles, re-spec, or
abandon.

## STOP

**Emitted by:** reviewer only
**Means:** the change is unsafe to ship.
**Outcome:** the pipeline halts entirely. The user must explicitly override in
`decisions-{id}.md` with justification.

### Valid triggers

- The tester relaxed a tolerance below what `test-spec-{id}.md` specified
  (Tolerance Integrity violation)
- The tester skipped a required test or a required design type
- The builder implemented behavior not in the spec (scope creep)
- The builder implemented the spec but the audit shows a regression in a test
  NOT in scope
- Coverage dropped below 95%, or any line this PR added is uncovered
- A gate failed in a way the audit labeled non-blocking and the reviewer
  disagrees
- The reviewer's own inputs are insufficient to reach a verdict — category
  `insufficient-inputs`

### Required body

The reviewer writes `review.md` with verdict=STOP and:

```
## STOP — {YYYY-MM-DD HH:MM}

**Category**: {tolerance-relaxation | test-skip | scope-creep | unflagged-regression | coverage-floor | gate-misclassification | insufficient-inputs}
**Evidence**: direct quote or diff from the offending artifact
**Why this is unsafe**: One paragraph
**What must happen before resume**: Exact fix, as a list
```

The shipper refuses to run when the latest `review.md` verdict is STOP. Period.

## Resume protocol

After the user resolves a HOLD or overrides a STOP, the resolving decision is
appended to `decisions-{id}.md`:

```
## Resolution — {YYYY-MM-DD HH:MM}

**Signal resolved**: {HOLD or STOP reference}
**Decision**: One sentence
**Authorized by**: user
**Resume from state**: {state name}
```

The skill then advances the pipeline from the recorded state.
