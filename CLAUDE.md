# surveyreports Package Development

**Part of the surveyverse ecosystem.**

surveyreports automates reporting analyses over multiple variables for
Taylor series, replicate weight, and two-phase survey designs.

------------------------------------------------------------------------

## surveycore Dependency

surveycore is **not on CRAN** — it is installed via
`Remotes: JDenn0514/surveycore` in DESCRIPTION. It lives in `Imports`,
not `Suggests`. Do **not** move it to `Suggests` and do **not** remove
the `Remotes:` entry.

------------------------------------------------------------------------

## Key Implementation Rules

- Every non-trivial change lives on a feature branch — never commit to
  `main` or `develop` directly
- Branch naming: `feature/`, `fix/`, `test/`, `docs/`, `chore/`
- All commits use Conventional Commits format:
  `feat(scope): description`
- Run `devtools::document()` before committing any file with roxygen2
  changes
- Run `devtools::check()` before opening a PR

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names
- `.claude/rules/` — code style, testing, package conventions, GitHub
  strategy

------------------------------------------------------------------------

## Engineering Principles

These govern every implementation decision. When in doubt, use this as
the tiebreaker.

1.  **DRY — flag repetition aggressively.** Repeated logic in 2+
    functions → extract a shared helper. Repeated validation →
    consolidate. Repeated test setup → move to `helper-*.R`. Surface DRY
    violations during spec review, not after.

2.  **Well-tested — more tests is better.** 98%+ line coverage is the
    floor. Every error class gets a test. Every edge case in the spec
    gets a test. Never suggest removing coverage to hit a deadline.

3.  **Engineered enough — not under, not over.** Under-engineered:
    missing edge cases, happy-path-only validation. Over-engineered:
    abstraction without two real call sites, generalization for
    hypothetical future work. Right-size to the current spec.

4.  **Handle more edge cases, not fewer.** All-NA inputs, zero-weight
    rows, single-level groups, empty domains — these appear in real
    survey data. Thoughtfulness \> speed.

5.  **Explicit over clever.** `S7::S7_inherits(x, ClassName)` not
    `inherits(x, "string")`. Named error classes on every `cli_abort()`.
    Spell out behavior in specs rather than leaving it implicit.
