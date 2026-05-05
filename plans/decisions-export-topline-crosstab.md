# Decisions Log — surveyreports export-topline-crosstab

This file records planning decisions made during export-topline-crosstab.
Each entry corresponds to one planning session.

---

## 2026-05-04 — Stage 4 Resolve: spec issues 1–17

### Context

Working through 17 issues (4 blocking, 12 required, 1 suggestion) from the Stage 3
adversarial spec review. Goal: resolve all issues and lock the spec before handing
off to `/implementation-workflow`.

### Questions & Decisions

**Q: Where does `.build_workbook()` fit in the data flow?**
- Options considered:
  - **Option A:** One sentence in the Data Flow section — parent calls `.build_workbook()` first, render helpers add sheets via side-effect, parent calls `wb_save()` last.
  - **Option B:** Describe in Rendering Details with explicit inputs/return value.
- **Decision:** Option A — one sentence in Data Flow.
- **Rationale:** The data flow is the right place for call-order information; Rendering Details handles structural output.

**Q: How should multiple variables be arranged in the workbook?**
- Options considered:
  - **Option A:** Topline → single sheet named "Topline"; crosstab `per_question` → one sheet per variable; crosstab `stacked` → single sheet named "Crosstab".
  - **Option B:** Group by var_type across sheets.
- **Decision:** Option A — simplest structure.
- **Rationale:** Minimises implementation complexity; predictable for test assertions; matches user mental model.

**Q: What should `export_topline()` and `export_crosstab()` return?**
- Options considered:
  - **Option A:** `invisible(file_name)` — consistent with `readr::write_csv()`.
  - **Option B:** `invisible(NULL)` — consistent with `ggsave()`.
- **Decision:** Option A — `invisible(file_name)`.
- **Rationale:** Gives the caller something useful; trivially testable with `expect_equal(result, path)`; allows piping.

**Q: Should `pub_type` be in `export_topline()`?**
- Options considered:
  - **Option A:** Keep it; document that it applies to wave columns when input is `survey_collection`.
  - **Option B:** Remove it — topline has no banner; suppression is a crosstab concept.
- **Decision:** Option B — remove `pub_type` from `export_topline()`.
- **Rationale:** `export_topline()` has no subgroups to suppress with `survey_base` input; wave columns in `survey_collection` are informational, not subgroup comparisons requiring suppression. Keeping the argument would require specifying complex wave-suppression behavior for marginal benefit.

**Q: How should empty-domain input be handled?**
- Options considered:
  - **Error:** `surveyreports_error_empty_domain` — abort immediately.
  - **Warning + empty workbook:** warn and continue.
- **Decision:** Error with `surveyreports_error_empty_domain`.
- **Rationale:** An empty domain is almost certainly a user mistake in a reporting context; failing fast with a clear message is more helpful than producing an empty or degenerate workbook.

**Q: Should a banner variable with a single level warn or be allowed silently?**
- Options considered:
  - **Option A:** Allow silently — valid output, just uninformative.
  - **Option B:** Emit `surveyreports_warning_single_level_banner`.
- **Decision:** Option A — allow silently, document, add edge case test.
- **Rationale:** Single-level banner is technically valid; warning would be noise for users working with filtered designs. The edge case test ensures the behavior is verified.

**Q: How should zero-column `vars` tidyselect be handled?**
- Options considered:
  - **Option A:** New class `surveyreports_error_vars_empty_selection`.
  - **Option B:** Absorb into `surveyreports_error_var_not_found`.
- **Decision:** Option A — new named class.
- **Rationale:** The two cases are structurally different: `var_not_found` is for a named variable that doesn't exist; `vars_empty_selection` is for a valid but empty tidyselect expression. Different message, different fix.

### Outcome

Spec `plans/2026-05-04-export-topline-crosstab-design.md` updated with all 17 issue
resolutions. Key structural decisions: removed `pub_type` from `export_topline()`;
added `.validate_export_inputs()` as shared helper; added sheet structure and render
helper output format sections; added 2 new error classes (`vars_empty_selection`,
`empty_domain`); updated `plans/error-messages.md` with all 10 errors + 2 warnings.
Spec is ready for `/implementation-workflow`.

---

## 2026-05-04 — Stage 4 Resolve: Pass 2 spec issues 1–7

### Context

Working through 7 issues (1 blocking, 4 required, 2 suggestions) from the Stage 3
Pass 2 adversarial spec review. Goal: close all remaining gaps before handing off
to `/implementation-workflow`.

### Questions & Decisions

**Q: Should `export_crosstab()` accept `survey_collection` input?**
- Options considered:
  - **Option A:** Reject with a typed error (`surveyreports_error_collection_not_supported_for_crosstab`) before `.validate_export_inputs()` is called.
  - **Option B/C:** Support it with a defined layout (wave spanners + banner subgroups, or vice versa).
- **Decision:** Option A — reject with a typed error; `survey_collection` is valid only for `export_topline()`.
- **Rationale:** Wave-within-banner crosstabs are a distinct complex feature not implied by the current spec scope. Right-sized to the engineering principle: "Engineered enough — not under, not over." This also simplifies the design-type check in `.validate_export_inputs()`: the `survey_collection` arm of the compound OR check now applies only to `export_topline()`.

**Q: At which pipeline stage should the self-banner drop be applied?**
- Options considered:
  - **Option A:** In `.build_freq_frame()` — skip calling `.compute_subgroup_freq(var, banner_var)` when `var == banner_var`.
  - **Option C:** Leave to implementer / Plan B implementation plan.
- **Decision:** Option A — pin the stage in the spec.
- **Rationale:** Prevents two implementers from choosing different stages. Skipping at `.build_freq_frame()` is the most efficient approach (avoids a degenerate `get_freqs()` call). External behavior is identical either way, but pinning it avoids divergence.

### Outcome

Spec `plans/2026-05-04-export-topline-crosstab-design.md` updated to v1.2 with all 7
Pass 2 issue resolutions. Key changes: `export_crosstab()` now explicitly rejects
`survey_collection` with a typed error; `pct` column documented as `[0, 1]` scale
with renderer ×100 note; render dispatch algorithm documented; test error-class counts
corrected (topline: 7, crosstab: 11). Added 1 new error class
(`collection_not_supported_for_crosstab`) to both the spec and `plans/error-messages.md`.
Spec is ready for `/implementation-workflow`.

---

## 2026-05-05 — Stage 3 Resolve: plan review issues 1–11

### Context

Working through 11 issues (3 blocking, 6 required, 2 suggestions) from the Stage 2
adversarial plan review. Goal: close all gaps in the implementation plan before
handing off to `/r-implement`.

### Questions & Decisions

**Q: Where does `.write_suppression_footnote()` live across the three PRs?**
- Options considered:
  - **Option A:** Add to PR 1 as task 10.5 in `R/export-utils.R` (shared utility PR).
  - **Option B:** Assign to PR 2; document PR 3 dependency explicitly.
- **Decision:** Option A — PR 1 owns it.
- **Rationale:** All 6 render helpers across PRs 2 and 3 call it; placing it in the shared-utilities PR removes cross-PR ownership ambiguity and keeps each PR self-contained.

**Q: How should `show_eff_n = TRUE` behave for topline (no banner subgroups)?**
- Options considered:
  - **Option A:** Compute overall (unfiltered) Kish eff_n; place it in the "%" column header as a grayed second line.
  - **Option B:** `show_eff_n` has no effect for topline; column absent.
- **Decision:** Option A — overall eff_n in the "%" column header.
- **Rationale:** Keeps the argument meaningful for topline callers; `col = NULL, level = NULL` in `.compute_eff_n()` means no filtering. Placement (grayed second line in header, not per row) specified by user to match the visual treatment of wave `(n=X,XXX)` labels.

**Q: What should wave column header cells look like?**
- Options considered:
  - **Option A:** Wave name on line 1; `(n=X,XXX)` on line 2 in gray (`#808080`) using `fmt_txt()` rich text + `wrap_text = TRUE`.
  - **Option B:** Single-line `"wave_name (n=X,XXX)"`.
- **Decision:** Option A — two-line grayed format (user-specified to match the visual treatment of N values inside proportion cells).
- **Rationale:** Consistent with the grayed second-line style used for eff_n in the "%" column header; readability over compactness.

**Q: Where should the `survey_collection` wave dispatch path live?**
- Options considered:
  - **Option A:** Fully implement in PR 1 task 9 (`.build_freq_frame()`), including missing-variable placeholder rows for stable column positions.
  - **Option B:** PR 2 adds it to a PR 1 file (cross-PR file mutation).
- **Decision:** Option A — wave path and missing-variable placeholder rows both in PR 1 task 9.
- **Rationale:** Keeps PR boundaries clean; PR 2 TDD Cycle 4 verifies rather than implements; PR 1 CI remains meaningful.

### Outcome

Implementation plan `plans/impl-export-topline-crosstab.md` updated with all 11 issue
resolutions. Key changes: `.write_suppression_footnote()` tasked in PR 1; inline
design-type checks added before NSE resolution in both `export_topline()` and
`export_crosstab()`; `survey_collection` wave dispatch path (including missing-variable
placeholder rows) fully tasked in PR 1 task 9; `var_label` added to spec's long frame
schema; wave column headers defined as two-line + gray using `fmt_txt()` rich text;
`show_eff_n` topline behavior defined (overall eff_n in "%" column header); temp file
pattern standardized to `local_tempfile(fileext = ".xlsx")`; exact coverage commands
added to PR 3 finalization; DESCRIPTION criterion added to PR 1 checklist.

---
