# Stage 1: Drafting the Implementation Plan

Only start this stage when the user explicitly says the spec is finalized.

## Before Writing Anything

Use the `AskUserQuestion` tool to gather context:

```
questions:
  - question: "Which spec is this plan for? I'll read it before drafting."
    header: "Spec location"
    multiSelect: false
    options:
      - label: "I'll provide the file path"
        description: "Share the path so I can read the full spec first."
      - label: "It's already in context from this session"
        description: "The spec content is visible in this conversation."

  - question: "Is there a spec-review output file to check scope against?"
    header: "Review file"
    multiSelect: false
    options:
      - label: "Yes — plans/spec-review-{id}.md exists"
        description: "I'll verify all BLOCKING and REQUIRED issues were resolved before drafting."
      - label: "No — spec was reviewed informally"
        description: "Draft directly from the spec."

  - question: "Any PR sequencing constraints I should know about?"
    header: "Constraints"
    multiSelect: false
    options:
      - label: "No — follow standard ordering"
        description: "Shared infrastructure first, then functions in spec order."
      - label: "Yes — I'll describe them"
        description: "Provide ordering requirements before I start."
```

Read the spec in full before writing a single line of the plan. If a spec-review
file exists, skim it to confirm no BLOCKING issues remain open.

---

## Plan Structure

The implementation plan is a separate document from the spec. Required sections:

**Overview** — 2–3 sentences: what this plan delivers and how it relates to
the spec.

**PR map** — A checkbox list of every planned PR:

```
- [ ] PR 1: `feature/branch-name` — one-sentence description
- [ ] PR 2: `feature/branch-name` — one-sentence description
```

Rules for the PR map:

- **One PR per exported function.** Two exports ship together only when they
  share a helper that cannot ship on its own.
- Shared infrastructure (validators, helpers, test data generators) ships in its
  own PR before the functions that depend on it.
- No PR should contain more than ~3 new R files + their test files.
- `devtools::document()` and `devtools::check()` must pass before every PR.
- Follow the TDD order within each PR: write failing tests first.

**Per-PR sections** — For each PR in the map:

```markdown
### PR [N]: [Human-readable title]

**Branch:** `feature/[name]`
**Depends on:** PR [n] (or "none")

**Files (in TDD order — tests first):**
- `tests/testthat/test-[function].R` — [one-sentence description]
- `R/[function].R` — [one-sentence description]

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Happy path tests pass for every design type in `testing.md`
- [ ] Every section in this file's template in `testing.md` covered
- [ ] Numerical oracle: estimates match surveycore::get_*() at point 1e-10, SE 1e-8
- [ ] All error paths covered with dual pattern (class= + snapshot)
- [ ] plans/error-messages.md updated if new error/warning classes introduced
- [ ] 98%+ line coverage on the new file(s)

**Notes:** [Any implementation details the implementor needs to know that aren't
in the spec — gotchas, ordering constraints, etc.]
```

---

## After the Draft

Tell the user:

> "Review the PR map carefully — the scope of each PR is harder to change
> once implementation starts. Confirm that each PR carries one exported
> function. Run Stage 2 in a new session for an adversarial review of this
> plan before handing off to `/r-implement`."
