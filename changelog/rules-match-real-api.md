# docs(pipeline): rewrite the rule files against the real package API

**Date**: 2026-09-10
**Branch**: docs/rules-match-real-api

## Changes

- Replace every reference to `report_freqs()`, `report_means()`, and
  `report_totals()` — none of which exist — with the real exports
  `export_topline()`, `export_crosstab()`, and `pool_pvals()`. There were 51
  such references across five files
- Correct the return-value contract: an `export_*()` function returns
  `invisible(file_name)` and writes an `.xlsx` file. The rules had said report
  functions return a visible tibble
- Scope the `design`-first argument rule to functions that take a design.
  `pool_pvals()` takes a list of tibbles
- Replace the `group`, `ci`, and `ci_level` arguments in every example with the
  real ones: `banner`, `interactions`, `file_name`, `conf_level`, `decimals`,
  `pub_type`, `show_n`, `show_eff_n`, `base_notes`
- Point shared internal helpers at `R/export-utils.R`. There is no `R/utils.R`
- State that `survey_base` has four subclasses, nonprob included, and that
  `survey_collection` is separate and does not inherit `survey_base`
- Widen the cross-design testing rule from three design types to all four
  `survey_base` subclasses, and note that `make_all_designs()` must still gain
  a `nonprob` entry
- Correct the replicate design in the test-data docs from BRR to JK1
- Document all 19 `make_survey_data()` columns, grouped by what they test. The
  rules had listed 10
- Set the commit scopes to `export`, `pvals`, `data`, `pipeline`, `ci`, `docs`
- Add three conventions no rule covered: the openxlsx2 row-cursor pattern, the
  internal helper name families, and question-type dispatch for SATA and
  battery blocks
- Correct the DESCRIPTION template — `GPL (>= 3)`, roxygen2 8.1.0, openxlsx2,
  S7, `Depends`, `LazyData`, and `Remotes`
- Align `@family` values with the section titles in `_pkgdown.yml`
- Add the `tempfile()` pattern for runnable examples in file-writing functions,
  and flag that both export functions still use `\dontrun{}`
- Fix `surveycore::as_survey_rep()` to `surveycore::as_survey_replicate()`

## Files Modified

- `.claude/rules/testing.md` — file mapping, cross-design rule, test-data
  documentation, every example, and the section templates, all rewritten from
  the real test files
- `.claude/rules/package-conventions.md` — export policy, naming, `@family`,
  `@returns`, `@examples`, `vars` resolution, the multi-variable pattern,
  DESCRIPTION, the package-level doc, and the pre-commit checklist
- `.claude/rules/code-style.md` — return-value table, argument order, helper
  placement and name families, a Design classes section, and a new section 5 on
  writing workbooks with openxlsx2
- `.claude/rules/github-strategy.md` — commit scopes with a coverage table,
  branch and commit examples, release tag meanings, and two additions to the PR
  checklist
- `.claude/standards/function-documentation.md` — `@param design` classes, the
  `@seealso` rule, the example data table, and the illustrative examples
- `CLAUDE.md` — package purpose and the list of exported functions
