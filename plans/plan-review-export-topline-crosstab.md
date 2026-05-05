## Plan Review: export-topline-crosstab — Pass 1 (2026-05-04)

### New Issues

---

#### Section: PR 1 — Shared Utilities + Foundation

**Issue 1: `.write_suppression_footnote()` has no owning task**
Severity: BLOCKING
Violates Lens 5 — file completeness; referenced helper not assigned to any PR

PR 2's `.render_topline_single()` task (step 10) says "Calls `.write_suppression_footnote()` if suppressed is non-empty." PR 3's implementation steps do the same. But PR 1's task list for `R/export-utils.R` (tasks 4–10) never defines this helper. PR 3's notes acknowledge the gap vaguely: "if not already in `R/export-utils.R`, add it there" — which means neither PR 1 nor PR 2 is committed to writing it, and it could be missing entirely when PR 3's render helpers call it.

Options:
- **[A]** Add `.write_suppression_footnote(wb, sheet, suppressed, start_row)` to PR 1's task list as task 10.5, immediately after `.build_workbook()` — it belongs in `R/export-utils.R` since it's called by all 6 render helpers across PRs 2 and 3. Effort: low, Risk: low, Impact: removes cross-PR ownership ambiguity
- **[B]** Assign it to PR 2 and document the PR 3 dependency explicitly in PR 3's "Depends on" field. Effort: low, Risk: medium (PR 3 compile-fails if PR 2 not merged first), Impact: forces strict merge order
- **[C] Do nothing** — implementer guesses where to put it; risk of it being defined twice (once in each PR) or both PRs failing to compile

**Recommendation: A** — it's a shared utility; it belongs in the shared-utilities PR.

---

**Issue 2: Design-type validation occurs after NSE resolution — will produce wrong error class**
Severity: BLOCKING
Violates `package-conventions.md`: "Design validation — Always first — before tidy-select resolution"

PR 2 task 4 specifies this sequence inside `export_topline()`:
1. `rlang::check_installed("surveycore")`
2. `vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), design@data))`
3. `.validate_export_inputs(design, vars_resolved, ...)`

When `design` is a plain `data.frame`, step 2 (`design@data`) will throw an opaque S7 slot-access error — not `surveyreports_error_not_survey_object`. The section-8 test `expect_error(..., class = "surveyreports_error_not_survey_object")` will fail because the actual condition has a different class.

PR 3 has the same ordering problem for the non-collection-object case: the `survey_collection` check runs first (correctly), but a plain `data.frame` passes that check (returns FALSE) and then hits NSE resolution before the design-type check in `.validate_export_inputs()`.

The pattern in `package-conventions.md` explicitly shows the inline design check before `eval_select()`:

```r
if (!S7::S7_inherits(design, surveycore::survey_base)) {
  cli::cli_abort(...)
}
vars_resolved <- names(tidyselect::eval_select(...))
```

Options:
- **[A]** Add an inline design-type check in `export_topline()` (and `export_crosstab()`) before NSE resolution, following the `package-conventions.md` pattern. `.validate_export_inputs()` keeps its own design check for defensive depth. Update PR 1 task 4 to note this and update PR 2 task 4 / PR 3 task 4 to include the inline check. Effort: low, Risk: low, Impact: error-path tests pass correctly
- **[B]** Move the design-type check out of `.validate_export_inputs()` and into both function bodies before NSE resolution. Effort: low, Risk: low, Impact: same result; slightly less defensive
- **[C] Do nothing** — section-8 error-path tests fail on `not_survey_object` class; missed by TDD cycle 1

**Recommendation: A** — inline check + defensive check in validate helper; matches existing codebase pattern.

---

**Issue 3: `survey_collection` dispatch path absent from PR 1 `.build_freq_frame()` task**
Severity: BLOCKING
Violates Lens 3 — spec coverage; Lens 4 — dependency ordering

PR 1 task 9 specifies `.build_freq_frame()` in detail but never mentions the `survey_collection` iteration path (loop over `@surveys`, tag rows with `subgroup_type = "wave"`, compute pooled "Total" via `get_freqs()` on the full collection). PR 2 TDD Cycle 4 (step 22) says "Implement `survey_collection` dispatch path in `.build_freq_frame()` (already in PR 1 utils — verify it handles `survey_collection` total + wave rows)." The parenthetical implies PR 1 wrote it, but PR 1's task list never does.

If this path isn't written until PR 2 step 22, it means:
- The `survey_collection` path lives in `R/export-utils.R` (PR 1's file) but is added in PR 2 — a cross-PR file mutation that breaks the PR 1 standalone CI check
- Alternatively, the implementer writes it during PR 2 and it never lands in PR 1's commit

The spec's data flow diagram shows `.build_freq_frame()` as the single computation stage that handles both topline and crosstab, including wave columns. The wave path must exist before PR 2's section-3 tests run.

Options:
- **[A]** Add the `survey_collection` dispatch path to PR 1 task 9 explicitly: when `S7::S7_inherits(design, survey_collection)`, iterate over `design@surveys`, call `.compute_total_freq()` on the full collection for the "Total" column, call `.compute_total_freq()` on each named wave for wave columns, tag rows with `subgroup_type = "wave"` and `subgroup_label = wave_name`. Add a subtask for the "n/a" missing-variable case (see Issue 5). Effort: medium, Risk: low, Impact: clean PR boundary; PR 2 section-3 tests can run against implemented code
- **[B]** Move the `survey_collection` path to PR 2 and change PR 1's task to leave a TODO stub. Effort: low, Risk: medium (PR 1 exports a function with undefined behavior), Impact: PR 1 CI passes but export-utils.R is incomplete
- **[C] Do nothing** — PR 2 step 22 writes to a PR 1 file; PR boundaries are muddled; implementer has to decide where to commit this

**Recommendation: A** — the wave path is part of `.build_freq_frame()` and must be in PR 1 to keep PR boundaries clean.

---

#### Section: PR 2 — `export_topline()`

**Issue 4: `var_label` column added in tasks but absent from spec's long frame schema**
Severity: REQUIRED
Violates Lens 4 — spec coverage (spec-plan mismatch)

PR 1 tasks 6, 7, and 8 all say to "Attach `var_label` (variable_label fallback to var name)" and add it as a column. The spec's long frame schema table does not list `var_label` as a column — it lists `question_text` but not a separate `var_label`.

`var_label` IS needed: the SATA render helper spec says "Rows 3+: one row per SATA item (var_label as row label...)" — so the frame must carry per-item labels distinct from the overall `question_text` (preface). But without `var_label` in the schema, render helpers written by a different implementer working from the spec won't know the column name.

Options:
- **[A]** Add `var_label` to the long frame schema in the spec and clarify its semantics: for single-response vars, `var_label = question_text`; for SATA/battery, `var_label = variable_label` of each item (distinct from `question_text` which is the preface). Update PR 1 tasks to match the clarified definition. Effort: low, Risk: low, Impact: removes ambiguity for render helper implementation
- **[B]** Remove `var_label` from the tasks and instead have render helpers derive it from `question_text` using a convention. Effort: medium, Risk: medium (render logic becomes implicit), Impact: avoids schema change but moves complexity into renderers
- **[C] Do nothing** — implementer adds a `var_label` column that render helpers silently depend on; other implementers working from spec won't know it exists

**Recommendation: A** — add it to the schema; the column is real and needed.

---

**Issue 5: Wave missing-variable "n/a" cell handling not tasked anywhere**
Severity: REQUIRED
Violates Lens 4 — spec coverage

The spec states: "When a variable is missing in a wave (per `@if_missing_var`), that wave's column is represented as an empty cell with 'n/a' in the column header rather than being omitted entirely, so column positions remain stable across variables."

No task in PR 1 (`.build_freq_frame()`) or PR 2 (render helpers) addresses this behavior. The "n/a" header format and the stable-column-position requirement are non-trivial: the renderer must output a fixed column count even when some waves don't have data for a given variable.

Options:
- **[A]** Add a subtask to PR 1 task 9 (`.build_freq_frame()` wave path): "When a variable is absent in a wave, insert a placeholder row with `pct = NA`, `n = NA`, and `subgroup_label = paste0(wave_name, ' (n/a)')` so the frame has a complete column structure." Add a corresponding render subtask in PR 2 step 10 to write `"n/a"` in the header cell and leave the data cell blank when `pct` is NA. Effort: low, Risk: low, Impact: spec behavior covered
- **[B]** Add an edge case test in PR 2 section 9 for a `survey_collection` where one wave lacks a variable; rely on `@if_missing_var` to handle it transparently. Effort: low, Risk: medium (surveycore may or may not handle this the right way for rendering), Impact: defers implementation detail to surveycore behavior
- **[C] Do nothing** — behavior is undefined; column positions may shift between variables; workbook is non-navigable

**Recommendation: A** — spec is explicit; the behavior must be tasked.

---

**Issue 6: Wave column header format (n=X) not tasked anywhere**
Severity: REQUIRED
Violates Lens 4 — spec coverage

The spec states: "Wave column headers show the wave name and raw N (e.g., `'Mar 2026 (n=1,203)'`)." No task in PR 2 covers how to produce this format. The raw N would need to come from the wave-specific `get_freqs()` call (sum of `n` column or explicit extraction).

Options:
- **[A]** Add a subtask to PR 2's render step 10 (or a new step): "Format wave column headers as `paste0(wave_name, ' (n=', format(wave_n, big.mark=','), ')')` where `wave_n` is the sum of unweighted counts from that wave's frequency frame." Add a test in section 3 asserting the format is present. Effort: low, Risk: low, Impact: spec behavior covered
- **[B]** Leave format unspecified; let implementer decide. Effort: zero, Risk: medium (implementation diverges from spec), Impact: format may not match documented expectation
- **[C] Do nothing** — wave column headers are unlabeled or use only the wave name

**Recommendation: A** — the spec is explicit and the format is verifiable in tests.

---

**Issue 7: `show_eff_n` behavior for topline total rows is undefined**
Severity: REQUIRED
Violates Lens 3 — acceptance criteria must be objectively verifiable

`.compute_eff_n(design, col, level)` takes a column name and a level value to filter rows before computing the Kish design effect. For topline, there are no banner subgroups — all rows have `subgroup_type = "total"`. PR 1 task 9 says "If `show_eff_n = TRUE`, compute and attach `eff_n` column per subgroup row" — but total rows aren't subgroup rows.

This creates an ambiguity: does `show_eff_n = TRUE` in `export_topline()`:
- Produce an `eff_n` value for the entire (unfiltered) design? (What col/level are passed to `.compute_eff_n()`?)
- Produce an `eff_n` per response category of the variable? (Filter on the response value column?)
- Produce nothing (column absent) because there are no banner subgroups?

PR 2 section 6 tests "toggles produce correct column presence/absence in workbook" but cannot pass until the behavior is defined. The test would need to know what value(s) to expect.

Options:
- **[A]** Define: for topline, `show_eff_n = TRUE` computes the overall (unfiltered) Kish eff_n for the design and places it once in the workbook column header (not per row). Update `.compute_eff_n()` to accept `col = NULL, level = NULL` meaning no filtering. Document in PR 1 task 5. Effort: low, Risk: low, Impact: defined behavior + testable
- **[B]** Define: `show_eff_n = TRUE` in `export_topline()` has no effect (column absent) since suppression/subgroup context is absent. Document this explicitly. Update PR 2 task 10 render helper to skip `eff_n` column for topline. Effort: low, Risk: low, Impact: simpler but `show_eff_n` argument is misleading for topline callers
- **[C] Do nothing** — implementation is undefined; section-6 test will be written incorrectly or skipped

**Recommendation: A** — explicit behavior with an updated `.compute_eff_n()` signature; keeps the argument meaningful for topline callers.

---

**Issue 8: `withr::local_tempfile` vs `withr::local_tempdir` inconsistency across PR 2 TDD cycles**
Severity: REQUIRED
Violates testing.md: "All tests use `withr::local_tempdir()` for output paths"

PR 2 TDD Cycle 1 (task 2) says: "Use `withr::local_tempfile(fileext = ".xlsx")` for file paths." PR 2 TDD Cycle 2 (task 7) says: "Use `make_all_designs(seed = 42)` and `withr::local_tempdir()` for temp paths."

These are functionally different: `local_tempfile()` creates a single temp file path; `local_tempdir()` creates a temp directory (requiring `file.path(dir, "out.xlsx")` to get an xlsx path). If TDD Cycle 1 tests use one pattern and later cycles use the other, the test file will be inconsistent — and subsequent TDD cycles that add to the same file may fail because helpers built in Cycle 1 use a different path convention.

Options:
- **[A]** Standardize on `withr::local_tempfile(fileext = ".xlsx")` throughout PR 2 (and PR 3). It's the most direct pattern for a single output file. Update the task text in TDD Cycle 2 to match. Effort: low, Risk: low, Impact: consistent test pattern; matches testing.md note on tempfile/tempdir
- **[B]** Standardize on `withr::local_tempdir()` + `file.path(dir, "out.xlsx")`. Consistent with testing.md's explicit mention of `local_tempdir()`. Effort: low, Risk: low, Impact: same
- **[C] Do nothing** — tests work but use inconsistent patterns; maintainability cost

**Recommendation: A** — `local_tempfile(fileext = ".xlsx")` is the most direct; one line per test vs two; note testing.md lists both as acceptable.

---

**Issue 9: `survey_collection` NSE conditional not spelled out in task code**
Severity: REQUIRED
Violates Lens 5 — file completeness; spec says "use first survey's `@data` for `survey_collection` input"

PR 2 task 4 mentions "(use first survey's `@data` for `survey_collection` input)" in parentheses but doesn't give the conditional. For `survey_collection`, `design@data` does not exist as a direct slot — the data lives in `design@surveys[[1]]@data`. Without the conditional spelled out, an implementer resolving NSE will fail when `design` is a `survey_collection`.

The same conditional is needed inside `.validate_export_inputs()` (PR 1 task 4, check #3), which the plan does mention: "all names in `vars_resolved` exist in `design@data` (or first survey's `@data` for collection)." But the NSE resolution code itself needs the same guard.

Options:
- **[A]** Expand PR 2 task 4 NSE block to:
  ```r
  data_for_select <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
    design@surveys[[1]]@data
  } else {
    design@data
  }
  vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), data_for_select))
  ```
  Effort: low, Risk: low, Impact: implementer has exact code; no ambiguity
- **[B]** Leave the parenthetical and trust implementer to derive the conditional. Effort: zero, Risk: medium (implementer may use wrong accessor), Impact: potential runtime error on `survey_collection` input
- **[C] Do nothing** — NSE resolution fails on `survey_collection` designs; section-3 tests fail immediately

**Recommendation: A** — the conditional is non-obvious enough to warrant explicit code.

---

#### Section: PR 3 — `export_crosstab()`

No new issues beyond what Issues 2 and 9 already cover (same NSE ordering and conditional problems apply to PR 3 task 4).

---

#### Section: Cross-PR / General

**Issue 10: Combined coverage verification command not specified**
Severity: SUGGESTION
Lens 3 — acceptance criteria verifiability

PR 3 acceptance criterion: "Combined coverage on `R/export-utils.R` ≥98% verified." No command is specified. `covr::package_coverage()` covers the whole package; `covr::file_coverage()` covers one file. An implementer needs the exact invocation to verify this before opening the PR.

Options:
- **[A]** Add to PR 3 finalization: "Run `covr::file_coverage('R/export-utils.R', c('tests/testthat/test-export-topline.R', 'tests/testthat/test-export-crosstab.R'))` — must be ≥98%." Effort: low, Risk: low, Impact: criterion is now runnable
- **[B]** Leave vague — implementer runs `devtools::test_coverage()` or `covr::package_coverage()` and checks. Effort: zero, Risk: low (either command works), Impact: minor friction
- **[C] Do nothing** — criterion stays unverifiable

**Recommendation: A** — exact command takes 30 seconds to add; removes ambiguity.

---

**Issue 11: DESCRIPTION update not an explicit verifiable criterion in PR 1**
Severity: SUGGESTION
Lens 3 — acceptance criteria verifiability

PR 1's acceptance criteria don't include "DESCRIPTION `Imports` contains `openxlsx2 (>= 1.0.0)` and `tidyselect (>= 1.2.0)`." The criterion "devtools::check() 0 errors" would catch a missing import at check time, but only if the code actually uses the packages. A reviewer scanning the acceptance checklist wouldn't think to verify the DESCRIPTION manually.

Options:
- **[A]** Add acceptance criterion: "`DESCRIPTION` `Imports` includes `openxlsx2 (>= 1.0.0)` and `tidyselect (>= 1.2.0)`; `Suggests` includes `withr`." Effort: trivial, Risk: zero, Impact: explicit PR-review checklist item
- **[B]** Leave implicit via `devtools::check()`. Effort: zero, Risk: low, Impact: caught at check time but not at PR-review time
- **[C] Do nothing**

**Recommendation: A** — trivial addition; explicit is better than implicit.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 6 |
| SUGGESTION | 2 |

**Total issues:** 11

**Overall assessment:** The plan is structurally sound — the three-PR sequence is correct, TDD ordering is disciplined, and test section coverage is thorough. But three blocking issues will cause implementation failures before the first test runs: a missing helper (`.write_suppression_footnote()`), NSE resolution before design-type validation (wrong error class in tests), and the `survey_collection` wave path absent from PR 1. The required issues are mostly spec-to-plan coverage gaps (wave format, `var_label` schema, `show_eff_n` ambiguity) that need one decision each. Resolve all three blocking issues before starting PR 1.
