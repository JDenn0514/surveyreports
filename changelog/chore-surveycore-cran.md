# chore: install surveycore from CRAN

**Date**: 2026-11-04
**Branch**: chore/surveycore-cran

## Changes

- Install surveycore from CRAN. surveycore 1.2.0 was published on CRAN on
  2026-11-03. `DESCRIPTION` no longer has a `Remotes:` line, and the
  `Imports:` floor rises from `surveycore (>= 0.8.2)` to
  `surveycore (>= 1.2.0)`.
- Change the rule for `Remotes:`. The old rule said surveycore is not on CRAN
  and that the `Remotes:` line must stay. The new rule says surveycore is on
  CRAN. A branch that needs unreleased surveycore code may add
  `Remotes: JDenn0514/surveycore@<branch>` for its life, and must remove the
  line before it merges.
- Reverse the tester's `DESCRIPTION` check to match. A PR into `develop` or
  `main` that carries a `Remotes:` line is now a BLOCK. Moving surveycore to
  `Suggests` is still a BLOCK.
- Point the r-implement version check at CRAN. It compared the installed
  version against the latest GitHub release tag. It now compares against the
  CRAN version, and the install hint is `pak::pak('surveycore')`.

No R source file, roxygen comment, or test file changed.

`devtools::test()` gives 424 passes, 0 failures, and 4 errors. The 4 errors
also occur on `develop` with surveycore 1.2.0 installed. Each one is a test
that builds a zero-row design, which surveycore 1.2.0 now rejects when the
design is built. A separate branch fixes those tests.

## Files Modified

- `DESCRIPTION` — removed `Remotes:`; raised the surveycore floor to 1.2.0
- `CLAUDE.md` — rewrote the **surveycore Dependency** section
- `.claude/rules/package-conventions.md` — rewrote the surveycore bullet in
  section 6, and added the branch-only rule for `Remotes:`
- `.claude/skills/pipeline-shared/references/r-package-profile.md` — reversed
  the `Remotes:` check
- `.claude/skills/r-implement/SKILL.md` — Step 2 now checks the CRAN version
- `changelog/chore-surveycore-cran.md` — new; this file
