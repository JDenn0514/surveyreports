# 01: About sheet glossary text

**What to build:** The glossary on the `"About"` sheet says only what is
true of the workbook. The `Why a column is missing` entry states the minimum
as a number, so it is true at every `withheld_note` value. The `Percentages`
entry names the two cases that read `-` under the whole-column rule of gap
17. A topline workbook carries no `Confidence intervals` entry, because no
topline cell shows an interval. Three user decisions of 2026-11-19 (gaps 14,
17 and 19) change this merged text.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

**Branch:** `fix/about-glossary-text`

## Spec

Spec v0.29.0: 2.2 (`.write_cover_sheet()`), 2.3 (`.build_workbook()`),
3.14, 3.15 (the three texts changed on 2026-11-19), 4.1, 4.2, 7.2
(`export_topline()` `@param variance`).

## Scenarios

- Own: XA-05b, XW-10, XW-11, TP-06a.
- Re-check only (the rows changed in v0.24.0 to pin shipped behavior):
  XW-07, XW-08, XA-03, XA-04, XA-06.

## Acceptance criteria

- [ ] Every listed scenario passes.
- [ ] Each scenario runs on all four designs from
      `make_all_designs(seed = 42)`, labelled with the design name.
- [ ] No cell of any `"About"` sheet holds `listed above`.
- [ ] The `Percentages` dash sentence matches spec 3.15 word for word.
      A direct `.write_cover_sheet()` test with `string_cells = TRUE` asserts
      it, because no export function writes string cells yet.
- [ ] `export_topline()` no longer passes `variance` to `.build_workbook()`,
      and still passes it to `get_freqs()`.
- [ ] `export_topline()`'s `@param variance` says the value has no visible
      effect yet (spec 7.2). `devtools::document()` was run.
- [ ] No `export_topline()` snapshot moved.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes.
- [ ] `changelog/fix-about-glossary-text.md` exists.

## Notes

- Existing tests hold the old text and fail on correct code. Rewrite them:
  - the glossary text constants near the top of the About tests in
    `tests/testthat/test-export-crosstab.R` ("listed above", "never offered
    there");
  - the `TP-06a` block in `tests/testthat/test-export-topline.R`, which
    asserts the entry is present;
  - any topline glossary constant that holds the `ci` text.
- The re-check rows: read each merged block against its v0.24.0 row. Add an
  assertion only where a clause is missing. Two known gaps: `XW-07` does not
  assert `Not shown` in column A on every line, and `XA-06` does not assert
  `Not shown` beside `None`.
- `XA-05` also asserts the new texts, but it needs string cells. Ticket 05
  owns it.
- The comment above the `.build_workbook()` call in `R/export-topline.R`
  says `variance` is passed. Correct it.
- `.write_cover_sheet()` still takes no `withheld_note` argument. Do not add
  one.
