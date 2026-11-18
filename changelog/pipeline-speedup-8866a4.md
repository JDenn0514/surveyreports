# chore(pipeline): cut repeated test runs from the pipeline gates

**Date**: 2026-11-18
**Branch**: claude/pipeline-speedup-8866a4

## Changes

A PR with no BLOCK ran the full test suite up to 9 times before CI. It now
runs it at most 4 times: the baseline once, the builder at most twice, and
the tester once. Most of the changes port surveycore 1d78525 (#370).

| Who | Suite runs before | Suite runs after |
|---|---|---|
| Baseline (`run-gates.sh --baseline`) | 2 (test, covr) | 1 (covr) |
| Builder | at most 2 | at most 2 |
| Tester (`run-gates.sh`) | 3 (test, check, covr) | 1 (covr) |
| `commit-and-pr` pre-flight | 2 (check, test) | 0 when the tree is unchanged, else 1 (check) |

- One covr run now gives the test counts, the failing tests and the coverage.
  Gates 2 and 7 are one gate, `tests + covr`. The tests run against the
  installed, instrumented package, as in `R CMD check`.
- The gate needs covr 4.0.0 or newer. `covr-report.R` prints
  `COVR_VERSION=`, and the summary row names the version. On an older covr
  the gate fails before it runs the tests, and the tester treats that as a
  HOLD. The cloud scripts install or flag an older covr.
- Gate 5 runs `R CMD check --no-tests`. Gate 2 ran the suite, and CI runs the
  check with tests on 5 OS.
- Gate 3 (`devtools::run_examples()`) is removed. The check runs the examples.
- Gate 6 runs `pkgdown::check_pkgdown()` in place of `build_site()`. CI builds
  the site on every PR.
- New `.claude/scripts/tree-hash.sh` prints one hash of the working tree,
  with uncommitted and untracked files, and without `changelog/`. The tester
  records it as `Tree:` in `audit.md`. `commit-and-pr` skips its pre-flight
  when the hash is unchanged since a PASS audit. Otherwise it runs
  `devtools::check()` and `check_pkgdown()`, and no longer runs
  `devtools::test()` as well.
- `r-implement`, its Mode C and CI-fix references, and the CI handoff block
  no longer run `devtools::test()` after `devtools::check()`.
- The tester and reviewer no longer mark the nonprob design as a `gap`.
  `make_all_designs()` returns it since a1d491b.
- New cloud setup script and SessionStart hook, ported from surveycore
  5e3d11c. The hook does nothing unless `CLAUDE_CODE_REMOTE` is `true`.

Measured on this branch, on a Windows laptop:

- New full `run-gates.sh`: 759 s, all gates PASS. The `tests + covr` gate took
  about 670 s (2697 tests, coverage 99.80%). `R CMD check --no-tests` took
  about 70 s. `check_pkgdown()` took a few seconds.
- One `devtools::test()` took 890 s. It ran at the same time as a covr run,
  so the number is high.

Not ported: the srr roclet removal (surveycore 9096dec). surveyreports has no
srr roclet. Not done: test runs scoped to the changed files. surveycore tried
that and reverted it, because it reported lines as uncovered that other test
files reach.

## Files Modified

- `.claude/scripts/run-gates.sh` — merges gates 2 and 7, removes gate 3, adds `--no-tests`, uses `check_pkgdown()`, takes `Tree:` from `tree-hash.sh`.
- `.claude/scripts/covr-report.R` — runs the tests inside covr and prints the test counts and failing tests with the coverage.
- `.claude/scripts/tree-hash.sh` — new; prints the working-tree hash.
- `.claude/skills/pipeline-shared/references/r-package-profile.md` — new gate table, covr caveats, pkgdown skip rule.
- `.claude/skills/pipeline-shared/references/artifact-schemas.md` — gate checklist and gate table rows.
- `.claude/skills/pipeline-shared/references/signals.md` — BLOCK triggers name the new gates.
- `.claude/skills/pipeline-simplified/SKILL.md` — baseline runs one gate.
- `.claude/agents/tester.md` — new gate text, covr-version HOLD, nonprob is a required column.
- `.claude/agents/reviewer.md` — nonprob is a required column; coverage row name.
- `.claude/agents/shipper.md` — SHIP READY block carries the audit tree hash.
- `.claude/skills/commit-and-pr/SKILL.md` — Step 3 skips on an unchanged tree; otherwise check only.
- `.claude/skills/commit-and-pr/refs/ci-handoff-template.md` — check only.
- `.claude/skills/r-implement/SKILL.md` — Verification and Done Criteria run check only.
- `.claude/skills/r-implement/references/mode-c-subagent.md` — baseline is check only.
- `.claude/skills/r-implement/references/ci-fix.md` — check only.
- `.claude/scripts/cloud-env-setup.sh` — new; cloud environment setup script.
- `.claude/scripts/cloud-session-start.sh` — new; installs missing packages in a cloud session.
- `.claude/settings.json` — new; registers the SessionStart hook.

## Notes

- Gate 1 runs `devtools::document()`. With roxygen2 8.1.1 installed, it
  changes `Config/roxygen2/version` in DESCRIPTION from 8.1.0. The gate checks
  only `NAMESPACE` and `man/`, so it passes, but DESCRIPTION is left modified.
- `R CMD check` gave 3 NOTEs on this worktree. The extra one is the hidden
  `.git` file that a git worktree has. The main checkout does not have it.
