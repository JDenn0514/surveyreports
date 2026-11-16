# feat(export): fall back to the universe for a base note

**Date**: 2026-11-13
**Branch**: feature/base-notes-adoption

## Changes

PR 8 of `plans/impl-export-metadata.md`. When the caller gives no base note
for a question, `export_topline()` and `export_crosstab()` now write the
universe text that surveycore holds for it, verbatim, with no `Base:`
prefix. A caller note still wins.

- Both export functions run `.validate_base_notes()` on the caller's vector
  alone, then call `.resolve_base_notes(design, base_notes)`. The resolved
  object goes to every render call: 3 in topline, 6 in crosstab.
- `.base_note_for(frame, base_notes)` reads the two-element object of spec
  3.6. A caller entry for the frame's first variable wins and is exempt from
  the unanimity rule. Otherwise the universe of every variable in the frame
  goes through `.unanimous_across()`:
  - one variable prints its own universe;
  - a SATA or battery group prints the universe only when every member has
    the same text. A member with no universe stops the note.

Reading the spec leaves open, stated in a code comment:

- `.render_topline_battery()` writes each battery item as its own table, so
  a per-item lookup would print the universe once per item. The universe is
  now judged once for the whole battery and written once under the preface.
  Each item keeps its own caller note. A caller note on the first item wins
  the block, as on the crosstab side.

## Tests

- `tests/testthat/test-export-topline.R`, new section 15: TP-01 to TP-04, and
  a test that a battery caller note wins over an agreed universe.
- `tests/testthat/test-export-crosstab.R`, new section 24: XM-01 to XM-05 and
  XM-07, and a test that a battery caller note is exempt from the unanimity
  rule.
- TP-01 and XM-01 also assert that no base note starts with `Base:`.

TP-01 failed first on all four designs. TP-02 passed on first write: the old
code never read the universe, so a caller note already won. No existing test
changed, and no snapshot moved.

The `@param base_notes` roxygen text is unchanged. `docs/export-metadata`
writes that prose.

## Files Modified

- `R/export-utils.R` — `.base_note_for()` reads the resolved object
- `R/export-topline.R` — resolves base notes; battery block note
- `R/export-crosstab.R` — resolves base notes
- `tests/testthat/test-export-topline.R` — section 15
- `tests/testthat/test-export-crosstab.R` — section 24
- `changelog/feature-base-notes-adoption.md` — new; this file
- `plans/impl-export-metadata.md` — marked PR 8 complete
