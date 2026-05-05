# Stage 4: Resolve Issues + Log Decisions

## Before Starting

Check for a spec-review file at `plans/spec-review-{id}.md`.

**If the file exists:** Work through those issues in order. Do not do a fresh
review pass — the adversarial review is already done.

Note: methodology issues (from `plans/spec-methodology-{id}.md`) should already
be resolved by Stage 2 Resolve and are not re-raised here. If a code-level
decision has introduced a new statistical error (e.g., a wrong column definition
or CI formula), flag it and suggest running a targeted Stage 2 mini-pass on that
section only.

**If no file exists:** Tell the user:

> "No spec-review file found at `plans/spec-review-{id}.md`.
> Run Stage 3 first to get a saved issue list, then come back here to
> resolve them. Alternatively, confirm you want an informal review pass
> without a saved issue list."

---

## Choose a Batch Size

Use the `AskUserQuestion` tool:

```
question: "How many issues do you want to see at a time?"
header: "Batch size"
multiSelect: false
options:
  - label: "BIG — 4 issues at a time"
    description: "Present up to 4 issues, resolve all of them, then move to the next batch. Faster overall."
  - label: "SMALL — 1 issue at a time"
    description: "Present one issue, resolve it, then the next. Easier to stay focused."
```

Wait for the answer before presenting any issues.

---

## Working Through the Issues

Work through the issues **in the order they appear in the review file** —
do not re-group or re-sequence them.

**In BIG mode (4 at a time):** Before presenting the batch, spawn one `Explore`
sub-agent per issue using the `Agent` tool. Run all four simultaneously (single
message, multiple `Agent` calls). Each agent deepens the analysis for its issue:

```
You are a senior R package engineer reviewing an issue from a surveyreports spec review.
Your job: research this issue and enrich the options analysis.

Spec file: plans/spec-{id}.md
Codebase root: [working directory]

Issue to research:
[paste the full issue text from the review file]

Do the following:
1. Read the relevant section(s) of the spec this issue references.
2. Search the codebase for any existing code related to this issue.
3. Check plans/decisions-{id}.md for any prior decisions touching this issue.
4. Return a short enrichment block (3–8 sentences) covering:
   - What the spec currently says (quote it)
   - Whether any existing code already handles or conflicts with the options
   - Any prior decision that constrains the choice
   - Any cross-issue dependency
   - Confirm or update the effort/risk estimates

Do NOT rewrite the issue or change the recommendation — just add the enrichment.
Return nothing else.
```

Wait for all agents to complete. Merge each enrichment into its issue under a
`> **Context:**` blockquote before showing it to the user. Then present the full
batch and use `AskUserQuestion` for each issue sequentially. Apply fixes after
all decisions in the batch are collected. Then ask:
> "Ready for the next batch?"

**In SMALL mode (1 at a time):** Show the issue text, use `AskUserQuestion`,
apply the fix immediately, then move to the next issue.

Do not apply fixes speculatively — wait for the `AskUserQuestion` response on
each issue before editing the spec.

---

## Issue Format

Show each issue as markdown, then immediately use `AskUserQuestion`. The
recommended option **must be first**. Every option **must be labeled** with
the issue number and letter.

Present the issue text:

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
[Rule violated, e.g. "Violates testing.md — missing error path test."]

[Concrete description, with section/spec reference.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: Option [A/B/C]** — [Why.]
```

Then call AskUserQuestion:

```
question: "Issue [N] — [Short title]: which option?"
header: "Issue [N]"
multiSelect: false
options:
  - label: "Issue [N] — Option [Rec]: [short label] (Recommended)"
    description: "[effort/risk/impact/maintenance summary]"
  - label: "Issue [N] — Option [Alt]: [short label]"
    description: "[trade-offs]"
  - label: "Issue [N] — Option C: Do nothing"
    description: "[consequences]"
```

---

## Applying Fixes

When the user approves a direction, **edit the spec file immediately** — before
presenting the next issue. Do not batch fixes. After each edit, summarize what
changed in one sentence.

---

## Decisions Log

After all issues are resolved, write a decisions log entry if ANY of these
are true:

- You asked the user a question during this session
- You chose between meaningfully different approaches
- You made a scope or behavior assumption not obvious from the spec
- You deferred something to a later implementation

**If every decision is already fully captured in the updated spec, skip the
log entry.**

The log lives at `plans/decisions-{id}.md`. This file is **append-only** —
never overwrite or delete existing entries. If the file exists, add the new
entry below all previous entries. Create the file with this header only if
it doesn't exist yet:

```markdown
# Decisions Log — surveyreports [id]

This file records planning decisions made during [id].
Each entry corresponds to one planning session.

---
```

Entry format:

```markdown
## [YYYY-MM-DD] — [Component or feature planned]

### Context

[1–2 sentences: what were we trying to figure out in this session?]

### Questions & Decisions

**Q: [The question that came up]**
- Options considered:
  - **[Option A]:** [description and trade-offs]
  - **[Option B]:** [description and trade-offs]
- **Decision:** [what was decided]
- **Rationale:** [why — mapped to project constraints and engineering preferences]

### Outcome

[1 sentence: what will be built as a result of this session]

---
```

Only log decisions — not implementation details already determined by the spec
or a rule file.

---

## After Resolution

1. Update the spec version in the header block.
2. End the session with:

   > "Code review resolved. {N} issues resolved ({X} blocking, {Y} required,
   > {Z} suggestions). Spec at version [X.Y] is approved. Start
   > `/implementation-workflow` in a new session to build the implementation plan."
