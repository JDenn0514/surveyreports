# Changelog Workflow

This is a reference document, not an invocable skill. It defines the canonical
changelog format enforced by `commit-and-pr`.

---

## Location and Timing

```
Location:  changelog/{branch-name}.md
Timing:    Created LAST on the branch, BEFORE opening the PR
Populated: From git log develop..HEAD --oneline
```

Where `{branch-name}` is the full branch name without the `feature/`, `fix/`,
etc. prefix (e.g., branch `feature/report-freqs` → file `changelog/report-freqs.md`).

---

## Entry Format

```markdown
# [type]([scope]): [description]

**Date**: YYYY-MM-DD
**Branch**: feature/[name]

## Changes

- [Bullet derived from commit messages describing what changed]
- [One bullet per logical change, not one per commit]

## Files Modified

- `R/[file].R` — [one sentence describing what changed in this file]
- `tests/testthat/test-[file].R` — [one sentence]
- `plans/error-messages.md` — [if new error classes were added]
```

---

## Deriving Content from Commits

Run `git log develop..HEAD --oneline` to get the commit list. Use those messages
to populate the `## Changes` section. Group related commits into single bullets
where appropriate (e.g., a sequence of "fix: " commits that address the same
issue can be one bullet).

---

## Validation Rules

These are enforced by `commit-and-pr` before a PR is opened:

1. File must exist at `changelog/{branch-name}.md`
2. File must not be empty or a stub (no `<!-- TODO -->` placeholders)
3. `## Changes` section must have at least one bullet
4. `## Files Modified` section must list at least one file
5. `**Date**` must be a real date (not a placeholder)

---

## Example

For a branch `feature/report-freqs`:

```markdown
# feat(freqs): implement report_freqs() for Taylor, replicate, and two-phase designs

**Date**: 2026-05-10
**Branch**: feature/report-freqs

## Changes

- Implement `report_freqs()` returning a tibble with one row per variable × value
- Add cross-design support for taylor, replicate, and twophase designs
- Add `group` argument for grouped frequency tables
- Add numerical accuracy tests comparing against `surveycore::get_freqs()`
- Update `plans/error-messages.md` with new freqs-specific error classes

## Files Modified

- `R/report-freqs.R` — implement `report_freqs()` and internal helpers
- `tests/testthat/test-report-freqs.R` — full test suite including cross-design and numerical accuracy
- `plans/error-messages.md` — new error class rows for report_freqs validation
- `_pkgdown.yml` — add `report_freqs` to the frequency functions reference section
```
