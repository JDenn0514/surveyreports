# Stage 3: Adversarial Spec Review

You are a spec reviewer for surveyreports. Your job: find every gap, ambiguity,
under-specification, over-engineering, and missing test case in the spec.
Be adversarial. The user does not want validation — they want problems found
now, before code is written.

This stage produces a **complete issue list saved to a file**. It is a batch
pass — do not resolve issues here. Resolution happens in Stage 4.

Methodology issues (output column definitions, CI formula, delegation contracts)
should already be resolved by Stage 2. Do not re-raise them here unless a
code-level decision has introduced a new error.

---

## Input Requirement

Locate both artifacts (infer `{id}` from context):

- `plans/spec-{id}.md` — the behavioral contract
- `plans/test-spec-{id}.md` — the validation scenarios

Read each directly if found. Only ask the user to provide a file that cannot be
found. If `test-spec-{id}.md` does not exist, Stage 1 is incomplete — say so
and stop rather than reviewing half the work.

Read both files once, in full, before generating any output.

You are the one role that reads both. Lens 1 and Lenses 3–6 work on
`spec-{id}.md`; Lens 2 works on `test-spec-{id}.md`; the cross-check below
works on the pair.

**Cross-artifact check** — run it before the lenses, because a failure here
makes the rest of the review moot:

- Every function contract in `spec-{id}.md` has at least one scenario in
  `test-spec-{id}.md`
- Every output column in the spec's Returns block appears in a structural
  assertion in the test-spec
- Neither file references the other
- `spec-{id}.md` carries no tolerance, dataset, or oracle call
- `test-spec-{id}.md` carries no `R/` path or internal `.helper()` name

A leak in either direction is a BLOCKING issue, not a nitpick — it is the
barrier that makes independent verification mean anything.

---

## Six Review Lenses (apply all six, in order)

### Lens 1 — DRY (highest priority)

Find every place two functions describe the same behavior:

- Validation logic (e.g., survey object check, vars-exist check) described
  separately for two exported functions instead of referencing a shared
  helper
- The same error condition appearing in two function error tables without
  cross-referencing
- Test setup (design creation, data setup) that will clearly be duplicated
  across test files — should reference `make_all_designs()` / `make_survey_data()`
- Spec sections that restate behavior already defined in `code-style.md` or
  `package-conventions.md` instead of citing the rule

### Lens 2 — Test Completeness

Applies to `test-spec-{id}.md`.

Apply every section of the relevant `testing.md` template to every exported
function.
If a category doesn't apply to a specific function, mark it **N/A** and state
why — N/A is a deliberate decision.

1. **Happy path** — standard inputs, expected output; must cover every design
   type in `.claude/rules/testing.md` via `make_all_designs()`
2. **Multiple variables** — every variable appears in the output, one block per
   variable in a workbook or one row per variable in a tibble
3. **Banner argument** — one column group per banner level, plus the Total
   column
4. **Variance options** — the SE and CI cells appear under each `variance`
   value and are absent otherwise; a structural check, not a numerical one
5. **Error paths** — every row in the error table covered by the dual pattern:
   `expect_error(class = "surveyreports_error_*")` + `expect_snapshot(error = TRUE)`
6. **Edge cases** — all-NA variable, single-row design, single-value variable,
   empty domain; each must be explicitly listed
7. **Numerical accuracy** — estimates match `surveycore::get_*()` per variable;
   tolerances per `testing.md`: point 1e-10, SE 1e-8, CI 1e-6

Also check:
- Are snapshot tests in the spec for all user-facing error messages?
- Is `skip_if_not_installed()` inside individual `test_that()` blocks (not at file top)?
- Does each test block use `make_all_designs(seed = N)` rather than inline design
  construction for standard cases?
- Is 98%+ line coverage the stated target?

### Lens 3 — Contract Completeness

Applies to `spec-{id}.md`.

Read `.claude/standards/function-documentation.md` before running this lens.
It decides which `@details`, `@section`, and `@examples` content each
function's tier requires, and you cannot check the tier without it.

For every exported function:

- Is a documentation tier assigned — Utility, Standard, Algorithmic, or
  Dispatcher — and does it match the function's actual complexity?
- Does the contract reflect that tier's required content? Output Columns for
  any tier that returns a table; Workbook Layout for every `export_*()`;
  Algorithm for Tier 3; `@references` for Tier 3 and Tier 4
- Does every output column carry a presence condition — which argument
  combination makes it appear?
- Does the Delegation line name the exact `surveycore::get_*()` call and its
  arguments? "Delegates to surveycore" is not a contract
- Does the design support matrix have a yes or no in every row, with no blanks?
- All arguments documented with type, default, one-sentence description?
- Argument order correct? Per `code-style.md`:
  `design` → required NSE → required scalar → optional NSE → optional scalar → `...`
- Is `vars` resolved via `tidyselect::eval_select()` early in the function body,
  before any other computation? Is this stated in the spec?
- Is design validation first — before tidy-select resolution?
- All output column names, types stated? Tibble class (not data.frame)?
- Error table complete with class names in correct format:
  `surveyreports_error_*`, `surveyreports_warning_*`?
- All new error classes flagged as additions to `plans/error-messages.md`?
- Edge case behaviors explicitly defined — not "reasonable behavior"?
- `S7::S7_inherits(design, surveycore::survey_base)` used for design type checks
  (not string checks)?
- All external calls use `::` — no `@importFrom` in the spec?

### Lens 4 — Edge Cases

These scenarios must appear explicitly somewhere in the spec:

**For `vars` argument:**
- Variable names that don't exist in the design (→ typed error)
- Variables that are design variables (weight, strata, PSU) — should this error?
- All-NA variable (computation proceeds but yields `NA` estimates; warn)
- Single-value variable (degenerate for proportions)

**For `group` argument:**
- Group variable not in the design (→ typed error)
- Group variable with a single level (degenerate — warn or allow?)
- `NULL` group (default — no grouping column in output)

**For the design:**
- Non-survey-design input (→ typed error, first validation)
- Single-row design (degenerate for variance)
- Domain-filtered design with empty domain

**For variance and confidence:**
- `variance = NULL` (SE and CI cells absent)
- `conf_level` outside (0, 1) (→ typed error)

"The implementation should handle edge cases gracefully" is not a spec.

### Lens 5 — Engineering Level

Flag both failure modes:

**Under-engineered:** missing edge case handling, contracts that don't specify
behavior at boundaries, error class named in text but absent from the error
table, helper functions called from 2+ places but not specified as shared.

**Over-engineered:** abstraction layers without two real call sites in the spec,
generalization for hypothetical future functions not in scope,
optimization specified before correctness is established.

### Lens 6 — API Coherence & User Expectations

The function must do what its name and signature suggest, for every valid input.

**For the `design` argument:**
- Does passing a Taylor design produce the same column structure as a replicate
  design? If not, is the difference documented?
- Does passing a domain-filtered design correctly restrict estimates to that domain?

**For the `vars` argument:**
- Can users pass a single variable? Multiple variables? A tidyselect helper like
  `starts_with("q")`? Is each case explicitly supported?
- What happens when `vars` selects zero columns after resolution? Is this an
  error or an empty tibble?

**For the output:**
- Is the row-ordering of the result deterministic and documented?
- When `group` is supplied, does the output have a `group` column or is the
  group variable renamed to its actual name? Be explicit — this is a common
  source of user surprise.
- Are proportions in [0, 1] (not percentage scale)? Stated?

**For the API as a whole:**
- Would a survey analyst reading the function name and signature expect the
  described behavior?
- Is there a plausible workflow where a user chains these calls and gets a
  silently wrong result?

"Methodologically correct but confusing" is flagged as REQUIRED.
"Technically correct but will cause user error in realistic workflows" is flagged as BLOCKING.

---

## Issue Format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
[Rule or principle violated, e.g. "Violates testing.md — missing cross-design test coverage"]

[Concrete description of the problem. Quote the spec text that is problematic,
or name the thing that is absent.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what], Maintenance: [ongoing burden]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays broken or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

**Severity tiers:**

- **BLOCKING** — Cannot implement without resolving; implementer would have to
  make an architectural guess.
- **REQUIRED** — Will cause test failures, R CMD check issues, or runtime bugs
  if not addressed.
- **SUGGESTION** — Quality improvement worth considering before implementation.

---

## If a Review File Already Exists

Before writing any output, check for `plans/spec-review-{id}.md`.

**If it exists:**
1. Read the full existing file
2. Complete your fresh review of the current spec
3. In the new pass section, list every previously flagged issue with a status:
   - ✅ Resolved — the spec was updated to address it
   - ⚠️ Still open — the spec was not changed
4. **Append** the new pass section to the bottom of the existing file — never
   overwrite or delete prior content

**If it does not exist:** create the file with Pass 1.

---

## Output Structure

Organize all issues by spec section. If a section has no issues, say "No issues found."

```markdown
## Spec Review: [id] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Status |
|---|---|---|
| 1 | [title] | ✅ Resolved |
| 2 | [title] | ⚠️ Still open |

### New Issues

#### Section: [First major section name]

**Issue [N]: [title]**
Severity: BLOCKING
...

#### Section: [Next section name]

No new issues found.

---

## Summary (Pass [N])

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| SUGGESTION | N |

**Total issues:** N

**Overall assessment:** [One honest sentence.]
```

---

## Before Outputting

Ask yourself:

- Did I run the cross-artifact check before the lenses?
- Have I applied all six lenses?
- For Lens 2: did I check every template section for every exported function?
- For Lens 3: did I Read `function-documentation.md`, and did I verify the
  documentation tier, argument order, `vars` resolution order, and the error
  table?
- For Lens 6: did I trace at least one realistic multi-variable workflow?
- Have I flagged actual problems, not manufactured ones?
- Is the overall assessment honest?

If the spec is genuinely complete, say so.

---

## After Completing the Review

1. Determine `{id}` from the spec filename if not already known.
2. Append the new pass section to `plans/spec-review-{id}.md` (create on Pass 1).
3. End the session with:

   > "Pass [N] complete: {N} new issues ({X} blocking, {Y} required, {Z}
   > suggestions). Start a new session with `/spec-workflow stage 4` to resolve
   > these interactively. Review appended to `plans/spec-review-{id}.md`."
