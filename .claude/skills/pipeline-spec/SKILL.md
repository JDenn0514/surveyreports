---
name: pipeline-spec
description: >
  Orchestrates the full spec workflow for surveyreports — from NEW request
  through SPEC_READY. Adds a state machine, Deep Comprehension Stage 0
  (literature ingestion from attached papers or PDFs), and a review-loop
  budget. Wraps the existing spec-workflow stages. Use when a user says "start
  planning", "pipeline it", "new feature", "new spec", or mentions a new
  exported function, a confidence interval method, or attaches a journal
  article. The result is two independently-sufficient artifacts:
  spec-{id}.md (for the builder) and test-spec-{id}.md (for the tester).
---

# Skill: pipeline-spec

**Announce at start:** "Running pipeline-spec — Stage N."

Drive a request from NEW to SPEC_READY. Produce `spec-{id}.md` (for the
builder) and `test-spec-{id}.md` (for the tester) that are independently
sufficient.

## When to use

- Any new exported function
- Any change to numerical output (a new CI method, a changed base-n
  convention, a new pooling rule)
- Any methodology-referencing change (attached papers, a new degrees-of-freedom
  approach)
- Any change to a public output column contract
- Any public API change

## When NOT to use

Check `.claude/rules/github-strategy.md`, Workflow Tiers section, first. This
skill is Tier 1 — the full workflow. For anything at Tier 2 or below, use that
tier instead:

| Change | Use |
|---|---|
| A clear bug fix in 1–2 functions, a test addition, a roxygen change | Tier 3 — branch, implement, PR |
| A typo, a comment, `.gitignore`, a README tweak | Tier 0 — commit to `develop` |
| A medium bug fix, a new argument, an edge case where the behavior is obvious but the approach is not | Tier 2 — `/implementation-workflow`, then `/r-implement` |

Running the pipeline on a Tier 3 change costs two documents, six dispatches,
and a review loop to produce a one-line fix. Say so and stop.

## Preconditions

- The current state is NEW, or this is the first run and the workspace does not
  exist yet
- The user has described what they want
- Any attached papers or PDFs are available

## Stage routing

| Stage | Purpose | Output | Next state |
|-------|---------|--------|------------|
| 0 | Deep Comprehension (if methods-heavy or a paper is attached) | `comprehension.md` | COMPREHENDED |
| 1 | Planner drafts `spec-{id}.md` + `test-spec-{id}.md` | two artifacts | DRAFT |
| 2 | Methodology review (5 lenses + literature lens) | `spec-methodology-{id}.md` | METHODS_REVIEWED |
| 2r | Resolve methodology findings | updated spec + test-spec | DRAFT (loop) |
| 3 | Spec review (adversarial, all lenses) | `spec-review-{id}.md` | SPEC_REVIEWED |
| 3r | Resolve spec findings | updated spec + test-spec | DRAFT (loop) |
| 4 | Freeze and advance | status → SPEC_READY | SPEC_READY |

Stages 2 and 3 may loop with their resolve counterparts until the verdict is
PASS, subject to the review-loop budget below.

## Setup (before Stage 0)

1. Determine `{id}` — infer it from the user's description
   (`report_freqs()` → `report-freqs`, "the crosstab totals" →
   `crosstab-totals`). Ask if it is ambiguous. The `{id}` is the feature branch
   identifier and the suffix on every `plans/` filename.
2. Create the workspace run directory:
   `.surveyreports-workspace/runs/{YYYY-MM-DD-id}/`
3. Write `request.md` from the user's description, per `artifact-schemas.md`.
4. Write `impact.md`. Assess scope and set the workflow tier result. If the
   tier is not `tier-1-full`, stop here and route to that tier.
5. Append `NEW` to `status.md`.

## Stage 0 — Deep Comprehension

Determine whether the request is methods-heavy, per `planner.md`, Step 1
criteria. Also check: did the user attach papers, PDFs, or markdown files of
journal articles? If so, how many?

**If NOT methods-heavy AND no papers attached:** auto-transition to
COMPREHENDED with the status line `(no methods — auto)`.

surveyreports delegates variance estimation to `surveycore::get_*()`, so this
stage fires less often here than in a package that implements estimators. It
still fires for: a CI formula or a degrees-of-freedom choice, a p-value
combining rule or multiplicity correction, a base-n or domain convention that
changes a denominator, and a `surveycore::get_*()` contract the repo has not
used before. Do not treat "we just wrap surveycore" as an automatic skip — the
delegation boundary is exactly where the errors hide.

### Single paper (exactly 1 attached), or methods-heavy with no paper

1. Dispatch the `planner` agent with this prompt:

   > Run Step 1 (Deep Comprehension Protocol) only. Write `comprehension.md`
   > per `artifact-schemas.md`. If a paper was attached, read it in full
   > before writing. Do not draft spec-{id}.md or test-spec-{id}.md yet.
   > Paper/attachment: {path or content}

2. On return, verify `comprehension.md` is coherent: the problem is restated,
   formulas are present with symbol bindings, the delegation boundary is drawn,
   there is at least one gotcha, at least one reference mapping, and the
   assumptions are listed. If it is not coherent, re-dispatch with specific
   feedback.

3. Append `COMPREHENDED` to `status.md`.

### Multiple papers (2 or more attached)

Reading several full papers inside one agent context crowds out the reasoning
needed for synthesis. Use parallel extraction first:

1. **Dispatch one `extractor` agent per paper, in the same turn** so they run
   in parallel. Each extractor reads one paper in full and writes
   `extraction-{slug}.md` into the workspace run directory. Derive the slug
   from the sanitized filename or a short paper title.

2. **Verify every extraction** before continuing. Each `extraction-{slug}.md`
   must contain at least one formula with symbol bindings, at least one gotcha,
   and at least one reference claim. Re-dispatch any extractor that produced a
   thin or incomplete result.

3. **Dispatch the `planner` agent for synthesis:**

   > Run Step 1 (Deep Comprehension Protocol) — synthesis pass only. All
   > papers have been pre-read by extraction agents. Their outputs are at:
   > {list all extraction-{slug}.md paths}
   >
   > Read all extractions. Synthesize them into `comprehension.md` per
   > `artifact-schemas.md`. Pay particular attention to:
   > - Conflicts between sources (different formulas for the same quantity)
   > - Assumptions that only one paper makes explicit
   > - Gotchas that appear in more than one source — these matter most
   > - Citations: aggregate every Citation section from the extractions into a
   >   single Citations section in `comprehension.md`. Preserve any
   >   [NOT FOUND] flags exactly — do not fill them in by inference.
   >
   > Do not re-read the original papers — work only from the extractions.

4. On return, verify `comprehension.md` with the same coherence checks as the
   single-paper path. Write any cross-paper conflict the planner could not
   resolve into `decisions-{id}.md` as a HOLD, for the user to settle before
   Stage 1.

5. Append `COMPREHENDED` to `status.md`.

## Stage 1 — Draft

Invoke `spec-workflow` Stage 1 — see
`.claude/skills/spec-workflow/references/stage-1-draft.md`.

The key constraint: Stage 1 produces TWO artifacts.

- `plans/spec-{id}.md` — the behavioral contract (the builder's input)
- `plans/test-spec-{id}.md` — the validation scenarios (the tester's input)

Neither may reference the other. See
`.claude/skills/pipeline-shared/references/pipeline-isolation.md`.

Pass the `comprehension.md` path to the planner if it exists.

Verify both artifacts exist and carry every required section on return.

When verifying the `spec-{id}.md` function contracts, apply
`.claude/standards/function-documentation.md`: check that the tier (Utility /
Standard / Algorithmic / Dispatcher) is identified for every new export, and
that the `@param`, `@returns`, `@details`, `@section`, and `@examples` rules for
that tier are reflected in the contract.

Also verify, before advancing:

- Every output column in `spec-{id}.md` Returns has a name, a type, and a
  presence condition
- The Design support matrix has a yes or no in every row, no blanks
- Every scenario in `test-spec-{id}.md` covers all three design types

Append `DRAFT` to `status.md`.

## Review-loop budget (applies to Stages 2/2r and 3/3r)

Measured cost of an unbounded loop: one surveycore feature ran 7 review
passes, about $300 of API-equivalent usage. These rules cap the loop:

1. **Maximum 3 passes** per review stage. If findings are still open after
   pass 3, HOLD. Ask the user. Do not run pass 4.
2. **Pass 1 is the only full pass** — all lenses, the whole document.
3. **Pass 2 and later are delta passes.** Review only the sections the
   resolver changed, plus the specific findings you are verifying. The
   resolver lists the changed section headings at the top of its response. Do
   not re-read the whole document.
4. **Early exit.** A pass whose findings need no change to the artifact ends
   the loop. The verdict is PASS.

## Stage 2 — Methodology review (conditional)

Self-assess applicability using the trigger criteria in
`.claude/skills/spec-workflow/references/stage-2-methodology.md`, Trigger
Condition section. Also check whether a paper or a `comprehension.md` is
available.

If applicable, run the full methodology review per that file — including the
Literature Lens if a paper was attached. Save the result to
`plans/spec-methodology-{id}.md`.

If you fan the lenses out to subagents instead of running them inline, pass
`model: "sonnet"` on every lens dispatch. A lens agent scans one document
against one named criterion. It does not need the session model.

Aggregate the findings into a verdict:

- **PASS** — no BLOCKING findings, no REQUIRED-UNAMBIGUOUS findings
- **BLOCK** — any BLOCKING finding
- **HOLD** — any JUDGMENT_CALL finding; the user decides

If not applicable, append `(Stage 2 N/A — {reason})` to `status.md`. Resist
the shortcut listed in `spec-workflow/SKILL.md`: "this function just wraps
surveycore" is not a reason to skip Stage 2.

## Stage 2r — Resolve methodology findings

Two modes:

- **UNAMBIGUOUS batch** — apply every unambiguous fix to `spec-{id}.md`,
  `test-spec-{id}.md`, and `comprehension.md` in one pass. Re-run only the
  affected lenses (a mini-pass) to confirm.
- **JUDGMENT_CALL per-issue** — ask the user with `AskUserQuestion`, one issue
  at a time. Record the resolution in `decisions-{id}.md`. Apply the fix.
  Mini-pass the affected lens.

Detailed procedure:
`.claude/skills/spec-workflow/references/stage-2-resolve.md`.

Loop until the `spec-methodology-{id}.md` verdict is PASS. Respect the
review-loop budget.

## Stage 3 — Spec review

Invoke `.claude/skills/spec-workflow/references/stage-3-review.md`.

When applying the Contract Completeness lens, consult
`.claude/standards/function-documentation.md` to determine which `@details`,
`@section`, and `@examples` content each function's tier requires.

Save the result to `plans/spec-review-{id}.md`. Aggregate the verdict:
PASS / BLOCK / HOLD.

## Stage 3r — Resolve spec findings

Invoke `.claude/skills/spec-workflow/references/stage-4-resolve.md`.

Use BIG mode (more than 8 findings) or SMALL mode (8 or fewer). Loop until the
`spec-review-{id}.md` verdict is PASS. Respect the review-loop budget.

## Stage 4 — Freeze and advance

On PASS from Stage 2 (where applicable) and Stage 3:

1. Verify `plans/spec-{id}.md` and `plans/test-spec-{id}.md` both exist and
   are finalized. Set the `Status` header in `spec-{id}.md` to `SPEC_READY`.
2. Verify `plans/decisions-{id}.md` is populated. The
   `spec-workflow` HARD-GATE requires it.
3. Copy `comprehension.md` to `plans/comprehension-{id}.md` if it exists.
4. Append `SPEC_READY` to `status.md`.
5. Return to the user with a summary:

   > "spec-{id}.md and test-spec-{id}.md are SPEC_READY. Next step: run
   > `/implementation-workflow` to draft the PR map."

## Signal handling

- **HOLD** from any stage → pause, write to `decisions-{id}.md`, ask the user
  with `AskUserQuestion`, resume
- **BLOCK** from the methodology review → route to Stage 2r
- Signal bodies and the resume protocol:
  `.claude/skills/pipeline-shared/references/signals.md`

## Downstream

`pipeline-spec` owns NEW through SPEC_READY. After that:

| State | Skill |
|---|---|
| SPEC_READY → PLAN_READY | `/pipeline-implement` |
| PLAN_READY → PIPELINES_COMPLETE | `/r-implement` |
| REVIEW_PASSED → DONE | `/commit-and-pr` |

`/pipeline-implement` wraps `/implementation-workflow` the way this skill wraps
`spec-workflow`. For a Tier 2 change that fits in one PR, call
`/implementation-workflow` directly instead.

surveywts routes to `pipeline-ship` after PLAN_READY. That skill is not ported
here; `/r-implement` and `/commit-and-pr` cover the same ground.

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/skills/pipeline-shared/references/workspace-layout.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md`
- `.claude/skills/spec-workflow/references/stage-1-draft.md`
- `.claude/skills/spec-workflow/references/stage-2-methodology.md`
- `.claude/skills/spec-workflow/references/stage-2-resolve.md`
- `.claude/skills/spec-workflow/references/stage-3-review.md`
- `.claude/skills/spec-workflow/references/stage-4-resolve.md`
- `.claude/agents/planner.md`
- `.claude/agents/extractor.md`
- `.claude/standards/function-documentation.md` — the documentation tier system
  and section rules, used in Stage 1 verification and the Stage 3 contract lens
