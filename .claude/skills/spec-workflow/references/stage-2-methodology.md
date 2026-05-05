# Stage 2: Methodology Review

## Trigger Condition

Run this stage only when the spec contains **at least one** of:
- A statistical output column (proportion, mean, total, SE, CI bound)
- A CI formula or df specification
- A delegation contract with `surveycore::get_*()`
- A cross-design behavior difference

If none of these apply (e.g., a pure print method, a utility function with no
statistical output, a documentation change), declare Stage 2 not applicable, note
the reason briefly in the output file, and skip to Stage 3.

---

## Scope Assessment

Before applying the lenses, answer the following:

- Does this function produce statistical quantities (proportions, means, totals,
  SEs, CI bounds)?
- Does it specify a delegation contract with `surveycore::get_*()`?
- Does it involve CI computation, df specification, or cross-design behavior?

**If none apply**, declare Stage 2 not applicable and skip to Stage 3.

**If any apply**, proceed with all five lenses below. Within each lens, skip
sub-questions that genuinely don't apply — but err toward checking.

---

## Your Role

You are reviewing a reporting-layer spec for statistical and methodological
correctness. Your job: find every flaw in the output contracts, CI specification,
delegation logic, and cross-design behavior before code is written.

surveyreports delegates all variance estimation to `surveycore::get_*()`. Errors
here are not about reimplementing survey statistics — they are about whether the
spec correctly describes what surveycore produces, whether the CI derivation is
valid, and whether edge cases in the reporting layer are handled correctly.

This stage produces a **complete methodology issue list saved to a file**. It is
a batch pass — do not resolve issues here. Resolution happens in Stage 2 Resolve.

---

## Five Methodology Lenses

### Lens 1 — Output Column Contracts

The output tibble is the primary user-facing contract. Every column must be
precisely defined.

- Is every output column listed with its exact name, R type, and statistical meaning?
- For proportion columns: is `prop` a probability (0–1) or a percentage? Is this
  stated explicitly?
- For SE columns: are `prop_se`, `mean_se`, etc. standard errors (not variances)?
  Is this stated?
- For count columns: is `n` the unweighted sample count or the weighted estimate?
  Is this stated? Both cannot be named `n` without disambiguation.
- For CI columns: are `prop_low` / `prop_high` (or equivalent) present only when
  `ci = TRUE`? Are the column names consistent across all `report_*()` functions?
- Does the column naming scheme follow a consistent pattern across functions
  (e.g., `{estimand}_se`, `{estimand}_low`, `{estimand}_high`)?
- When `group` is supplied: is the group column named `group`, or does it use the
  actual variable name? Is this explicitly stated?
- Are there any columns that would differ between design types (Taylor vs.
  replicate vs. twophase)? If so, are those differences specified?

### Lens 2 — Confidence Interval Specification

CI columns are derived quantities. Errors here produce wrong intervals that pass
all structure tests.

- Is the CI formula stated? For a two-sided interval at level `α`:
  `estimate ± t(df, 1 - α/2) × SE` (t-based) or
  `estimate ± z(1 - α/2) × SE` (normal approximation).
  Which does the spec use? Is it consistent with what `surveycore::get_*()` returns?
- Is the df source specified? For Taylor designs: `degf(design)` gives design-based
  df. For replicate designs: df is the number of replicates minus 1 (or design-specific).
  Does the spec state which df is used, or delegate to surveycore?
- If the spec delegates CI computation entirely to surveycore (i.e., surveycore
  returns CI bounds directly), is this stated explicitly? If so, does the spec
  document what level surveycore uses and how `ci_level` is passed?
- What happens when `ci = FALSE`? Are CI columns absent from the result, or present
  with `NA` values? The spec must choose one and state it.
- Are CI bounds guaranteed to respect the estimand's support (e.g., proportions
  bounded to [0, 1])? If surveycore does not enforce this, does surveyreports?
- Is `ci_level` passed correctly to surveycore? The spec must show the mapping.

### Lens 3 — Statistical Delegation Accuracy

surveyreports wraps `surveycore::get_*()`. An incorrect delegation contract
produces silently wrong results.

- For each design type (Taylor, replicate, twophase): which specific
  `surveycore::get_*()` function is called? Is this stated?
- What arguments are passed? Is every relevant argument (`ci`, `ci_level`,
  `group`, domain column) shown in the delegation contract?
- What does surveycore return? Is the spec's description of the return value
  consistent with what `get_*()` actually returns (column names, types,
  structure)?
- Does the spec describe how surveyreports transforms surveycore output into the
  final tibble? Are any column renames, reorderings, or additions explicitly
  specified?
- For multi-variable iteration: the spec must state that `report_*()` calls
  surveycore once per variable (via `lapply()`). Is the iteration strategy shown,
  including how results are combined (`dplyr::bind_rows()`)?
- If surveycore raises an error or warning for an edge case (e.g., all-NA
  variable), does the spec state whether surveyreports propagates it, catches it,
  or adds its own?

### Lens 4 — Cross-Design Consistency

surveyreports must work correctly across Taylor, replicate, and twophase designs.

- Does the spec explicitly state that all three design types are supported?
- Are there any behavioral differences between design types? (Usually there
  should be none at the reporting layer — all differences are handled by
  surveycore.) If differences exist, are they intentional and documented?
- Does the spec state how the design type is detected? (Via
  `S7::S7_inherits(design, surveycore::survey_base)` or similar — not string
  checks.)
- Are edge cases (e.g., very small df in some replicate designs, empty domain
  across all three types) addressed consistently?

### Lens 5 — Domain and Grouping Behavior

Domain estimation and grouped analysis are the most common sources of subtle
reporting errors.

- When `group` is supplied: does the spec state that `report_*()` passes the
  group argument to surveycore, or does it iterate over group levels manually?
  The former is preferred; the latter is a delegation contract change.
- When a domain is active on the design: does `report_*()` respect it? Is this
  stated explicitly?
- When both `group` and a domain are active: does the spec define the composed
  behavior?
- For empty groups (a group level present in the design but with no in-domain
  rows): what does the spec say happens? Silence is not acceptable.
- Is the `group` column resolution specified? (Using `tidyselect::eval_select()`
  per `package-conventions.md`.)

---

## Issue Format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
Lens: [1–5 and lens name]
Resolution type: UNAMBIGUOUS | JUDGMENT CALL

[Concrete description. Quote or reference the spec text that is missing or
wrong. State the specific methodological problem in plain language.
For UNAMBIGUOUS: state the correct fix directly.
For JUDGMENT CALL: state the options and their trade-offs.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high], Impact: [what changes]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays wrong or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

**Severity tiers:**

- **BLOCKING** — The function will produce wrong statistical output without
  resolving this. An implementer could write code that passes all structure tests
  and still emit incorrect estimates or CI bounds.
- **REQUIRED** — A significant gap that will cause silent wrong behavior,
  inconsistency across design types, or user confusion about what the output means.
- **SUGGESTION** — A documentation or clarity improvement; the implementation
  would likely still be correct without it.

**Resolution types** (used by Stage 2 Resolve for batching):

- **UNAMBIGUOUS** — There is one correct answer. Show the fix; ask once to confirm.
- **JUDGMENT CALL** — Multiple valid approaches exist. Ask the user to decide.

---

## If a Methodology Review File Already Exists

Before writing any output, check for `plans/spec-methodology-{id}.md`.

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

Organize all issues by lens. If a lens has no issues, say "No issues found."
If a lens was skipped, say "Lens [N] not applicable: [reason]."

```markdown
## Methodology Review: [id] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | [title] | 1 | ✅ Resolved |
| 2 | [title] | 3 | ⚠️ Still open |

### New Issues

#### Lens 1 — Output Column Contracts

**Issue [N]: [title]**
Severity: BLOCKING
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS
...

#### Lens 2 — Confidence Interval Specification

No issues found.

[continue for all five lenses]

---

## Summary (Pass [N])

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| SUGGESTION | N |

**Total issues:** N

**Overall assessment:** [One honest sentence — e.g., "The output column contracts
are sound but the CI delegation to surveycore is unspecified, meaning the CI level
may not be passed correctly for replicate designs."]
```

---

## Before Outputting

Ask yourself:

- Did I complete the Scope Assessment?
- Have I applied all five lenses?
- Have I flagged every column whose statistical meaning is vague or unstated?
- Have I verified the CI formula and df source are explicit?
- Have I checked the delegation contract for all three design types?
- Is every issue assigned UNAMBIGUOUS or JUDGMENT CALL?
- Is the overall assessment honest?

If the methodology is genuinely sound, say so.

---

## Mini-Pass Mode

Use this mode when an error is discovered in Stage 3 or during implementation
and the methodology lock needs a targeted update.

1. Read only the affected section of the spec.
2. Apply only the relevant lenses to that section.
3. Write a `### Mini-Pass [N] ([YYYY-MM-DD])` section and **append** it to the
   existing `plans/spec-methodology-{id}.md` — never overwrite.
4. End with: `"Mini-pass complete: {N} issues found. Resolve via Stage 2 Resolve
   targeting these issues only."`

---

## After Completing the Review

1. Determine `{id}` from the spec filename if not already known.
2. Append the new pass section to `plans/spec-methodology-{id}.md` (create on Pass 1).
3. End the session with:

   > "Methodology review Pass [N] complete: {N} new issues ({X} blocking,
   > {Y} required, {Z} suggestions). Start a new session with
   > `/spec-workflow stage 2 resolve` to lock the methodology before running
   > the code review. Review appended to `plans/spec-methodology-{id}.md`."
