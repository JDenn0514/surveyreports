# Stage 1: Drafting a Spec Sheet

## Before Writing Anything

Use the `AskUserQuestion` tool to gather context before reading or writing anything:

```
questions:
  - question: "Which function or feature is this spec for?"
    header: "Feature"
    multiSelect: false
    options:
      - label: "report_freqs() — weighted frequencies and proportions"
        description: "Tabulates one or more categorical variables across all three design types."
      - label: "report_means() — survey-weighted means"
        description: "Computes means with SEs and CIs for continuous variables."
      - label: "report_totals() — estimated population totals"
        description: "Computes weighted totals with SEs and CIs."
      - label: "Other / new function"
        description: "A new report_*() function or a utility/helper not listed above."

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

Confirm the `{id}` with the user if not obvious from context. Default patterns:
`report_freqs()` → `report-freqs`, `report_means()` → `report-means`. The output
file will be `plans/spec-{id}.md` — establish this before writing anything.

Wait for the user to provide any referenced documents. Read all provided context
before writing a single line of the spec.

---

## Spec Structure

Required sections:

| Section | Content |
|---|---|
| Header block | Version, date, status |
| Document Purpose | One paragraph: this is the source of truth for this function |
| I. Scope | What this spec delivers, what it does NOT deliver, design support matrix (taylor / replicate / twophase) |
| II. Architecture | File organization, shared helpers with signatures |
| III–N. Function specs | One section per exported function: signature, argument table, output contract, behavior rules, error table |
| Testing section | Per-function test categories (all 7 from `testing.md`), edge cases |
| Quality Gates | Checklist of what "done" means — must be objectively verifiable |

---

## Spec Writing Rules

- Every exported function gets a full argument table: name, type, default,
  one-sentence description. Argument order follows `code-style.md`:
  `design` → required NSE → required scalar → optional NSE → optional scalar → `...`.
- Every function gets an explicit output contract: column names, types, and the
  tibble class. Columns must include at minimum: `variable`, and any estimand
  columns with exact names (`prop`, `prop_se`, `mean`, `mean_se`, etc.).
- Every error condition is listed in a table with: error class, trigger
  condition, and the message template. Class names follow:
  `"surveyreports_error_{snake_case}"` or `"surveyreports_warning_{snake_case}"`.
  All new classes must also be added to `plans/error-messages.md`.
- "TBD" and "to be determined" are not allowed — flag as **GAP** with
  `> ⚠️ GAP: [description]` so they are easy to find.
- The spec must explicitly state which `surveycore::get_*()` function is called
  for each design type and what the delegation contract is.
- Cross-design behavior must be specified: what changes (if anything) between
  Taylor, replicate, and twophase designs?
- CI behavior must be fully specified: formula, df source, distribution (t vs z),
  and what happens when `ci = FALSE`.
- Do NOT restate rules already defined in `code-style.md` or
  `package-conventions.md`. Reference them.

---

## After the Draft

Tell the user:

> "This is a first draft. I expect there are gaps. Next steps:
> - Run Stage 2 (methodology review) in a new session — it will self-assess
>   whether the output column contracts and CI specification need a methodology pass.
> - Do not resolve anything until both reviews are complete."
