# docs(pipeline): cut the caches the rule rewrite left behind

**Date**: 2026-09-10
**Branch**: docs/rules-match-real-api

## Changes

- Cut the near-verbatim DESCRIPTION copy from `package-conventions.md` section
  6. What stays is the part reading DESCRIPTION does not give you: why
  `LazyData: true` is required, and why `Remotes:` carries surveycore and must
  keep it in `Imports`
- Drop the stale version bounds from the version-pinning rule in section 5.
  One of them (`rlang (>= 1.1.0)`) had already drifted from DESCRIPTION
  (`>= 1.0.0`)
- Replace the 19-column roster of `make_survey_data()` in `testing.md` with
  what the column names do not say: the three question shapes the fixture
  covers, its phase-2 indicator, its all-NA column, and the fixed column set
- Make the `survey_base` subclass table in `testing.md`, **Cross-design
  testing**, the single source of truth. `code-style.md`,
  `package-conventions.md`, and `function-documentation.md` now cite it.
  Adding a fifth subclass is a one-file edit
- Keep the `survey_collection` distinction — it does not inherit
  `survey_base` — everywhere it already appeared
- Stop `stage-2-methodology.md` Lens 1 from listing the internal columns of
  `.build_freq_frame()`. The lens now checks the user-visible output contract,
  so a correct spec that says nothing about the private frame no longer gets
  flagged

## Files Modified

- `.claude/rules/package-conventions.md` — drop the DESCRIPTION copy and the
  pinned version list; cite `testing.md` from the `@param design` example
- `.claude/rules/testing.md` — add the canonical subclass table; replace the
  column roster with the fixture's coverage
- `.claude/rules/code-style.md` — replace the design-class table with a
  citation to `testing.md`
- `.claude/standards/function-documentation.md` — cite `testing.md` in the
  three places that enumerated the subclasses
- `.claude/skills/spec-workflow/references/stage-2-methodology.md` — Lens 1
  checks the output contract, not the internal frame's columns

## Notes

Three "current gap" notes are deliberate and stay: `make_all_designs()` has no
`nonprob` design, and both export functions still wrap their `@examples` in
`\dontrun{}`.
