---
name: pipeline-simplified
description: >
  Fast path from NEW to DONE for a Tier 3 change that edits R code or a test —
  a clear bug fix in one or two functions, or a test addition. Runs
  planner-lite, builder, tester, then shipper. There is no
  spec and test-spec split, no comprehension document, and no separate
  reviewer; the tester is the quality gate. Escalates to the full pipeline when
  the change grows. Use when `impact.md` gives the tier result `tier-3`, or
  when the user says "small fix", "quick fix", or "just patch it".
---

# Skill: pipeline-simplified

**Announce at start:** "Running pipeline-simplified — Step N."

Drive a small change from NEW to DONE in four dispatches. The skill writes no
`spec-{id}.md` and no `test-spec-{id}.md`, so there is no barrier to hold
between them. The tester is the quality gate. No reviewer runs.

## When this runs

`.claude/rules/github-strategy.md`, Workflow Tiers, splits Tier 3 in two. This
skill drives one half:

| A Tier 3 change that... | Path |
|---|---|
| Edits R code or a test file | This skill |
| Edits only roxygen comments, `man/`, `README`, a vignette, `_pkgdown.yml`, or `plans/` | Branch, implement, PR — no agents |

"Edits R code" means executable code in `R/`. A roxygen comment is not
executable code, so a roxygen-only change takes the direct path.

## Preconditions

- The current state is NEW.
- `request.md` exists.
- `impact.md` exists, and its Workflow tier result is `tier-3`.
- The change edits R code or a test file.

Route elsewhere when a precondition fails:

| Tier result | Route |
|---|---|
| `tier-0` | Commit to `develop` |
| `tier-3`, docs only | Branch, implement, PR |
| `tier-2` | `/implementation-workflow`, then `/r-implement` |
| `tier-1-full` | `/pipeline-spec` |

The user may ask for the full pipeline on a `tier-3` change. Honor that request
and run `/pipeline-spec` instead.

## Routine patterns

Each of these is a change this skill drives:

- Fix a wrong comparison, a wrong row cursor, or a wrong default in an existing
  function
- Fix a `cli_abort()` message that names the wrong argument or the wrong value
- Replace an `@importFrom` tag with a `::` call at the call site —
  `.claude/rules/package-conventions.md` bans `@importFrom` outright
- Add `class =` to a `cli_abort()` or `cli_warn()`, plus its row in
  `plans/error-messages.md`
- Replace a string class check with `S7::S7_inherits(x, ClassName)`
- Add a test for an edge case an existing function already handles
- Convert an `@examples` block to the `tempfile()` pattern

## Not this skill

Each of these means the tier result in `impact.md` is wrong. Reassess it, then
follow the routing table above:

- The change adds an exported function
- The change alters a public contract — an argument, a returned column, or a
  shipped error class
- The change is expected to move a number
- The request carries an attached paper, PDF, or reference implementation
- The change touches more than three files

## State chain

```
NEW → PLANNED → DONE
```

See `.claude/skills/pipeline-shared/references/state-model.md`, Simplified
workflow section.

## Step 1 — Plan (planner-lite)

Dispatch the `planner` agent:

> Simplified workflow. Extend `request.md` — do not write `spec-{id}.md`,
> `test-spec-{id}.md`, or `impl-{id}.md`, and do not run the Deep Comprehension
> Protocol. Add these four sections:
> - **Change**: what the change does, in two sentences
> - **Acceptance criteria**: observable outcomes, one per line
> - **Write surface**: the files this change may touch, at most three
> - **Validation**: which existing tests must still pass, and which new
>   assertion proves the change
> Request: {path to request.md}
> Impact: {path to impact.md}

**In the same turn as the planner dispatch**, start the baseline capture in the
background. The tree is still clean, because the builder has not run:

```bash
bash .claude/scripts/run-gates.sh {run-dir}/logs/baseline --baseline
```

Use `run_in_background: true`. The summary becomes the tester's Before column.
Do not wait for it here. Collect the result before Step 2b.

On return, verify `request.md` carries all four new sections. Append `PLANNED`
to `status.md`.

## Step 2 — Build and test

### 2a. Dispatch the builder

Dispatch the `builder` agent without worktree isolation. The change is small,
and the isolation costs more than it returns:

> Simplified workflow. There is no `spec-{id}.md`. `request.md` carries the
> contract: read its Change, Acceptance criteria, Write surface, and Validation
> sections, and treat them as the spec.
> Request: {path to request.md}
> Write surface: {files from request.md}
> You MAY read and edit test files in `tests/testthat/`. Isolation is relaxed
> here, because no test-spec exists to teach to.
> Write `implementation.md` per `artifact-schemas.md`.

### 2b. Dispatch the tester

Dispatch the `tester` agent:

> Simplified workflow. There is no `test-spec-{id}.md`. Take the scenarios from
> the Acceptance criteria and Validation sections of `request.md`.
> Request: {path to request.md}
> Baseline results: {summary from the Step 1 background capture}
> Validate that:
> 1. Every acceptance criterion in `request.md` holds
> 2. Every profile gate passes, per `r-package-profile.md`
> 3. The CRAN cookbook scan is clean on the changed files
> 4. No test that passed in the baseline now fails
> Cross-design coverage and Tolerance Integrity still bind. Neither relaxes.
> You still do not read `implementation.md`.
> Write `audit.md` with verdict PASS or BLOCK.

On BLOCK, re-dispatch the builder with the BLOCK body alone, per `signals.md`.
The third BLOCK escalates — see Escalation below.

### 2c. Advance

The tester is the quality gate in this workflow. On verdict PASS, go to Step 3.

## Step 3 — Ship

Dispatch the `shipper` agent. It gates on a PASS quality verdict; in this
workflow that verdict is `audit.md`, not `review.md`:

> Simplified workflow. No reviewer ran. The quality gate is `audit.md` with
> verdict PASS — read it in place of `review.md`. There is no `impl-{id}.md`;
> take the branch name from `request.md` and the write surface from
> `implementation.md`.
> Audit: {path to audit.md}
> Implementation: {path to implementation.md}

The shipper hands a SHIP READY block back to this session. It does not open the
PR. Run `/commit-and-pr` here to write the changelog entry, open the PR, and
monitor CI. That skill stops for user approval twice, and a subagent can answer
neither prompt.

After `/commit-and-pr` finishes, complete `shipper.md` and append `DONE` to
`status.md`.

## Gates the fast path still owes

A smaller workflow does not buy a smaller obligation. Three gates hold:

1. **A changelog entry** at `changelog/{branch-name}.md`. `commit-and-pr`
   refuses to open a PR without one. Format:
   `.claude/skills/changelog-workflow.md`.
2. **Cross-design testing**, when the change touches a function that takes a
   `design`. The subclass list is in `.claude/rules/testing.md`, Cross-design
   testing — that table is the single source of truth. `survey_collection` is
   not in it and does not inherit `survey_base`; a function that accepts one
   needs its own test block.
3. **A Conventional Commit title**, and a branch prefix of `feature/`, `fix/`,
   `docs/`, `test/`, or `chore/`. See `.claude/rules/github-strategy.md`.

## Escalation to the full workflow

Escalate when any of these happens:

- The builder emits HOLD twice
- The tester emits a third BLOCK
- The change turns out to touch more than three files
- A CRAN cookbook violation needs a design change, not a syntax fix
- An acceptance criterion turns out to rest on methodology the request never
  described

To escalate:

1. Append `ESCALATED — {reason}` to `status.md`.
2. Run `/pipeline-spec` from its Stage 0.
3. Keep every artifact written so far. The partial working tree may need to go;
   the planner writes a fresh spec with the context already gathered.

## Signal handling

- **HOLD** — any agent. Pause, ask the user, resolve, then resume or escalate.
- **BLOCK** — the tester only. The third BLOCK escalates.
- **STOP** — no agent emits STOP here, because no reviewer runs. A finding that
  would earn a STOP is an escalation trigger.

Signal bodies and the resume protocol:
`.claude/skills/pipeline-shared/references/signals.md`.

## Workspace layout

One PR, so no `prs/pr-{n}-{slug}/` subdirectory:

```
.surveyreports-workspace/runs/{request-id}/
├── status.md
├── request.md          (the planner extended this)
├── impact.md
├── decisions-{id}.md
├── logs/
│   └── baseline/       (the Step 1 capture)
├── implementation.md
├── audit.md
└── shipper.md
```

No `spec-{id}.md`, no `test-spec-{id}.md`, no `comprehension.md`, no
`impl-{id}.md`, no `review.md`. Full layout:
`.claude/skills/pipeline-shared/references/workspace-layout.md`.

## What you give up

| Given up | What covers it instead |
|---|---|
| The methodology review | Tier 3 excludes a change that moves a number |
| The spec and test-spec barrier | Tier 3 excludes an algorithmic change, so there is no numerical oracle to protect |
| The reviewer | The tester gates on the profile gates and the cookbook scan |
| The comprehension document | Tier 3 excludes paper-driven work |
| The PR map | One PR needs no map |

## References

- `.claude/skills/pipeline-shared/references/state-model.md` — Simplified
  workflow section
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md` — When
  isolation is not worth its friction
- `.claude/skills/pipeline-shared/references/workspace-layout.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/r-package-profile.md` — the profile
  gates and the runner
- `.claude/skills/changelog-workflow.md`
- `.claude/agents/planner.md`, `builder.md`, `tester.md`, `shipper.md`
