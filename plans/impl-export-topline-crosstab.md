# Implementation Plan: `export_topline()` and `export_crosstab()`

**Date:** 2026-05-04
**Spec:** `plans/2026-05-04-export-topline-crosstab-design.md` (v1.2)
**Decisions log:** `plans/decisions-export-topline-crosstab.md`
**Error registry:** `plans/error-messages.md` (already updated with all 10 errors + 2 warnings)
**Branch base:** `develop`
**Id:** `export-topline-crosstab`
**Supersedes:** `plans/2026-05-04-export-topline-implementation.md` (pre-finalization draft — wrong `pub_type` sig, wrong return value, topline only)

## Overview

This plan delivers `export_topline()` and `export_crosstab()`, two publication-quality
frequency export functions that produce styled `.xlsx` workbooks from survey design
objects using `openxlsx2`. Shared computation, validation, and workbook helpers live in
`R/export-utils.R` and ship first along with test data infrastructure; the two public
functions ship in separate PRs. Three question types (single, SATA, battery) are
auto-detected via `surveycore::classify_question_type()`. `export_topline()` supports
`survey_collection` wave columns; `export_crosstab()` rejects `survey_collection` with a
typed error.

## PR Map

- [x] PR 1: `feature/export-utils` — Shared utilities, test data helper, DESCRIPTION updates
- [x] PR 2: `feature/export-topline` — `export_topline()`, render helpers, and full test suite
- [x] PR 3: `feature/export-crosstab` — `export_crosstab()`, render helpers, and full test suite

---

### PR 1: Shared Utilities + Foundation

**Branch:** `feature/export-utils`
**Depends on:** none

**Files:**
- `DESCRIPTION` — add `openxlsx2 (>= 1.0.0)` and `tidyselect (>= 1.2.0)` to `Imports`; add `withr` to `Suggests` if absent
- `tests/testthat/helper-test-data.R` — replace stub with full `make_survey_data()` + `make_all_designs()` including SATA/battery vars
- `R/export-utils.R` — all internal shared helpers

**Notes:**
- All helpers in `R/export-utils.R` are internal; their tests ship in PRs 2 and 3 (covered via public API). No standalone test file in this PR.
- `devtools::check()` must pass 0 errors, 0 warnings before merging, even without standalone tests for the new R file.
- Coverage for `R/export-utils.R` accumulates across PRs 2 and 3; 98% target is verified at end of PR 3.

**Tasks:**

1. Create branch: `git checkout -b feature/export-utils develop`

2. **Update `DESCRIPTION`** — add to `Imports`:
   `openxlsx2 (>= 1.0.0)`, `tidyselect (>= 1.2.0)`
   — add to `Suggests` if absent: `withr`

3. **Replace `tests/testthat/helper-test-data.R`** with two functions:
   - `make_survey_data(n, n_psu, n_strata, seed)` — returns a plain `data.frame` with columns:
     `psu`, `strata`, `fpc`, `wt` (design vars),
     `y1`, `y2`, `y3` (continuous),
     `q1` (3 levels: "Agree"/"Neutral"/"Disagree"), `q2` (2 levels: "Yes"/"No"),
     `group` (3 levels: "A"/"B"/"C"),
     `sata_a`, `sata_b`, `sata_c` (integer 0/1),
     `bat_1`, `bat_2`, `bat_3` (integer 1–5),
     `in_phase2` (logical),
     `all_na_var` (NA_character_)
   - `make_all_designs(seed)` — calls `skip_if_not_installed("surveycore")`;
     builds `taylor` (`as_survey()`), `replicate` (`as_survey_replicate()` with JK1 weights),
     and `twophase` (`as_survey_twophase()`); calls `surveycore::set_sata()` on
     sata vars and `surveycore::set_question_preface()` on sata + battery vars for
     all three designs; returns named list `list(taylor = ..., replicate = ..., twophase = ...)`

4. **Create `R/export-utils.R`** — write `.validate_export_inputs()`:
   - Signature: `.validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)`
   - Note: this helper includes a defensive design-type check (check #1 below), but callers (`export_topline()`, `export_crosstab()`) MUST also perform an inline design-type check before NSE resolution so that a plain `data.frame` raises `surveyreports_error_not_survey_object` rather than an opaque S7 slot-access error
   - Check order (per spec "Helper signatures"):
     1. `!(S7::S7_inherits(design, surveycore::survey_base) || S7::S7_inherits(design, surveycore::survey_collection))` → `surveyreports_error_not_survey_object`
     2. `length(vars_resolved) == 0L` → `surveyreports_error_vars_empty_selection`
     3. All names in `vars_resolved` exist in `design@data` (or first survey's `@data` for collection) → `surveyreports_error_var_not_found`
     4. Domain row count == 0 → `surveyreports_error_empty_domain`
     5. `file_name` ends in `.xlsx` → `surveyreports_error_invalid_file_name`
     6. `conf_level` in `(0, 1)` → `surveyreports_error_invalid_conf_level`
     7. `decimals` is a positive integer scalar → `surveyreports_error_invalid_decimals`
   - Returns `invisible(TRUE)` on success

5. **Write `.compute_eff_n(design, col = NULL, level = NULL)`** in `export-utils.R`:
   - If `col` is non-NULL: filter `design@data` to rows where `design@data[[col]] == level` before computing DEFF
   - If `col` is NULL (topline use case): use all rows of `design@data` unfiltered
   - Compute Kish DEFF: `n × Σwi² / (Σwi)²` (wi = weight values from `design@variables$weights`)
   - Return `eff_n = n / DEFF` as scalar `dbl`
   - Topline use: `show_eff_n = TRUE` → call `.compute_eff_n(design)` (no `col`/`level`) and place result once in the "%" column header cell (e.g., as a second line: `"% (Eff N=XXX)"`); not placed per row

6. **Write `.compute_total_freq(design, var, ...)`** in `export-utils.R`:
   - Call `surveycore::get_freqs(design, !!rlang::sym(var), ...)`
   - Tag result with `subgroup_type = "total"`, `subgroup_var = NA_character_`, `subgroup_value = NA_character_`
   - Attach `question_text` from `surveycore::meta(result)` (variable_label or question_preface; fallback to var name)
   - Attach `var_label` (variable_label fallback to var name)
   - Add `variable`, `var_type`, `group_id`, `subgroup_label = "Total"` columns
   - Return tagged tibble

7. **Write `.compute_subgroup_freq(design, var, banner_var, ...)`** in `export-utils.R`:
   - Call `surveycore::get_freqs(design, !!sym(var), group = !!sym(banner_var), ...)`
   - Tag with `subgroup_type = "banner"`, `subgroup_var = banner_var`
   - Add `variable`, `var_type`, `group_id`, `question_text`, `var_label` columns
   - Return tagged tibble

8. **Write `.compute_interaction_freq(design, var, banner_vars, ...)`** in `export-utils.R`:
   - Call `surveycore::get_freqs(design, !!sym(var), group = interaction(!!!rlang::syms(banner_vars), sep = " × "), ...)`
   - Tag with `subgroup_type = "interaction"`, `subgroup_var = paste(banner_vars, collapse = " × ")`
   - Add standard columns; return tagged tibble

9. **Write `.build_freq_frame(design, vars_resolved, classify_out, banner_resolved = NULL, interactions = NULL, variance = NULL, conf_level = 0.95, show_eff_n = FALSE, pub_type = "none")`** in `export-utils.R`:
   - **`survey_collection` dispatch path** (when `S7::S7_inherits(design, surveycore::survey_collection)`):
     - Compute pooled "Total" column: call `.compute_total_freq()` on the full collection object for each var in `vars_resolved`; tag rows with `subgroup_type = "total"`, `subgroup_label = "Total"`
     - Compute per-wave columns: iterate over `names(design@surveys)`; for each wave name call `.compute_total_freq()` on `design@surveys[[wave_name]]`; tag rows with `subgroup_type = "wave"`, `subgroup_label = wave_name`
     - Missing-variable handling: if a var is absent in a wave's data (`!var %in% names(design@surveys[[wave_name]]@data)`), insert a placeholder row with `pct = NA`, `n = NA`, `subgroup_label = paste0(wave_name, " (n/a)")` — stable column positions required even when data is absent
     - No suppression for `survey_collection` (no banner); `banner_resolved` is ignored
     - Skip straight to `dplyr::bind_rows()` after wave rows are built
   - **Standard path** (all other design types):
     - Suppression: if `pub_type != "none"` and `banner_resolved` is non-NULL, call `.compute_eff_n()` once per banner level; apply F.4a/b/c thresholds from spec; collect suppressed levels into `suppressed` tibble (columns: `subgroup_var`, `subgroup_value`, `eff_n`, `raw_n`, `threshold`, `pub_type`); emit `surveyreports_warning_subgroup_suppressed` if any rows
     - Frame building: `lapply(vars_resolved, ...)` calling `.compute_total_freq()` for each var; skip `.compute_subgroup_freq(var, banner_var)` when `var == banner_var` (self-banner drop); call `.compute_subgroup_freq()` for each non-suppressed banner level; call `.compute_interaction_freq()` for each interaction group element
   - If `show_eff_n = TRUE`, compute and attach `eff_n` column per subgroup row (for both paths)
   - `dplyr::bind_rows()` all results into long frame
   - Emit `surveyreports_warning_missing_variable_label` if any `question_text` derived from variable name fallback (list all affected vars in single warning)
   - Returns `list(frame = <tibble>, suppressed = <tibble>)`

10. **Write `.build_workbook()`** in `export-utils.R`:
    - Calls `openxlsx2::wb_workbook()`; returns `wb` object

10.5. **Write `.write_suppression_footnote(wb, sheet, suppressed, start_row)`** in `export-utils.R`:
    - Takes the `suppressed` tibble from `.build_freq_frame()` result (columns: `subgroup_var`, `subgroup_value`, `eff_n`, `raw_n`, `threshold`, `pub_type`)
    - Writes a footnote block below the table starting at `start_row`; one line per suppressed level: `"* [subgroup_var]: [subgroup_value] suppressed (n=[raw_n], threshold=[threshold])"`
    - Returns `wb` invisibly
    - This helper is called by all 6 render helpers across PRs 2 and 3; it must be defined here before any render helper needs it

11. Run `devtools::document()` — confirm no roxygen errors

12. Run `devtools::check()` — must be 0 errors, 0 warnings, ≤2 pre-approved notes

13. Commit: `feat(export): add shared export utilities, openxlsx2 dependency, and test data helpers`

14. Push and open PR against `develop`

**Acceptance criteria:**
- [x] `DESCRIPTION` `Imports` includes `openxlsx2 (>= 1.0.0)` and `tidyselect (>= 1.2.0)`; `Suggests` includes `withr`
- [x] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [x] `devtools::document()` run; NAMESPACE and man/ in sync
- [x] `make_all_designs()` creates all three design types and applies SATA/battery metadata
- [x] All error class names in `.validate_export_inputs()` match `plans/error-messages.md` exactly

---

### PR 2: `export_topline()`

**Branch:** `feature/export-topline`
**Depends on:** PR 1 merged into `develop`

**Files (TDD order — tests first):**
- `tests/testthat/test-export-topline.R` — 10 sections
- `R/export-topline.R` — `export_topline()`, `.render_topline_single()`, `.render_topline_sata()`, `.render_topline_battery()`

**Key spec constraints to track:**
- No `pub_type` argument — `export_topline()` has 8 arguments, none is `pub_type`
- Returns `invisible(file_name)` (not `invisible(NULL)`)
- `survey_collection` input is valid; produces wave columns; no suppression
- 7 error classes: `not_survey_object`, `var_not_found`, `vars_empty_selection`, `empty_domain`, `invalid_file_name`, `invalid_conf_level`, `invalid_decimals`
- All output on a single sheet named `"Topline"`
- `pct` scale is `[0, 1]`; renderer multiplies by 100 before displaying

**Tasks:**

**TDD Cycle 1 — Error paths (section 8)**

1. Create branch: `git checkout -b feature/export-topline develop`

2. Create `tests/testthat/test-export-topline.R` with section 8 — all 7 error-path test blocks, dual pattern:
   ```
   expect_error(..., class = "surveyreports_error_{class}")
   expect_snapshot(error = TRUE, ...)
   ```
   Classes: `not_survey_object`, `var_not_found`, `vars_empty_selection`, `empty_domain`,
   `invalid_file_name`, `invalid_conf_level`, `invalid_decimals`
   Use `withr::local_tempfile(fileext = ".xlsx")` for file paths; `make_all_designs(seed = 42)` for valid designs

3. Run `devtools::test(filter = "export-topline")` — confirm all 7 blocks fail red ("could not find function `export_topline`")

4. Create `R/export-topline.R`; write `export_topline()` with:
   - Full roxygen (`@param` for all 8 args, `@return invisible(file_name)`, `@examples`, `@family "frequency functions"`, `@seealso`, `@export`)
   - `rlang::check_installed("surveycore")`
   - **Inline design-type check BEFORE NSE resolution** (per `package-conventions.md`):
     ```r
     if (!(S7::S7_inherits(design, surveycore::survey_base) ||
             S7::S7_inherits(design, surveycore::survey_collection))) {
       cli::cli_abort(
         c("x" = "{.arg design} must be a survey design object.",
           "i" = "Got class {.cls {class(design)}}.",
           "v" = "Use {.fn surveycore::as_survey} to create a design object."),
         class = "surveyreports_error_not_survey_object"
       )
     }
     ```
   - NSE resolution (after the design check):
     ```r
     data_for_select <- if (S7::S7_inherits(design, surveycore::survey_collection)) {
       design@surveys[[1]]@data
     } else {
       design@data
     }
     vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), data_for_select))
     ```
   - `.validate_export_inputs(design, vars_resolved, file_name, conf_level, decimals)` call
   - Stub body beyond validation: `invisible(file_name)`

5. Run section 8 — confirm all 7 pass green; other sections still red

6. Commit: `test(export-topline): write error path tests; add function stub`

---

**TDD Cycle 2 — Happy path and multiple variables (sections 1, 2)**

7. Add sections 1 and 2 to test file:
   - Section 1 (happy paths): file created + non-empty for all 3 design types; workbook has sheet named `"Topline"`; return value is `invisible(file_name)` (not NULL, not visible)
   - Section 2 (multiple variables): `vars = c(q1, q2)` — all variable names appear in workbook cells; single sheet `"Topline"`
   Use `make_all_designs(seed = 42)` and `withr::local_tempfile(fileext = ".xlsx")` for temp paths

8. Run — confirm sections 1–2 fail red

9. Complete `export_topline()` body:
   - Resolve NSE, call `.validate_export_inputs()`
   - `surveycore::classify_question_type(design, vars_resolved)` → `classify_out`
   - `.build_freq_frame(design, vars_resolved, classify_out, variance = variance, conf_level = conf_level, show_eff_n = show_eff_n)` → `freq_result`
   - `.build_workbook()` → `wb`; `wb_add_worksheet(wb, "Topline")`
   - Render dispatch loop: split `classify_out` by `group_id` (NA = singleton); iterate in `vars_resolved` order; track `groups_done`; dispatch to `.render_topline_single()` for singletons
   - `openxlsx2::wb_save(wb, file_name)` + `invisible(file_name)`

10. Write `.render_topline_single(wb, sheet, frame, start_row, show_n, show_eff_n, decimals, suppressed)` per spec:
    - Row 1: question text merged across all columns (bold)
    - Row 2: column headers ("Response", "%", optional "N"); for `show_eff_n = TRUE` on topline (no banner subgroups), the "%" column header shows the overall eff_n: two-line format `"%\n(Eff N=XXX)"` in gray (`#808080`) on line 2, using `fmt_txt()` and `wrap_text = TRUE` — no separate "Eff N" column for topline; for `survey_collection` wave columns, each wave header is two-line: wave name on line 1, `(n=X,XXX)` on line 2 in gray (`#808080`); use `openxlsx2::fmt_txt()` rich-text for partial cell formatting; apply `wrap_text = TRUE` on header cells via `wb_set_cell_style()`; `wave_n` = sum of `n` column from that wave's frequency rows in the frame
    - Rows 3+: one row per response category; `pct × 100` rounded to `decimals` dp as string
    - Final row: "Total" / "100%"
    - Calls `.write_suppression_footnote()` if suppressed is non-empty
    - Returns `list(wb = wb, next_row = <int>)`

11. Run sections 1–2 — confirm green for single-type vars

12. Commit: `feat(export-topline): implement core pipeline and single-type render`

---

**TDD Cycle 3 — var_type dispatch: SATA and battery (section 4)**

13. Add section 4 (var_type dispatch): SATA vars complete without error + file exists; battery vars complete without error + file exists; cross-design loop for both

14. Run — confirm fail red

15. Implement `.render_topline_sata()` per spec:
    - Row 1: question preface merged (bold); Row 2: column headers ("Item", "%", optional "N")
    - Rows 3+: one row per SATA item (var_label as row label, pct for value `"1"`)
    - No total row; returns `list(wb, next_row)`

16. Implement `.render_topline_battery()` per spec:
    - Row 1: battery preface merged (bold)
    - Calls `.render_topline_single()` for each sub-item (using var_label as question_text); no per-item footnote
    - Single footnote at battery block end; returns `list(wb, next_row)`

17. Update render dispatch in `export_topline()` to call correct helper for sata/battery groups

18. Run section 4 — confirm green

19. Commit: `feat(export-topline): implement SATA and battery render helpers`

---

**TDD Cycle 4 — `survey_collection` wave columns (section 3)**

20. Add section 3 tests: `survey_collection` input creates file without error; workbook "Topline" sheet contains `names(@surveys)` wave names in column headers; "Total" column present; each wave column header cell contains the wave name and `"(n="` string (two-line format verified by inspecting the rich-text or cell value string via `wb_to_df()` or `wb_read()`) 

21. Run — confirm fail red

22. Implement `survey_collection` dispatch path in `.build_freq_frame()` (already in PR 1 utils — verify it handles `survey_collection` total + wave rows); add "Total" pooled computation if not present

23. Run section 3 — confirm green

24. Commit: `feat(export-topline): verify survey_collection wave-column support`

---

**TDD Cycle 5 — Display options and metadata (sections 5, 6, 7)**

25. Add sections 5–7:
    - Section 5 (variance): `variance = NULL` → no se/ci cols in frame; `"se"` → se col present; `"ci"` → ci_low/ci_high present
    - Section 6 (show_n / show_eff_n): toggles produce correct column presence/absence in workbook
    - Section 7 (missing metadata): `surveyreports_warning_missing_variable_label` fires when no variable_label set; variable name used as question text; warning does NOT fire when label is set

26. Run — confirm fail red for any not yet covered

27. Wire `variance` pass-through to `.build_freq_frame()` + render helpers; wire show_n/show_eff_n to render helpers

28. Run sections 5–7 — confirm green

29. Commit: `feat(export-topline): wire variance, display toggles, and missing-label warning`

---

**TDD Cycle 6 — Edge cases (section 9)**

30. Add section 9: all-NA variable (file created, no crash); single-value variable (file created); single-row design (file created); empty domain (errors `surveyreports_error_empty_domain`)

31. Run — confirm expected results (green or correct typed error)

32. Fix any edge-case gaps (e.g., all-NA must not crash render helpers)

33. Commit: `test(export-topline): add edge case tests`

---

**TDD Cycle 7 — Numerical accuracy (section 10)**

34. Add section 10: call `.build_freq_frame()` directly on taylor design; compare `pct` per value against `surveycore::get_freqs()` at tolerance 1e-10; compare `se` at 1e-8; compare `ci_low`/`ci_high` at 1e-6; guard all blocks with `skip_if_not_installed("surveycore")`

35. Run — confirm green

36. Commit: `test(export-topline): add numerical accuracy oracle tests`

---

**Finalization**

37. Run `devtools::test(filter = "export-topline")` — all 10 sections green, no snapshot failures; update snapshots via `testthat::snapshot_review()` if any changes needed (do not use `snapshot_accept()` blindly)

38. Run `devtools::document()` — confirm NAMESPACE and `man/export_topline.Rd` generated

39. Update `R/surveyreports-package.R` `@section Key Functions:` to include `[export_topline()]`

40. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes

41. Run coverage check (`covr::file_coverage()`) — confirm ≥98% on `R/export-topline.R`

42. Push and open PR against `develop`

**Acceptance criteria:**
- [x] All new tests confirmed failing (red) before each implementation step
- [x] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [x] `devtools::document()` run; NAMESPACE and man/ in sync
- [x] Happy path tests pass for all 3 design types (taylor, replicate, twophase)
- [x] All 10 test sections covered
- [x] Numerical oracle: `.build_freq_frame()` totals match `surveycore::get_freqs()` at point 1e-10, SE 1e-8, CI 1e-6
- [x] All 7 error paths covered with dual pattern (class= + snapshot)
- [x] `plans/error-messages.md` — no new classes needed; already up-to-date
- [x] 98%+ line coverage on `R/export-topline.R`

**Notes:**
- No `pub_type` argument in `export_topline()` — this is correct per spec v1.2 decisions.
- Returns `invisible(file_name)`, not `invisible(NULL)` — verify `withVisible()` test in section 1.
- `survey_collection` input passes `.validate_export_inputs()` (the compound OR check accepts it); no suppression applied.
- Render helpers write to `wb` via side-effect; all return `list(wb = wb, next_row = <int>)`.
- All tests use `withr::local_tempfile(fileext = ".xlsx")` for output paths (standardized; `local_tempdir()` not used).
- Workbook cell assertions use `openxlsx2::wb_to_df(openxlsx2::wb_load(out), ...)`.
- Direct access to `.build_freq_frame()` in section 10 uses `surveyreports:::.build_freq_frame()`.

---

### PR 3: `export_crosstab()`

**Branch:** `feature/export-crosstab`
**Depends on:** PR 1 merged into `develop` (PR 2 recommended to merge first, but not required)

**Files (TDD order — tests first):**
- `tests/testthat/test-export-crosstab.R` — 14 sections
- `R/export-crosstab.R` — `export_crosstab()`, `.render_crosstab_single()`, `.render_crosstab_sata()`, `.render_crosstab_battery()`

**Key spec constraints to track:**
- `survey_collection` rejected with `surveyreports_error_collection_not_supported_for_crosstab` as the FIRST check — before `rlang::check_installed()` and before `.validate_export_inputs()`
- Returns `invisible(file_name)`
- 11 error classes (7 shared + 4 crosstab-specific)
- `layout = "per_question"`: one sheet per variable (sheet name = variable name, truncated to 31 chars); `layout = "stacked"`: one sheet named `"Crosstab"`, separated by blank rows
- Variable order = `vars_resolved` order throughout
- Self-banner drop happens in `.build_freq_frame()` (already in PR 1) — no action in render helpers
- `pub_type` applies here; suppression footnotes appear at bottom of each affected table block

**Tasks:**

**TDD Cycle 1 — Error paths (section 12)**

1. Create branch: `git checkout -b feature/export-crosstab develop`

2. Create `tests/testthat/test-export-crosstab.R` with section 12 — all 11 error-path test blocks, dual pattern:
   Classes: `collection_not_supported_for_crosstab`, `not_survey_object`, `var_not_found`,
   `vars_empty_selection`, `empty_domain`, `invalid_file_name`, `invalid_conf_level`,
   `invalid_decimals`, `banner_not_found`, `interaction_not_in_banner`, `interactions_not_list`

3. Run `devtools::test(filter = "export-crosstab")` — confirm all 11 fail red

4. Create `R/export-crosstab.R`; write `export_crosstab()` with:
   - Full roxygen
   - `survey_collection` rejection check FIRST (before any other code): `S7::S7_inherits(design, surveycore::survey_collection)` → `surveyreports_error_collection_not_supported_for_crosstab`
   - `rlang::check_installed("surveycore")`
   - **Inline design-type check BEFORE NSE resolution** (per `package-conventions.md`; note: `survey_collection` already rejected above, so only `survey_base` check is needed here):
     ```r
     if (!S7::S7_inherits(design, surveycore::survey_base)) {
       cli::cli_abort(
         c("x" = "{.arg design} must be a survey design object.",
           "i" = "Got class {.cls {class(design)}}.",
           "v" = "Use {.fn surveycore::as_survey} to create a design object."),
         class = "surveyreports_error_not_survey_object"
       )
     }
     ```
   - NSE resolution for `vars` and `banner` (using `design@data` directly — `survey_collection` already rejected):
     ```r
     vars_resolved <- names(tidyselect::eval_select(rlang::enquo(vars), design@data))
     banner_resolved <- names(tidyselect::eval_select(rlang::enquo(banner), design@data))
     ```
   - `.validate_export_inputs()` call
   - Banner validation: all `banner_resolved` names exist in `design@data` → `surveyreports_error_banner_not_found`
   - Interactions validation: `interactions` is `NULL` or a list → `surveyreports_error_interactions_not_list`; each element names vars in `banner_resolved` → `surveyreports_error_interaction_not_in_banner`
   - Stub body: `invisible(file_name)`

5. Run section 12 — confirm all 11 pass green; other sections still red

6. Commit: `test(export-crosstab): write error path tests; add function stub`

---

**TDD Cycle 2 — Happy path, per_question, stacked (sections 1, 2, 3)**

7. Add sections 1–3:
   - Section 1 (happy path): file created for all 3 design types; `per_question` default
   - Section 2 (multiple variables): `vars = c(q1, q2)` — all variable names in workbook; correct sheet count for `per_question`
   - Section 3 (layout): `per_question` → 2 sheets named "q1" and "q2"; `stacked` → 1 sheet named "Crosstab"

8. Run — confirm fail red

9. Complete `export_crosstab()` body:
   - `classify_question_type()`, `.build_freq_frame()` (with banner/interactions), `.build_workbook()`
   - `per_question`: one `wb_add_worksheet(wb, truncate(var, 31))` per group before render, pass sheet name + start_row = 1
   - `stacked`: one `wb_add_worksheet(wb, "Crosstab")`; track `current_row` across groups
   - Render dispatch (same algorithm as topline: group by group_id, iterate in vars_resolved order, track groups_done)
   - `wb_save()` + `invisible(file_name)`

10. Write `.render_crosstab_single()` stub (write question text + placeholder; accept all args; return `list(wb, next_row)`)

11. Run sections 1–3 — confirm green

12. Commit: `feat(export-crosstab): implement core pipeline with per_question and stacked layouts`

---

**TDD Cycle 3 — Banner spanners, interactions, self-banner (sections 4, 5, 6)**

13. Add sections 4–6:
    - Section 4 (banner): subgroup columns present; spanner labels match banner var names; correct number of column sets
    - Section 5 (interactions): interaction spanner groups present in workbook; one spanner per interactions element
    - Section 6 (self-banner): `vars = c(q1, group)` + `banner = c(group)` → q1 has group columns; group var row has no group banner column (self-banner silently dropped); no error, no warning

14. Run — confirm fail red

15. Implement full `.render_crosstab_single()`:
    - Spanner row above column headers: banner variable names spanning their column group(s)
    - Row 1: question text merged across all columns (bold)
    - Row 2 (spanner headers): banner variable names spanning respective column groups
    - Row 3: column headers ("Response", then banner level labels)
    - Rows 4+: one row per response category; `pct × 100` rounded to `decimals` dp
    - Final row: "Total" / "100%"
    - Interaction spanner groups follow banner spanner groups in column order
    - Calls `.write_suppression_footnote()` if `suppressed` non-empty; returns `list(wb, next_row)`

16. Confirm self-banner drop is already handled in `.build_freq_frame()` — no render-layer code needed

17. Run sections 4–6 — confirm green

18. Commit: `feat(export-crosstab): implement single-type render with banner spanners and interactions`

---

**TDD Cycle 4 — var_type dispatch: SATA and battery (section 7)**

19. Add section 7: SATA vars render without error + spanner headers present; battery vars render without error + scale categories as columns

20. Run — confirm fail red

21. Implement `.render_crosstab_sata()`:
    - Same structure as single but no total row; items are rows; banner spanners above column headers
    - Returns `list(wb, next_row)`

22. Implement `.render_crosstab_battery()`:
    - Battery preface row merged (bold); scale categories as columns; banner spanner groups repeat across scale columns
    - One row per sub-item; no total row; returns `list(wb, next_row)`

23. Update render dispatch to call correct helper

24. Run section 7 — confirm green

25. Commit: `feat(export-crosstab): implement SATA and battery render helpers`

---

**TDD Cycle 5 — Suppression, display options, metadata (sections 8, 9, 10, 11)**

26. Add sections 8–11:
    - Section 8 (variance): same as topline section 5
    - Section 9 (show_n / show_eff_n): same as topline section 6
    - Section 10 (pub_type suppression): `pub_type = "external"` with a small-N banner level → suppressed column absent; footnote present; `surveyreports_warning_subgroup_suppressed` fires; all-subgroups-suppressed → variable still present with total only + footnote
    - Section 11 (missing metadata): `surveyreports_warning_missing_variable_label` fires

27. Run — confirm fail red for any not yet covered

28. Wire variance and display-toggle pass-through in crosstab render helpers

29. Suppression: render helpers read `suppressed` tibble from `.build_freq_frame()` result; drop suppressed banner columns from output; write footnote (`.write_suppression_footnote()` from PR 1 utils, or define locally if not already shared); confirm warning fires from `.build_freq_frame()`

30. Run sections 8–11 — confirm green

31. Commit: `feat(export-crosstab): wire suppression, variance, display toggles`

---

**TDD Cycle 6 — Edge cases (section 13)**

32. Add section 13: all-NA variable; single-value variable; single-row data; empty domain (errors `surveyreports_error_empty_domain`); single-level banner (allowed silently — no warning, file created, one subgroup column present)

33. Run — confirm expected results

34. Fix gaps

35. Commit: `test(export-crosstab): add edge case tests`

---

**TDD Cycle 7 — Numerical accuracy (section 14)**

36. Add section 14: compare `.build_freq_frame()` subgroup `pct` against `surveycore::get_freqs(design, var, group = banner_var)` at tolerance 1e-10; SE at 1e-8; guard with `skip_if_not_installed("surveycore")`

37. Run — confirm green

38. Commit: `test(export-crosstab): add numerical accuracy oracle tests`

---

**Finalization**

39. Run `devtools::test(filter = "export-crosstab")` — all 14 sections green, no snapshot failures

40. Run `devtools::document()` — confirm NAMESPACE and `man/export_crosstab.Rd` generated

41. Update `R/surveyreports-package.R` `@section Key Functions:` to include `[export_crosstab()]`

42. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes

43. Run coverage checks:
    - `covr::file_coverage("R/export-crosstab.R", c("tests/testthat/test-export-topline.R", "tests/testthat/test-export-crosstab.R"))` — must be ≥98%
    - `covr::file_coverage("R/export-utils.R", c("tests/testthat/test-export-topline.R", "tests/testthat/test-export-crosstab.R"))` — combined coverage across PRs 2 and 3 must be ≥98%

44. Push and open PR against `develop`

**Acceptance criteria:**
- [x] All new tests confirmed failing (red) before each implementation step
- [x] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [x] `devtools::document()` run; NAMESPACE and man/ in sync
- [x] Happy path tests pass for all 3 design types (taylor, replicate, twophase)
- [x] All 14 test sections covered
- [x] Numerical oracle: `.build_freq_frame()` subgroup values match `surveycore::get_freqs()` at point 1e-10, SE 1e-8, CI 1e-6
- [x] All 11 error paths covered with dual pattern (class= + snapshot)
- [x] `plans/error-messages.md` — no new classes needed
- [x] 98%+ line coverage on `R/export-crosstab.R`
- [x] Combined coverage on `R/export-utils.R` ≥98% verified

**Notes:**
- `survey_collection` rejection is the FIRST check in `export_crosstab()` — before `rlang::check_installed()`.
- Banner and interaction validation live in `export_crosstab()` body, not in `.validate_export_inputs()`.
- Interactions validation: `interactions` must be a list; each element is a character vector of 2+ variable names all present in `banner_resolved`.
- Suppression logic runs in `.build_freq_frame()` (PR 1); render helpers only read the `suppressed` tibble.
- Self-banner drop happens in `.build_freq_frame()` (PR 1) — no render-helper code needed.
- `.write_suppression_footnote()` helper: if not already in `R/export-utils.R`, add it there (used by all 6 render helpers across PRs 2–3).
