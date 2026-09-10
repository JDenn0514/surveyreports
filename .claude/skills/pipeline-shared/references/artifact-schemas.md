# Artifact Schemas

Every `.md` artifact in the pipeline follows a fixed schema. Orchestrating
skills validate these sections before advancing state.

## `request.md`

```
# Request — {slug}

## Intent
{1–3 sentences: what the user asked for}

## Acceptance criteria
- {bullet list of observable outcomes}

## Attachments
- {any papers, PDFs, or markdown files of journal articles the user provided}
- {any external references — surveycore source, survey package docs, a client
   deliverable the output must match}
```

## `impact.md`

```
# Impact — {slug}

## Estimated scope
- Files touched: {count and list}
- Exported functions added/changed: {list}
- New dependencies: {list or "none"}
- Design types affected: taylor | replicate | twophase | all
- surveycore API surface used: {which get_*() functions, or "none"}
- CRAN-relevant: {yes/no — DESCRIPTION change, export change, new vignette}

## Workflow tier
- Result: tier-0 | tier-3 | tier-2 | tier-1-full
  (see .claude/rules/github-strategy.md §Workflow Tiers)
- Rationale: {one sentence}
```

The tier result routes the request. Only `tier-1-full` runs the full pipeline:

| Result | Route |
|---|---|
| `tier-1-full` | `/pipeline-spec`, then `/pipeline-implement` |
| `tier-2` | `/implementation-workflow`, then `/r-implement` |
| `tier-3`, and Files touched includes R code or a test | `/pipeline-simplified` |
| `tier-3`, docs only | Branch, implement, PR |
| `tier-0` | Commit to `develop` |

Read the R-code-or-docs split off the Files touched list. A roxygen comment is
not R code.

## `comprehension.md` (methods-heavy only)

Required when the request involves a CI formula, a degrees-of-freedom choice, a
pooling or adjustment method, a `surveycore::get_*()` contract the repo has not
used before, or a referenced paper or package implementation.

```
# Comprehension — {slug}

## Problem
{one paragraph in your own words}

## Formulas
{restated math; bind every symbol to a function argument or an output column}
{use exact LaTeX or pseudocode — no prose substitutes}

## Delegation boundary
- What surveycore computes: {list — estimate, SE, df, CI}
- What surveyreports computes on top: {list — or "nothing, pass-through"}
- Where the boundary could be crossed by mistake: {list}

## Gotchas
- {edge case} — {what to watch for}
- {e.g., empty domain after filtering, single-level group, all-NA variable,
   zero-weight rows, a SATA block where one item has no true-zero cell}

## Reference mapping
- {paper/package} §{section/equation} → {design decision in the spec}
- {e.g., Rubin (1987) eq. 3.1.3 → pool_pvals() combining rule}

## Assumptions
- {implicit constraint} — {why it matters}

## Citations
{one bulleted entry per source, in the format required by
 .claude/standards/function-documentation.md §@references}
{preserve any [NOT FOUND] flags from the extractions exactly}
```

## `spec-{id}.md`

The builder's input. Contains ONLY the behavioral contract — no test scenarios,
no tolerances, no test datasets, no oracle calls.

```
# Spec — {id}

**Status**: DRAFT | METHODS_REVIEWED | SPEC_READY
**Target version**: X.Y.Z.9000
**PR range**: PR n–m
**Standards read**: {exact file list from the planner's Step 0}

## Document purpose
{one paragraph: this is the source of truth for this function}

## Scope
### In
### Out
### Design support matrix
| Design type | Supported | Notes |
|---|---|---|
| survey_taylor | yes/no | |
| survey_replicate | yes/no | |
| survey_twophase | yes/no | |
| survey_collection | yes/no | |

## Architecture
- Files touched: {list}
- Functions added: {signatures}
- Functions modified: {signatures}
- Shared helpers: {signature + placement per code-style.md section 4}

## Function contracts
For each function:
### `fn_name(args)`
- **Documentation tier**: Utility | Standard | Algorithmic | Dispatcher
  (see `.claude/standards/function-documentation.md`)
- **Signature**: full signature with defaults, in the argument order from
  `code-style.md` section 4
- **Arguments**: each with semantics, `NULL` behavior, valid range
- **Delegation**: which `surveycore::get_*()` is called, with which arguments
- **Returns**: class, shape, exact column names and types, attributes

  | Column | Type | Meaning | Present when |
  |--------|------|---------|--------------|

- **Errors**: one row per named error class (must exist in `plans/error-messages.md`)

  | Class | Trigger condition |
  |-------|-------------------|
  | surveyreports_error_* | ... |

- **Warnings**: one row per named warning class
- **Edge cases**: exact behavior for empty domain, single-row data,
  single-level group, all-NA variable, zero-weight rows, unused factor level
- **Cross-design behavior**: any way the output differs by design type

## Quality gates
- {invariants that must hold across all inputs — e.g., proportions within a
   variable sum to 1 within floating-point tolerance; every row carries a
   non-NA `variable`}

## Pipeline split
recommended | optional — {justification}
```

No test cases. No tolerances. No references to `test-spec-{id}.md`.

## `test-spec-{id}.md`

The tester's input. Contains ONLY validation scenarios — no implementation
hints, no file paths from `R/`, no internal helper names.

```
# Test-spec — {id}

## Reference oracle
- `surveycore::get_{fn}()` — the single-variable function this output must match
- {any second oracle, e.g. survey::svymean for a hand-check, with version}

## Datasets
- `make_all_designs(seed = 42)` → every design type; structure and error tests
- `make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)` → plain data.frame
- {package data: anes_2024 | gss_2024 | ns_wave1 | pew_jewish_2020} → {purpose}
- Edge case data: inline in the test block, never a new generator parameter

## Per-function test plan
### `fn_name`
- **Happy path**

  | Scenario | Design type | Dataset | Expected | Tolerance |
  |----------|-------------|---------|----------|-----------|
  | ... | taylor / replicate / twophase / nonprob | ... | ... | 1e-10 |

- **Cross-design** — every scenario runs against every design type in
  `.claude/rules/testing.md`, Cross-design testing. A row naming one design
  type only is a gap. A function that takes no design has no such row.
- **Error paths** — one row per named error class

  | Error class | Trigger | Pattern |
  |-------------|---------|---------|
  | surveyreports_error_* | {trigger} | expect_error(class=) + expect_snapshot(error=TRUE) |

- **Warning paths** — one row per named warning class, using
  `expect_warning(result <- ..., class = ...)`
- **Edge cases** — one row per edge case from the spec

  | Case | Input | Expected behavior |
  |------|-------|-------------------|
  | empty domain | filter matching 0 rows | error: surveyreports_error_empty_domain |

- **Result structure** — the columns, types, and row count asserted before any
  numerical check, in every block
- **Numerical accuracy** — one row per estimand, compared against the oracle

## Tolerances
- Point estimates (mean, total, proportion): 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations (with written justification): {list, or "none"}

## Assertion conventions
- Structural (names, character vectors, column presence, NULL/NA):
  `expect_identical()`
- Numeric (proportions, estimates, SEs, weights): `expect_equal()` with tolerance
- Errors: dual pattern — `expect_error(class = )` AND `expect_snapshot(error = TRUE)`
- No `withCallingHandlers()` or `tryCatch()` in tests

## Profile gates (the tester runs ALL unless a skip condition applies)
- [ ] devtools::document() — NAMESPACE/man/ unchanged after the run
- [ ] devtools::test() — all tests pass
- [ ] devtools::run_examples() — all @examples run clean
- [ ] R CMD build
- [ ] R CMD check --as-cran — 0 errors, 0 warnings, notes reviewed
- [ ] pkgdown::build_site() — site builds (or SKIPPED — scope)
- [ ] covr::package_coverage() — 95% floor, 98% target, no uncovered new lines
- [ ] air format --check . — every R file already formatted
```

No implementation hints. No file paths from `R/`. No internal helper names.

## `impl-{id}.md`

```
# Implementation plan — {id}

## Overview
{2–3 sentences: what this plan delivers and how it relates to the spec}

## PR map
- [ ] PR 1: feature/{branch-slug} — {one-line goal}
- [ ] PR 2: feature/{branch-slug} — {one-line goal}

### PR 1: {Human-readable title}

**Branch:** `feature/{name}`
**Depends on:** PR {n} (or "none")

**Tasks** (2–5 min each, TDD sub-steps explicit):
1. Update `plans/error-messages.md` with new error/warning classes
2. Write the failing test for {behavior} in `tests/testthat/test-{file}.R`
3. Confirm the test fails for the right reason
4. Implement {function} in `R/{file}.R`
5. Verify the test passes
6. Run devtools::document()
7. Verify the full test suite passes
8. Write the changelog entry

**Acceptance criteria** — observable outcomes before merge:
- [ ] devtools::check(): 0 errors, 0 warnings, at most 2 pre-approved notes
- [ ] All tests in PR scope pass (list the specific test names)
- [ ] Every scenario runs against every design type required by `testing.md`
- [ ] Coverage at or above 98% overall, 95% floor, no uncovered new lines
- [ ] plans/error-messages.md updated (if applicable)

**Files touched** — the exact write surface:
- `plans/error-messages.md` — (if new classes)
- `R/{file}.R` — created | modified
- `tests/testthat/test-{file}.R` — created | modified
- `tests/testthat/_snaps/{file}.md` — generated by the snapshot tests
- `man/{fn}.Rd` — generated by devtools::document()
- `NAMESPACE` — generated by devtools::document()
```

No two concurrent PRs may share a file.

## `implementation.md` (per PR)

```
# Implementation — PR {n} — {id}

**Standards read**: {exact file list from Step 0}

## Write surface
- {file} — created | modified | deleted

## Summary
{what was implemented, in 3–5 bullets}

## Task checklist
- [x] {task 1}
- [x] {task 2}

## Signals raised
- {HOLD references, if any}

## CRAN compliance
- [x] TRUE/FALSE used throughout
- [x] :: used for every external call; no @importFrom anywhere
- [x] No bare print()/cat()
- [x] devtools::document() run
- [x] Every cli_abort()/cli_warn() has class=, and the class is in
      plans/error-messages.md
- [x] S7 class checks use S7::S7_inherits() with the class object

## Notes for tester
(Optional — neutral observations, NOT implementation details)
```

The builder does NOT write test results here. The builder's own unit tests run;
if they fail, the builder iterates. The tester's audit is separate.

## `audit.md` (per PR)

```
# Audit — PR {n} — {id}

**Verdict**: PASS | BLOCK
**Date**: {YYYY-MM-DD HH:MM}
**Standards read**: {(injected in dispatch prompt) | exact file list}

## Per-Test Result Table
| Test | Design type | Got | Expected | Tolerance | Pass |
|------|-------------|-----|----------|-----------|------|
| {name} | taylor | {value} | {value} | {value} | pass / fail |

## Cross-design coverage
| Function | taylor | replicate | twophase |
|----------|--------|-----------|----------|
| {fn} | pass | pass | pass |

## Before/After Comparison
| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| tests passing | {n} | {m} | +{diff} |
| coverage | {%} | {%} | {+/-%} |
| R CMD check notes | {n} | {m} | {diff} |

## Profile gates
| Gate | Result | Notes |
|------|--------|-------|
| devtools::document() | PASS/FAIL | {drift detected or clean} |
| devtools::test() | PASS/FAIL | {summary} |
| devtools::run_examples() | PASS/FAIL | {summary} |
| R CMD build | PASS/FAIL | {tarball} |
| R CMD check --as-cran | PASS/FAIL | {errors, warnings, notes} |
| pkgdown::build_site() | PASS/FAIL/SKIPPED | {reason if skipped} |
| covr::package_coverage() | {%} | {drop vs baseline, uncovered new lines} |
| air format --check . | PASS/FAIL | {count of unformatted files} |

Tree: {git tree hash at gate time}
Logs: {log directory path}

## CRAN cookbook violations
| File | Line | Violation | Label |
|------|------|-----------|-------|
(None — or list violations here)

## BLOCKs (if any)
(See signals.md BLOCK schema)
```

## `review.md` (per PR)

```
# Review — PR {n} — {id}

**Verdict**: PASS | BLOCK | STOP
**Date**: {YYYY-MM-DD HH:MM}
**Standards read**: {exact file list from Step 0}

## Convergence checks
- Spec coverage: {the audit validates every item in spec-{id}.md Function contracts — y/n}
- Test-spec coverage of spec: {test-spec-{id}.md covers every item in spec-{id}.md — y/n}
- Cross-design coverage: {every design-taking function tested against every required design type — y/n}
- Tolerance integrity: {the tester used the tolerances from the test-spec — y/n}
- Scope discipline: {implementation.md write surface matches the plan — y/n}
- Regression safety: {no test outside PR scope changed state — y/n}
- Documentation tiers: {every new export carries its tier's required sections — y/n}
- Comprehension alignment: {every gotcha from comprehension.md is tested or deferred — y/n}

## Cross-consistency notes
{narrative where the implementation and the audit disagree, if any}

## Decision
{1–3 sentences: why PASS, BLOCK, or STOP}

## STOP (if verdict=STOP)
(See signals.md STOP schema)
```

## `shipper.md` (per PR)

```
# Ship — PR {n} — {id}

**Branch**: feature/{slug}
**PR URL**: {url}
**Merged**: {YYYY-MM-DD HH:MM}
**Merge commit**: {sha}
**Standards read**: {exact file list from Step 0}

## Timeline
- {HH:MM} branch created
- {HH:MM} pushed
- {HH:MM} PR opened
- {HH:MM} CI green
- {HH:MM} merged

## CI gates
- R-CMD-check matrix: PASS ({which jobs})
- pkgdown: {result — informational}
- test-coverage: {result — informational}

## Post-merge
- [x] Plan checkbox marked
- [x] Branch deleted (local + remote)
```

## `status.md`

Append-only log. One line per transition:

```
{timestamp ISO8601}  {state}  ({justification})
```

Example:

```
2026-09-09T14:32:11Z  NEW
2026-09-09T14:38:00Z  COMPREHENDED  (no methods — auto)
2026-09-09T15:10:22Z  SPEC_READY    (spec-review PASS, methods-review N/A)
2026-09-09T15:45:03Z  PLAN_READY    (plan-review PASS)
2026-09-09T17:22:18Z  PIPELINES_COMPLETE  (PR 1 audit PASS)
2026-09-09T17:30:44Z  REVIEW_PASSED
2026-09-09T17:55:00Z  DONE
```

## `decisions-{id}.md`

Append-only log of HOLD and STOP signals and their resolutions. See
`signals.md` for the body schemas.
