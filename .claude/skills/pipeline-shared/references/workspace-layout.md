# Workspace Layout

Per-request runtime artifacts live under `.surveyreports-workspace/`, a
gitignored directory at the repo root. Durable documentation artifacts (specs,
reviews, decisions) live in `plans/` and are committed.

## Directory structure

```
<repo-root>/
├── .surveyreports-workspace/        (gitignored)
│   └── runs/
│       └── {request-id}/
│           ├── status.md            state transitions (append-only)
│           ├── request.md           user intent
│           ├── impact.md            scope assessment
│           ├── comprehension.md     optional — methods-heavy only
│           ├── extraction-{slug}.md optional — one per attached paper
│           ├── decisions.md         HOLD/STOP resolutions log
│           ├── logs/                gate output (gate-{N}-*.log)
│           └── prs/
│               └── pr-{n}-{slug}/
│                   ├── implementation.md   builder output
│                   ├── audit.md            tester output
│                   ├── review.md           reviewer output
│                   └── shipper.md          ship record
└── plans/                           (committed)
    ├── spec-{id}.md                 builder's input — behavioral contract
    ├── test-spec-{id}.md            tester's input — validation scenarios
    ├── impl-{id}.md                 PR map + acceptance criteria
    ├── spec-methodology-{id}.md     methodology review (if applicable)
    ├── spec-review-{id}.md          spec review output
    ├── plan-review-{id}.md          plan review output
    ├── comprehension-{id}.md        durable copy (if methods-heavy)
    ├── decisions-{id}.md            decisions log (durable copy)
    └── error-messages.md            canonical error/warning class table
```

`plans/` already holds artifacts under these names — `spec-review-export-topline-crosstab.md`,
`impl-export-topline-crosstab.md`, `decisions-export-topline-crosstab.md`. The
pipeline adopts the convention that is already in use; it does not introduce a
new one.

## Request ID

Format: `YYYY-MM-DD-{slug}` where slug is short kebab-case. Example:
`2026-09-09-report-freqs`. Stable across the whole lifecycle.

The `{id}` used inside `plans/` filenames is the slug alone, without the date —
`spec-report-freqs.md`, not `spec-2026-09-09-report-freqs.md`. It matches the
feature branch identifier.

## Gitignore

`.gitignore` at the repo root carries:

```
.surveyreports-workspace/
```

## Lifecycle

- **At request start**: the orchestrating skill creates `runs/{id}/` and writes
  `request.md`, `impact.md`, and `status.md` (with line `NEW`).
- **During work**: agents write outputs into the run directory. Status
  transitions are appended to `status.md`.
- **At SPEC_READY**: `spec-{id}.md` and `test-spec-{id}.md` are copied into
  `plans/` and committed.
- **At DONE**: the orchestrating skill copies the remaining durable artifacts
  (`impl-{id}.md`, `decisions-{id}.md`) into `plans/`. The workspace entry is
  kept for forensics.

## What NOT to put in the workspace

- Production code (lives in `R/`, `tests/testthat/`)
- Roxygen docs (inline in source)
- `NEWS.md` entries (committed)
- Anything a reviewer needs after the branch merges — that goes in `plans/`

## Per-PR subdirectories

`prs/pr-{n}-{slug}/` groups builder, tester, and reviewer outputs for a single
PR. Required when the implementation plan has more than one PR — each PR needs
its own artifact set so parallel dispatch does not collide.
