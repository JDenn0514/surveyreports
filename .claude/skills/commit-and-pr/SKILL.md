---
name: commit-and-pr
description: >
  Commits staged changes, opens a pull request against develop, and monitors CI
  for surveyreports feature branches. Read-only commit workflow — does not write
  or edit R source files or test files; use r-implement for code changes first.
  Trigger when the user says "commit", "make a PR", "open PR", "submit this
  work", "PR time", "commit and PR", "commit and merge", "commit, PR, and merge",
  "ship it", or "land it".
---

# Commit and PR Skill

**Announce at start:** "Running commit-and-pr skill."

## HARD CONSTRAINT — READ THIS FIRST

**YOU ARE A COMMIT/PR AGENT.**

You CANNOT write, edit, or create:
- `.R` source files
- `.R` test files
- Any other source code

If you notice code that should change, add a `TODO:` note to the PR body
describing the issue, and report it to the user. Do NOT touch the code.

**The ONLY files you may create or edit:**
- `changelog/{branch-name}.md` — the changelog entry for this branch

If you find yourself about to use the Edit or Write tool on a `.R` file,
**stop immediately and tell the user what you found**. Ask them whether to
invoke `r-implement` to address it, or note it as a TODO in the PR.

---

## Session Recovery — Check This Before Starting

Call `TaskList` first. If a "PR:" task already exists in `in_progress`:

| Task state | What to do |
|---|---|
| PR task `in_progress`, no CI task | Check if PR exists (`gh pr view`); resume from Step 5 if yes, Step 2 if no |
| PR task `in_progress`, CI task `in_progress` | Resume CI monitoring (Step 8) using `runId` from task metadata |
| PR task `in_progress`, CI task `completed` with status `failed` | Reproduce failure locally, produce handoff block (Step 9), ask user to invoke `r-implement` |
| PR task `completed` | Report PR URL and done message — nothing to do |
| No tasks | Fresh start — proceed to Step 1 |

---

## Step 1: Orientation

Run these first, before anything else:

```bash
git branch --show-current
git log develop..HEAD --oneline
git status
```

**If on `main` or `develop`: STOP.** Inform the user that implementation work
must be on a feature branch cut from `develop`. Do not proceed.

**Detect merge intent:** Check whether the user's invocation included any of
these phrases: "commit and merge", "commit, PR, and merge", "ship it",
"land it". If yes:
- Announce: "Merge after CI will be performed."
- Set the flag in task metadata (see TaskCreate below).

Create the main tracking task:

```
TaskCreate:
  subject:    "PR: [branch-name]"
  description: "Commit and open PR for [branch-name]."
  activeForm: "Preparing PR for [branch-name]"

TaskUpdate:
  status: in_progress
  metadata: { mergeAfterCI: true }   ← only if merge intent detected; omit otherwise
```

---

## Step 2: Changelog Entry (REQUIRED before any commit)

Read `.claude/skills/changelog-workflow.md` for the canonical format.

The changelog file lives at: `changelog/{branch-name}.md`

Steps:
1. Check if `changelog/{branch-name}.md` exists
2. **If it does not exist:** create it following `changelog-workflow.md`,
   using `git log develop..HEAD --oneline` to populate the `## Changes` section
3. **If it exists:** verify it is populated — not empty, no `<!-- TODO -->`
   placeholders, `## Changes` has at least one real bullet

**If the changelog entry is missing or empty, STOP and report:**

```
No changelog entry found for this branch.

Expected: changelog/{branch-name}.md

The changelog entry must be created before opening the PR.
```

Do not proceed to pre-flight or commits until the changelog entry exists and
is populated.

---

## Step 3: Pre-flight Checks

Run AFTER the changelog entry is confirmed.

### 3a. Skip when the tester already passed this code

Find the `audit.md` for this branch. Its path is the `Audit:` line of the
shipper's SHIP READY block, or the user gives it. If no audit path is known,
go to 3b.

Skip the pre-flight check only when all three are true:

1. `audit.md` has `**Verdict**: PASS`.
2. `audit.md` has a `Tree:` line.
3. The `Tree:` value equals the output of this command:

```bash
bash .claude/scripts/tree-hash.sh
```

The hash covers every file in the working tree except `changelog/`. Equal
values mean the code has not changed since the tester ran the gates. The
tester ran the full test suite, R CMD check, and `pkgdown::check_pkgdown()`
on that code.

When you skip, record this line in the task metadata and in your report to the
user:

```
Pre-flight: SKIPPED — tree unchanged since audit {path}
```

Then go to Step 4.

### 3b. Run the pre-flight check

Run this when 3a does not skip: no audit is known, the verdict is not PASS,
the audit has no `Tree:` line, or the hashes differ.

```bash
log_dir="$(mktemp -d)"
Rscript -e 'devtools::check(error_on = "warning")' \
  > "$log_dir/check.log" 2>&1
echo "check exit: $?"
Rscript -e 'pkgdown::check_pkgdown()' > "$log_dir/pkgdown.log" 2>&1
echo "pkgdown exit: $?"
```

`devtools::check()` runs the full test suite and the examples, so do not run
`devtools::test()` as well. Keep the logs out of the repo, so they do not show
in `git status`.

Read only the end of each log and its error lines:

```bash
tail -25 "$log_dir/check.log"
grep -E "ERROR|WARNING|NOTE|FAIL" "$log_dir/check.log"
tail -25 "$log_dir/pkgdown.log"
```

Required results:
- `devtools::check()` — 0 errors, 0 warnings, ≤2 notes, no test failures
- `pkgdown::check_pkgdown()` — no problems

**If either fails: STOP.** Inform the user of the failure. Do not proceed to
commits. Ask the user to invoke `r-implement` to fix the issue, then re-invoke
`commit-and-pr`.

---

## Step 4: Stage and Commit

```bash
git status
```

Review the changed files list. If any `.R` source or test files appear that were
not part of this implementation task, stop and report to the user before staging.
This skill does not write code — unexpected `.R` changes need investigation.

Stage SPECIFIC files by name — never `git add -A` or `git add .`.

Always include the changelog file in the staged set.

Commit format, valid types, and valid scopes: see `github-strategy.md` (Commit
Format section).

Pass the commit message via HEREDOC:
```bash
git commit -m "$(cat <<'EOF'
feat(export): add base notes to export_topline()

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

**Rules:**
- Never amend; always create new commits for fixes
- Never skip pre-commit hooks (`--no-verify`)
- If a pre-commit hook fails: fix the issue, re-stage, create a NEW commit
  (do not amend)

---

## Step 5: Check for Existing PR

Before creating a PR, verify one doesn't already exist:

```bash
gh pr view 2>/dev/null && echo "PR EXISTS" || echo "NO PR"
```

If a PR already exists: report its URL, update the task with its URL, and
skip to Step 8 (Monitor CI).

---

## Step 6: Draft and Approve PR

PR template: see `refs/feature-pr-template.md`.

Draft a PR title (Conventional Commit format) and body following that template.
**Show the draft to the user before creating.** Ask for approval. Revise if
requested. Do NOT create the PR until the user approves.

---

## Step 7: Push and Create PR

```bash
git push -u origin <branch-name>

gh pr create \
  --base develop \
  --title "<approved-title>" \
  --body "$(cat <<'EOF'
<approved-body>
EOF
)"
```

Capture the PR URL and store it:

```
TaskUpdate:
  metadata: { prUrl: "<url>", prNumber: <N> }
```

Report the PR URL to the user.

---

## Step 8: Monitor CI

Read `refs/ci-monitoring.md` for the complete monitoring and failure-handoff
procedure. Return here for Step 10 when CI passes.

---

## Step 10: CI Passed — Merge Check

When CI passes:

```
TaskUpdate (CI task):
  subject: "CI Run #N: passed"
  status:  completed
  metadata: { status: "passed" }
```

Check task metadata for `mergeAfterCI`:

- **`mergeAfterCI == true`:** Proceed to Step 11.
- **`mergeAfterCI` absent or false:** Mark PR task complete and stop (see
  "Done without merge" below).

**Done without merge:**

```
TaskUpdate (PR task):
  status: completed
```

1. Report the PR URL
2. Read the implementation plan and find the first remaining `- [ ]` section
3. Report:

   > "Next section: `branch-name` — [description]. Start a new session with
   > `/r-implement` to continue."

---

## Step 11: Optional Merge (only when `mergeAfterCI == true`)

**Confirmation gate** — show and wait for explicit user approval:

> "CI passed. PR #N (`feature/foo` → `develop`): *{prTitle}*
>
> Squash-merge this PR?"

Do NOT proceed until the user says yes. If no or cancel:

> "Merge cancelled. PR #N is open and CI-green — merge manually when ready."

Stop.

**On approval:**

```bash
gh pr merge <prNumber> --squash --delete-branch
```

```
TaskUpdate (PR task):
  status: completed
```

Report: "Merged: {prUrl}"

Then read the implementation plan and report the first remaining `- [ ]`
section as the next action (same as the "Done without merge" step above).

---

**Do NOT merge the PR unless the user explicitly requested merge at invocation
time (`mergeAfterCI` flag). When in doubt, stop after CI.**

---

## Quick Reference: What This Skill CAN and CANNOT Do

| Action | Allowed? |
|---|---|
| Read `.R` files to understand what was implemented | Yes |
| Create `changelog/{branch-name}.md` | Yes |
| Run `devtools::check()` and `pkgdown::check_pkgdown()` | Yes |
| Skip the pre-flight check when the tree hash equals a PASS audit's `Tree:` | Yes |
| Run `devtools::test()` after `devtools::check()` | **NO** — check runs the tests |
| Stage and commit files | Yes |
| Push the branch | Yes |
| Create the PR | Yes |
| Monitor CI | Yes |
| Produce CI failure handoff block for r-implement | Yes |
| Merge the PR (when explicitly requested at invocation) | Yes |
| Write or edit `.R` source files | **NO** |
| Write or edit `.R` test files | **NO** |
| Fix failing tests | **NO** |
| Fix R CMD check errors | **NO** |
| Amend commits | **NO** |
| Merge the PR (when NOT requested at invocation) | **NO** |
