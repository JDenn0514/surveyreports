# Stage 1: Drafting a Spec Sheet

## Before Writing Anything

Use the `AskUserQuestion` tool to gather context before reading or writing anything:

```
questions:
  - question: "Which function or feature is this spec for?"
    header: "Feature"
    multiSelect: false
    options:
      - label: "A change to an existing export"
        description: "A new argument, a changed output contract, or a fix in export_topline(), export_crosstab(), or pool_pvals()."
      - label: "A new output function"
        description: "A new function that writes a formatted file from a survey design."
      - label: "A new reporting helper"
        description: "A function that supports the reporting workflow without writing a file."

  - question: "Is there an existing roadmap or prior spec to reference?"
    header: "Reference documents"
    multiSelect: false
    options:
      - label: "Yes — I'll share the path(s) or paste the content"
        description: "Provide all reference documents before the draft begins."
      - label: "No — draft from scratch based on this conversation"
        description: "This spec is self-contained."

  - question: "Are there upstream constraints from surveycore I should know about?"
    header: "Upstream constraints"
    multiSelect: false
    options:
      - label: "Yes — I'll describe them"
        description: "Share surveycore API details before drafting."
      - label: "No — use the surveycore conventions I already know"
        description: "Rely on surveycore::get_*() conventions as specified."
```

Confirm the `{id}` with the user if it is not obvious from context. Derive it
from the function or the feature: `export_topline()` → `export-topline`, "the
crosstab base notes" → `crosstab-base-notes`. The output file will be
`plans/spec-{id}.md` — establish this before writing anything.

Wait for the user to provide any referenced documents. Read all provided context
before writing a single line of the spec.

---

## Two Artifacts, Not One

Stage 1 produces TWO files, and neither may reference the other:

| File | Reader | Contains |
|---|---|---|
| `plans/spec-{id}.md` | the builder | the behavioral contract |
| `plans/test-spec-{id}.md` | the tester | the validation scenarios |

The split exists so the builder cannot write to the test list and the tester
cannot read the implementation. Both sides reach the same behavior from
independent premises, which is the only way a wrong column contract gets
caught. The full rationale and the who-reads-what table are in
`.claude/skills/pipeline-shared/references/pipeline-isolation.md`.

**The line between them.** The spec says what the function must do. The
test-spec says how you would know. A tolerance, a dataset, an oracle call, or a
`test_that()` name in `spec-{id}.md` is a leak. An `R/` file path or an
internal `.helper()` name in `test-spec-{id}.md` is a leak.

Neither file says "see the other document."

---

## `spec-{id}.md` Structure

The exact schema is
`.claude/skills/pipeline-shared/references/artifact-schemas.md`, section
`spec-{id}.md`. Required sections:

| Section | Content |
|---|---|
| Header block | Status, target version, PR range, `Standards read:` |
| Document Purpose | One paragraph: this is the source of truth for this function |
| I. Scope | What this spec delivers, what it does NOT deliver, design support matrix (taylor / replicate / twophase / collection) |
| II. Architecture | File organization, shared helpers with signatures |
| III–N. Function specs | One section per exported function: documentation tier, signature, argument table, delegation, output contract, error table, warning table, edge cases, cross-design behavior |
| Quality Gates | Invariants that must hold across all inputs — objectively verifiable |
| Pipeline split | `recommended` or `optional`, with justification |

No test cases. No tolerances. No datasets. The Testing section that used to
live here is now `test-spec-{id}.md`.

---

## `test-spec-{id}.md` Structure

The exact schema is `artifact-schemas.md`, section `test-spec-{id}.md`.
Required sections:

| Section | Content |
|---|---|
| Reference oracle | The single-variable `surveycore::get_*()` this output must match, and the columns compared |
| Datasets | `make_all_designs()`, `make_survey_data()`, package data; edge case data stays inline in the test |
| Per-function test plan | All 7 categories from `testing.md`, as tables: happy path, cross-design, error paths, warning paths, edge cases, result structure, numerical accuracy |
| Tolerances | Point `1e-10`, SE `1e-8`, CI `1e-6`; every deviation justified in writing |
| Assertion conventions | `expect_identical()` vs `expect_equal()`, the dual error pattern, no `tryCatch()` |
| Profile gates | The full gate list, verbatim |

Two rules carry the most weight:

- **Every scenario covers every design type** in `.claude/rules/testing.md`,
  Cross-design testing. A row naming one design type only is a gap. This is
  the surveyreports equivalent of an invariant check.
- **Every error class from the spec gets both assertions** —
  `expect_error(class = )` and `expect_snapshot(error = TRUE)`.

---

## Spec Writing Rules

These apply to `spec-{id}.md`.

- Every exported function gets a documentation tier — Utility, Standard,
  Algorithmic, or Dispatcher — recorded in its contract. The tier decides which
  `@section` blocks and which `@references` content are required. See
  `.claude/standards/function-documentation.md`.
- Every exported function gets a full argument table: name, type, default,
  one-sentence description. Argument order follows `code-style.md`:
  `design` → required NSE → required scalar → optional NSE → optional scalar → `...`.
- Every function gets an explicit output contract: column names, types, and the
  tibble class. Columns must include at minimum: `variable`, and any estimand
  columns with exact names (`prop`, `prop_se`, `mean`, `mean_se`, etc.). Give
  every column a presence condition — which argument combination makes it
  appear. A column contract left vague is a contract the builder and the tester
  will read differently, and that is the failure this whole workflow exists to
  prevent.
- Every error condition is listed in a table with: error class, trigger
  condition, and the message template. Class names follow:
  `"surveyreports_error_{snake_case}"` or `"surveyreports_warning_{snake_case}"`.
  All new classes must also be added to `plans/error-messages.md`.
- "TBD" and "to be determined" are not allowed — flag as **GAP** with
  `> ⚠️ GAP: [description]` so they are easy to find.
- The spec must explicitly state which `surveycore::get_*()` function is called
  for each design type and what the delegation contract is.
- Cross-design behavior must be specified: what changes, if anything, between
  the `survey_base` subclasses?
- CI behavior must be fully specified: formula, df source, distribution (t vs
  z), and what happens under each `variance` value.
- Do NOT restate rules already defined in `code-style.md` or
  `package-conventions.md`. Reference them.

---

## Before You Return — Leak Check

Verify all of these. Any failure means the draft is not done:

- [ ] `spec-{id}.md` has zero tolerances, zero datasets, zero oracle calls,
      zero `test_that()` names
- [ ] `test-spec-{id}.md` has zero `R/` file paths and zero internal
      `.helper()` names
- [ ] Neither file says "see the other document"
- [ ] Every output column in the spec has a name, a type, and a presence
      condition
- [ ] The design support matrix has a yes or no in every row — no blanks
- [ ] Every scenario in the test-spec covers taylor, replicate, and twophase
- [ ] Every error class named in either file exists in
      `plans/error-messages.md`
- [ ] Every new exported function has a documentation tier assigned

---

## After the Draft

Tell the user:

> "This is a first draft of spec-{id}.md and test-spec-{id}.md. I expect there
> are gaps. Next steps:
> - Run Stage 2 (methodology review) in a new session — it will self-assess
>   whether the output column contracts and CI specification need a methodology pass.
> - Do not resolve anything until both reviews are complete."
