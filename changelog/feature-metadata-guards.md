# feat(export): add the two selection guards for export-metadata

**Date**: 2026-11-11
**Branch**: feature/metadata-guards

## Changes

PR 4 of `plans/impl-export-metadata.md`. Two internal guards go into
`R/export-utils.R`. No exported function calls them yet, so no workbook
changes. They stay separate: the role guard reads `var_extra`, and the
design-variable check reads `@variables`.

- `.apply_role_guard(design, cols, arg, empty_class)` drops a column whose
  `role` is `weight`, `identifier`, `paradata` or `free_text`, with one
  `surveyreports_warning_role_dropped`. It keeps a column with an unknown or
  malformed role, with one `surveyreports_warning_unknown_role`. A column with
  no role is kept with no warning. When nothing survives it aborts with
  `empty_class`. It returns the survivors in input order.
- `.reject_design_vars(design, cols, arg)` aborts with
  `surveyreports_error_design_variable_selected` when a selected column is a
  column the design names. It reads the slots of each subclass, including the
  `phase1` and `phase2` nesting of a two-phase design. It skips slots that
  hold no column name. On a collection it checks every member.
- `.resolve_roles()` now returns `attr(, "malformed")`: the columns whose
  role is a length-2 or longer vector or a non-character value. Without it,
  the guard sees the same `NA` for an absent role and a malformed one. Spec
  2.2 records this decision. On a collection, malformed in any member counts.
- New helper `.design_members()` returns the members of a collection, or the
  one design. `.resolve_roles()`, `.resolve_base_notes()` and
  `.reject_design_vars()` call it. It replaces `.extract_unanimous()`, which
  had one caller left.

The tests are direct calls in a new section 21 of
`tests/testthat/test-export-crosstab.R`: 29 blocks, covering all four design
types and the collection cases. They assert the classes only. The plan puts
the message snapshots in `feature/topline-guards` and
`feature/crosstab-guards`. The section 20 tests of `.resolve_roles()` now
compare `c(result)`, which drops the new attribute.

## Open question for `feature/crosstab-guards`

Spec 3.17 says `unknown_role` fires once per call. The guard runs once per
argument, so `export_crosstab()` can raise it once for `vars` and once for
`banner`. Decide this before test-spec `XV-11` is written.

## Files Modified

- `R/export-utils.R` — added the two guards and `.design_members()`; added
  the malformed attribute to `.resolve_roles()`; removed `.extract_unanimous()`
- `tests/testthat/test-export-crosstab.R` — added section 21, 29 test blocks;
  adjusted section 20 for the new attribute
- `plans/spec-export-metadata.md` — recorded the malformed attribute in 2.2
- `changelog/feature-metadata-guards.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 4 complete
