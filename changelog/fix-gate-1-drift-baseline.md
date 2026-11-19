# fix(pipeline): compare gate 1 with the files before document()

**Date**: 2026-11-19
**Branch**: fix/gate-1-drift-baseline

## Changes

Gate 1 of `.claude/scripts/run-gates.sh` checks that `devtools::document()`
changes nothing in `NAMESPACE` and `man/`. It used `git diff --quiet`, which
compares the working tree with the index. The builder runs `document()` but
does not commit, so the regenerated Rd file was still uncommitted when the
gates ran. The gate then reported drift although `document()` changed
nothing. This happened on PR 14 (`feature/crosstab-label-cols-and-sizes`,
`man/export_crosstab.Rd`).

The gate is now the function `gate_document()`:

- It copies `NAMESPACE`, `man/` and `DESCRIPTION` to a temp directory, runs
  `document()`, and compares each file with its copy.
- A changed, new or deleted file is drift. The log lists each file and shows
  the diff. The summary row gives the count of files.
- The comparison ignores CR at line ends. roxygen2 writes LF, and a checkout
  with `core.autocrlf` has CRLF.
- `document()` writes the local roxygen2 version into
  `Config/roxygen2/version` in DESCRIPTION. When that line is the only
  change, the gate puts DESCRIPTION back as it was and does not report it.
  Any other change to DESCRIPTION, such as a new `Collate` field, is drift.
- The gate fails when `document()` exits with an error. Before, an error
  left `man/` unchanged and the gate passed.

`.claude/skills/pipeline-shared/references/r-package-profile.md` describes the
new check in the Validation commands section.

## Testing

Gate 1 ran alone, from the function text in the script, on scratch changes
to the roxygen of `pool_pvals()`:

| Case | Result |
|---|---|
| Clean tree | PASS |
| Roxygen edit, `document()` run, Rd uncommitted | PASS |
| Same, DESCRIPTION at 8.1.0 and local roxygen2 8.1.1 | PASS, DESCRIPTION put back |
| Roxygen edit, no `document()` run | FAIL, `changed: man/pool_pvals.Rd` |
| `man/pool_pvals.Rd` deleted | FAIL, `new: man/pool_pvals.Rd` |

The scratch changes were reverted. The full gate script was not run.
