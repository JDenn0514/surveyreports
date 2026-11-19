# 08: Documentation prose for both export functions

**What to build:** The help pages of `export_crosstab()` and
`export_topline()` describe what the functions now do. Both meet the Tier 4
(dispatcher) documentation rule: a `@details` route overview, a
`@section Workbook Layout`, a `@returns` that names the sheets, and a
`@seealso` that links the related functions. The `@param` entries that the
earlier tickets did not touch gain the role rule, the universe fallback and
the fourth design constructor.

**Blocked by:** 01, 02, 03, 04, 05, 06 and 07 (all other tickets). The
prose describes the final behavior.

**Status:** ready-for-agent

**Branch:** `docs/export-metadata`

## Spec

Spec v0.29.0: 7.1, 7.2, 7.3, VIII (the documentation checks).

## Scenarios

None. This ticket changes no behavior that a scenario describes. The
profile gates and the source-tree checks of spec VIII verify it.

## Acceptance criteria

- [ ] Both functions hold an `@details` route overview and a
      `@section Workbook Layout`, and neither holds `@section Algorithm`.
- [ ] `export_topline()`'s `@seealso` names `export_crosstab()` and keeps
      `surveycore::get_freqs()`.
- [ ] `@param design` names four constructors in both files, including
      `surveycore::as_survey_nonprob()`.
- [ ] `layout`, `min_eff_n`, `variance`, `variance_display`,
      `sample_size_display` and `withheld_note` each list their accepted
      values.
- [ ] The `\value{}` block of `man/export_crosstab.Rd` names `About`, and
      the block of `man/export_topline.Rd` names `Topline` and `About`
      (extract each with the `sed` command of spec VIII).
- [ ] `grep -rn "pub_type" R/ man/` returns nothing.
- [ ] `_pkgdown.yml` needs no change: this work adds no export.
- [ ] `bash .claude/scripts/run-gates.sh <log-dir>` passes, with pkgdown not
      skipped.
- [ ] `changelog/docs-export-metadata.md` exists.

## Notes

- This is a Tier 3 change that edits roxygen only, so it runs no agents
  (`github-strategy.md`). Edit no R expression.
- The merged PRs and tickets 04 and 05 wrote the `@param` entries of the
  arguments they added: `min_eff_n`, `variance_display`,
  `sample_size_display`, `show_ess`, `withheld_note`, `total_label`, `na.rm`
  and `na_label`. Confirm each one. Ticket 01 rewrote `export_topline()`'s
  `@param variance`. Confirm it says the value has no visible effect yet.
- The old plan's task to raise a correction to spec 3.15 is void. The gap
  18 decision already marks the `variance = "se"` paragraph as replaced.
- Spec 7.2 names, for `export_topline()`'s `@details`, the internal names
  to read. Each one is a `grep` target; none carries a line number.
- `@examples` stay as they are. Their `\dontrun{}` conversion is parked
  (spec 1.3).
- Add no `@references`. This work implements no published method.
