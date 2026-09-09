# R Package Profile — surveyreports

R-specific commands, gates, and CRAN-compliance rules. The tester agent runs
these in order; the builder respects them during implementation.

This file states the gate mechanics. It does not restate `.claude/rules/`,
which is auto-loaded. Where the two overlap, the rule file wins.

## Validation commands (the tester runs these in order)

| # | Command | Gate | On fail |
|---|---------|------|---------|
| 1 | `Rscript -e "devtools::document()"` | NAMESPACE/man/ unchanged after the run | BLOCK (the builder forgot `document()`) |
| 2 | `Rscript -e "devtools::test()"` | all tests pass | BLOCK (numerical-miss or contract-miss) |
| 3 | `Rscript -e "devtools::run_examples()"` | all `@examples` run clean | BLOCK (examples use unloaded Imports or broken syntax) |
| 4 | `R CMD build .` | tarball produced | BLOCK (build failure) |
| 5 | `R CMD check --as-cran <tarball>` | 0 ERRORs, 0 WARNINGs; NOTEs reviewed | BLOCK on ERROR/WARNING |
| 6 | `Rscript -e "pkgdown::build_site(preview = FALSE)"` | site builds, no errored pages | BLOCK (unless skipped, see below) |
| 7 | `Rscript -e "covr::package_coverage()"` | 95% floor, 98% target | BLOCK below 95%; HOLD if 95–98% and dropped vs baseline |
| 8 | `air format --check .` | every R file already formatted | BLOCK — run `air format .` as its own commit, then redo the change |

### Canonical runner

Run the whole table with ONE background command:

```
bash .claude/scripts/run-gates.sh <log-dir> [--skip-pkgdown]
```

It logs each gate to `<log-dir>`, prints one summary table plus a `Tree:` hash,
and exits 0 only when every gate passes. `--baseline` mode (gates 2 and 7 only)
captures the Before-column numbers on a clean tree. Never run the gates one
command at a time.

## Output discipline (all gates)

Redirect every gate's full output to
`{workspace-run-dir}/logs/gate-{N}-*.log`. Bring into context ONLY:

- `tail -25` of the log, and
- `grep -E "FAIL|ERROR|WARNING|NOTE"` of the log.

Record each log path in `audit.md` under Profile gates. Read a full log only
when diagnosing that gate's failure.

### pkgdown skip condition

The tester MAY skip gate 6 when the PR's write surface does not touch:

- `R/` (any source file)
- `vignettes/`
- `README.Rmd`, `README.md`
- `_pkgdown.yml`
- `DESCRIPTION` (Title, Description, Imports)

A skip is logged in the `audit.md` Profile gates table as `SKIPPED — scope`.

**No skip when exports change.** If the PR adds, removes, or renames any
exported function, pkgdown MUST run — a non-empty NAMESPACE diff means no
exception.

## Pre-approved NOTEs

These NOTEs do NOT block. The list comes from
`.claude/rules/package-conventions.md` section 5:

| NOTE | Reason |
|------|--------|
| `no visible binding for global variable 'X'` | Universal in tidy packages; do NOT suppress with `utils::globalVariables()` |
| `checking CRAN incoming feasibility` | Informational only; the package is not on CRAN yet |

Any other NOTE is reviewed by the tester. The reviewer escalates to STOP if a
new NOTE pattern appears that is not on this list.

## CRAN cookbook scan

The tester greps these patterns in every changed `.R` file (the
`implementation.md` write surface). The Label column is an audit label, not a
`cli_abort()` class — do not add these to `plans/error-messages.md`.

| Violation | Pattern | Label |
|-----------|---------|-------|
| `T`/`F` as logicals | bare `T` or `F` in code context | `cookbook_tf_abbrev` |
| Hardcoded `set.seed()` in non-test code | `set\.seed\(` in `R/` without a `seed` arg | `cookbook_hardcoded_seed` |
| Bare `print()` or `cat()` | `^\s*(print|cat)\(` in `R/` outside print/summary methods | `cookbook_bare_print` |
| `options(warn = -1)` | `options\(warn\s*=\s*-1` | `cookbook_suppress_warn_global` |
| `installed.packages()` | `installed\.packages\(` | `cookbook_installed_packages` |
| `<<-` | `<<-` | `cookbook_global_assign` |
| Unrestored `par()` / `options()` | `par\(|options\(` without `on.exit()` in the same function | `cookbook_unrestored_state` |
| More than 2 cores | `mc\.cores\s*=\s*[3-9]` or `makeCluster\([3-9]` | `cookbook_cores_gt_2` |
| `@importFrom` in source | `^#' @importFrom` anywhere in `R/` | `cookbook_importfrom` |
| `%>%` pipe | `%>%` in `R/` or `tests/` | `cookbook_magrittr_pipe` |
| String-based class check | `inherits\(.*"survey_` | `cookbook_string_class_check` |
| `cli_abort` without a class | `cli_abort\(` in a call with no `class =` | `cookbook_untyped_condition` |

The last three are surveyreports-specific, from `.claude/rules/code-style.md`:
the pipe is `|>` only, class membership uses
`S7::S7_inherits(x, ClassName)` with the class object, and `class=` is required
on every `cli_abort()` and `cli_warn()`.

Each hit is a BLOCK. The tester reports in `audit.md`:

```
## CRAN cookbook violations
| File | Line | Violation | Label |
|------|------|-----------|-------|
| R/report-freqs.R | 42 | T as logical | cookbook_tf_abbrev |
```

## DESCRIPTION checks

The tester validates against `.claude/rules/package-conventions.md`:

- **Description field**: at least 2 sentences
- **Title**: Title Case
- **Authors@R**: `person()` format; no deprecated `Author`/`Maintainer`
- **Imports versions**: lower-bound pins `(>= x.y.z)` on all entries; no exact
  pins (`==`)
- **`Remotes:` entry for surveycore is present.** surveycore is not on CRAN.
  A PR that removes the `Remotes: JDenn0514/surveycore` line, or moves
  surveycore from `Imports` to `Suggests`, is a BLOCK. See `CLAUDE.md`.
- **No `@importFrom`**: grep `^#' @importFrom` across `R/` — any hit is a BLOCK

## Error class registry check

Every `class =` string in a `cli_abort()` or `cli_warn()` call in the write
surface must appear as a row in `plans/error-messages.md`. A class thrown by
code but absent from the table is a BLOCK. A row in the table that no code
throws is a note, not a BLOCK — flag it for the reviewer.

## Builder compliance rules

The builder MUST follow these during implementation:

1. Use `TRUE`/`FALSE`, never `T`/`F`
2. Call external functions with `::`; no `@importFrom` anywhere
3. Use `cli::cli_inform()` for informational output, not `print()`/`cat()`
4. Provide a `seed = NULL` argument for any function using randomness
5. Restore `par()` / `options()` with `on.exit()`
6. Use `tempdir()` for I/O; clean up with `on.exit(unlink(...))`. Workbook
   export functions write to a caller-supplied path — never a hardcoded one
7. Cap parallel workers at 2 in examples and tests
8. Run `devtools::document()` before committing roxygen changes
9. Use `requireNamespace("pkg", quietly = TRUE)`, not `installed.packages()`
10. Every `cli_abort()` and `cli_warn()` carries `class =`, and that class
    exists in `plans/error-messages.md`
11. Test S7 class membership with `S7::S7_inherits(x, surveycore::survey_base)`
    — the class object, never a string
12. Use `|>`, never `%>%`
13. Resolve tidy-select arguments to character vectors before any computation

The builder notes compliance at the bottom of `implementation.md` — see
`artifact-schemas.md`.
