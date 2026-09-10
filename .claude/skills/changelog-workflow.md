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
etc. prefix (e.g., branch `feature/export-topline` → file
`changelog/export-topline.md`).

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

For a branch `feature/export-topline-base-notes`:

```markdown
# feat(export): add base notes to export_topline()

**Date**: 2026-05-10
**Branch**: feature/export-topline-base-notes

## Changes

- Add a `base_notes` argument that writes a per-question base note beneath
  each block
- Validate `base_notes` and raise a typed error for an unnamed list
- Add cross-design tests for every design type from `make_all_designs()`
- Update `plans/error-messages.md` with the new error class

## Files Modified

- `R/export-topline.R` — accept and thread `base_notes` through the render
  helpers
- `R/export-utils.R` — add `.validate_base_notes()` and `.write_base_note()`
- `tests/testthat/test-export-topline.R` — cross-design and error-path tests
- `tests/testthat/_snaps/export-topline.md` — snapshot for the new error
- `plans/error-messages.md` — new error class row for base note validation
```
