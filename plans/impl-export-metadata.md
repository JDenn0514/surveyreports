# Implementation plan — export-metadata

**Status:** PLAN_READY
**Version:** 4.3.0
**Date:** 2026-11-04
**Id:** `export-metadata`
**Source spec:** `plans/spec-export-metadata.md` v0.21.0
**Source test-spec:** `plans/test-spec-export-metadata.md` v0.16.0
**Review applied:** `plans/plan-review-export-metadata.md` Pass 1 — 21 issues, all
resolved; Pass 2 — issues 22 and 23 resolved, suggestions 24 and 25 open;
Pass 3 — PASS, suggestions 26 and 27 applied
**Standards read:** `.claude/standards/function-documentation.md`

---

## Overview

This plan turns the spec into nineteen pull requests. The first five build
shared helpers. The next four land Part A — the metadata integration. The
following nine rebuild `export_crosstab()` output. The last one writes the
documentation prose.

**Every PR depends on the one before it.** The chain is strict, so no two PRs
run at the same time, and the rule that forbids two concurrent PRs from naming
one file is satisfied by the order alone. Each PR still lists its exact write
surface below, so a reviewer can see what it touches.

Each PR leaves the package green: `devtools::check()` passes, the suite passes,
and the coverage floor holds.

**Cross-references name a branch, not a number.** The PR numbering has changed
three times. A reference below names the branch, so the next renumber cannot
break it.

### Why four helper PRs exist

`feature/metadata-readers`, `feature/metadata-unanimity`,
`feature/metadata-guards` and `feature/format-helpers` add fifteen internal
helpers and own no scenario. Two reasons hold them apart from their callers.
`.claude/skills/implementation-workflow/references/stage-1-draft.md` requires
shared infrastructure to ship in its own PR before the functions that depend on
it. Folding each helper into its first caller would re-inflate the PRs that the
two earlier splits reduced. Pass 1 of the review proposed dissolving the four,
and the user declined.

The real risk those four carry is a return shape chosen without its consumer.
Each helper's criteria below therefore state the return shape and name the
branch whose call site will read it.

### The documentation split

Five PRs change a formal argument of the exported, documented
`export_crosstab()`. Each of those five edits its own `@param` entries, runs
`devtools::document()`, and carries `man/export_crosstab.Rd` and `NAMESPACE` in
its write surface. Without that, `R CMD check` reports a codoc mismatch and an
undocumented argument — both WARNINGs — and eight consecutive PRs carry a merge
gate none of them can pass.

`docs/export-metadata` still carries the prose of spec 7.2 — `@description`,
`@details`, `@section Workbook Layout`, `@returns`, `@seealso` — and the
`@param` entries of arguments this work neither adds nor removes. Those raise no
codoc mismatch, so deferring them is safe. **The prose deferral of spec 7.3
stands.** Only the formal arguments come forward.

`_pkgdown.yml` stays in `docs/export-metadata` alone.

---

## PR map

- [ ] PR 1: `chore/export-metadata-infra` — check the surveycore floor, add the
      `survey_nonprob` design to the generator, confirm the class table.
- [ ] PR 2: `feature/metadata-readers` — the five helpers that read a design.
- [ ] PR 3: `feature/metadata-unanimity` — the two resolvers that apply the
      unanimity rule.
- [ ] PR 4: `feature/metadata-guards` — the role guard and the
      design-variable reader.
- [ ] PR 5: `feature/format-helpers` — the six format and write helpers.
- [ ] PR 6: `feature/cover-sheet` — every workbook gains an `"About"` sheet.
- [ ] PR 7: `feature/effective-n-rewiring` — the reported effective N becomes
      correct on twophase and domain-restricted designs.
- [ ] PR 8: `feature/base-notes-adoption` — a base note falls back to the
      design's `universe` metadata, in both export functions.
- [ ] PR 9: `feature/topline-guards` — `export_topline()` runs the role guard
      and the design-variable check.
- [ ] PR 10: `feature/crosstab-guards` — `export_crosstab()` runs the same two
      guards, and re-validates `interactions`.
- [ ] PR 11: `feature/crosstab-min-eff-n` — `min_eff_n` replaces `pub_type`,
      and a banner level below the floor loses its column.
- [ ] PR 12: `feature/crosstab-banner-headings` — banner spanners and
      interaction levels read labels.
- [ ] PR 13: `feature/crosstab-withheld-notices` — the withholding warnings,
      the withheld lines and `withheld_note`.
- [ ] PR 14: `feature/crosstab-label-cols-and-sizes` — `label_cols`, the two
      sample-size rows, and the shared block preamble and footer.
- [ ] PR 15: `feature/crosstab-sheet-properties` — the `100%` row goes; fixed
      widths, wrapping, row height and a freeze pane.
- [ ] PR 16: `feature/crosstab-percent-cells` — a percentage cell becomes a
      string.
- [ ] PR 17: `feature/crosstab-variance-strings` — `variance_display`, the
      variance strings and the legend row.
- [ ] PR 18: `feature/crosstab-total-and-missing` — the Total column, the
      missing-value rows, the glossary and the block row order.
- [ ] PR 19: `docs/export-metadata` — the documentation prose and
      `_pkgdown.yml`.

---

## The final argument order

Spec 3.1 fixes the order of `export_crosstab()`, and states that no shipped
argument moves. Nine new or changed arguments arrive across five PRs, so each
insertion task below names the argument its new one follows.

```
design, vars, banner, file_name, layout, interactions, min_eff_n, variance,
variance_display, conf_level, sample_size_display, show_ess, decimals,
show_total, total_label, na.rm, na_label, withheld_note, base_notes
```

`show_total` already ships, between `decimals` and `base_notes`, and must not
move. `feature/crosstab-total-and-missing` is the last PR to touch the
signature, and it carries the criterion that pins the whole order.

---

## A fact a PR description must carry

One fact lives in the spec and not in the code. A reviewer who reads the diff
alone will undo it.

The surveycore pin that earlier versions of this plan listed here is gone.
surveycore 1.2.0 is on CRAN, and `develop` already reads
`surveycore (>= 1.2.0)` with no `Remotes:` line (spec IX). No PR in this plan
changes that line.

**Three helpers sit in the shared file by exception
(`feature/format-helpers`).** `.fmt_variance()`, `.write_sample_size_rows()` and
`.build_withheld()` have one call-site file today, so `code-style.md` read
literally would place them in `R/export-crosstab.R`. They go in
`R/export-utils.R` because the second call site is scheduled: the
`export_topline()` pass adopts the same cell format, the same variance string
and the same sample-size rows. That PR's description must say this, or a
reviewer applying the rule literally will move them back (spec 2.1, gate VIII).

---

## What the error and warning table already holds

Constraint: a PR that adds an error or warning class lists
`plans/error-messages.md` in its write surface, and the edit lands before the
code that raises the class.

**Measured 2026-09-22 against the committed file.** The table already holds
every class this spec needs:

| Item | Spec count | Found in `plans/error-messages.md` |
|---|---|---|
| New error classes | 6 | all 6 present |
| New warning classes | 4 | all 4 present |
| Renamed warning class | 1 | `surveyreports_warning_subgroup_withheld` present; `_subgroup_suppressed` absent |
| Extended trigger | 1 | `surveyreports_warning_missing_variable_label` names a `banner` column |

The six errors are `vars_all_dropped`, `banner_empty_selection`,
`duplicate_value_label`, `multiple_unlabelled_codes`,
`design_variable_selected` and `invalid_min_eff_n`. The four warnings are
`banner_all_withheld`, `full_sample_below_min`, `role_dropped` and
`unknown_role`.

So the task on that file in `chore/export-metadata-infra` is a check against
spec 3.17 and 3.18, not a rewrite. The file stays in that PR's write surface,
because a check that finds a gap must close it there and nowhere later.

---

### PR 1: Check the surveycore floor, add the nonprob design, confirm the class table

**Branch:** `chore/export-metadata-infra`
**Depends on:** none
**Commit type:** `chore(pipeline)`

**Tasks** (2–5 minutes each):

1. Cut `chore/export-metadata-infra` from `develop`.
2. Read `plans/error-messages.md` against spec 3.17. Confirm the six error
   classes.
3. Read the same file against spec 3.18. Confirm the four warning classes, the
   rename and the extended trigger.
4. Add any missing row to `plans/error-messages.md`. Skip this task when tasks
   2 and 3 find no gap.
5. Confirm `DESCRIPTION` reads `surveycore (>= 1.2.0)` or higher under
   `Imports:`. Do not edit the line.
6. Confirm `DESCRIPTION` has no `Remotes:` line.
7. Confirm surveycore stays in `Imports`.
8. Confirm the installed surveycore is 1.2.0 or later and exports
   `surveycore::get_effective_n`. If it is older, install it from CRAN.
9. Write the failing test: `make_all_designs(seed = 42)` returns four elements,
   and the fourth is named `nonprob`.
10. Run the test. Confirm it fails because the list has three elements.
11. Add a `nonprob` element to `make_all_designs()`, built with
    `surveycore::as_survey_nonprob()` over the same `make_survey_data()` frame
    the other three use.
12. Apply `apply_meta()` to the new design, so it carries the same SATA and
    battery metadata as the other three.
13. Run the test. Confirm it passes.
14. Run `devtools::test()`. Record every block that fails because a loop now
    sees a fourth design.
15. Fix each failing block in `tests/testthat/test-export-topline.R`. Change
    only what the fourth design broke.
16. Fix each failing block in `tests/testthat/test-export-crosstab.R`. Change
    only what the fourth design broke.
17. Remove the "Gap to close" note under **Cross-design testing** in
    `.claude/rules/testing.md`.
18. Run `covr::package_coverage()` and `covr::zero_coverage()`.
19. Run `air format .`, in its own commit. On `develop` at `6b83e5f` this
    reformats seven files: `tests/testthat/helper-test-data.R`, which this PR
    already changes, and six files that this feature does not otherwise touch
    (five `data-raw/` scripts and `tests/testthat/test-pool-pvals.R`). The
    formatting commit holds the seven files and no change other than
    formatting.
    `air format --check .` then passes for every later PR of the chain.
20. Run `devtools::check()`.
21. Write `changelog/chore-export-metadata-infra.md`.
22. Open the PR.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `make_all_designs(seed = 42)` returns four elements, named `taylor`,
      `replicate`, `twophase` and `nonprob` (spec 1.6; test-spec profile gate
      "make_all_designs() returns four designs").
- [ ] `plans/error-messages.md` holds the six error classes of spec 3.17 and
      the four warning classes of spec 3.18, holds
      `surveyreports_warning_subgroup_withheld`, and does not hold
      `surveyreports_warning_subgroup_suppressed` (spec VIII).
- [ ] `DESCRIPTION` reads `surveycore (>= 1.2.0)` or higher under `Imports:`
      and has no `Remotes:` line (spec VIII, spec IX).
- [ ] `.claude/rules/testing.md` holds no "Gap to close" note under
      Cross-design testing (spec 1.6, spec VIII).
- [ ] `devtools::test()` passes with four designs in every cross-design loop
      (test-spec profile gates).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/chore-export-metadata-infra.md` exists (`github-strategy.md`,
      PR checklist).

**Scenarios owned:** none. This PR changes no behavior a test-spec scenario
describes. Its validation is the profile gate on the generator count plus the
existing suite.

**Files touched** — the exact write surface:

- `DESCRIPTION` — checked; not modified
- `plans/error-messages.md` — checked; modified only if a gap is found
- `tests/testthat/helper-test-data.R` — modified
- `tests/testthat/test-export-topline.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `.claude/rules/testing.md` — modified
- `data-raw/parse-nationscape-codebooks.R` — reformatted by `air`; no other
  change
- `data-raw/prepare-anes-2024.R` — reformatted by `air`; no other change
- `data-raw/prepare-gss-2024.R` — reformatted by `air`; no other change
- `data-raw/prepare-nationscape-helpers.R` — reformatted by `air`; no other
  change
- `data-raw/prepare-nationscape-phase1.R` — reformatted by `air`; no other
  change
- `tests/testthat/test-pool-pvals.R` — reformatted by `air`; no other change
- `changelog/chore-export-metadata-infra.md` — created

---

## A note on the four helper PRs

`feature/metadata-readers`, `feature/metadata-unanimity`,
`feature/metadata-guards` and `feature/format-helpers` add helpers that no
exported function calls yet, so the coverage floor has no indirect path to
them. `.claude/rules/testing.md` names the two export test files as the cover
for `R/export-utils.R`, and `export_crosstab()` is the function that ends up
calling every one of them, so the direct tests go in
`tests/testthat/test-export-crosstab.R`.

The four PRs split on the dependency order among the helpers.
`.unanimous_across()` comes before `.resolve_roles()` and
`.resolve_base_notes()`, which both call it. `.resolve_roles()` comes before
`.apply_role_guard()`, which reads it. The chain gives that order for free.

---

### PR 2: The design readers

**Branch:** `feature/metadata-readers`
**Depends on:** PR 1
**Commit type:** `feat(export)`

Five helpers go into `R/export-utils.R`. Each one reads a design and returns a
value. None classifies, warns or drops.

**Tasks** (2–5 minutes each):

1. Cut `feature/metadata-readers` from `develop`.
2. Write the failing test for `.unanimous_across()`: a key that agrees across
   every member survives; a key that disagrees is omitted; a key missing in one
   member is omitted.
3. Run it. Confirm it fails because the function does not exist.
4. Implement `.unanimous_across()` in `R/export-utils.R`.
5. Run the test. Confirm it passes.
6. Write the failing test for `.has_domain()`: TRUE when
   `surveycore::SURVEYCORE_DOMAIN_COL` is a column name, FALSE otherwise, on
   all four designs.
7. Run it. Confirm it fails.
8. Implement `.has_domain()` as a direct column-name test.
9. Run the test. Confirm it passes.
10. Write the failing test for `.resolve_eff_n()` with `group_var = NULL`: one
    row, `level` is `NA_character_`, and `n` and `n_eff` match
    `surveycore::get_effective_n()`. Compare `n` exactly as integers and
    `n_eff` at `1e-8`.
11. Write the failing test for `.resolve_eff_n()` with a `group_var`: one row
    per observed level, levels in `get_freqs()` vocabulary.
12. Write the failing test for `.resolve_eff_n()` on a `survey_collection`: one
    row per member, `level` taken from the `.survey` column.
13. Run all three. Confirm they fail.
14. Implement `.resolve_eff_n()`, delegating to
    `surveycore::get_effective_n(design, group = , na.rm = )`.
15. Muffle `surveycore_warning_small_cell` inside the helper.
16. Run the three tests. Confirm they pass.
17. Write the failing test for `.banner_levels_labelled()`: a factor returns a
    factor with its level order intact; anything else returns a character
    vector; `NA` is preserved.
18. Run it. Confirm it fails.
19. Implement `.banner_levels_labelled()`.
20. Run the test. Confirm it passes.
21. Write the failing test for `.banner_heading()`: returns the variable label
    with `fell_back = FALSE`, and the column name with `fell_back = TRUE`.
22. Run it. Confirm it fails.
23. Implement `.banner_heading()`.
24. Run the test. Confirm it passes.
25. Run `devtools::test()`.
26. Run `covr::package_coverage()` and `covr::zero_coverage()`.
27. Run `air format .`, in its own commit.
28. Run `devtools::check()`.
29. Write `changelog/feature-metadata-readers.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `R/export-utils.R` defines `.unanimous_across()`, `.has_domain()`,
      `.resolve_eff_n()`, `.banner_levels_labelled()` and `.banner_heading()`,
      each matching its signature in spec 2.2.
- [ ] `.unanimous_across()` returns a named character vector. A key whose value
      agrees and is non-missing across every member survives; a key that
      disagrees anywhere is omitted; a key missing in any member is omitted
      (spec 2.2). `.resolve_roles()` and `.resolve_base_notes()` consume it, in
      `feature/metadata-unanimity`.
- [ ] `.has_domain()` returns `logical(1)` and reads the column name only, so a
      domain that selects every row still counts as a restriction (spec 2.2,
      spec 3.9). `.write_cover_sheet()` consumes it in `feature/cover-sheet`,
      and `export_crosstab()` in `feature/crosstab-total-and-missing`.
- [ ] `.resolve_eff_n()` returns a tibble of `level` (character), `n` (integer)
      and `n_eff` (double) (spec 2.2). `.build_freq_frame()` consumes it in
      `feature/effective-n-rewiring`, and the withholding loop in
      `feature/crosstab-min-eff-n`.
- [ ] `.resolve_eff_n()`'s `n` equals `surveycore::get_effective_n()`'s `n`
      exactly, compared as integers, and its `n_eff` matches at a tolerance of
      `1e-8`. The effective N is a variance-derived quantity, not a point
      estimate, so the 1e-10 point-estimate tolerance does not apply to it
      (spec 1.4.1).
- [ ] `.resolve_eff_n()`'s levels match `surveycore::get_freqs()` compared as
      `as.character(level)` (spec 2.2, spec 1.4.1).
- [ ] `.resolve_eff_n()` returns one row per member on a `survey_collection`,
      keyed by the wave name (spec 2.2, spec 4.1).
- [ ] `.resolve_eff_n()` raises no warning of its own and muffles
      `surveycore_warning_small_cell` (spec 2.2).
- [ ] `.banner_levels_labelled()` returns a vector of length
      `nrow(design@data)`. A factor input returns a factor with its level order
      intact; any other input returns a character vector; `NA` is preserved in
      both cases (spec 2.2, spec 3.8). `.compute_interaction_freq()` consumes
      it in `feature/crosstab-banner-headings`.
- [ ] `.banner_heading()` returns a list of `heading` (character, length 1) and
      `fell_back` (logical, length 1), and raises no warning itself (spec 2.2).
      `export_crosstab()` collects `fell_back` across columns in
      `feature/crosstab-banner-headings`.
- [ ] `git diff --exit-code tests/testthat/_snaps/` is clean and
      `devtools::test()` passes. Neither snapshot file is in this PR's write
      surface (spec 5.2).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-metadata-readers.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned:** none. Every helper here is unwired.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `changelog/feature-metadata-readers.md` — created

---

### PR 3: The two resolvers

**Branch:** `feature/metadata-unanimity`
**Depends on:** PR 2
**Commit type:** `feat(export)`

`.resolve_roles()` and `.resolve_base_notes()` both read every member of a
collection and both call `.unanimous_across()`. Neither aborts on a collection,
which is the trap spec 1.5 records.

**Tasks** (2–5 minutes each):

1. Cut `feature/metadata-unanimity` from `develop`.
2. Write the failing test for `.resolve_roles()` over the five payload shapes
   of spec 3.10: a length-1 character, an absent key, a length-0 value, a
   length-2 vector, and a non-character value.
3. Write the failing test for `.resolve_roles()` on a `survey_collection`: a
   role that disagrees across members resolves to `NA_character_`, and the call
   does not abort.
4. Run both. Confirm they fail.
5. Implement `.resolve_roles()` without `vapply(..., character(1))`, which
   aborts on a length-0 payload.
6. Add the collection branch to `.resolve_roles()`, applying the unanimity rule
   of spec 3.6.
7. Run the two tests. Confirm they pass.
8. Write the failing test for `.resolve_base_notes()`: the caller vector and
   the universe come back as two separate elements, and both empty returns
   `NULL`.
9. Write the failing test for `.resolve_base_notes()` on a collection: the wave
   unanimity rule of spec 3.6 applies, and the call does not abort.
10. Run both. Confirm they fail.
11. Implement `.resolve_base_notes()`, reading the universe itself and applying
    the wave rule and no other.
12. Run the two tests. Confirm they pass.
13. Run `devtools::test()`.
14. Run `covr::package_coverage()` and `covr::zero_coverage()`.
15. Run `air format .`, in its own commit.
16. Run `devtools::check()`.
17. Write `changelog/feature-metadata-unanimity.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `R/export-utils.R` defines `.resolve_roles()` and
      `.resolve_base_notes()`, each matching its signature in spec 2.2.
- [ ] `.resolve_roles()` returns a named character vector with one entry per
      element of `cols`, in input order (spec 2.2). `.apply_role_guard()`
      consumes it in `feature/metadata-guards`.
- [ ] `.resolve_roles()` returns the string itself for a length-1 character
      payload, whether or not the string is one of the seven known roles
      (spec 3.10).
- [ ] `.resolve_roles()` returns `NA_character_` for an absent key, a length-0,
      a length-2 and a non-character payload, and aborts on none of them
      (spec 3.10).
- [ ] `.resolve_roles()` does not abort on a `survey_collection`, and a role
      that disagrees across members or is missing in any member resolves to
      `NA_character_` (spec 1.5, spec 3.6, spec 3.10).
- [ ] `.resolve_base_notes()` returns a list of `caller` and `universe`, kept
      separate, and returns `NULL` when both sources are empty (spec 2.2,
      spec 3.6). `.base_note_for()` consumes it in
      `feature/base-notes-adoption`.
- [ ] `.resolve_base_notes()`'s `universe` element is a named character vector,
      keyed by variable, and `character(0)` when nothing is set (spec 2.2).
- [ ] `.resolve_base_notes()` does not abort on a `survey_collection`, and
      applies the wave rule alone (spec 1.5, spec 3.6).
- [ ] `git diff --exit-code tests/testthat/_snaps/` is clean and
      `devtools::test()` passes. Neither snapshot file is in this PR's write
      surface (spec 5.2).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-metadata-unanimity.md` exists (`github-strategy.md`,
      PR checklist).

**Scenarios owned:** none. Both helpers are unwired.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `changelog/feature-metadata-unanimity.md` — created

---

### PR 4: The two selection guards

**Branch:** `feature/metadata-guards`
**Depends on:** PR 3
**Commit type:** `feat(export)`

`.apply_role_guard()` reads `.resolve_roles()`. `.reject_design_vars()` reads
the design object per subclass. The two mechanisms stay separate, per
spec 3.10.

**Tasks** (2–5 minutes each):

1. Cut `feature/metadata-guards` from `develop`.
2. Write the failing test for `.apply_role_guard()`: a non-substantive column
   is dropped with `surveyreports_warning_role_dropped`; an unrecognized role
   is kept with `surveyreports_warning_unknown_role`; an empty result aborts
   with the class the caller passed.
3. Write the failing test that the survivors come back in input order.
4. Run both. Confirm they fail.
5. Implement `.apply_role_guard()`, returning the survivors in input order.
6. Run the two tests. Confirm they pass.
7. Write the failing test for `.reject_design_vars()` on `survey_taylor`: the
   weight, the cluster id, the stratum and the FPC column each abort with
   `surveyreports_error_design_variable_selected`.
8. Write the failing test on `survey_replicate`: each of the ten
   replicate-weight columns aborts.
9. Write the failing test on `survey_twophase`: the subset column and a phase-1
   slot column each abort.
10. Write the failing test that a non-column slot is skipped: no comparison
    runs against `TRUE`, `0.9` or `"JK1"`.
11. Run all four. Confirm they fail.
12. Implement `.reject_design_vars()` with a per-subclass reader, including the
    `phase1` and `phase2` nesting.
13. Run the four tests. Confirm they pass.
14. Run `devtools::test()`.
15. Run `covr::package_coverage()` and `covr::zero_coverage()`.
16. Run `air format .`, in its own commit.
17. Run `devtools::check()`.
18. Write `changelog/feature-metadata-guards.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `R/export-utils.R` defines `.apply_role_guard()` and
      `.reject_design_vars()`, each matching its signature in spec 2.2.
- [ ] `.apply_role_guard()` returns a character vector of the surviving column
      names, **in input order** (spec 2.2). Input order is load-bearing:
      `XM-15`, in `feature/crosstab-guards`, asserts that a sheet name follows
      the first survivor. Both export functions consume it, in
      `feature/topline-guards` and `feature/crosstab-guards`.
- [ ] `.apply_role_guard()` drops a non-substantive column with
      `surveyreports_warning_role_dropped`, keeps an unrecognized role with
      `surveyreports_warning_unknown_role`, and aborts with the class the
      caller passed when nothing survives (spec 3.10).
- [ ] `.reject_design_vars()` returns `invisible(TRUE)` when no column matches
      (spec 2.2). Both export functions consume it, in the same two branches.
- [ ] `.reject_design_vars()` aborts with
      `surveyreports_error_design_variable_selected` for every slot that holds
      a column name, on all four subclasses, and skips the slots that hold no
      column name (spec 2.2, spec 3.17).
- [ ] `grep -n "phase1" R/export-utils.R` returns a line inside
      `.reject_design_vars()` (spec VIII).
- [ ] `grep -rn "design_variable_selected" R/` returns lines in
      `R/export-utils.R` only (spec VIII).
- [ ] `git diff --exit-code tests/testthat/_snaps/` is clean and
      `devtools::test()` passes. Neither snapshot file is in this PR's write
      surface (spec 5.2).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-metadata-guards.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned:** none. Both guards are unwired.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `changelog/feature-metadata-guards.md` — created

---

### PR 5: The format and write helpers

**Branch:** `feature/format-helpers`
**Depends on:** PR 4
**Commit type:** `feat(export)`

Five helpers go into `R/export-utils.R`, and one into `R/export-crosstab.R`.
None is wired yet, so no workbook changes.

**Tasks** (2–5 minutes each):

1. Cut `feature/format-helpers` from `develop`.
2. Write the failing test for `.fmt_pct()` over the five forms of spec 3.3:
   `-`, `0%`, the floor string, the ceiling string, and a rounded percentage.
3. Write the failing test that the floor and the ceiling strings follow
   `decimals` at 0, 1 and 2.
4. Run both. Confirm they fail.
5. Implement `.fmt_pct()`. It takes a proportion and multiplies by 100 itself.
6. Run the two tests. Confirm they pass.
7. Write the failing test for `.fmt_variance()` under `variance = "se"`: the
   string is the standard error in parentheses, with one `%`.
8. Write the failing test under `variance = "ci"`: two bounds, one `%` each,
   separated by an en-dash (U+2013) with one space on each side.
9. Write the failing test that a negative lower bound prints with a
   hyphen-minus (U+002D) and no space.
10. Write the failing test that the string is empty when `variance` is `NULL`
    and again when `has_rows` is FALSE.
11. Run all four. Confirm they fail.
12. Implement `.fmt_variance()`, formatting every number through `.fmt_pct()`.
13. Run the four tests. Confirm they pass.
14. Write the failing test for `.format_withheld_lines()`: one line per
    withheld subgroup, naming the subgroup, its banner variable and its
    effective N, and no raw N.
15. Write the failing test that a zero-row frame and `NULL` both return
    `character(0)`.
16. Run both. Confirm they fail.
17. Implement `.format_withheld_lines()`.
18. Run the two tests. Confirm they pass.
19. Write the failing test for `.build_withheld()`: one row per subgroup whose
    `n_eff` is strictly below `min_eff_n`, and a zero-row frame when none is.
20. Write the failing test that the helper never returns `NULL`.
21. Run both. Confirm they fail.
22. Implement `.build_withheld()`. The comparison `n_eff < min_eff_n` lives
    here and nowhere else.
23. Run the two tests. Confirm they pass.
24. Write the failing test for `.write_sample_size_rows()`: two rows, the
    labels in column A, one cell per row of `counts` in write order, and the
    next free row returned.
25. Write the failing test that a zero-row `counts` frame writes the labels,
    writes no data cell, and returns the next free row.
26. Run both. Confirm they fail.
27. Implement `.write_sample_size_rows()`.
28. Run the two tests. Confirm they pass.
29. Write the failing test for `.unique_sheet_name()`: a name already in the
    workbook is suffixed `_2`, the comparison folds case, and a name longer
    than 31 characters is truncated first.
30. Run it. Confirm it fails.
31. Implement `.unique_sheet_name()` in `R/export-crosstab.R`, below the
    exported function.
32. Run the test. Confirm it passes.
33. Run `devtools::test()`.
34. Run `covr::package_coverage()` and `covr::zero_coverage()`.
35. Run `air format .`, in its own commit.
36. Run `devtools::check()`.
37. Write `changelog/feature-format-helpers.md`.
38. Open the PR. The description states why `.fmt_variance()`,
    `.write_sample_size_rows()` and `.build_withheld()` sit in
    `R/export-utils.R` with one call-site file today.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `.fmt_pct()` returns `character(1)`, one of the five forms of spec 3.3,
      and both threshold strings follow `decimals`. The three crosstab render
      routes consume it in `feature/crosstab-percent-cells`.
- [ ] `.fmt_pct()` owns the proportion-to-percentage conversion, so no call
      site does the arithmetic (spec 3.3).
- [ ] `.fmt_variance()` returns `character(1)` and writes an en-dash separator
      and a hyphen-minus sign, and accepts a negative lower bound (spec 3.12,
      spec 8.1). The three crosstab render routes consume it in
      `feature/crosstab-variance-strings`.
- [ ] `.fmt_variance()` returns an empty string when `variance` is `NULL`, and
      again when `has_rows` is FALSE (spec 2.2, spec 3.12).
- [ ] `.fmt_variance()` formats every number through `.fmt_pct()`, so it
      inherits the rounding mode and both threshold strings (spec 3.12).
- [ ] `.format_withheld_lines()` returns a character vector, one element per
      withheld subgroup in the frame's order, names no raw N, and returns
      `character(0)` for a zero-row frame and for `NULL` (spec 3.14).
      `.write_cover_sheet()` consumes it in `feature/cover-sheet`, and the
      block footer and the console warning in
      `feature/crosstab-withheld-notices`.
- [ ] `.build_withheld()` returns a tibble of `level`, `banner_var` and
      `n_eff`, one row per withheld subgroup, and never returns `NULL`
      (spec 2.2, spec 3.5). `export_crosstab()` consumes it in
      `feature/crosstab-min-eff-n`.
- [ ] `grep -rn "n_eff <" R/` returns one line, inside `.build_withheld()`. No
      other code compares an effective N against `min_eff_n` (spec 3.5).
- [ ] `.write_sample_size_rows()` returns `list(wb = , next_row = )`. On the
      happy path it writes the row label in column A, leaves any second label
      column blank, and writes one cell per row of `counts` in write order
      (spec 2.2, spec 3.4). The three crosstab render routes consume it in
      `feature/crosstab-label-cols-and-sizes`.
- [ ] `.write_sample_size_rows()` accepts a zero-row `counts` frame, writes no
      data cell, and returns the next free row (spec 3.4).
- [ ] `.unique_sheet_name()` returns `character(1)`, folds case, and truncates
      to 31 characters before it suffixes (spec 2.2, spec 3.14). The three
      routed `wb_add_worksheet()` calls consume it in `feature/cover-sheet`.
- [ ] `R/export-crosstab.R` holds `.unique_sheet_name()` below the exported
      function (spec 2.1).
- [ ] The PR description states the placement exception for the three helpers
      (spec 2.1, spec VIII).
- [ ] `git diff --exit-code tests/testthat/_snaps/` is clean and
      `devtools::test()` passes. Neither snapshot file is in this PR's write
      surface (spec 5.2).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-format-helpers.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned:** none. Every helper here is unwired.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-crosstab.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `changelog/feature-format-helpers.md` — created

---

### PR 6: The cover sheet

**Branch:** `feature/cover-sheet`
**Depends on:** PR 5
**Commit type:** `feat(export)`

`.build_workbook()` gains its new signature, so both export functions change
their call site and every workbook gains an `"About"` sheet.

**The glossary stays at five terms.** Spec 3.15 ends with a sentence saying
that under `variance = "se"` an entry names the statistic in the brackets. The
same section carries **Decision (2026-09-16, issue 66): the glossary stays at
five terms**, and `.write_cover_sheet()`'s arguments drive three conditions,
not four. The issue-66 decision governs, and the closing sentence is
superseded. Under `variance = "se"` the legend row of spec 3.12 names the
statistic instead, in the same view as the bracketed number.
`docs/export-metadata` raises the one-line spec correction.

**Tasks** (2–5 minutes each):

1. Cut `feature/cover-sheet` from `develop`.
2. Write the failing test for `XA-01` and `XA-02`: a sheet named `About`
   exists, is sheet 1, and carries the glossary block with no dataset metadata
   set.
3. Run it. Confirm it fails.
4. Implement `.write_cover_sheet()`: the survey metadata block, in surveycore's
   canonical key order, under a `Key` / `Value` header.
5. Add the domain row to `.write_cover_sheet()`, written when
   `.has_domain(design)` is TRUE.
6. Add the withheld block to `.write_cover_sheet()`, reading
   `.format_withheld_lines()`, with a `None` row for a zero-row frame and no
   block for `NULL`.
7. Add the glossary block to `.write_cover_sheet()`, with the five terms of
   spec 3.15 and their three conditions.
8. Add the collection branch: one block per wave in `@surveys` order, and a
   heading for a wave with no keys.
9. Set the `Key` and `Value` column widths with
   `openxlsx2::wb_set_col_widths()`. Write no merged cell anywhere on the
   sheet.
10. Change `.build_workbook()` to the signature of spec 2.3 and have it add the
    `"About"` sheet before any question sheet.
11. Update the `.build_workbook()` call in `R/export-topline.R` to pass
    `design` and its own `variance`.
12. Update the `.build_workbook()` call in `R/export-crosstab.R` to pass
    `design`, `has_banner = TRUE`, `string_cells = FALSE`, `variance`, and
    `withheld = NULL`.
13. Route the three `wb_add_worksheet()` calls in `R/export-crosstab.R` through
    `.unique_sheet_name()`. Assign the result back to the sheet-name variable
    before the sheet is added and before it is rendered into.
14. Run the test from task 2. Confirm it passes.
15. Write the tests for `XA-03`, `XA-04`, `XA-08` and `XA-13`.
16. Run them. Confirm they pass.
17. Write the tests for `XA-09`, `XA-10` and `XA-11`.
18. Run them. Confirm they pass.
19. Write the tests for `TP-06`, `TP-06a` and `TP-07`.
20. Run them. Confirm they pass.
21. Write the tests for `TC-05`, `TC-06` and `TC-07`.
22. Run them. Confirm they pass.
23. Run `devtools::test()`.
24. Run `covr::package_coverage()` and `covr::zero_coverage()`.
25. Run `air format .`, in its own commit.
26. Run `devtools::check()`.
27. Write `changelog/feature-cover-sheet.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] Every workbook holds a sheet named `About`, and it is sheet 1
      (test-spec XA-01; spec 3.14, spec 8.1).
- [ ] The sheet is written with no dataset metadata set, and carries the
      glossary (test-spec XA-02).
- [ ] Every set key appears in canonical order, as an ordered character vector
      (test-spec XA-03).
- [ ] An unset key produces no row (test-spec XA-04).
- [ ] The saved and reloaded workbook opens on sheet 1 (test-spec XA-08).
- [ ] A restricted design gains a `Restricted to` row below the dataset keys,
      and an unrestricted design does not (test-spec XA-13; spec 3.14).
- [ ] A data sheet named `About` is suffixed `About_2`, the comparison folds
      case, and two variables sharing 31 characters both get a sheet
      (test-spec XA-09, XA-10, XA-11).
- [ ] The About sheet holds no merged cell, and both the `Key` and the `Value`
      column carry a stored width (spec 3.14).
- [ ] An `export_topline()` workbook holds the glossary with the two
      sample-size terms, and holds neither `Why a column is missing` nor
      `Percentages` (test-spec TP-06; spec 3.15, spec 4.1).
- [ ] An `export_topline()` call at `variance = "ci"` gains the
      `Confidence intervals` entry (test-spec TP-06a; spec 2.3).
- [ ] An `export_topline()` workbook holds no withheld block
      (test-spec TP-07; spec 3.11).
- [ ] A collection workbook holds one metadata block per wave in `@surveys`
      order, a heading for a wave with no keys, and the glossary when no
      metadata is set (test-spec TC-05, TC-06, TC-07; spec 3.14).
- [ ] The glossary holds five terms and three conditions. No sixth term is
      added under `variance = "se"`; the issue-66 decision in spec 3.15
      governs, and the legend row of spec 3.12 names the statistic.
- [ ] `.write_cover_sheet()` takes no `withheld_note` argument (spec 3.14).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-cover-sheet.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned (15):** XA-01, XA-02, XA-03, XA-04, XA-08, XA-09, XA-10,
XA-11, XA-13, TP-06, TP-06a, TP-07, TC-05, TC-06, TC-07.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-crosstab.R` — modified
- `R/export-topline.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/test-export-topline.R` — modified
- `changelog/feature-cover-sheet.md` — created

---

### PR 7: The effective N is rewired to surveycore

**Branch:** `feature/effective-n-rewiring`
**Depends on:** PR 6
**Commit type:** `fix(export)`

`.compute_eff_n()` publishes an effective N above the raw N of the table it
labels, on twophase and on domain-restricted designs. `.resolve_eff_n()`
replaces it at every call site.

**One call site is a holding change.** The old `pub_type` suppression loop in
`.build_freq_frame()` also calls `.compute_eff_n()`. The helper cannot be
deleted while that call stands, so this PR swaps the call for a
`.resolve_eff_n()` row lookup and keeps the existing `pub_type` thresholds
untouched. `feature/crosstab-min-eff-n` rewrites the loop.

**Tasks** (2–5 minutes each):

1. Cut `feature/effective-n-rewiring` from `develop`.
2. Write the failing test `TN-02`: the reported N equals the rows the design
   tabulates, on all four designs and on a domain-restricted design.
3. Run it. Confirm it fails on twophase and on the restricted design.
4. Replace the `.compute_eff_n()` call in `.build_freq_frame()`'s frame block
   with a `.resolve_eff_n()` lookup.
5. Replace the `.compute_eff_n()` call in the collection wave block with a
   `.resolve_eff_n()` lookup, joined on the wave name.
6. Replace the `.compute_eff_n()` call inside the `pub_type` suppression loop
   with a `.resolve_eff_n()` row lookup. Keep the `pub_type` thresholds as they
   are.
7. Delete the `show_eff_n` join block in `R/export-utils.R`.
8. Delete `.compute_eff_n()` and the three `# nocov` markers inside it.
9. Run `grep -rn "compute_eff_n" R/`. Confirm it returns nothing.
10. Run the test from task 2. Confirm it passes.
11. Write the failing test `TC-08`: `export_topline(collection, show_eff_n =
    TRUE)` returns the path.
12. Run it. Confirm it fails at the wave join.
13. Add the wave-name join to the collection path of `export_topline()`.
14. Run the test. Confirm it passes.
15. Delete the dead effective-N branch in the collection `Total` header of
    `.render_topline_single()`. Do not mark it `# nocov`.
16. Write the test `TN-03`: no header on a collection carries an effective N,
    and each wave header reads the wave name and `(n=…)`.
17. Run it. Confirm it passes.
18. Write the test `TN-01`: the percentage column's header reads `%`, a line
    break, `(Eff N=`, a whole number with a thousands separator, then `)`.
19. Run it. Confirm it passes. Fix the header only if the value moved.
20. Write the test `TN-04`: the topline percentages still compare as numbers
    against the oracle at `decimals = 1L`.
21. Run it. Confirm it passes.
22. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`. Confirm the only moved snapshots are the
    `show_eff_n` ones on twophase and on a domain-restricted design.
23. Run `covr::package_coverage()` and `covr::zero_coverage()`.
24. Run `air format .`, in its own commit.
25. Run `devtools::check()`.
26. Write `changelog/feature-effective-n-rewiring.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `grep -rn "compute_eff_n" R/` returns nothing (spec VIII).
- [ ] The reported unweighted N equals the rows the design tabulates, including
      the phase-2 subset and the in-domain rows (test-spec TN-02; spec 1.4.1,
      spec 3.20).
- [ ] The topline percentage header holds a whole-number effective N with a
      thousands separator (test-spec TN-01; spec 4.2).
- [ ] No collection header carries an effective N, and the dead branch is gone
      (test-spec TN-03; spec 2.3, spec 4.2).
- [ ] `export_topline(collection, show_eff_n = TRUE)` returns the path
      (test-spec TC-08; spec 4.1).
- [ ] Topline percentage cells still compare as numbers against the oracle
      (test-spec TN-04; spec 4.2).
- [ ] The only moved `export_topline()` snapshots are the `show_eff_n`
      snapshots on twophase and on a domain-restricted design (spec 5.2).
- [ ] No crosstab snapshot moved. The `pub_type` default is `"none"`, so the
      suppression loop does not run (spec 4.1).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-effective-n-rewiring.md` exists (`github-strategy.md`,
      PR checklist).

**Scenarios owned (5):** TN-01, TN-02, TN-03, TN-04, TC-08.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-topline.R` — modified
- `tests/testthat/test-export-topline.R` — modified
- `tests/testthat/_snaps/export-topline.md` — regenerated
- `changelog/feature-effective-n-rewiring.md` — created

---

### PR 8: Base notes fall back to the universe

**Branch:** `feature/base-notes-adoption`
**Depends on:** PR 7
**Commit type:** `feat(export)`

`.base_note_for()` reads the two-element object of spec 3.6, so both export
functions change their call site together.

**Tasks** (2–5 minutes each):

1. Cut `feature/base-notes-adoption` from `develop`.
2. Write the failing tests `TP-01` and `TP-02`: the universe text appears
   verbatim, and a caller note wins.
3. Run them. Confirm they fail.
4. Change `.base_note_for()` to read the two-element list of spec 3.6, with the
   caller-first rule.
5. Add the unanimity rule to `.base_note_for()` for a SATA or a battery block.
6. Call `.resolve_base_notes()` in `export_topline()` and pass its result to
   `.base_note_for()`.
7. Call `.resolve_base_notes()` in `export_crosstab()` and pass its result to
   `.base_note_for()`.
8. Confirm `.validate_base_notes()` still runs on the caller vector alone,
   before the merge.
9. Run the tests from task 2. Confirm they pass.
10. Write the failing tests `TP-03` and `TP-04`: a battery whose members agree
    prints the universe; a battery whose members disagree prints none.
11. Run them. Confirm they pass.
12. Write the failing tests `XM-01` and `XM-02`: the crosstab side of the same
    two rules.
13. Run them. Confirm they pass.
14. Write the failing tests `XM-03`, `XM-04` and `XM-05`: the battery cases on
    the crosstab side, including one member unset.
15. Run them. Confirm they pass.
16. Write the failing test `XM-07`: a SATA block prints a unanimous universe.
17. Run it. Confirm it passes.
18. Confirm no base note carries a `Base:` prefix anywhere in either workbook.
19. Run `devtools::test()`.
20. Run `covr::package_coverage()` and `covr::zero_coverage()`.
21. Run `air format .`, in its own commit.
22. Run `devtools::check()`.
23. Write `changelog/feature-base-notes-adoption.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] A universe base note appears verbatim when the caller supplies none, in
      both functions (test-spec TP-01, XM-01; spec 3.6).
- [ ] A caller note wins over a universe, in both functions (test-spec TP-02,
      XM-02; spec 3.6).
- [ ] No base note carries a `Base:` prefix (spec 3.6).
- [ ] A battery prints the universe only when every member carries the same
      text (test-spec TP-03, TP-04, XM-03, XM-04, XM-05; spec 3.6).
- [ ] A SATA block prints a unanimous universe (test-spec XM-07; spec 3.6).
- [ ] The caller and the universe stay separate in the resolved object, so a
      caller entry is exempt from the unanimity rule (spec 3.6).
- [ ] `.validate_base_notes()` runs on the caller's vector alone (spec 3.6).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-base-notes-adoption.md` exists (`github-strategy.md`,
      PR checklist).

**Scenarios owned (10):** TP-01, TP-02, TP-03, TP-04, XM-01, XM-02, XM-03,
XM-04, XM-05, XM-07.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-topline.R` — modified
- `R/export-crosstab.R` — modified
- `tests/testthat/test-export-topline.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `changelog/feature-base-notes-adoption.md` — created

---

### PR 9: The guards in `export_topline()`

**Branch:** `feature/topline-guards`
**Depends on:** PR 8
**Commit type:** `feat(export)`

`export_topline()` gains the role guard, the design-variable check and the
`all_of()` fix. Its signature does not change, so no `man/` file moves here.

**Ordering inside the PR.** Spec 3.11 fixes the topline step order. The
design-variable check runs at step 5, after the tidy-select resolution and
before the role guard at step 6. The empty-domain check at step 3 runs before
both. Tasks 4, 8 and 15 carry that order.

**Two snapshots land in `feature/crosstab-guards`, not here.** `TW-01` asserts
the `role_dropped` class alone, and `TE-04` asserts the
`design_variable_selected` class alone. The test-spec puts the snapshot for
each on the crosstab row of the same wording — `XV-01` and `XE-12`. Both texts
are therefore unpinned between this PR and the next. That is a two-PR gap in a
strict chain, not a missing test.

**Tasks** (2–5 minutes each):

1. Cut `feature/topline-guards` from `develop`.
2. Write the failing test `TP-05`: a `role = "free_text"` column is dropped
   from `vars`.
3. Run it. Confirm it fails.
4. Call `.apply_role_guard()` on `vars` in `export_topline()`, at step 6 of the
   topline order in spec 3.11.
5. Run the test. Confirm it passes.
6. Write the failing test `TE-04`: the design's weight column in `vars` aborts,
   and no file is written.
7. Run it. Confirm it fails.
8. Call `.reject_design_vars()` on `vars` in `export_topline()`, at step 5,
   before the role guard.
9. Run the test. Confirm it passes, on every design the generator returns.
10. Replace the bare resolved vector in `export_topline()`'s
    `classify_question_type()` call with `tidyselect::all_of()`.
11. Write the test `TP-08`: no tidyselect deprecation warning.
12. Run it. Confirm it passes.
13. Write the error tests `TE-01`, with the dual pattern, and `TE-02`.
14. Run them. Confirm they pass.
15. Write the test `TE-03`: an empty domain with a role-dropped `vars` column
    raises `surveyreports_error_empty_domain`, and no role warning is raised
    first.
16. Run it. Confirm it passes.
17. Write the warning tests `TW-01` and `TW-02`, each asserting the class
    alone.
18. Run them. Confirm they pass, and the file is still written.
19. Write the tests `TP-09`, `TP-10`, `TP-11` and `TP-12`: the scope-boundary
    rows.
20. Run them. Confirm they pass.
21. Write the test `TP-13`: a SATA block renders in its own shape.
22. Run it. Confirm it passes.
23. Write the tests `TC-01` and `TC-02`: a collection with universe metadata
    does not abort, and differing universes across waves print none.
24. Run them. Confirm they pass.
25. Write the tests `TC-03` and `TC-04`: the role guard on a collection does
    not abort, and a role differing between waves keeps the column.
26. Run them. Confirm they pass.
27. Run `devtools::test()`. Confirm the suite's warning count has dropped. The
    full drop lands with the crosstab `all_of()` fix in
    `feature/crosstab-guards`.
28. Review every moved snapshot with `testthat::snapshot_review()`.
29. Run `covr::package_coverage()` and `covr::zero_coverage()`.
30. Run `air format .`, in its own commit.
31. Run `devtools::check()`.
32. Write `changelog/feature-topline-guards.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] A `role = "free_text"` column is dropped from `vars`, with one
      `surveyreports_warning_role_dropped` (test-spec TP-05, TW-01; spec 3.10,
      spec 3.18).
- [ ] An unrecognized role keeps the column and raises
      `surveyreports_warning_unknown_role` (test-spec TW-02; spec 3.10).
- [ ] Naming a design column in `vars` aborts with
      `surveyreports_error_design_variable_selected`, and no file is written,
      on every design the generator returns (test-spec TE-04; spec 3.17,
      spec 4.1).
- [ ] An all-dropped `vars` selection raises
      `surveyreports_error_vars_all_dropped` (test-spec TE-01; spec 3.10).
- [ ] A plain data frame raises `surveyreports_error_not_survey_object`
      (test-spec TE-02).
- [ ] An empty domain raises `surveyreports_error_empty_domain`, and no role
      warning is raised first (test-spec TE-03; spec 3.11).
- [ ] The classification call raises no tidyselect deprecation warning
      (test-spec TP-08; spec 2.1).
- [ ] Topline percentage cells stay numeric; the `N` column stays; the
      effective N stays in the header; no subgroup is withheld (test-spec
      TP-09, TP-10, TP-11, TP-12; spec 4.1, spec 4.2).
- [ ] A topline SATA block keeps its own shape (test-spec TP-13; spec 4.2).
- [ ] A collection does not abort on a universe read or a role read
      (test-spec TC-01, TC-02, TC-03, TC-04; spec 1.5, spec 3.6).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-topline-guards.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned (17):** TP-05, TP-08, TP-09, TP-10, TP-11, TP-12, TP-13,
TC-01, TC-02, TC-03, TC-04, TE-01, TE-02, TE-03, TE-04, TW-01, TW-02.

**Files touched** — the exact write surface:

- `R/export-topline.R` — modified
- `tests/testthat/test-export-topline.R` — modified
- `tests/testthat/_snaps/export-topline.md` — regenerated
- `changelog/feature-topline-guards.md` — created

---

### PR 10: The guards in `export_crosstab()`

**Branch:** `feature/crosstab-guards`
**Depends on:** PR 9
**Commit type:** `feat(export)`

`export_crosstab()` runs the same two guards on `vars` and again on `banner`,
re-validates `interactions`, and takes the `all_of()` fix. This PR closes
Part A. It adds and removes no formal argument, so no `man/` file moves here.

**Ordering inside the PR.** Spec 3.11 fixes the step order. The
design-variable check runs at step 9, after both tidy-select resolutions and
before the role guard at step 10. `interactions` is re-validated at step 11,
against the surviving banner. Tasks 4, 5 and 6 carry that order.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-guards` from `develop`.
2. Write the failing test `XM-08`: a `role = "free_text"` column is dropped
   from `vars`.
3. Run it. Confirm it fails.
4. Call `.reject_design_vars()` on `vars`, then on `banner`, in
   `export_crosstab()`, at step 9 of spec 3.11.
5. Call `.apply_role_guard()` on `vars`, then on `banner`, in
   `export_crosstab()`, at step 10.
6. Re-validate `interactions` against the surviving banner, at step 11.
7. Replace the bare resolved vector in `export_crosstab()`'s
   `classify_question_type()` call with `tidyselect::all_of()`.
8. Run the test from task 2. Confirm it passes.
9. Run `devtools::test()`. Confirm the suite is green.
10. Write the failing tests `XM-09`, `XM-10` and `XM-11`: the four dropping
    roles, the three keeping roles, and the banner drop.
11. Run them. Confirm they pass.
12. Write the failing tests `XM-12`, `XM-13` and `XM-14`: a group survives a
    partial drop, becomes a single question at one survivor, and the SATA route
    behaves the same.
13. Run them. Confirm they pass.
14. Write the failing test `XM-15`: the sheet name follows the first survivor.
15. Run it. Confirm it passes.
16. Write the test `XM-16`: a design with no `role` set keeps every column.
17. Run it. Confirm it passes.
18. Write the failing test `XM-06`: unanimity is judged on the survivors, with
    the dropped member's differing universe ignored.
19. Run it. Confirm it passes.
20. Write the test `XM-17`: no tidyselect deprecation warning from the crosstab
    path.
21. Run it. Confirm it passes.
22. Write the error tests `XE-01`, with the dual pattern, and `XE-02`.
23. Run them. Confirm they pass.
24. Write the error test `XE-03`, with the dual pattern.
25. Run it. Confirm it passes.
26. Write the error test `XE-06`: `interactions` naming a dropped banner column
    fails the second check.
27. Run it. Confirm it passes.
28. Write the error tests `XE-12` and `XE-14`. Each loops `names(designs)` and
    takes its own snapshot, because the message names the argument.
29. Run them. Confirm they pass.
30. Write the error tests `XE-13`, on taylor, and `XE-15`, on replicate and on
    twophase.
31. Run them. Confirm they pass.
32. Write the regression tests `XE-08`, `XE-09` and `XE-10`.
33. Run them. Confirm they pass.
34. Write the test `XX-10`: an empty domain with a role-dropped column raises
    `surveyreports_error_empty_domain`, and no role warning is raised first.
35. Run it. Confirm it passes.
36. Write the warning tests `XV-01` and `XV-02`. Each takes its own snapshot.
37. Run them. Confirm they pass, and the file is still written.
38. Write the warning tests `XV-07`, with the dual pattern, `XV-08` and
    `XV-09`.
39. Run them. Confirm they pass.
40. Run `devtools::test()`. Confirm the warning count has dropped from 88 to 8
    or fewer.
41. Review every moved snapshot with `testthat::snapshot_review()`.
42. Run `covr::package_coverage()` and `covr::zero_coverage()`.
43. Run `air format .`, in its own commit.
44. Run `devtools::check()`.
45. Write `changelog/feature-crosstab-guards.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] A non-substantive `role` drops a `vars` or `banner` column, with one
      `surveyreports_warning_role_dropped` per argument (test-spec XM-08,
      XM-09, XM-11, XV-01, XV-02; spec 3.10, spec 3.18).
- [ ] Each of the three substantive roles keeps its column with no warning
      (test-spec XM-10; spec 3.10).
- [ ] A group survives a partial drop, becomes a single question at one
      survivor, and keeps the SATA route's shape (test-spec XM-12, XM-13,
      XM-14; spec 3.10).
- [ ] The sheet name follows the first survivor (test-spec XM-15; spec 3.10).
- [ ] A design with no role set keeps every column (test-spec XM-16;
      spec 3.10).
- [ ] Unanimity is judged on the members that reach the frame (test-spec
      XM-06; spec 3.6).
- [ ] An unrecognized role, a length-2 role and a non-character role each keep
      the column and raise `surveyreports_warning_unknown_role` (test-spec
      XV-07, XV-08, XV-09; spec 3.10).
- [ ] Naming a design column in `vars` or `banner` aborts with
      `surveyreports_error_design_variable_selected`, and the `vars` and
      `banner` wordings each carry their own snapshot (test-spec XE-12, XE-13,
      XE-14, XE-15; spec 3.17).
- [ ] An all-dropped `vars` selection raises
      `surveyreports_error_vars_all_dropped`, and the condition does not
      inherit `surveyreports_error_vars_empty_selection` (test-spec XE-01,
      XE-02; spec 3.10).
- [ ] An all-dropped `banner` selection raises
      `surveyreports_error_banner_empty_selection` (test-spec XE-03;
      spec 3.10).
- [ ] `interactions` naming a dropped banner column aborts with
      `surveyreports_error_interaction_not_in_banner` on the second check
      (test-spec XE-06; spec 3.10, spec 3.11).
- [ ] A `survey_collection` raises
      `surveyreports_error_collection_not_supported_for_crosstab`, a plain data
      frame raises `surveyreports_error_not_survey_object`, and an empty domain
      raises `surveyreports_error_empty_domain` (test-spec XE-08, XE-09,
      XE-10; spec 3.11).
- [ ] The empty-domain error wins over a role warning (test-spec XX-10;
      spec 3.11).
- [ ] The classification call raises no tidyselect deprecation warning, and the
      suite's warning count is 8 or fewer (test-spec XM-17; test-spec profile
      gates).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-guards.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned (28):** XM-06, XM-08, XM-09, XM-10, XM-11, XM-12, XM-13,
XM-14, XM-15, XM-16, XM-17, XE-01, XE-02, XE-03, XE-06, XE-08, XE-09, XE-10,
XE-12, XE-13, XE-14, XE-15, XV-01, XV-02, XV-07, XV-08, XV-09, XX-10.

**Files touched** — the exact write surface:

- `R/export-crosstab.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-guards.md` — created

---

### PR 11: `min_eff_n` replaces `pub_type`

**Branch:** `feature/crosstab-min-eff-n`
**Depends on:** PR 10
**Commit type:** `feat(export)`

One floor replaces three modes over two thresholds. A banner level below the
floor loses its column.

**This PR changes a formal argument, so it owns its own roxygen.** It removes
`@param pub_type`, writes `@param min_eff_n`, and runs `devtools::document()`.
Without that, `R CMD check` reports a codoc mismatch and an undocumented
argument, and this PR's own `0 warnings` gate is unreachable.

**It also deletes the tests of the argument it removes.** Section 10 of
`tests/testthat/test-export-crosstab.R`, "pub_type suppression", holds five
blocks that pass `pub_type`. `export_crosstab()` takes no `...`, so those
blocks raise an unused-argument error the moment the formal goes. The test-spec
marks that template section N/A and gives the reason.

**Why this PR runs before the rest of Part B.** `min_eff_n` defaults to 100,
and on a 200-row design that floor withholds most subgroups. Landing it now
lets every later PR write its happy-path fixtures with `min_eff_n = 0` from the
start. Two blocks written in `feature/crosstab-guards` — `XM-10` and `XM-16`,
which assert that no warning fires — gain `min_eff_n = 0` here.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-min-eff-n` from `develop`.
2. Write the failing test `XE-11`: five invalid `min_eff_n` inputs each abort
   with `surveyreports_error_invalid_min_eff_n`, and `Inf` aborts before any
   workbook is written.
3. Run it. Confirm it fails.
4. Replace `pub_type` with `min_eff_n = 100` in the `export_crosstab()`
   signature, in the same position — immediately after `interactions` and
   before `variance`, per spec 3.1.
5. Delete section 10, "pub_type suppression", from
   `tests/testthat/test-export-crosstab.R` — five blocks. The test-spec marks
   that template section N/A.
6. Remove the `@param pub_type` roxygen entry from `R/export-crosstab.R`.
7. Write the `@param min_eff_n` roxygen entry, stating the range, the default
   and the `0` escape.
8. Run `devtools::document()`.
9. Add the `min_eff_n` check to `.validate_export_inputs()`: length-1,
   non-missing, finite, numeric, and at or above 0.
10. Run the test from task 2. Confirm it passes.
11. Remove the `pub_type` column from `.empty_suppressed()`. Keep the
    `threshold` column, which `.write_suppression_footnote()` still reads.
12. Run `grep -rn "pub_type" R/ man/`. Confirm it returns nothing.
13. Run `grep -n "pub_type" tests/testthat/test-export-crosstab.R`. Confirm it
    returns nothing.
14. Add `min_eff_n = 0` to the `XM-10` and `XM-16` blocks written in
    `feature/crosstab-guards`.
15. Run `devtools::test()`. Add `min_eff_n = 0` to any other block that now
    asserts on a withheld table.
16. Confirm the suite is green.
17. Write the failing test `XW-01`: the `Female` heading and its cells are
    absent at `min_eff_n = 100`.
18. Run it. Confirm it fails.
19. Rewrite the withholding loop in `.build_freq_frame()` to call
    `.resolve_eff_n()` once per banner column, then `.build_withheld()`. This
    also retires the holding change made in `feature/effective-n-rewiring`.
20. Filter the withheld rows out of the frequency frame, so the column-group
    builder reads no heading and no cell for them.
21. Take the kept levels as a set difference on `level`, so no second
    comparison exists.
22. Run the test from task 17. Confirm it passes.
23. Write the failing tests `XW-02`, `XW-03` and `XW-04`.
24. Run them. Confirm they pass.
25. Write the failing test `XW-12`: the sheet has one fewer data column than
    the same call at `min_eff_n = 0`.
26. Run it. Confirm it passes.
27. Write the failing test `XW-13`: a subgroup whose effective N equals
    `min_eff_n` stays published.
28. Run it. Confirm it passes, and that a `<=` implementation would fail it.
29. Write the failing test `XW-05`: the floor reads the effective N and not the
    raw N.
30. Run it. Confirm it passes.
31. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`.
32. Run `covr::package_coverage()` and `covr::zero_coverage()`.
33. Run `air format .`, in its own commit.
34. Run `devtools::check()`.
35. Write `changelog/feature-crosstab-min-eff-n.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `grep -rn "pub_type" R/ man/` returns nothing (spec VIII).
- [ ] `grep -n "pub_type" tests/testthat/test-export-crosstab.R` returns
      nothing (spec VIII; test-spec template section 10, marked N/A).
- [ ] `min_eff_n` sits immediately after `interactions` in
      `names(formals(export_crosstab))` (spec 3.1).
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync (test-spec
      profile gates).
- [ ] A subgroup below the floor loses its heading, its cells and its share of
      the spanner (test-spec XW-01, XW-03; spec 3.5).
- [ ] The surviving column's estimates equal the same call at `min_eff_n = 0`
      (test-spec XW-02; spec 3.5).
- [ ] `min_eff_n = 0` withholds nothing (test-spec XW-04; spec 3.19).
- [ ] The sheet has one fewer data column, not a blank column (test-spec
      XW-12; spec 3.5).
- [ ] A subgroup whose effective N equals `min_eff_n` stays published
      (test-spec XW-13; spec 3.5).
- [ ] The floor reads the effective N and not the raw N (test-spec XW-05;
      spec 3.5).
- [ ] `grep -rn "n_eff <" R/` returns one line, inside `.build_withheld()`. No
      other code compares an effective N against `min_eff_n` (spec 3.5).
- [ ] Five invalid `min_eff_n` inputs each abort before any workbook is written
      (test-spec XE-11; spec 3.17, spec 3.19).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-min-eff-n.md` exists (`github-strategy.md`,
      PR checklist).

**Scenarios owned (8):** XE-11, XW-01, XW-02, XW-03, XW-04, XW-05, XW-12,
XW-13.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-crosstab.R` — modified, including its roxygen
- `man/export_crosstab.Rd` — regenerated
- `NAMESPACE` — regenerated; no change expected
- `tests/testthat/test-export-crosstab.R` — modified; section 10 deleted
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-min-eff-n.md` — created

---

### PR 12: Banner headings and interaction labels

**Branch:** `feature/crosstab-banner-headings`
**Depends on:** PR 11
**Commit type:** `feat(export)`

A spanner reads `Gender`, not `gen`. A crossed heading reads `Male × North`,
not `1 × 1`. No formal argument changes, so no `man/` file moves here.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-banner-headings` from `develop`.
2. Write the failing test `XH-01`: the spanner reads the variable label, and no
   spanner reads the column name.
3. Run it. Confirm it fails.
4. Call `.banner_heading()` for each surviving banner column in
   `export_crosstab()`.
5. Collect `fell_back` across the columns and raise one
   `surveyreports_warning_missing_variable_label`.
6. Run the test from task 2. Confirm it passes.
7. Write the failing tests `XH-02` and `XV-06`. `XV-06` takes the dual pattern
   on the banner trigger.
8. Run them. Confirm they pass.
9. Write the failing test `XH-04`: a crossed heading reads `Male × North`.
10. Run it. Confirm it fails.
11. Call `.banner_levels_labelled()` in `.compute_interaction_freq()`, before
    `interaction()` runs.
12. Run the test from task 9. Confirm it passes.
13. Write the failing test `XH-03`: an interaction spanner reads both labels.
14. Run it. Confirm it passes.
15. Write the failing test `XH-05`: a crossed factor banner keeps its level
    order.
16. Run it. Confirm it passes, and the headings are not sorted alphabetically.
17. Write the failing test `XH-06`: a factor banner keeps its column order.
18. Run it. Confirm it passes.
19. Write the test `XH-07`: a sheet tab keeps the variable name.
20. Run it. Confirm it passes.
21. Write the failing tests `XE-04` and `XE-05`, each with the dual pattern.
    Set no role on the fixture columns, so the guard does not drop them first.
22. Run them. Confirm they fail.
23. Add the banner label validation of spec 3.7 at step 12 of spec 3.11, on the
    surviving columns only.
24. Run the tests from task 21. Confirm they pass.
25. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`.
26. Run `covr::package_coverage()` and `covr::zero_coverage()`.
27. Run `air format .`, in its own commit.
28. Run `devtools::check()`.
29. Write `changelog/feature-crosstab-banner-headings.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] A banner spanner reads the variable label (test-spec XH-01; spec 3.8).
- [ ] A banner with no variable label falls back to the column name and raises
      one `surveyreports_warning_missing_variable_label` naming it (test-spec
      XH-02, XV-06; spec 3.8, spec 3.18).
- [ ] An interaction spanner reads both labels, and a crossed heading reads
      value labels (test-spec XH-03, XH-04; spec 3.8).
- [ ] A factor banner keeps its level order, alone and crossed (test-spec
      XH-05, XH-06; spec 3.8).
- [ ] A sheet tab keeps the variable name (test-spec XH-07; spec 3.8).
- [ ] A duplicate value label aborts with
      `surveyreports_error_duplicate_value_label` (test-spec XE-04; spec 3.7,
      spec 3.17).
- [ ] Two unlabelled observed codes abort with
      `surveyreports_error_multiple_unlabelled_codes` (test-spec XE-05;
      spec 3.7, spec 3.17).
- [ ] Both label checks run on the surviving banner columns, after the role
      guard (spec 3.7, spec 3.11).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-banner-headings.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (10):** XH-01, XH-02, XH-03, XH-04, XH-05, XH-06, XH-07,
XE-04, XE-05, XV-06.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-crosstab.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-banner-headings.md` — created

---

### PR 13: The withheld notices

**Branch:** `feature/crosstab-withheld-notices`
**Depends on:** PR 12
**Commit type:** `feat(export)`

The floor reaches crossed cells, the three warnings fire, and `withheld_note`
decides where the lines are written.

**This PR adds a formal argument, so it owns its own roxygen.** It writes
`@param withheld_note` and runs `devtools::document()`.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-withheld-notices` from `develop`.
2. Write the failing test `XW-06`: a crossed cell below the floor loses its
   column, and the surviving ones stay.
3. Run it. Confirm it fails.
4. Call `.resolve_eff_n()` on the synthetic interaction column and
   `.build_withheld()` once per interaction.
5. Filter the withheld crossed cells out of the frame, on the same set
   difference the banner path uses.
6. Run the test from task 2. Confirm it passes.
7. Write the failing test `XW-08`: each withheld line names the subgroup, its
   banner variable and its effective N, and reports no raw N.
8. Run it. Confirm it passes.
9. Write the failing test `XV-03`, with the dual pattern.
10. Run it. Confirm it fails.
11. Raise `surveyreports_warning_subgroup_withheld` once per call, with the
    bullets from `.format_withheld_lines()`.
12. Run the test from task 9. Confirm it passes, the file exists, and the
    return value is the path.
13. Write the failing tests `XV-04` and `XV-05`, each with the dual pattern.
14. Run them. Confirm they fail.
15. Raise `surveyreports_warning_banner_all_withheld` when every level of a
    column group or every cell of an interaction falls below the floor.
16. Raise `surveyreports_warning_full_sample_below_min` when the full sample's
    own effective N is below the floor. Remove nothing.
17. Run the tests from task 13. Confirm they pass, and the workbook is written
    in both.
18. Write the failing test `XV-11`: the six classes arrive in the order of
    spec 3.11.
19. Run it. Confirm it passes, or fix the emission order.
20. Write the tests `XV-10`, `XV-12` and `XV-13`.
21. Run them. Confirm they pass.
22. Add `withheld_note = c("once", "every", "none")` to the signature,
    immediately after `show_total` and before `base_notes`. Spec 3.1 places it
    after `na_label`, which `feature/crosstab-total-and-missing` inserts in
    front of it.
23. Write the `@param withheld_note` roxygen entry, listing its three values.
24. Run `devtools::document()`.
25. Pass the withheld frame to `.build_workbook()` when `withheld_note` is
    `"once"`, and `NULL` otherwise.
26. Write the withheld lines at the end of each question block when
    `withheld_note` is `"every"`, from the three render routes.
    `feature/crosstab-label-cols-and-sizes` moves this into
    `.render_block_footer()`.
27. Write the failing tests `XW-09`, `XW-10` and `XW-11`.
28. Run them. Confirm they pass, and the console warning still fires at
    `"none"`.
29. Write the failing test `XW-07`: the cover sheet's withheld block names the
    crossed subgroup.
30. Run it. Confirm it passes.
31. Pass `min_eff_n` and `has_banner` to `.write_cover_sheet()`, so the
    `Why a column is missing` entry follows spec 3.15.
32. Write the failing tests `XA-06` and `XA-07`.
33. Run them. Confirm they pass.
34. Write the failing test `XA-12`: the two header cells and every block
    heading resolve to a bold font, with all three blocks present.
35. Run it. Confirm it passes.
36. Write the edge-case tests `XX-02`, `XX-06` and `XX-07`.
37. Run them. Confirm they pass.
38. Write the edge-case tests `XX-08` and `XX-09`.
39. Run them. Confirm they pass.
40. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`.
41. Run `covr::package_coverage()` and `covr::zero_coverage()`.
42. Run `air format .`, in its own commit.
43. Run `devtools::check()`.
44. Write `changelog/feature-crosstab-withheld-notices.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] A crossed cell below the floor loses its column, and the surviving ones
      stay (test-spec XW-06; spec 3.5).
- [ ] The cover sheet's withheld block names the crossed subgroup, not only the
      banner levels (test-spec XW-07; spec 3.14).
- [ ] Each withheld line names the subgroup, its banner variable and its
      effective N, and reports no raw N (test-spec XW-08; spec 3.14).
- [ ] `withheld_note` places the lines on the cover sheet, under each table, or
      nowhere, and changes nothing about what is withheld (test-spec XW-09,
      XW-10, XW-11; spec 3.5, spec 3.14).
- [ ] `withheld_note` sits immediately before `base_notes` in
      `names(formals(export_crosstab))`, which is where spec 3.1 puts it once
      `na_label` exists (spec 3.1).
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync (test-spec
      profile gates).
- [ ] The three withholding warnings fire with the dual pattern, none aborts,
      and each leaves a readable file at the path returned (test-spec XV-03,
      XV-04, XV-05; spec 3.18).
- [ ] The raised condition does not inherit
      `surveyreports_warning_subgroup_suppressed` (test-spec XV-10;
      spec 3.18).
- [ ] `grep -rn "subgroup_suppressed" R/ man/ tests/` returns nothing
      (spec VIII).
- [ ] The six warning classes arrive in the order of spec 3.11 (test-spec
      XV-11).
- [ ] A design with no role set and every subgroup above the floor raises no
      warning, and `surveycore_warning_small_cell` never reaches the caller
      (test-spec XV-12, XV-13; spec 3.5).
- [ ] The withheld block states `None` at a floor that withholds nothing, and
      is absent at `min_eff_n = 0` (test-spec XA-06, XA-07; spec 3.14).
- [ ] The cover sheet's header cells and every block heading are bold
      (test-spec XA-12; spec 3.14).
- [ ] A single-row design at the default floor writes the file and raises both
      `surveyreports_warning_banner_all_withheld` and
      `surveyreports_warning_full_sample_below_min` (test-spec XX-02;
      spec 3.19).
- [ ] An unused factor level on the banner and an unobserved value label each
      produce no column and no withheld entry (test-spec XX-06, XX-07;
      spec 3.19).
- [ ] One unlabelled observed code is a real subgroup, withheld and listed as a
      missing label (test-spec XX-08; spec 3.7, spec 3.19).
- [ ] A self-banner column is skipped for its own variable (test-spec XX-09;
      spec 3.19).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-withheld-notices.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (21):** XW-06, XW-07, XW-08, XW-09, XW-10, XW-11, XV-03,
XV-04, XV-05, XV-10, XV-11, XV-12, XV-13, XA-06, XA-07, XA-12, XX-02, XX-06,
XX-07, XX-08, XX-09.

**Files touched** — the exact write surface:

- `R/export-utils.R` — modified
- `R/export-crosstab.R` — modified, including its roxygen
- `man/export_crosstab.Rd` — regenerated
- `NAMESPACE` — regenerated; no change expected
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-withheld-notices.md` — created

---

### PR 14: Label columns, sample sizes, and the shared block helpers

**Branch:** `feature/crosstab-label-cols-and-sizes`
**Depends on:** PR 13
**Commit type:** `feat(export)`

Two sample-size rows replace the per-response `N` column. The three render
routes get one shared preamble and one shared footer.

**This PR changes three formal arguments, so it owns its own roxygen.** It
removes `@param show_n` and `@param show_eff_n`, writes
`@param sample_size_display` and `@param show_ess`, and runs
`devtools::document()`.

**`show_eff_n` goes with `show_n`.** Spec 5.1 lists the rename to `show_ess` as
a breaking change, and spec 3.2 says `show_ess` replaces `show_eff_n`, "which
was a no-op". `feature/effective-n-rewiring` already deleted the join block
that gave it any effect, so it is inert by the time this PR starts.

**It also deletes the tests of the arguments it removes.** Section 9 of
`tests/testthat/test-export-crosstab.R`, "show_n and show_eff_n", holds three
blocks that pass both. `export_crosstab()` takes no `...`, so those blocks
raise an unused-argument error the moment the formals go.

**One ordering inside this PR is forced.** `.write_crosstab_headers()` gains
`label_cols` and the battery route adopts it **before**
`.render_block_preamble()` is extracted. The battery route writes its spanner
and heading rows inline today, so a preamble extracted first would serve two
routes of three and leave the third to drift (spec IX, spec 3.16). Tasks 4 to 9
come before task 25.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-label-cols-and-sizes` from `develop`.
2. Write the failing test `XD-01`: a SATA block holds one label column headed
   `Item`; a battery block holds two, headed `Item` then `Response`.
3. Run it. Confirm it fails on the battery shape.
4. Change `.write_crosstab_headers()`'s `label_col1` argument to `label_cols`,
   a character vector of headings.
5. Start the banner spanners at column `length(label_cols) + 1`.
6. Update the single route's call to pass `c("Response")`.
7. Update the SATA route's call to pass `c("Item")`.
8. Replace the battery route's inline spanner and heading sequence with a call
   passing `c("Item", "Response")`.
9. Run the test from task 2. Confirm it passes.
10. Write the failing test `XS-01`: two rows labelled `Unweighted sample size`
    and `Effective sample size` sit directly under the heading row, in that
    order.
11. Run it. Confirm it fails.
12. Remove `show_n` and `show_eff_n` from the `export_crosstab()` signature,
    and add `sample_size_display = c("top", "bottom", "none")` then
    `show_ess = TRUE` in the slot the two removed arguments vacate —
    immediately after `conf_level` and before `decimals`, per spec 3.1.
13. Remove `show_eff_n` from its ten internal call sites in
    `R/export-crosstab.R`.
14. Delete section 9, "show_n and show_eff_n", from
    `tests/testthat/test-export-crosstab.R` — three blocks. The test-spec
    covers the replacement under `XS-05` and `XS-08`.
15. Remove the `@param show_n` and `@param show_eff_n` roxygen entries from
    `R/export-crosstab.R`.
16. Write the `@param sample_size_display` and `@param show_ess` roxygen
    entries, each listing its accepted values.
17. Run `devtools::document()`.
18. Remove the per-response `N` cell and its heading from the single route and
    from the battery route.
19. Remove the `.sata_n_cell()` call and the `N` heading from the SATA route.
    The helper itself stays unchanged for `export_topline()` — spec 2.3 ties
    its removal to the `show_n` removal, and `XS-08` asserts it here.
20. Build the `counts` frame in `export_crosstab()`: one row per rendered data
    column, in write order, with the Total column carried as a row whose
    `level` is the Total heading.
21. Call `.write_sample_size_rows()` from the single route.
22. Run the test from task 10. Confirm it passes.
23. Write the failing test `XE-07`: a call passing `pub_type`, `show_n` or
    `show_eff_n` gets an unused-argument error.
24. Run it. Confirm it passes.
25. Extract `.render_block_preamble()` in `R/export-crosstab.R`, below the
    exported function. It writes rows 1 to 7 of spec 3.16 and returns the first
    data row.
26. Extract `.render_block_footer()` beside it, also below the exported
    function. It writes the bottom sample-size rows and the withheld lines, and
    returns the next free row.
27. Move the `withheld_note == "every"` lines written in
    `feature/crosstab-withheld-notices` into `.render_block_footer()`.
28. Replace the single route's opening sequence with a
    `.render_block_preamble()` call.
29. Replace the SATA route's opening sequence with a `.render_block_preamble()`
    call.
30. Replace the battery route's opening sequence with a
    `.render_block_preamble()` call.
31. Call `.render_block_footer()` from all three routes.
32. Run `devtools::test()`. Confirm the suite is green.
33. Write the failing tests `XS-02` and `XS-05`.
34. Run them. Confirm they pass.
35. Write the failing tests `XS-06` and `XS-07`.
36. Run them. Confirm they pass.
37. Write the failing test `XS-08`: no heading cell reads `N`, and the last
    data column is a banner level.
38. Run it. Confirm it passes on a single, a SATA and a battery block.
39. Write the failing test `XS-10`: a battery block's sample-size rows leave
    the second label column blank.
40. Run it. Confirm it passes.
41. Write the failing tests `XS-03` and `XS-04`, comparing against the oracle
    rounded to one decimal.
42. Run them. Confirm they pass.
43. Write the failing test `XS-09`: the counts ignore the tabulated variable.
44. Run it. Confirm it passes, and the response rows total less.
45. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`.
46. Run `covr::package_coverage()` and `covr::zero_coverage()`.
47. Run `air format .`, in its own commit.
48. Run `devtools::check()`.
49. Write `changelog/feature-crosstab-label-cols-and-sizes.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `grep -rn "show_n" R/export-crosstab.R man/export_crosstab.Rd` returns
      nothing (spec VIII).
- [ ] `grep -rn "show_eff_n" R/export-crosstab.R` returns nothing (spec 3.2,
      spec 5.1).
- [ ] `grep -n "show_n\|show_eff_n" tests/testthat/test-export-crosstab.R`
      returns nothing (spec VIII; test-spec template section 9, replaced by
      `XS-05` and `XS-08`).
- [ ] `sample_size_display` then `show_ess` sit immediately after `conf_level`
      and before `decimals` in `names(formals(export_crosstab))` (spec 3.1).
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync (test-spec
      profile gates).
- [ ] A SATA block and a battery block each render in their own shape, with the
      label column count, the label headings and the row count asserted
      (test-spec XD-01; spec 3.16).
- [ ] Two sample-size rows sit under the heading row by default, in order
      (test-spec XS-01; spec 3.4, spec 3.16).
- [ ] Both rows are italic and one point smaller than an estimate cell
      (test-spec XS-02; spec 3.4).
- [ ] `show_ess = FALSE` removes only the second row (test-spec XS-05;
      spec 3.4).
- [ ] `sample_size_display = "bottom"` moves both rows below the estimates, and
      `"none"` removes both (test-spec XS-06, XS-07; spec 3.4).
- [ ] No heading cell reads `N`, on any of the three block shapes (test-spec
      XS-08; spec 2.3, spec 5.1).
- [ ] A battery block's sample-size rows leave the second label column blank
      (test-spec XS-10; spec 3.4).
- [ ] The counts match the oracle for each subgroup and for the full sample
      (test-spec XS-03, XS-04; spec 3.4).
- [ ] The counts ignore the tabulated variable (test-spec XS-09;
      spec 1.4.1, spec 3.4).
- [ ] A call passing `pub_type`, `show_n` or `show_eff_n` gets an
      unused-argument error (test-spec XE-07; spec 5.1).
- [ ] `grep -n "sample_size_display" R/export-crosstab.R` returns lines inside
      `export_crosstab()`, `.render_block_preamble()` and
      `.render_block_footer()` only, and no line inside
      `.render_crosstab_single()`, `.render_crosstab_sata()` or
      `.render_crosstab_battery()` (spec 3.16).
- [ ] `grep -n "write_crosstab_headers" R/export-crosstab.R` returns four
      lines: the definition and one call from each of the three render routes
      (spec 2.3, spec 3.16).
- [ ] `R/export-crosstab.R` holds `.render_block_preamble()`,
      `.render_block_footer()` and `.unique_sheet_name()` below the exported
      function (spec 2.1, spec VIII).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-label-cols-and-sizes.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (12):** XD-01, XS-01, XS-02, XS-03, XS-04, XS-05, XS-06,
XS-07, XS-08, XS-09, XS-10, XE-07.

**Files touched** — the exact write surface:

- `R/export-crosstab.R` — modified, including its roxygen
- `R/export-utils.R` — modified
- `man/export_crosstab.Rd` — regenerated
- `NAMESPACE` — regenerated; no change expected
- `tests/testthat/test-export-crosstab.R` — modified; section 9 deleted
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-label-cols-and-sizes.md` — created

---

### PR 15: The sheet properties

**Branch:** `feature/crosstab-sheet-properties`
**Depends on:** PR 14
**Commit type:** `feat(export)`

The `100%` row goes from the crosstab. Widths, wrapping, row height and the
freeze pane are fixed values, so a label change moves no snapshot. No formal
argument changes, so no `man/` file moves here.

**The topline `100%` row stays.** Spec 4.2 says `export_topline()` still writes
it. Both files hold a single-response route, so task 4 names
`.render_crosstab_single()` and no other.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-sheet-properties` from `develop`.
2. Write the failing test `XH-10`: no cell in an `export_crosstab()` sheet
   holds the string `100%`.
3. Run it. Confirm it fails.
4. Delete the `Total` row of `100%` cells from `.render_crosstab_single()`.
   Replace it with nothing. Do not touch `.render_topline_single()`.
5. Run the test from task 2. Confirm it passes.
6. Write the test that `export_topline()` still writes its `Total` row of
   `100%` cells.
7. Run it. Confirm it passes.
8. Write the failing test `XB-01`: the label column's stored width rounds to
   44, and each data column's rounds to 12.
9. Run it. Confirm it fails.
10. Set fixed column widths with `openxlsx2::wb_set_col_widths()`. Do not
    auto-fit.
11. Run the test from task 8. Confirm it passes.
12. Write the failing test `XB-02`: two calls with labels of different length
    give the same widths, column by column.
13. Run it. Confirm it passes.
14. Write the failing test `XB-03`: the label column and the heading row
    resolve to a wrapping alignment, an estimate cell does not, and the heading
    row's stored height is 30.
15. Run it. Confirm it fails.
16. Set the wrapping alignment on the label column and on the heading row.
17. Set the heading row height to 30 points with
    `openxlsx2::wb_set_row_heights()`. Do not auto-fit.
18. Run the test from task 14. Confirm it passes.
19. Write the failing test `XB-04`: a freeze pane under `"top"`, and none under
    `"bottom"`.
20. Run it. Confirm it fails.
21. Add the freeze pane, split below the last sample-size row, and skip it when
    `sample_size_display == "bottom"`.
22. Run the test from task 19. Confirm it passes.
23. Write the numerical tests `XN-01`, `XN-02` and `XN-03`, each tagged
    `[numerical]`.
24. Run them. Confirm they pass.
25. Write the numerical test `XN-04`: the count equals the rows the design
    tabulates, computed from the design rather than hard-coded.
26. Run it. Confirm it passes on twophase.
27. Write the numerical test `XN-05`: the count equals the in-domain row count.
28. Run it. Confirm it passes.
29. Write the edge-case tests `XX-01`, `XX-03` and `XX-04`. Each block runs
    against both export functions and labels every assertion with the function
    name.
30. Run them. Confirm they pass.
31. Write the edge-case test for an unused factor level on the tabulated
    variable: no response row, and the sample-size rows unchanged.
32. Run it. Confirm it passes.
33. Write the edge-case test `XX-11`: the stacked layout writes one `Crosstab`
    sheet plus the cover sheet.
34. Run it. Confirm it passes.
35. Write the edge-case test `XX-12`: the response rows total less than the
    sample size above them, with no warning.
36. Run it. Confirm it passes.
37. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`.
38. Run `covr::package_coverage()` and `covr::zero_coverage()`.
39. Run `air format .`, in its own commit.
40. Run `devtools::check()`.
41. Write `changelog/feature-crosstab-sheet-properties.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] No cell in an `export_crosstab()` sheet holds the string `100%`
      (test-spec XH-10; spec 3.9, spec 3.16).
- [ ] `export_topline()` still writes its `Total` row of `100%` cells
      (spec 4.2).
- [ ] The column widths are fixed at 44 and 12 (test-spec XB-01; spec 3.16).
- [ ] The widths do not follow the label text (test-spec XB-02; spec 3.16).
- [ ] The label column and the heading row wrap, and the heading row's height
      is 30 points (test-spec XB-03; spec 3.16).
- [ ] A freeze pane is present under `"top"` and absent under `"bottom"`
      (test-spec XB-04; spec 3.16).
- [ ] Both counts match the oracle for the full sample and for a subgroup
      (test-spec XN-01, XN-02, XN-03; spec 3.4).
- [ ] The counts follow the phase-2 subset and the in-domain rows (test-spec
      XN-04, XN-05; spec 3.20).
- [ ] A single-row design at `min_eff_n = 0` succeeds and reports an unweighted
      sample size of `1`, in both export functions (test-spec XX-01;
      spec 3.19).
- [ ] An all-NA variable succeeds and the sample-size rows report the design's
      in-scope rows, not `0`, in both export functions (test-spec XX-03;
      spec 3.19).
- [ ] A single-value variable produces one response row, and the sample-size
      rows are unchanged against another variable on the same design, in both
      export functions (test-spec XX-04; spec 3.19).
- [ ] An unused factor level on the tabulated variable produces no response
      row, and the sample-size rows are unchanged (spec 3.19).
- [ ] The stacked layout writes exactly two sheets (test-spec XX-11;
      spec 3.2).
- [ ] A variable with missing values raises no warning about it (test-spec
      XX-12; spec 3.4, spec 3.19).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-sheet-properties.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (15):** XH-10, XB-01, XB-02, XB-03, XB-04, XN-01, XN-02,
XN-03, XN-04, XN-05, XX-01, XX-03, XX-04, XX-11, XX-12.

**Files touched** — the exact write surface:

- `R/export-crosstab.R` — modified
- `R/export-utils.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/test-export-topline.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-sheet-properties.md` — created

---

### PR 16: A percentage cell becomes a string

**Branch:** `feature/crosstab-percent-cells`
**Depends on:** PR 15
**Commit type:** `feat(export)`

`.fmt_pct()` owns the proportion-to-percentage conversion in the crosstab
render path. Every estimate cell becomes text. No formal argument changes, so
no `man/` file moves here.

**One glossary entry lags by two PRs.** The `Percentages` entry follows
`string_cells`, and `export_crosstab()` starts passing `string_cells = TRUE` in
`feature/crosstab-total-and-missing`. Between this PR and that one the cells
are strings and the entry is absent. `XA-05` asserts the closed state there.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-percent-cells` from `develop`.
2. Write the failing test `XC-01`: every estimate cell is character and matches
   one of the five forms; no estimate cell is numeric.
3. Run it. Confirm it fails because the cells are numeric.
4. Replace the single route's `round(x$pct[[1L]] * 100, decimals)` with a
   `.fmt_pct()` call, passing the proportion unchanged.
5. Replace the battery route's inline conversion with a `.fmt_pct()` call.
6. Change the SATA route to build its cell from `.fmt_pct()` rather than
   `.sata_pct_cell()`. Leave the helper unchanged for `export_topline()`.
7. Compute `has_rows` at each call site as `nrow(rows) > 0 && rows$n > 0`.
8. Run `grep -rn "\* 100" R/`. Confirm it returns three lines, two in
   `R/export-topline.R` and one in `R/export-utils.R`.
9. Run the test from task 2. Confirm it passes.
10. Write the failing test `XC-02`: the cell equals the string the test builds
    from the oracle.
11. Run it. Confirm it passes.
12. Write the failing test `XC-03`: the same construction holds at
    `decimals = 0` and at `2`.
13. Run it. Confirm it passes.
14. Write the failing tests `XC-04` and `XC-05`: the floor string, and the
    floor string following `decimals`.
15. Run them. Confirm they pass.
16. Write the failing tests `XC-05a` and `XC-05b`: the ceiling string, and no
    cell reading `100.0%`.
17. Run them. Confirm they pass.
18. Write the failing test `XC-06`: a true zero reads `0%`.
19. Run it. Confirm it passes, and the cell is neither `<0.1%` nor `-`.
20. Write the failing test `XC-07`: a cell with no rows reads `-`, on a
    placeholder row whose `n` is 0.
21. Run it. Confirm it passes.
22. Write the failing test `XC-07a`: a SATA item never asked and an item nobody
    chose both read `-`.
23. Run it. Confirm it passes, and no cell in the block is blank.
24. Write the failing test `XC-08`: all four special forms and a plain
    percentage appear in one block.
25. Run it. Confirm it passes.
26. Run `devtools::test()`. Review every moved crosstab snapshot with
    `testthat::snapshot_review()`.
27. Confirm no `export_topline()` snapshot moved.
28. Run `covr::package_coverage()` and `covr::zero_coverage()`.
29. Run `air format .`, in its own commit.
30. Run `devtools::check()`.
31. Write `changelog/feature-crosstab-percent-cells.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] Every estimate cell is character and matches one of the five forms of
      spec 3.3 (test-spec XC-01; spec 8.1).
- [ ] The rendered value matches the oracle, at `decimals` 0, 1 and 2
      (test-spec XC-02, XC-03; spec 3.3).
- [ ] A nonzero value that rounds to zero reads the floor string, and the
      string follows `decimals` (test-spec XC-04, XC-05; spec 3.3).
- [ ] A value below 100 that rounds to 100 reads the ceiling string, and no
      estimate cell reads `100.0%` at any `decimals` (test-spec XC-05a,
      XC-05b; spec 3.3, spec 8.1).
- [ ] A true zero reads `0%`, and a cell with no rows reads `-` (test-spec
      XC-06, XC-07; spec 3.3).
- [ ] A SATA item never asked and an item nobody chose both read `-`, and no
      cell in the block is blank (test-spec XC-07a; spec 3.3).
- [ ] All four special forms and a plain percentage appear in one block
      (test-spec XC-08; spec 3.3).
- [ ] `grep -rn "\* 100" R/` returns three lines, two in `R/export-topline.R`
      and one in `R/export-utils.R` (spec VIII, spec 8.1).
- [ ] No `export_topline()` snapshot moved (spec 4.1, spec 5.2).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-percent-cells.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (11):** XC-01, XC-02, XC-03, XC-04, XC-05, XC-05a, XC-05b,
XC-06, XC-07, XC-07a, XC-08.

**Files touched** — the exact write surface:

- `R/export-crosstab.R` — modified
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-percent-cells.md` — created

---

### PR 17: The variance strings and the legend row

**Branch:** `feature/crosstab-variance-strings`
**Depends on:** PR 16
**Commit type:** `feat(export)`

`.fmt_variance()` owns the whole parenthesised value. A legend row explains it.

**This PR adds a formal argument, so it owns its own roxygen.** It writes
`@param variance_display` and runs `devtools::document()`.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-variance-strings` from `develop`.
2. Write the failing test `XH-15`: an estimate cell holds the percentage and a
   parenthesised standard error, with one `%`.
3. Run it. Confirm it fails.
4. Add `variance_display = c("cell", "row")` to the signature, immediately
   after `variance` and before `conf_level`, per spec 3.1.
5. Write the `@param variance_display` roxygen entry, listing both values.
6. Run `devtools::document()`.
7. Call `.fmt_variance()` from the single route, writing the second line with
   `openxlsx2::fmt_txt()` at a smaller size and a lighter colour.
8. Call `.fmt_variance()` from the SATA route.
9. Call `.fmt_variance()` from the battery route.
10. Run the test from task 2. Confirm it passes.
11. Write the failing test `XH-16`: the two bounds, one `%` each, en-dash
    separated.
12. Run it. Confirm it passes, and a hyphen-minus separator would fail.
13. Write the failing test `XH-16a`: a negative lower bound prints unclipped.
14. Run it. Confirm it passes against the oracle, not against 0.
15. Write the failing test `XH-17`: `variance_display = "row"` doubles the
    estimate rows and leaves the cells without a parenthesis.
16. Run it. Confirm it fails.
17. Write the variance row directly under each estimate row, with the label
    columns blank.
18. Run the test from task 15. Confirm it passes.
19. Write the failing test `XH-20`: a `-` cell reads `-` alone under
    `variance`.
20. Run it. Confirm it passes, and the variance row is blank in that column.
21. Write the failing tests `XH-18` and `XH-19`.
22. Run them. Confirm they fail.
23. Write the legend row in `.render_block_preamble()`, at row 3 of spec 3.16,
    only when `variance` is not `NULL`.
24. Name the confidence level in the legend from `conf_level`.
25. Run the tests from task 21. Confirm they pass.
26. Write the numerical test `XN-09`, tagged `[numerical]`.
27. Run it. Confirm it passes.
28. Write the numerical test `XN-10`, tagged `[numerical]`.
29. Run it. Confirm it passes, with the en-dash asserted.
30. Run `devtools::test()`. Review every moved snapshot with
    `testthat::snapshot_review()`.
31. Run `covr::package_coverage()` and `covr::zero_coverage()`.
32. Run `air format .`, in its own commit.
33. Run `devtools::check()`.
34. Write `changelog/feature-crosstab-variance-strings.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `variance = "se"` writes the standard error in parentheses, with one `%`
      (test-spec XH-15, XN-09; spec 3.12).
- [ ] `variance = "ci"` writes both bounds, one `%` each, separated by an
      en-dash with one space on each side (test-spec XH-16, XN-10; spec 3.12,
      spec 8.1).
- [ ] A negative lower bound prints unclipped, with a hyphen-minus and no space
      (test-spec XH-16a; spec 3.12, spec 8.1).
- [ ] `variance_display = "row"` writes its own row and leaves the estimate
      cells without a parenthesis (test-spec XH-17; spec 3.12).
- [ ] A `-` cell carries no variance under either display (test-spec XH-20;
      spec 3.12).
- [ ] A legend row appears only under `variance`, and names a non-default
      `conf_level` (test-spec XH-18, XH-19; spec 3.12, spec 3.16).
- [ ] `variance_display` sits immediately after `variance` and before
      `conf_level` in `names(formals(export_crosstab))` (spec 3.1).
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync (test-spec
      profile gates).
- [ ] `grep -n "fmt_variance" R/export-crosstab.R` returns three call sites,
      one per render route, and `grep -n "\* 100" R/export-crosstab.R` returns
      nothing. Every variance number reaches `.fmt_pct()` through
      `.fmt_variance()` (spec 8.1).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-variance-strings.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (9):** XH-15, XH-16, XH-16a, XH-17, XH-18, XH-19, XH-20,
XN-09, XN-10.

**Files touched** — the exact write surface:

- `R/export-crosstab.R` — modified, including its roxygen
- `man/export_crosstab.Rd` — regenerated
- `NAMESPACE` — regenerated; no change expected
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-variance-strings.md` — created

---

### PR 18: The Total column, missing data, and the block row order

**Branch:** `feature/crosstab-total-and-missing`
**Depends on:** PR 17
**Commit type:** `feat(export)`

The last of the crosstab rebuild. This PR also closes the glossary, pins the
whole block row order, and pins the final argument order.

**This PR adds four formal arguments, so it owns its own roxygen.** It writes
`@param total_label`, `@param na.rm` and `@param na_label`, corrects
`@param show_total`, and runs `devtools::document()`. It is the last PR to
touch the signature, so it also carries the criterion that compares the whole
order against spec 3.1.

**Tasks** (2–5 minutes each):

1. Cut `feature/crosstab-total-and-missing` from `develop`.
2. Write the failing test `XH-08`: on a design with no domain column the
   heading reads `Full Sample`, then the supplied `total_label`.
3. Run it. Confirm it fails.
4. Add `total_label = NULL` to the signature, immediately after `show_total`,
   per spec 3.1. Leave `show_total` where it already ships.
5. Add the `total_label` and `spanner` arguments to `.total_col_group()`, both
   defaulting to `"Total"`.
6. Resolve the `NULL` default of `total_label` from `.has_domain(design)`:
   `"Total"` when restricted, `"Full Sample"` otherwise.
7. Pass the resolved `total_label` and `spanner = ""` at the three
   `R/export-crosstab.R` call sites. Leave the three other call sites
   argument-free.
8. Run the test from task 2. Confirm it passes.
9. Write the failing tests `XH-08a` and `XH-08b`.
10. Run them. Confirm they pass, and neither string is hard-coded.
11. Write the failing test `XH-09`: the spanner cell above the Total heading is
    empty.
12. Run it. Confirm it passes.
13. Write the failing test `XH-09a`, on the single-response route alone, and
    state the reason in the block description.
14. Run it. Confirm it fails.
15. Skip building the total column group when `show_total` is FALSE.
16. Run the test from task 13. Confirm it passes.
17. Write the failing test `XX-13`: zero data columns, with the three
    assertions of the test-spec.
18. Run it. Confirm it passes, with two warnings and no third.
19. Write the failing test `XH-11`: `na.rm = FALSE` adds a response row.
20. Run it. Confirm it fails.
21. Add `na.rm = TRUE` then `na_label = "No answer"` to the signature,
    immediately after `total_label` and before `withheld_note`, per spec 3.1.
22. Write the `@param total_label`, `@param na.rm` and `@param na_label`
    roxygen entries, and correct `@param show_total`.
23. Run `devtools::document()`.
24. Pass `na.rm` to `.compute_total_freq()`, `.compute_subgroup_freq()` and
    `.compute_interaction_freq()`.
25. Pass `na.rm` to `.resolve_eff_n()`, so the counts frame holds a row for a
    missing-value banner level whenever the workbook holds its column.
26. Label the missing-value response row and the missing-value banner level
    with `na_label`.
27. Run the test from task 19. Confirm it passes.
28. Write the failing tests `XH-12` and `XH-13`.
29. Run them. Confirm they pass.
30. Write the failing test `XH-14`: a missing-value banner column faces the
    floor and is named in the withheld list.
31. Run it. Confirm it passes.
32. Pass `string_cells = TRUE` to `.build_workbook()` from
    `export_crosstab()`.
33. Write the failing test `XA-05`: the glossary holds four terms, and
    `Confidence intervals` is absent.
34. Run it. Confirm it passes.
35. Write the failing test `XA-05a`: exactly two entries flip at
    `min_eff_n = 0` with `variance = "ci"`.
36. Run it. Confirm it passes.
37. Write the numerical tests `XN-06` and `XN-07`, each tagged `[numerical]`.
38. Run them. Confirm they pass.
39. Write the numerical test `XN-08`, tagged `[numerical]`.
40. Run it. Confirm it passes over the crossed grouping.
41. Write the failing test `XR-01`: column A reads as an ordered character
    vector under `sample_size_display = "top"`.
42. Run it. Confirm it passes, with blank and `NA` normalised first.
43. Write the failing test `XR-02`: the same under `"bottom"`.
44. Run it. Confirm it passes.
45. Compare `names(formals(export_crosstab))` against the order of spec 3.1.
    Fix any argument that sits out of place.
46. Run `devtools::test()`. Review every moved crosstab snapshot with
    `testthat::snapshot_review()`.
47. Confirm no `export_topline()` snapshot moved.
48. Run `covr::package_coverage()` and `covr::zero_coverage()`.
49. Run `air format .`, in its own commit.
50. Run `devtools::check()`.
51. Write `changelog/feature-crosstab-total-and-missing.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `names(formals(export_crosstab))` is identical to the order of spec 3.1
      (spec 3.1).
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync (test-spec
      profile gates).
- [ ] The Total heading takes `total_label`, and its `NULL` default resolves to
      `Full Sample` on an unrestricted design and `Total` on a restricted one
      (test-spec XH-08, XH-08a; spec 3.9).
- [ ] A caller-supplied `total_label` wins on a restricted design (test-spec
      XH-08b; spec 3.9).
- [ ] The Total column's spanner cell is empty (test-spec XH-09; spec 3.9).
- [ ] `show_total = FALSE` removes the column group, and the block holds one
      group fewer (test-spec XH-09a; spec 3.9).
- [ ] `show_total = FALSE` with every banner level withheld writes a block with
      no data column, raises `surveyreports_warning_banner_all_withheld` and
      `surveyreports_warning_subgroup_withheld` and no third warning, and
      returns the path (test-spec XX-13; spec 3.5, spec 3.19).
- [ ] `na.rm = FALSE` adds a response row and a banner column, and `na_label`
      renames both (test-spec XH-11, XH-12, XH-13; spec 3.13).
- [ ] A missing-value banner level faces the floor and is named in the withheld
      list (test-spec XH-14; spec 3.13).
- [ ] `na.rm` reaches the four call sites inside this PR's write surface with
      the same value: `.compute_total_freq()`, `.compute_subgroup_freq()`,
      `.compute_interaction_freq()` and `.resolve_eff_n()` (spec 3.13). The
      fifth site of spec 3.13, the collection path of `export_topline()`, is
      out of scope: `export_topline()` takes no `na.rm`, and spec 4.1 bounds
      its change.
- [ ] The glossary holds four terms at `variance = NULL` with a floor in force
      (test-spec XA-05; spec 3.15).
- [ ] Exactly two glossary entries flip at `min_eff_n = 0` with
      `variance = "ci"` (test-spec XA-05a; spec 3.15).
- [ ] Every Total-column, banner-column and interaction-cell estimate matches
      the oracle as a string (test-spec XN-06, XN-07, XN-08).
- [ ] Column A of a block reads in the order of spec 3.16 under both
      `sample_size_display` values (test-spec XR-01, XR-02).
- [ ] `R/export-utils.R` holds the 15 shared helpers of spec 2.1, and
      `R/export-crosstab.R` holds the 3 helpers spec 2.1 assigns to it, below
      the exported function. `ls("package:surveyreports", all.names = TRUE)`
      exposes none of them, and no `R/utils.R` exists (spec VIII).
- [ ] No `export_topline()` snapshot moved (spec 4.1, spec 5.2).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] Coverage: 95 percent floor, 98 percent target; `covr::zero_coverage()`
      lists no line in a file this PR touched (test-spec profile gates).
- [ ] `air format --check .` passes (test-spec profile gates).
- [ ] `changelog/feature-crosstab-total-and-missing.md` exists
      (`github-strategy.md`, PR checklist).

**Scenarios owned (17):** XH-08, XH-08a, XH-08b, XH-09, XH-09a, XH-11, XH-12,
XH-13, XH-14, XX-13, XA-05, XA-05a, XR-01, XR-02, XN-06, XN-07, XN-08.

**Files touched** — the exact write surface:

- `R/export-crosstab.R` — modified, including its roxygen
- `R/export-utils.R` — modified
- `man/export_crosstab.Rd` — regenerated
- `NAMESPACE` — regenerated; no change expected
- `tests/testthat/test-export-crosstab.R` — modified
- `tests/testthat/_snaps/export-crosstab.md` — regenerated
- `changelog/feature-crosstab-total-and-missing.md` — created

---

### PR 19: The documentation prose

**Branch:** `docs/export-metadata`
**Depends on:** PR 18
**Commit type:** `docs(export)`

Five earlier PRs each edited the `@param` entries of the formal arguments they
changed, and each ran `devtools::document()`. This PR carries what is left: the
prose blocks of spec 7.2, the `@param` entries of arguments this work neither
adds nor removes, `man/export_topline.Rd`, and `_pkgdown.yml`. A `@param` edited
here belongs to an argument whose formal did not move, so it raises no codoc
mismatch and deferring it was safe.

**Documentation tiers.** This work adds no exported function. Both functions
keep the tier the spec assigns: `export_crosstab()` is **Tier 4 — Dispatcher**
and `export_topline()` is **Tier 4 — Dispatcher** (spec 3.1, spec 7.1). Neither
meets its tier today, so the tier's required sections are deliverables here.

**Tasks** (2–5 minutes each):

1. Cut `docs/export-metadata` from `develop`.
2. Correct the closing sentence of `export_crosstab()`'s `@description`: name
   `surveycore::classify_question_type()` as what selects the render route, and
   say `layout` selects the sheet arrangement.
3. Confirm `export_topline()`'s `@description` closing sentence is correct as
   it stands.
4. Extend `@param layout` so it lists both values with a brief
   characterization.
5. Extend `@param banner` with the role rule, the two label aborts, and the
   `interactions` abort.
6. Extend `@param vars` in both files with the role drop and the all-dropped
   abort.
7. Extend `@param base_notes` in both files with the universe fallback, the
   unanimity rule, and the caller-wins rule.
8. Add `[surveycore::as_survey_nonprob()]` to `@param design` in both files.
9. Add to `export_topline()`'s `@param vars` that the question structure of the
   selected columns decides the block shape, and point at `@details`.
10. Confirm the `@param` entries for `min_eff_n`, `variance_display`,
    `sample_size_display`, `show_ess`, `withheld_note`, `total_label`, `na.rm`
    and `na_label` are already present, written by the five PRs that added
    each argument.
11. Write `export_crosstab()`'s `@details`: the three render routes, what
    selects each, and the role guard and the withholding step as stages before
    dispatch.
12. Write `export_crosstab()`'s `@section Workbook Layout`: the cover sheet,
    the Total column, the banner column groups, the two layouts, the
    sample-size rows, and the row order of spec 3.16.
13. Rewrite `export_crosstab()`'s `@returns` per spec 7.2, naming the `"About"`
    sheet and the question sheets.
14. Write `export_topline()`'s `@details` per spec 7.2, naming the three render
    routes, the classifier, the once-per-group rule, the battery sub-block
    route, and the collection path.
15. Write `export_topline()`'s `@section Workbook Layout` per spec 7.2, naming
    both sheets and the measured block row order.
16. Rewrite `export_topline()`'s `@returns` per spec 7.2, naming the
    `"Topline"` sheet and the `"About"` sheet.
17. Add `[export_crosstab()]` to `export_topline()`'s `@seealso`, keeping
    `surveycore::get_freqs()`.
18. Confirm neither file holds an `@section Algorithm`.
19. Confirm no `@references` tag is added. This work implements no published
    method.
20. Raise the one-line correction to spec 3.15: the closing `variance = "se"`
    sentence is superseded by the issue-66 decision, and the glossary stays at
    five terms.
21. Run `devtools::document()`.
22. Confirm `NAMESPACE` is unchanged.
23. Check `_pkgdown.yml`. This work adds no export, so confirm no section needs
    a change.
24. Extract the `\value{}` block from `man/export_crosstab.Rd` and grep it for
    `About`.
25. Extract the `\value{}` block from `man/export_topline.Rd` and grep it for
    `Topline` and for `About`.
26. Run `devtools::run_examples()`.
27. Run `pkgdown::build_site()`.
28. Run `devtools::check()`.
29. Write `changelog/docs-export-metadata.md`.

**Acceptance criteria** — observable outcomes before merge:

- [ ] `export_crosstab()` holds an `@details` route overview and a
      `@section Workbook Layout` (spec 7.1, spec 7.2, spec VIII).
- [ ] `export_topline()` holds an `@details` route overview and a
      `@section Workbook Layout` (spec 7.1, spec 7.2, spec VIII).
- [ ] `export_topline()`'s `@seealso` names `export_crosstab()` (spec 7.2,
      spec VIII).
- [ ] Neither function holds an `@section Algorithm` (spec 7.1, spec VIII).
- [ ] Every new and changed argument of spec 3.2 has a `@param` entry, and
      `layout`, `min_eff_n`, `variance`, `variance_display`,
      `sample_size_display` and `withheld_note` each list their accepted values
      (spec 7.2).
- [ ] `@param design` names four constructors in both files, including
      `surveycore::as_survey_nonprob()` (spec 7.2).
- [ ] `grep -rn "pub_type" R/ man/` returns nothing (spec VIII).
- [ ] The `\value{}` block of `man/export_crosstab.Rd` names `About`, and the
      block of `man/export_topline.Rd` names `Topline` and `About`
      (spec VIII).
- [ ] `man/export_topline.Rd` and `man/export_crosstab.Rd` are regenerated and
      tracked (spec VIII).
- [ ] The one-line correction to spec 3.15 is raised, so the glossary's
      five-term decision and its closing sentence no longer disagree
      (spec 3.15).
- [ ] `devtools::document()` leaves `NAMESPACE` and `man/` unchanged on a
      second run (test-spec profile gates).
- [ ] `devtools::run_examples()` runs clean (test-spec profile gates).
- [ ] `pkgdown::build_site()` builds (test-spec profile gates).
- [ ] `devtools::check()`: 0 errors, 0 warnings, at most 2 pre-approved notes
      (test-spec profile gates).
- [ ] `changelog/docs-export-metadata.md` exists (`github-strategy.md`, PR
      checklist).

**Scenarios owned:** none. This PR changes no behavior a test-spec scenario
describes. Its validation is the profile gates and the source-tree checks of
spec VIII.

**Files touched** — the exact write surface:

- `R/export-topline.R` — modified, roxygen only
- `R/export-crosstab.R` — modified, roxygen only
- `man/export_topline.Rd` — regenerated
- `man/export_crosstab.Rd` — regenerated
- `NAMESPACE` — regenerated; no change expected
- `_pkgdown.yml` — checked; no change expected
- `changelog/docs-export-metadata.md` — created

---

## Write surface, file by file

Every PR depends on the one before it, so no two run at the same time and no
file is shared by two concurrent PRs. The list shows which PRs touch each file
across the chain.

| File | PRs that touch it |
|---|---|
| `DESCRIPTION` | 1 |
| `plans/error-messages.md` | 1 |
| `.claude/rules/testing.md` | 1 |
| `tests/testthat/helper-test-data.R` | 1 |
| `data-raw/` — five scripts, `air` reformat only | 1 |
| `tests/testthat/test-pool-pvals.R` — `air` reformat only | 1 |
| `R/export-utils.R` | 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 18 |
| `R/export-topline.R` | 6, 7, 8, 9, 19 |
| `R/export-crosstab.R` | 5, 6, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 |
| `tests/testthat/test-export-topline.R` | 1, 6, 7, 8, 9, 15 |
| `tests/testthat/test-export-crosstab.R` | 1, 2, 3, 4, 5, 6, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18 |
| `tests/testthat/_snaps/export-topline.md` | 7, 9 |
| `tests/testthat/_snaps/export-crosstab.md` | 10, 11, 12, 13, 14, 15, 16, 17, 18 |
| `man/export_crosstab.Rd` | 11, 13, 14, 17, 18, 19 |
| `man/export_topline.Rd` | 19 |
| `NAMESPACE` | 11, 13, 14, 17, 18, 19 |
| `_pkgdown.yml` | 19 |
| `changelog/{branch-name}.md` | 1 to 19, one file each |

`man/export_crosstab.Rd` and `NAMESPACE` appear against the five PRs that
change a formal argument of `export_crosstab()`, plus `docs/export-metadata`.
Each of the five runs `devtools::document()`, so the generated file tracks the
signature at every link of the chain. `NAMESPACE` is expected to come back
unchanged each time, because this work adds no export.

---

## Scenario coverage

Each of the 178 scenario ids in `plans/test-spec-export-metadata.md` v0.16.0 is
assigned to exactly one PR.

| PR | Branch | Count | Scenario ids |
|---|---|---|---|
| 1 | `chore/export-metadata-infra` | 0 | — |
| 2 | `feature/metadata-readers` | 0 | — |
| 3 | `feature/metadata-unanimity` | 0 | — |
| 4 | `feature/metadata-guards` | 0 | — |
| 5 | `feature/format-helpers` | 0 | — |
| 6 | `feature/cover-sheet` | 15 | XA-01, XA-02, XA-03, XA-04, XA-08, XA-09, XA-10, XA-11, XA-13, TP-06, TP-06a, TP-07, TC-05, TC-06, TC-07 |
| 7 | `feature/effective-n-rewiring` | 5 | TN-01, TN-02, TN-03, TN-04, TC-08 |
| 8 | `feature/base-notes-adoption` | 10 | TP-01, TP-02, TP-03, TP-04, XM-01, XM-02, XM-03, XM-04, XM-05, XM-07 |
| 9 | `feature/topline-guards` | 17 | TP-05, TP-08, TP-09, TP-10, TP-11, TP-12, TP-13, TC-01, TC-02, TC-03, TC-04, TE-01, TE-02, TE-03, TE-04, TW-01, TW-02 |
| 10 | `feature/crosstab-guards` | 28 | XM-06, XM-08, XM-09, XM-10, XM-11, XM-12, XM-13, XM-14, XM-15, XM-16, XM-17, XE-01, XE-02, XE-03, XE-06, XE-08, XE-09, XE-10, XE-12, XE-13, XE-14, XE-15, XV-01, XV-02, XV-07, XV-08, XV-09, XX-10 |
| 11 | `feature/crosstab-min-eff-n` | 8 | XE-11, XW-01, XW-02, XW-03, XW-04, XW-05, XW-12, XW-13 |
| 12 | `feature/crosstab-banner-headings` | 10 | XH-01, XH-02, XH-03, XH-04, XH-05, XH-06, XH-07, XE-04, XE-05, XV-06 |
| 13 | `feature/crosstab-withheld-notices` | 21 | XW-06, XW-07, XW-08, XW-09, XW-10, XW-11, XV-03, XV-04, XV-05, XV-10, XV-11, XV-12, XV-13, XA-06, XA-07, XA-12, XX-02, XX-06, XX-07, XX-08, XX-09 |
| 14 | `feature/crosstab-label-cols-and-sizes` | 12 | XD-01, XS-01, XS-02, XS-03, XS-04, XS-05, XS-06, XS-07, XS-08, XS-09, XS-10, XE-07 |
| 15 | `feature/crosstab-sheet-properties` | 15 | XH-10, XB-01, XB-02, XB-03, XB-04, XN-01, XN-02, XN-03, XN-04, XN-05, XX-01, XX-03, XX-04, XX-11, XX-12 |
| 16 | `feature/crosstab-percent-cells` | 11 | XC-01, XC-02, XC-03, XC-04, XC-05, XC-05a, XC-05b, XC-06, XC-07, XC-07a, XC-08 |
| 17 | `feature/crosstab-variance-strings` | 9 | XH-15, XH-16, XH-16a, XH-17, XH-18, XH-19, XH-20, XN-09, XN-10 |
| 18 | `feature/crosstab-total-and-missing` | 17 | XH-08, XH-08a, XH-08b, XH-09, XH-09a, XH-11, XH-12, XH-13, XH-14, XX-13, XA-05, XA-05a, XR-01, XR-02, XN-06, XN-07, XN-08 |
| 19 | `docs/export-metadata` | 0 | — |
| | **Total** | **178** | |

**Check by family.** XC 11, XS 10, XW 13, XH 24, XD 1, XR 2, XB 4, XA 14,
XM 17, XE 15, XV 13, XX 12, XN 10 — 146 for `export_crosstab()`. TP 14, TC 8,
TE 4, TW 2, TN 4 — 32 for `export_topline()`. 146 plus 32 is 178. The id
`XX-05` is retired in the test-spec and is not counted.

**Six PRs own no scenario.** PRs 1 to 5 and PR 19. PR 1 changes a fixture and a
manifest, PRs 2 to 5 add helpers that no exported function calls yet, and PR 19
changes documentation prose alone. Each is verified by the profile gates, by
the direct helper tests the coverage floor forces, and by the source-tree
checks of spec VIII.

**Three criteria carry no scenario id, by design.** Two came from the review:
the topline `100%` row in `feature/crosstab-sheet-properties`, and the unused
factor level on the tabulated variable in the same PR. The third is the About
sheet's width and merged-cell rule in `feature/cover-sheet`. Each cites a spec
section instead, because the test-spec has no row for it.

---

## Ordering constraints carried from the spec

| Constraint | Where it lands |
|---|---|
| `plans/error-messages.md` is checked before any code raises a class | `chore/export-metadata-infra`, tasks 2 to 4 |
| The surveycore floor check precedes any call to `get_effective_n()` | `chore/export-metadata-infra`, tasks 5 to 8 |
| `.unanimous_across()` precedes the two resolvers that call it | `feature/metadata-readers` precedes `feature/metadata-unanimity` |
| `.resolve_roles()` precedes `.apply_role_guard()`, which reads it | `feature/metadata-unanimity` precedes `feature/metadata-guards` |
| Part A lands before Part B | PRs 6 to 9 precede PRs 10 to 18 |
| Part B's withholding reads `.resolve_eff_n()` | `feature/metadata-readers` defines it; `feature/effective-n-rewiring` wires it; `feature/crosstab-min-eff-n` reads it |
| Part B's cover sheet reads `.write_cover_sheet()` | `feature/cover-sheet` defines it; `feature/crosstab-withheld-notices` and `feature/crosstab-total-and-missing` feed it |
| `.write_crosstab_headers()` gains `label_cols`, and the battery route adopts it, before `.render_block_preamble()` is extracted | `feature/crosstab-label-cols-and-sizes`, tasks 4 to 9 precede task 25 |
| The design-variable check runs after the tidy-select resolutions and before the role guard | `feature/topline-guards`, tasks 4 and 8; `feature/crosstab-guards`, tasks 4 and 5 |
| The empty-domain check runs before the role guard | `feature/topline-guards`, task 15; `feature/crosstab-guards`, task 34 |
| Withholding runs before the workbook build | `feature/crosstab-withheld-notices`, tasks 5 and 25 |
| `min_eff_n` lands before the happy-path fixtures that need `min_eff_n = 0` | `feature/crosstab-min-eff-n` precedes PRs 12 to 18 |
| The banner label checks run on the surviving columns, after the role guard | `feature/crosstab-guards` precedes `feature/crosstab-banner-headings` |
| Each formal-argument change carries its own `devtools::document()` run | `feature/crosstab-min-eff-n`, `feature/crosstab-withheld-notices`, `feature/crosstab-label-cols-and-sizes`, `feature/crosstab-variance-strings`, `feature/crosstab-total-and-missing` |
| The final argument order is pinned once, by the last PR to touch the signature | `feature/crosstab-total-and-missing`, task 45 |

---

## Notes for the builder and the tester

**Three test edits cross a PR boundary.**

- `feature/crosstab-min-eff-n` introduces `min_eff_n` with a default of 100. On
  a 200-row design that floor withholds most subgroups, so two blocks written
  in `feature/crosstab-guards` — `XM-10` and `XM-16`, which assert that no
  warning fires — gain `min_eff_n = 0` there. Tasks 14 and 15 of
  `feature/crosstab-min-eff-n` carry the edit. No other block from that PR is
  affected, because the rest assert block presence, and withholding removes a
  column and never a block.
- `feature/crosstab-min-eff-n` also deletes section 10 of
  `tests/testthat/test-export-crosstab.R`, five blocks that pass `pub_type`.
  `export_crosstab()` takes no `...`, so those blocks raise an unused-argument
  error the moment the formal goes. The test-spec marks that template section
  N/A.
- `feature/crosstab-label-cols-and-sizes` deletes section 9, three blocks that
  pass `show_n` and `show_eff_n`, for the same reason. `XS-05` and `XS-08`
  replace their coverage in the same PR.

**One code move crosses a PR boundary.**
`feature/crosstab-withheld-notices` writes the `withheld_note = "every"` lines
at the end of each question block, from the three render routes.
`feature/crosstab-label-cols-and-sizes` moves that write into
`.render_block_footer()`, at task 27. The move cannot be avoided: spec 3.16
puts the closing sequence in the footer, and the footer cannot exist before
`label_cols` lands, while `withheld_note` cannot wait that long without
shipping half-implemented.

**One holding change crosses a PR boundary.** `.compute_eff_n()` has four call
sites, and one is inside the old `pub_type` suppression loop.
`feature/effective-n-rewiring` swaps that one call for a `.resolve_eff_n()` row
lookup and keeps the `pub_type` thresholds, so the helper can be deleted there.
`feature/crosstab-min-eff-n` rewrites the loop and retires the holding change,
at its task 19.

**One helper call sits with the `show_n` removal.** The SATA route's
`.sata_n_cell()` call writes the per-response `N` cell and is gated on
`show_n`. Spec 2.3 ties its removal to B2 — the `show_n` removal — and `XS-08`,
which `feature/crosstab-label-cols-and-sizes` owns, asserts that no heading
cell reads `N` on any block shape. So that PR removes the call, at task 19.
`feature/crosstab-percent-cells` handles `.sata_pct_cell()` alone. The helper
itself stays unchanged in both cases, because `export_topline()` still calls
it.

**One glossary entry lags.** `export_crosstab()` cells become strings in
`feature/crosstab-percent-cells`, and the `Percentages` glossary entry follows
`string_cells`, which `feature/crosstab-total-and-missing` sets. Between the
two the entry is absent while the cells are strings. `XA-05` asserts the closed
state in the later PR.

**Two message wordings are unpinned for one PR.** `TW-01` and `TE-04`, in
`feature/topline-guards`, assert a class alone. The test-spec puts the snapshot
for each on the crosstab row of the same wording — `XV-01` and `XE-12` — and
those land in `feature/crosstab-guards`. The `role_dropped` and
`design_variable_selected` texts are therefore unpinned across one PR of the
chain. That is a gap in time, not a missing test.

**Direct helper tests.** PRs 2 to 5 add helpers that no exported function calls
yet, so the coverage floor has no indirect path to them.
`.claude/rules/testing.md` names the two export test files as the cover for
`R/export-utils.R`, and `export_crosstab()` is the function that ends up
calling every one of them, so those direct tests go in
`tests/testthat/test-export-crosstab.R`.

**Snapshots.** Every committed crosstab snapshot moves across PRs 10 to 18.
That is expected. A moved `export_topline()` snapshot is not:
`feature/effective-n-rewiring` may move only the `show_eff_n` snapshots on
twophase and on a domain-restricted design, `feature/topline-guards` adds the
new topline error and warning snapshots, and every later PR may move none
(spec 5.2).
