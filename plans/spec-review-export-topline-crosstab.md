## Spec Review: export-topline-crosstab — Pass 1 (2026-05-04)

### New Issues

#### Section: Architecture / Data Flow

**Issue 1: `.build_workbook()` role in the data flow is unspecified**
Severity: BLOCKING
Principle: Spec must define every helper's place in the call chain before implementation begins.

`.build_workbook()` appears in the Architecture table (`R/export-utils.R`) but is absent from the Data Flow section. The data flow reads:

> `.render_topline() / .render_crosstab()` → `openxlsx2 workbook → wb_save(wb, file_name)`

Where does `.build_workbook()` fit? Does the parent function call `.build_workbook()` to initialise a workbook object and then pass it into each `.render_*()` call? Do the render helpers each create their own sheets and return them? Does `.build_workbook()` assemble everything after all render calls finish? An implementer cannot write this without guessing.

Options:
- **[A]** Add a sentence to the Data Flow section: "The parent function calls `.build_workbook()` to initialise an empty `wb` object; each render helper adds one sheet (or one table block) to `wb` via side-effect; the parent calls `wb_save()` when all variables are rendered." — Effort: low, Risk: low, Impact: resolves ambiguity, Maintenance: none
- **[B]** Describe `.build_workbook()` inline in the Rendering Details section with explicit inputs and return value. — Effort: low, Risk: low
- **[C] Do nothing** — every implementer invents the plumbing; topline and crosstab may end up with incompatible workbook initialisation patterns.

**Recommendation: [A]** — one sentence in the data flow directly resolves the confusion.

---

**Issue 2: Workbook sheet/block organisation is unspecified**
Severity: BLOCKING
Principle: Any behavior with user-visible output must be specified before code is written.

Neither the Architecture nor Rendering Details sections say how multiple variables are arranged in the workbook. Does each variable get its own worksheet? Do all variables appear in sequence on a single sheet separated by blank rows? For `layout = "stacked"` (crosstab) the spec says "all variables in one table" — but does that mean one sheet? For `layout = "per_question"` (crosstab), one sheet per variable or one sheet for all? For topline, which has no `layout` argument, is the default one sheet per variable or all on one sheet?

This directly affects:
- How `.render_*()` helpers interact with the `wb` object (add a new sheet vs. write to a row offset)
- Test assertions ("check workbook has N sheets" vs. "check row 5 column 2 on sheet 1")

Options:
- **[A]** Add a "Sheet structure" paragraph under Rendering Details: e.g., "Topline: all variables on a single worksheet named 'Topline'. Crosstab `per_question`: one worksheet per variable, named by the variable name. Crosstab `stacked`: all variables on a single worksheet named 'Crosstab'." — Effort: low, Risk: low, Impact: unblocks implementation and tests
- **[B]** One worksheet per var-type group (all singles together, all batteries together). — Effort: medium, Risk: medium
- **[C] Do nothing** — sheet structure invented at implementation time; likely wrong.

**Recommendation: [A]** — the simplest structure is the right default; add it now.

---

**Issue 3: Return value of `export_topline()` and `export_crosstab()` not specified**
Severity: BLOCKING
Principle: `@return` is required on all exported functions (package-conventions.md). Tests need to know what to assert.

The data flow ends with `wb_save(wb, file_name)` but says nothing about what the R function returns to the caller. Options are `invisible(NULL)` (like `ggsave()`), `invisible(file_name)` (like `readr::write_csv()`), or the workbook object. Without this, implementers can't write `@return` and test writers don't know what `expect_*` to use for the call itself.

Options:
- **[A]** Return `invisible(file_name)` — consistent with `readr::write_csv()`, allows piping, easy to test with `expect_equal(result, expected_path)`. — Effort: low, Risk: low
- **[B]** Return `invisible(NULL)` — consistent with `ggsave()`, simpler. — Effort: low, Risk: low
- **[C] Do nothing** — every implementer decides independently; inconsistent across topline vs. crosstab.

**Recommendation: [A]** — `invisible(file_name)` gives the caller something useful and is trivially testable.

---

**Issue 4: `pub_type` behaviour for `export_topline()` (no banner) is unspecified**
Severity: BLOCKING
Principle: Every argument's behaviour at every input state must be specified.

The suppression section describes suppression purely in terms of "banner levels" and "subgroups." `export_topline()` takes no `banner` argument. In a non-collection input, there are no subgroups — `pub_type` would be a no-op. But with a `survey_collection` input, topline produces wave columns. Are wave columns subject to suppression? The spec is silent.

If `pub_type` is a no-op for `export_topline()` with `survey_base` input, it should probably not appear in the signature — or its scope must be documented clearly.

Options:
- **[A]** Add a sentence: "For `export_topline()` with `survey_base` input, `pub_type` applies only to wave columns when `design` is a `survey_collection`; wave columns are suppressed by the same eff_n thresholds as banner columns. With a plain `survey_base` input, `pub_type` has no effect." — Effort: low, Risk: low
- **[B]** Remove `pub_type` from `export_topline()` entirely (crosstab-only argument). — Effort: low, Risk: medium (API change)
- **[C] Do nothing** — implementer guesses; suppression for topline wave columns will be implemented inconsistently.

**Recommendation: [A]** — this is the most likely intended behaviour; document it.

---

#### Section: Rendering Details

**Issue 5: Render helper structural output not described**
Severity: REQUIRED
Principle: Implementers cannot write render helpers without knowing what the rendered output looks like.

The spec names six render helpers (`.render_topline_single`, `.render_topline_sata`, `.render_topline_battery`, and three crosstab equivalents) but does not describe what the rendered output looks like structurally for each `var_type`. Key questions unaddressed:
- For `single`: is the response-category column on the left with a pct column to the right?
- For `sata`: are items stacked as rows, with one row per item?
- For `battery`: are sub-items rows, with the battery preface as a merged header above them?
- How does the battery/SATA group header row differ from the individual item rows?
- What column widths, merged cells, or spanner rows are expected?

Without this, each render helper is invented from scratch with no spec to test against.

Options:
- **[A]** Add a "Render helper output format" subsection with one table per var_type showing row structure (header row, item rows, totals row if any). Wireframe-style descriptions are sufficient — exact pixel sizes are implementation detail. — Effort: medium, Risk: low, Impact: unblocks all render implementation and workbook assertions in tests
- **[B]** Reference an external style guide or existing workbook template. — Effort: low, Risk: medium (if the reference drifts)
- **[C] Do nothing** — render helpers are invented; workbook test assertions are vague; SATA and battery formatting will be inconsistent.

**Recommendation: [A]** — even 2–3 sentences per var_type is enough to unblock implementation.

---

**Issue 6: `survey_collection` topline output layout not specified**
Severity: REQUIRED
Principle: Every combination of design type × function must have a documented output structure.

For `survey_collection` input to `export_topline()`, the spec says wave columns are "handled identically to banner columns" and "Raw N for each wave appears in the column header." But:
- Is there also a "Total" column (combined across all waves)?
- Are wave columns to the right of the total column?
- What happens when a variable is missing in some waves? (The spec defers to `@if_missing_var` on the collection, which is correct, but the rendered output for a missing wave column is unspecified — blank column? Omitted column?)

Options:
- **[A]** Add a "survey_collection topline layout" note: "Output includes a 'Total' column first (pooled across waves, if meaningful), then one wave column per named survey in `@surveys`. Missing-wave behavior follows `@if_missing_var`; absent wave columns are represented as an empty cell with 'n/a' in the header." — Effort: low, Risk: low
- **[B]** Omit Total column — waves only. — Effort: low, Risk: medium (user surprise)
- **[C] Do nothing** — layout invented at implementation; tests can't assert wave layout structure.

**Recommendation: [A]** — Total + wave columns is the expected layout; confirm it explicitly.

---

**Issue 7: `.compute_interaction_freq()` not described**
Severity: REQUIRED
Principle: Every helper in the architecture must have its computation defined.

`.compute_interaction_freq()` appears in the Architecture table and data flow but its computation is not described. The `interactions` argument is documented as "character vector of 2+ variable names; all must be in `banner`; produces one interaction spanner group per element." But how is the interaction frequency actually computed? Is it a joint cross-tabulation of all variables in the element? Is it computed via `get_freqs(design, var, group = interaction(b1, b2))`? The spec says nothing.

Options:
- **[A]** Add a sentence: "`.compute_interaction_freq()` calls `surveycore::get_freqs(design, var, group = interaction(banner_vars_in_group, sep = ' × '))` for each variable in `vars`, producing one column per unique combination of the interacted banner variables." — Effort: low, Risk: low
- **[B]** Specify the crossing logic: "Produces a cartesian product of the levels of all variables in the interaction element." — Effort: low
- **[C] Do nothing** — implementer invents; test assertions for interaction spanner groups are impossible to write correctly.

**Recommendation: [A]** — one sentence fully resolves this.

---

#### Section: Testing

**Issue 8: "Multiple variables" test category missing from both test files**
Severity: REQUIRED
Violates testing.md — category 2 (multiple variables) is mandatory for all exported functions.

Neither `test-export-topline.R` nor `test-export-crosstab.R` includes a section verifying that passing multiple variables produces output for all variables. The happy-path section 1 presumably tests one variable at a time. A distinct test block is needed that passes `vars = c(q1, q2, q3)` and asserts all three variables appear in the workbook (e.g., correct number of sheets, or all variable names present in workbook cells).

Options:
- **[A]** Add section `# 2b. Multiple variables — all vars appear in workbook` to both test files. — Effort: low, Risk: low, Impact: closes a coverage gap for a common usage pattern
- **[B]** Fold multi-variable check into the existing happy-path section 1. — Effort: low, Risk: low (but harder to locate later)
- **[C] Do nothing** — multi-variable calls may silently output only the first variable; this would go undetected.

**Recommendation: [A]** — named section is cleaner and matches the testing.md convention.

---

**Issue 9: Edge case: `vars` resolving to zero columns not addressed**
Severity: REQUIRED
Violates testing.md — Lens 4 edge cases require every argument's boundary behavior specified.

If `vars = starts_with("nonexistent_prefix")` resolves to zero columns via `tidyselect::eval_select()`, the spec is silent on the outcome. Should this error with a typed class (e.g., `surveyreports_error_var_not_found`)? Produce an empty workbook? The current error table only covers "a variable in `vars` does not exist" — the zero-columns case is structurally different (no invalid name, just an empty selection).

Options:
- **[A]** Treat as a typed error: add `surveyreports_error_vars_empty_selection` to the error table and `plans/error-messages.md`. — Effort: low, Risk: low
- **[B]** Absorb into `surveyreports_error_var_not_found` with an adapted message. — Effort: low, Risk: medium (misleading class name)
- **[C] Do nothing** — zero-selection hits undocumented code paths; likely an uninformative system error from `get_freqs()`.

**Recommendation: [A]** — a named error class gives users a clear signal.

---

**Issue 10: Edge case: single-row design missing from topline test cases**
Severity: REQUIRED
Violates testing.md — edge case section must include single-row design for every exported function.

Section 9 of `test-export-topline.R` lists only all-NA variable and single-value variable. Section 12 of `test-export-crosstab.R` correctly includes single-row data. Topline should match.

Options:
- **[A]** Add single-row data to the topline edge cases section 9. — Effort: low, Risk: low
- **[C] Do nothing** — single-row designs may crash `wb_save()` or produce degenerate output in topline that goes untested.

**Recommendation: [A]** — trivial addition.

---

**Issue 11: Edge case: empty domain not covered in either test file**
Severity: REQUIRED
Violates testing.md — empty domain is an explicit edge case category.

Neither test file mentions domain-filtered designs where the domain is empty (zero rows after filtering). This is a common real-world scenario: a domain filter that selects no respondents. Without it, `get_freqs()` may return an empty frame or `NA` estimates that cause `wb_save()` to fail silently.

Options:
- **[A]** Add to both edge case sections: "domain-filtered design with zero rows — function either returns empty workbook with warning or errors with typed class." Add the appropriate behavior to the spec and the typed error or warning to the error table. — Effort: low, Risk: low
- **[C] Do nothing** — empty-domain surveys fail at runtime with uninformative errors.

**Recommendation: [A]** — must decide: error or empty workbook + warning.

---

**Issue 12: `.compute_eff_n()` inputs and outputs not documented**
Severity: REQUIRED
Principle: Every internal helper in the architecture table must have defined inputs/outputs (Lens 5).

`.compute_eff_n()` appears in the architecture and suppression sections ("runs once per banner level") but has no documented signature. What are its inputs — `design` + a character column name + a level value? What does it return — a scalar `dbl`? A tibble with `eff_n` and `raw_n` columns? This is needed both for implementation and for the suppression logic tests.

Options:
- **[A]** Add a "Helper Signatures" subsection (or inline note): "`.compute_eff_n(design, col, level)` → scalar `dbl`. Filters `design@data` to rows where `col == level`, computes Kish DEFF = n × Σwi² / (Σwi)², returns eff_n = n / DEFF." — Effort: low, Risk: low
- **[B]** Document via roxygen `@keywords internal` comment in the implementation — not in the spec. — Effort: low, Risk: medium (the spec review can't verify correctness without it)
- **[C] Do nothing** — suppression logic is correct only if eff_n is computed consistently; implementers may diverge.

**Recommendation: [A]** — pin the formula in the spec so suppression thresholds are deterministic.

---

**Issue 13: Banner variable with a single level is unaddressed**
Severity: REQUIRED
Violates Lens 4 — group argument boundary behavior must be specified.

If a banner variable has only one unique level (e.g., `region` in a single-region dataset), the crosstab produces a single subgroup column. This is degenerate — the "subgroup" is identical to the total. The spec doesn't say whether to warn, suppress, or allow it.

Options:
- **[A]** Allow silently — single-level banner is valid, just uninformative. Document in the spec. — Effort: low, Risk: low
- **[B]** Emit a warning (`surveyreports_warning_single_level_banner`). — Effort: low, Risk: low
- **[C] Do nothing** — unexpected: users may not notice degenerate output; tests will not cover this scenario.

**Recommendation: [A]** — allow silently and document. Add an edge case test.

---

#### Section: Error and Warning Classes

**Issue 14: Eight new error classes and two warning classes not yet added to `plans/error-messages.md`**
Severity: REQUIRED
Violates package-conventions.md: "When adding a new error/warning: 1. Add a row to plans/error-messages.md first."

The spec says updating `plans/error-messages.md` is part of implementation ("Updated files: plans/error-messages.md — Add 8 error rows and 2 warning rows"). But per the rule, the error table must be updated _before_ writing any code. This is a pre-implementation gate, not an implementation task.

Options:
- **[A]** Update `plans/error-messages.md` as part of resolving Stage 4 issues, before handing off to `/implementation-workflow`. — Effort: low, Risk: low
- **[C] Do nothing** — error classes used in code won't have canonical entries; violates the stated rule.

**Recommendation: [A]** — low effort, must be done before coding starts.

---

#### Section: Architecture (DRY)

**Issue 15: Five shared validation checks not identified as a shared helper**
Severity: REQUIRED
Violates CLAUDE.md — DRY principle: "Repeated validation → consolidate."

Five of the eight errors are shared between both functions (`not_survey_object`, `var_not_found`, `invalid_file_name`, `invalid_conf_level`, `invalid_decimals`). The spec doesn't name a shared validation helper for these. Without one, both function bodies will contain duplicated validation logic. Per the helper placement rule in code-style.md: helpers used in 2+ files live in `R/utils.R` (or, by the export-domain extension, in `R/export-utils.R`).

Options:
- **[A]** Add `.validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)` to `R/export-utils.R`. Document it in the Architecture table. Both `export_topline()` and `export_crosstab()` call it as their first validation step. — Effort: low, Risk: low, Impact: eliminates ~15 lines of duplicated validation per function, Maintenance: single location for all shared export errors
- **[B]** Call each check inline in both functions (current implicit approach). — Effort: zero, Risk: medium (divergence over time)
- **[C] Do nothing** — validation logic duplicated; error messages can diverge between functions.

**Recommendation: [A]** — explicit in spec and required by the DRY rule.

---

#### Section: Testing (DRY)

**Issue 16: Test files don't reference `make_all_designs()` for standard design coverage**
Severity: REQUIRED
Violates testing.md: "Does each test block use `make_all_designs(seed = N)` rather than inline design construction for standard cases?"

The spec says "All tests use `withr::local_tempdir()` for output paths" and section 1 in both test files says "file created for all 3 design types" — but the spec doesn't explicitly say tests use `make_all_designs(seed = N)`. Without this call-out, test authors may construct inline designs that diverge from the standard test data, making it harder to catch cross-design regressions.

Options:
- **[A]** Add a note to the Testing section: "Cross-design tests use `make_all_designs(seed = N)` (from `helper-test-data.R`) for all three design types." — Effort: low, Risk: low
- **[C] Do nothing** — tests may use ad hoc designs; cross-design consistency is harder to audit.

**Recommendation: [A]** — one sentence.

---

#### Section: Suppression

**Issue 17: All-subgroups-suppressed behaviour not specified**
Severity: SUGGESTION
Principle: Boundary behavior of the suppression system must be defined.

If `pub_type = "external"` causes all banner levels of a variable to be suppressed, the output for that variable has no subgroup columns — only the total. The spec says "suppressed subgroups are dropped entirely" and a footnote is added. But if all subgroups are dropped, does the variable still appear in the workbook (totals only + footnote)? Or is the variable silently omitted? The spec's suppressed-tibble mechanism implies the variable's total rows are kept, but this is implicit.

Options:
- **[A]** Add a sentence: "If all subgroups for a variable are suppressed, the variable appears in the workbook with totals only and a footnote listing all dropped subgroups." — Effort: low, Risk: low
- **[C] Do nothing** — likely correct by inference, but untestable without an explicit statement.

**Recommendation: [A]** — one sentence removes all ambiguity.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 12 |
| SUGGESTION | 1 |

**Total issues:** 17

**Overall assessment:** The data architecture, long frame schema, and suppression logic are solid, but the spec has four blocking gaps (workbook organisation, `.build_workbook()` placement, return value, and `pub_type` scope for topline) that would force every implementer to make architectural guesses. Twelve required issues cover missing test categories, undocumented helper signatures, unspecified edge cases, and the pre-implementation gate of updating `plans/error-messages.md`. None of these are hard to resolve — most are one-sentence additions. Resolve in Stage 4 before handing off.

---

## Spec Review: export-topline-crosstab — Pass 2 (2026-05-04)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `.build_workbook()` role in data flow unspecified | ✅ Resolved |
| 2 | Workbook sheet/block organisation unspecified | ✅ Resolved |
| 3 | Return value of both functions not specified | ✅ Resolved |
| 4 | `pub_type` behaviour for `export_topline()` unspecified | ✅ Resolved |
| 5 | Render helper structural output not described | ✅ Resolved |
| 6 | `survey_collection` topline output layout not specified | ✅ Resolved |
| 7 | `.compute_interaction_freq()` not described | ✅ Resolved |
| 8 | "Multiple variables" test category missing from both test files | ✅ Resolved |
| 9 | `vars` resolving to zero columns not addressed | ✅ Resolved |
| 10 | Single-row design missing from topline edge cases | ✅ Resolved |
| 11 | Empty domain not covered in either test file | ✅ Resolved |
| 12 | `.compute_eff_n()` inputs and outputs not documented | ✅ Resolved |
| 13 | Banner variable with a single level unaddressed | ✅ Resolved |
| 14 | Error classes not yet added to `plans/error-messages.md` | ✅ Resolved |
| 15 | Shared validation checks not identified as a shared helper | ✅ Resolved |
| 16 | Test files don't reference `make_all_designs()` | ✅ Resolved |
| 17 | All-subgroups-suppressed behaviour not specified | ✅ Resolved |

All 17 Pass 1 issues are resolved. `plans/error-messages.md` confirmed updated with 10 new error rows and 2 warning rows.

### New Issues

#### Section: Function Signatures / Data Flow

**Issue 1: `export_crosstab()` with `survey_collection` input is unspecified**
Severity: BLOCKING
Principle: Every valid input combination must have a documented output structure.

`.validate_export_inputs()` accepts `survey_collection` for *both* `export_topline()` and `export_crosstab()`. But the `survey_collection` handling section describes only a wave-column layout (Total + one wave column per `@surveys` entry). For `export_crosstab()`, a `survey_collection` input arrives with a `banner` argument too. The spec is silent on how these interact:

- Does `export_crosstab()` show banner columns nested within each wave? (One spanner group per wave, with banner columns inside it?)
- Does it show wave columns nested within each banner group?
- Are they shown separately (banner crosstab ignores wave structure; wave layout ignores banner)?
- Or is `survey_collection` simply not valid input for `export_crosstab()` — in which case `.validate_export_inputs()` should reject it with a typed error?

An implementer must guess the output structure. Any test they write will encode their guess.

Options:
- **[A]** Document the interaction: `survey_collection` in `export_crosstab()` is not supported; add `surveyreports_error_collection_not_supported_for_crosstab` and validate it in the function body before calling `.validate_export_inputs()`. — Effort: low, Risk: low, Impact: honest API boundary with a clear error
- **[B]** Support it with a defined layout: wave spanner groups first, banner subgroups within each wave. — Effort: high, Risk: high (complex rendering), Maintenance: significant
- **[C]** Support it with a defined layout: banner spanner groups first, wave comparison within each banner. — Effort: high, Risk: high
- **[D] Do nothing** — implementer invents an undocumented layout; tests cannot assert correct structure; the behavior diverges from user expectations silently.

**Recommendation: [A]** — `survey_collection` crosstabs are a distinct complex feature not implied by the current spec scope. Reject it explicitly with a typed error and document. This is the "right-sized to current spec" answer per the engineering principles.

---

**Issue 2: Design type check syntax for two accepted types not specified**
Severity: REQUIRED
Violates code-style.md — "Always use `S7::S7_inherits(x, ClassName)` with the class object — never a string."

`.validate_export_inputs()` checks that `design` is `survey_base` or `survey_collection`. Code-style.md mandates `S7::S7_inherits()` for class membership tests. But whether `survey_collection` inherits from `survey_base` in surveycore is not stated in the spec. If it does not, a single `S7::S7_inherits(design, surveycore::survey_base)` check would incorrectly reject valid `survey_collection` input — a silent runtime error on a real use case.

The spec needs to either:
(a) State that `survey_collection` inherits from `survey_base` (so a single check suffices), or
(b) Specify the compound check: `S7::S7_inherits(design, surveycore::survey_base) || S7::S7_inherits(design, surveycore::survey_collection)`.

Options:
- **[A]** Add a note to the `.validate_export_inputs()` helper spec: "Checks `S7::S7_inherits(design, surveycore::survey_base) || S7::S7_inherits(design, surveycore::survey_collection)`. (Note: if Issue 1 is resolved via Option A, remove `survey_collection` from the valid-types check entirely.)" — Effort: low, Risk: low
- **[B]** Confirm in the spec that `survey_collection <: survey_base` in surveycore, so the single-class check works. — Effort: low (requires one lookup), Risk: low
- **[C] Do nothing** — implementer makes a wrong assumption about the class hierarchy; `export_topline()` silently rejects `survey_collection` inputs at runtime.

**Recommendation: [A]** if Issue 1 resolved as Option A; **[B]** if `survey_collection` is kept as valid input.

---

**Issue 3: `pct` column scale not stated in the long frame schema**
Severity: REQUIRED
Principle: Every output column's type and value contract must be specified (Lens 3 — Contract Completeness).

The long frame schema says `pct` is "Weighted proportion (from `get_freqs()`)." It does not say whether `pct` is on the `[0, 1]` scale or the `[0, 100]` scale. This matters directly for rendering:

- If `pct = 0.312` (proportion scale), the renderer multiplies by 100 and rounds to `decimals` places → `"31.2%"`.
- If `pct = 31.2` (percentage scale), the renderer rounds directly → `"31.2%"`.

The wrong assumption produces off-by-100 display errors that are hard to catch in workbook assertions (a test checking that a cell contains `"31.2%"` could pass for either convention if the renderer is consistent internally).

Options:
- **[A]** Add "(scale: `[0, 1]`)" to the `pct` column description and add a note to the rendering section: "The renderer multiplies `pct` by 100 before applying `decimals` rounding." — Effort: low, Risk: low
- **[B]** Store `pct` on the `[0, 100]` scale and document that. — Effort: low, Risk: medium (inconsistent with how surveycore and most R survey packages report proportions)
- **[C] Do nothing** — implementers assume whatever convention they know; topline and crosstab renderers may encode different assumptions; percentages in the workbook are wrong for one or both.

**Recommendation: [A]** — `[0, 1]` is the convention in surveycore and R generally; make it explicit.

---

**Issue 4: Battery/SATA variable batching loop structure not described**
Severity: REQUIRED
Principle: The main function body must be specifiable from the spec alone (Lens 5 — Engineering Level).

The spec says `classify_question_type()` output "drives how variables with the same `group_id` are batched together into one table block." But the algorithm for that batching is not described. The main function calls `.build_freq_frame()` on all vars together, then must render them. For a single-response variable the dispatch is trivial: one call to `.render_*_single(var, ...)`. For a battery with `group_id = 2` containing `[q5a, q5b, q5c]`, the dispatch is not specified:

- Does the main function loop over `unique(group_id)` in the classify output, collect all vars with that group_id, and pass the group to `.render_*_battery(group_vars, ...)`?
- Is there a helper (e.g., `.split_vars_by_group()`) that returns a named list for the render loop?
- Does `.render_*_battery()` take a character vector of var names, or a subset of the long frame?

Without this, an implementer cannot write the render dispatch portion of `export_topline()` or `export_crosstab()` correctly for non-single question types.

Options:
- **[A]** Add a "Render dispatch" subsection under Data Flow or Rendering Details: "After building the long frame, the parent function splits the classify output into groups by `group_id` (treating each `NA` group_id as its own singleton group). It iterates over groups in the order they appear in `vars_resolved`, calling `.render_*_single()` for singletons and `.render_*_battery()` / `.render_*_sata()` for multi-item groups. The long frame is filtered to the variables in each group before passing." — Effort: low, Risk: low, Impact: fully specifies the render loop
- **[B]** Add a `.dispatch_render(classify_out, long_frame, wb, ...)` helper to the architecture, with its iteration logic fully described. — Effort: low, Risk: low (cleaner separation)
- **[C] Do nothing** — render dispatch invented at implementation time; SATA and battery blocks may render incorrectly or skip variables.

**Recommendation: [A]** — a short paragraph resolves the ambiguity without adding a new helper. If Option B appeals, add it to the architecture table.

---

#### Section: Testing

**Issue 5: Error class counts in test section headers are stale**
Severity: REQUIRED
Principle: Test plan must enumerate every error class it covers (testing.md — Lens 2, category 5).

Stage 4 added two error classes (`surveyreports_error_vars_empty_selection` and `surveyreports_error_empty_domain`) to both functions. The test section headers were not updated:

- `test-export-topline.R` section 8: "Error paths — **all 5 error classes**" — should be **7** (not_survey_object, var_not_found, vars_empty_selection, empty_domain, invalid_file_name, invalid_conf_level, invalid_decimals).
- `test-export-crosstab.R` section 12: "Error paths — **all 8 error classes**" — should be **10** (7 shared + banner_not_found, interaction_not_in_banner, interactions_not_list).

Stale counts cause test authors to stop at 5 or 8 and believe they have complete coverage. `vars_empty_selection` and `empty_domain` — two of the errors most likely to be encountered by real users — are at risk of being skipped.

Options:
- **[A]** Update both section headers with correct counts and list the class names explicitly. — Effort: low, Risk: low
- **[C] Do nothing** — test authors write 5 or 8 tests and believe the suite is complete; two error paths go untested.

**Recommendation: [A]** — trivial fix; list the class names so the reader can verify coverage without counting the error table.

---

#### Section: Rendering Details

**Issue 6: Self-banner drop — pipeline stage not specified**
Severity: SUGGESTION
Principle: Behavioral specs should be precise enough to inform one implementation path.

The spec says: "For the row where `variable == banner_var`, that banner column is silently dropped per variable." Three plausible pipeline stages for this drop:

1. In `.build_freq_frame()` — skip calling `.compute_subgroup_freq(var, banner_var)` when `var == banner_var`.
2. In the long frame post-processing — filter out rows where `variable == subgroup_var`.
3. In the render helper — skip rendering that column for that variable's block.

Option 1 is most efficient (avoids a degenerate `get_freqs()` call). Options 2 and 3 require `.build_freq_frame()` to still compute the degenerate result. Without specifying which, two implementers will choose different stages; the behavior is identical externally but the test for "self-banner is dropped" cannot assert the right internal mechanism.

Options:
- **[A]** Add one sentence: "The drop is applied in `.build_freq_frame()`: `.compute_subgroup_freq(var, banner_var)` is not called when `var == banner_var`." — Effort: low, Risk: low
- **[C] Do nothing** — behavior is correct regardless; test assertions only check external output, not internal mechanism.

**Recommendation: [A]** — one sentence; makes the test for "no extra `get_freqs()` call for self-banner" possible if desired.

---

**Issue 7: Variable block ordering in workbook not stated**
Severity: SUGGESTION
Principle: Deterministic output ordering must be documented (Lens 6 — API Coherence).

The spec specifies sheet structure (one sheet per variable for `per_question`, one sheet for `stacked`) but not the order of variable blocks within a sheet or the order of sheets in the workbook. Analysts who pass `vars = c(q1, q2, q3)` will expect the workbook to reflect that order. If the implementation sorts by variable name, `q10` appears between `q1` and `q2`, which surprises users.

Options:
- **[A]** Add one sentence to the Sheet Structure section: "Variable blocks are written in the order of `vars_resolved` (the order variables appear in the `vars` argument after tidyselect resolution). Sheet order in `per_question` layout follows the same order." — Effort: low, Risk: low
- **[C] Do nothing** — likely correct by convention; test assertions that check sheet order will pin whichever order the implementer chose.

**Recommendation: [A]** — one sentence; prevents a surprising sort at implementation time.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 7

**Overall assessment:** The spec is substantially improved from Pass 1 — all 17 prior issues are resolved and the structural additions (sheet layout, render formats, helper signatures, suppression details) are solid. One blocking issue remains: `export_crosstab()` with `survey_collection` input is accepted by `.validate_export_inputs()` but the output structure is entirely unspecified. The recommended resolution (reject with a typed error) is a one-line addition. The four required issues are all low-effort fixes — stale counts, an underspecified type check, a missing `pct` scale declaration, and the absent render dispatch algorithm. Resolve in Stage 4 before handing off to `/implementation-workflow`.
