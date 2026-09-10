# GitHub Strategy

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Branching model | `develop` integration branch — features → `develop`; `develop` → `main` for releases |
| Branch naming | `feature/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/` |
| Merge strategy | Squash and merge everywhere |
| Commit format | Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) |
| PR granularity | One PR per logical unit of work |
| Versioning | `X.Y.Z.9000` on `develop`; `X.Y.Z` on `main` after release |
| CI | R-CMD-check required on `main` and `develop`; all PRs |
| Release workflow | Use `/merge-main` |

---

## Workflow Tiers

| Tier | When to use | Workflow |
|------|-------------|----------|
| **1 — Full** | New phases, new exported functions, anything where correct behavior is undecided | spec → plan → implement → PR |
| **2 — Plan only** | Medium bug fixes, new arguments, edge cases — behavior obvious, approach isn't | plan → implement → PR |
| **3 — Direct** | Clear bug fixes in 1–2 functions, test additions, roxygen changes | branch → implement → PR |
| **0 — Commit** | Typos, comments, `.gitignore`, README tweaks | direct commit to `develop` |

---

## Branching Model

```
main          ← always stable; every commit is a tagged release
  ↑
develop       ← integration branch; all feature work lands here first
  ↑
feature/*     ← individual units of work; branch from develop
hotfix/*      ← urgent fixes only; branch from main
```

Feature branches always cut from `develop` and merge back to `develop`. Never
open a feature PR directly against `main`.

Hotfixes branch from `main`, merge to `main`, then immediately open a second PR
into `develop`. Do not leave `main` ahead of `develop`.

**Before any release PR:** run `git log origin/develop..origin/main --oneline`.
If it shows anything, sync `develop` first.

### Branch vs. direct push

| Change type | Branch needed? |
|-------------|----------------|
| New R source file | Yes |
| New test file | Yes |
| Any change to exported function | Yes |
| README / docs update | No |
| Comment or typo fix | No |
| `.Rbuildignore` / `.gitignore` | No |
| Version bump + NEWS.md | Direct commit to `develop` |

---

## Branch Naming

Format: `{type}/{short-description}`

| Prefix | Use for |
|--------|---------|
| `feature/` | New functionality |
| `fix/` | Bug fix in existing implementation |
| `hotfix/` | Urgent fix that can't wait for next release |
| `docs/` | Documentation-only changes |
| `test/` | Test-only additions or fixes |
| `chore/` | Maintenance (CI config, build tooling) |
| `refactor/` | Internal restructuring, no behavioral change |

Examples: `feature/export-topline-base-notes`, `fix/crosstab-empty-banner-level`,
`test/topline-cross-design`

---

## Commit Format (Conventional Commits)

```
{type}({scope}): {short description}
```

| Type | Use for |
|------|---------|
| `feat` | New exported function |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |
| `perf` | Performance improvement |

Scopes: `export`, `pvals`, `data`, `pipeline`, `ci`, `docs`

| Scope | Covers |
|-------|--------|
| `export` | `R/export-topline.R`, `R/export-crosstab.R`, `R/export-utils.R` |
| `pvals` | `R/pool-pvals.R` and the `print.survey_pooled_pvals()` method |
| `data` | `R/data.R` and the bundled datasets |
| `pipeline` | The workflow skills, agents, and rule files under `.claude/` |
| `ci` | GitHub Actions workflows and coverage config |
| `docs` | README, `_pkgdown.yml`, vignettes, and files in `plans/` |

Examples:
```
feat(export): add show_eff_n to topline and crosstab
fix(export): handle an empty banner level without error
test(pvals): add BH edge cases for a single-row family
chore(ci): add test-coverage GitHub Actions workflow
```

Squash merge commit: `feat(export): add base notes to topline and crosstab (#3)`

---

## PR Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] `_pkgdown.yml` updated (if a new export was added)
- [ ] Changelog entry created at `changelog/{branch-name}.md`
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)

---

## Versioning

| Context | Format | Example |
|---------|--------|---------|
| Active development on `develop` | `X.Y.Z.9000` | `0.1.0.9000` |
| Released on `main` | `X.Y.Z` | `0.1.0` |

| Tag | What it means |
|-----|---------------|
| `v0.1.0` | Core output functions — `export_topline()`, `export_crosstab()` |
| `v0.2.0` | Reporting helpers beyond the two export functions |
| `v1.0.0` | Stable API, CRAN submission |

---

## Release Preparation

Use `/merge-main`. It handles: NEWS.md update → version bump → `devtools::check()` →
PR `develop` → `main` → tag → post-release `.9000` bump.
