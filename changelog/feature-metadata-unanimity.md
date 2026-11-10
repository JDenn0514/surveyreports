# feat(export): add the two metadata resolvers for export-metadata

**Date**: 2026-11-10
**Branch**: feature/metadata-unanimity

## Changes

PR 3 of `plans/impl-export-metadata.md`. Two internal resolvers go into
`R/export-utils.R`. Both read every member of a `survey_collection` and call
`.unanimous_across()`. Neither aborts on a collection. No exported function
calls them yet, so no workbook changes.

- `.resolve_roles(design, cols)` returns the `role` of each column in `cols`,
  in input order. A length-1 character payload comes back as that string,
  known role or not. An absent key, a length-0 value, a length-2 value and a
  non-character value all become `NA_character_`. On a collection, a role
  that disagrees across members, or is missing in one, becomes `NA`.
  `.apply_role_guard()` reads it in `feature/metadata-guards`.
- `.resolve_base_notes(design, base_notes)` returns
  `list(caller = , universe = )`, with the two sources kept separate. It reads
  the universe itself. On a collection it applies the wave unanimity rule and
  no other. It returns `NULL` when both sources are empty.
  `.base_note_for()` reads it in `feature/base-notes-adoption`.

Three internal helpers support them:

- `.extract_unanimous(design, reader)` runs a reader on one design, or on each
  member of a collection and then `.unanimous_across()`. Both resolvers call
  it.
- `.extract_roles_single()` and `.extract_universe_single()` are the two
  single-design readers.

Two readings the spec leaves open, each stated in a code comment:

- An empty-string or `NA` universe counts as no universe and is omitted.
- A zero-length `base_notes` counts as empty and gives `caller = NULL`.

The tests are direct calls in a new section 20 of
`tests/testthat/test-export-crosstab.R`: 23 blocks, covering all four design
types and the collection cases.

## Files Modified

- `R/export-utils.R` — added the two resolvers and three supporting helpers
- `tests/testthat/test-export-crosstab.R` — added section 20, 23 test blocks
- `changelog/feature-metadata-unanimity.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 3 complete
