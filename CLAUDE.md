# surveyreports Package Development

**Part of the surveyverse ecosystem.**

surveyreports automates reporting analyses over multiple variables for Taylor series, replicate weight, and two-phase survey designs.

---

## Current Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0 — Initial scaffold | 🔜 Next | See `plans/` |

**Next action:** Begin Phase 0.

---

## Key Implementation Rules

- Every non-trivial change lives on a feature branch — never commit to `main` or
  `develop` directly
- Branch naming: `feature/`, `fix/`, `test/`, `docs/`, `chore/`
- All commits use Conventional Commits format: `feat(scope): description`
- Run `devtools::document()` before committing any file with roxygen2 changes
- Run `devtools::check()` before opening a PR

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names
- `.claude/rules/` — code style, testing standards, R package conventions
