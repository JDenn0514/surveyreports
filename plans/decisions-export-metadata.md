# Decisions Log — surveyreports export-metadata

This file records planning decisions made during export-metadata.
Each entry corresponds to one planning session.

---

## [2026-09-09] — Methodology lock: export metadata integration

### Context

Stage 2 pass 1 raised 14 issues against `plans/spec-export-metadata.md` v0.1.0:
4 BLOCKING, 6 REQUIRED, 4 SUGGESTION. Four were judgment calls. This session
resolved all 14 and locked the methodology. The spec is now v0.2.0.

Before deciding, four claims from the review were re-measured against
surveycore `1.1.0.9000`. All held, and one added a fact the review did not
have: `get_effective_n()` accepts a `survey_collection` and returns one row per
member, unlike the three metadata readers that abort.

| Path | local `.compute_eff_n()` | `get_effective_n()` | `get_freqs()` n |
|---|---|---|---|
| taylor | 184.98 | 184.98 | 200 |
| twophase | 184.98 | 110.15 | 119 |
| domain-restricted | 184.98 | 68.65 | 75 |
| labelled banner join | — | 0 unmatched of 4 rows | — |

### Questions & Decisions

**Q: Issue 5 (BLOCKING) — workstream 1 rebuilds a join that
`surveycore::get_effective_n()` already performs. Delegate, or keep the local
implementation?**

- Options considered:
  - **A — Delegate:** replace `.compute_eff_n()` and the proposed
    `.banner_row_mask()` with one `get_effective_n()` call per banner column,
    joined on the label. Resolves issues 9 and 12 as a side effect.
  - **B — Keep local, fix its edge cases:** build the mask as specified, plus a
    phase-2 row filter and a domain-column intersection, plus tests for both.
  - **C — Do nothing.**
- **Decision:** A.
- **Rationale:** the delegated function returns the raw N, the Kish effective N
  and the value label in one call, in the same vocabulary `get_freqs()` uses.
  It also resolves the phase-2 subset and the domain column the local helper
  ignores — two paths where the current code publishes an effective N above the
  raw N of the table it labels. Option B would carry a second Kish estimator in
  this package that must track surveycore's domain, twophase and labelling
  rules by hand. The join was verified clean on character, factor and labelled
  banners before deciding. Workstream 1 becomes a deletion.

**Q: Issue 1 (REQUIRED) — `show_eff_n` reaches all three crosstab renderers and
none of them read it. Render it, or state that it is not rendered?**

- Options considered:
  - **A — Add a sixth workstream** that renders `eff_n` in the crosstab spanner.
  - **B — State the fact and park the render:** correct section 3.2, restrict
    the test to `export_topline()`, record the gap in section 1.3.
  - **C — Do nothing.**
- **Decision:** B.
- **Rationale:** rendering would change every committed crosstab snapshot taken
  with `show_eff_n = TRUE`, which section 9.4's no-snapshot-change gate forbids.
  The spec's scope in section 1.3 is deliberately narrow. Workstream 1 still
  fixes the number `export_topline()` prints and the number that drives
  suppression in both functions.

**Q: Issue 4 (REQUIRED), old open question 7, and issue 10's collection branch
— `.base_note_for()` keys on the first variable of a group. With the universe
fallback, what happens when the metadata varies within one rendered table?**

- Options considered:
  - **A — Unanimous-only, one rule everywhere:** print the universe only when
    every member carries the same text. Apply the identical rule to battery and
    SATA blocks, to collections, and to the role lookup on a collection.
  - **B — First member wins, documented.**
  - **C — Single-choice tables only:** skip the fallback for groups and
    collections.
- **Decision:** A.
- **Rationale:** a caller-supplied `base_notes` entry names the first variable
  on purpose, so first-member semantics are correct for the caller's own input.
  Metadata read from the design carries no such intent — a five-item battery
  cleaned by the ADL schema carries a universe on all five members, and
  first-member semantics would print member 1's text over the block whether or
  not the others agree, and print nothing when member 1 alone is unset. Option
  A never states something false for a member. One rule covers three places
  that were otherwise going to be decided separately, and one helper
  (`.unanimous_across()`) implements it.

**Q: Issue 14 (SUGGESTION) — interaction cells are never evaluated for
suppression. Fix it here, or park it?**

- Options considered:
  - **A — Add interaction suppression as workstream 6.**
  - **B — Park it in section 1.3 with the reason and a follow-up issue.**
  - **C — Do nothing.**
- **Decision:** B.
- **Rationale:** the defect is pre-existing and outside the five workstreams,
  and closing it would change any committed snapshot with interactions and a
  `pub_type`. Recording it stops a later reader taking the spec to mean
  suppression is complete after workstream 1. It is a distinct defect with its
  own test surface.

### Unambiguous fixes applied in the same session

Ten issues had one correct fix and were applied together.

| Issue | Fix |
|---|---|
| 2, 13 | Interaction spanners group and label on codes. Translate each banner column with `.banner_levels_labelled()` before `interaction()` runs. |
| 3 | Cover sheet gains a `Key` / `Value` header row; `"About"` is stated as sheet 1 and active on open; a colliding **data** sheet is suffixed. |
| 6 | Reverse the duplicate-value-label decision. The specified union is unobservable — `get_freqs()` and `get_effective_n()` both abort in `.apply_group_labels()` first. Detect during validation and abort with `surveyreports_error_duplicate_value_label`. The warning class is removed. |
| 7 | `.resolve_roles()` must not abort on a foreign `var_extra` payload. A `role` that is not a length-1 character is treated as unset: keep the column, warn `surveyreports_warning_unknown_role`. |
| 8 | Replace the stale abort quote in section 4.4 with the dimensions message surveycore actually raises. |
| 9, 12 | Twophase phase-1 rows and the ignored domain column. Both resolved by the issue 5 delegation. Section 1.4's twophase row corrected. |
| 10 | Workstream 3 does reach a collection, through `vars`. Section 1.4's collection row becomes "2, 3, 4, 5"; section 5.6 specifies the branch; test row 23 added. |
| 11 | `export_topline()` has no `banner`, so 7 of the previous 18 test rows were unwritable against it. Every section 9.2 row now carries an **Applies to** column, and section VIII's "Raised by" column is corrected. |

### Outcome

The spec is methodology-locked at v0.2.0. Workstream 1 is now a delegation to
`surveycore::get_effective_n()` plus an interaction-vocabulary fix, rather than
a local row-mask implementation; three of the four blocking issues closed with
it. Four questions remain open for Stage 4: the non-substantive role set, the
all-banner-dropped error, the shared-helper file location, and the per-wave
cover sheet layout.

---

## [2026-09-09] — Methodology lock, pass 2: `get_effective_n()`'s real signature

### Context

Pass 2 of the methodology review raised 9 issues against spec v0.2.0. None is
blocking. Pass 1's delegation decision holds under re-measurement: the twophase
pair is 110.15 against a table of 119, and the domain pair is 68.65 against 75.
What pass 2 found is that the delegation contract was written against a
three-argument mental model of `get_effective_n()`. The real function takes
seven arguments, and two of them change the spec: `min_cell_n = 30L` makes the
helper warn on exactly the small cells suppression exists to find, and `x` is
inert under the Kish estimator, so `eff_n` stays independent of the variable
being tabulated. The remaining issues are internal contradictions in the spec
rather than statistical errors.

### Questions & Decisions

**Q: `n` and `n_eff` ignore the tabulated variable, so the Total header can
still print an effective N above the table's N. State the limit, or make
`eff_n` per variable? (Issue 15)**

- Options considered:
  - **State the contract limit:** `n` and `n_eff` are design-level or
    banner-level row counts. Restate test row 6 and the section X gate against
    the design's in-scope row count — 119 twophase, 75 domain — rather than the
    table's N. Record variable-level missingness in 1.2.1 as a third,
    unaddressed cause. Low effort, low risk. The header keeps today's meaning.
  - **Make `eff_n` per variable:** subset the design to each variable's
    non-missing rows before the call. The header then matches the table.
    Medium effort and risk: `show_eff_n` output changes for every variable with
    missing values, so section 9.4's no-snapshot-change gate needs re-checking,
    and `eff_n` becomes one value per variable rather than one per table.
  - **Do nothing:** the spec keeps asserting an invariant that measurement
    contradicts. Test row 6 as written passes on `make_all_designs()` and fails
    on any variable with missing values.
- **Decision:** state the contract limit.
- **Rationale:** the defect this spec set out to fix is the twophase and domain
  pair, and delegation closes both. Measured, 300 rows with 60 missing on `q1`
  give `n_eff = 278.6` against a table N of 240 — and the **current**
  `.compute_eff_n()` returns the same 278.6. So this is pre-existing, not a
  regression the spec introduces. Widening the scope to variable-level
  missingness is a separate change with its own snapshot risk.

### Unambiguous fixes applied

| Issue | Fix |
|---|---|
| 16 | `.resolve_eff_n()` branched on `banner_var`, which gave a collection `level = NA_character_` for every member while 3.5's own contract table said `.survey`. Branch on the design type instead. The return is one row per member. |
| 17 | A partly labelled banner yields a real `NA` level with a real `n`. Added to 3.5's contract table; 3.4 consequence 3 records that the suppression footnote changes from `gen=3` to `gen=NA`; test row 26 added. |
| 18 | `.banner_levels_labelled()` returning character re-sorts a factor banner's interaction spanners alphabetically, so a Likert banner ordered `Low`, `Medium`, `High` would render `High`, `Low`, `Medium`. The helper preserves the factor and its level order. Sections 3.3 and 9.4 also carried a wrong fixture claim — `helper-test-data.R` has no `factor()` call, so every fixture column is character. Corrected; test row 27 and a factor fixture added. |
| 19 | `get_effective_n(min_cell_n = 30L)` raises `surveycore_warning_small_cell` on exactly the cells suppression exists to find, which would break section X's warning-count gate and every snapshot that records a warning. Muffle it in `.resolve_eff_n()` with the `withCallingHandlers()` the two frequency helpers already use. Test row 28 added. |
| 20 | Section 3.8 listed 3 of 4 `.compute_eff_n()` call sites. The fourth is `.build_freq_frame()`'s collection branch at `export-utils.R:381-396`, which joins on `subgroup_var`, not `subgroup_value` — so 3.8's stated join rule matches nothing there. Added, with the decision that the pooled `Total` row keeps `NA_real_`. Test row 29 added. |
| 21 | Pass 1 issue 8 replaced an accurate abort quote with an inaccurate one. Rather than restore it, sections 4.4, 5.6 and 6.3 now quote nothing and state the fact the branch depends on: the three readers abort. Two passes measured two different texts, so the quote is the part that decays. |
| 22 | Section 6.2.1 specified a sheet-suffix rule that section 2.1 assigned to no file. A shared `.unique_sheet_name()` in `R/export-utils.R` owns it, over all three `wb_add_worksheet()` call sites. It also closes the pre-existing case of two variables sharing their first 31 characters. |
| 23 | `.unanimous_across()`'s signature fits the collection case and not the battery case — applied literally, a battery would never print a base note. The battery call reshapes to one shared key; a battery inside a collection resolves waves first. Pulled 4.2 with it: `.resolve_base_notes()` keeps the caller's vector and the universe **separate**, because a merge makes the two sources indistinguishable and defeats the caller exemption 4.5 states. Test row 30 added. |

### Outcome

The spec is methodology-locked at v0.3.0. All 23 issues across both passes are
resolved. Workstream 1's delegation stands with three additions the real
`get_effective_n()` signature forces: a muffled small-cell warning, a
design-type branch for collections, and a stated limit that `eff_n` does not
depend on the tabulated variable. Six test rows were added, bringing section
9.2 to 30. The four Stage 4 questions are unchanged.

---

---

## [2026-09-10] — Stage 4 open questions closed

### Context

The spec reached v0.3.0 methodology-locked on 2026-09-09 with four questions
carried to Stage 4. Three of them shape test scenarios, so they had to close
before `test-spec-export-metadata.md` could be drafted. The fourth was a
misreading of a rule file and closed by measurement.

### Questions & Decisions

**Q: Open question 6 — do the shared helpers stay in `R/export-utils.R`, or
does `R/utils.R` get created?**

- **Decision:** they stay in `R/export-utils.R`. No `R/utils.R` is created.
- **Rationale:** no user decision was needed. The spec's GAP note says
  `code-style.md` directs a helper used in 2 or more source files to
  `R/utils.R`. It does not. Measured — `code-style.md` line 21 reads
  "`R/export-utils.R` if used in 2+ files" and line 239 reads
  "| 2 or more source files | `R/export-utils.R` |". The rule and the existing
  placement already agree, so the gap was never real.

**Q: Open question 3 — which `role` values are non-substantive?**

- Options considered:
  - **A —** drop `weight`, `identifier`, `paradata`, `free_text`; keep `item`,
    `demographic`, `treatment`.
  - **B —** drop `paradata` and `free_text` only, the literal set the earlier
    confirmed decision named.
  - **C —** A plus `treatment`.
- **Decision:** A.
- **Rationale:** a weight column tabulated as response categories, and a
  respondent-ID column rendered as a 119-row table at 0.1% each, are never a
  wanted table. They fail for the same reason `free_text` does, so they belong
  in the same set. C was rejected because a treatment arm is a common banner
  variable — dropping it would remove exactly the column an experimental report
  crosses on.

**Q: Open question 4 — when the role guard drops every `banner` column, does
`export_crosstab()` abort?**

- Options considered:
  - **A —** abort with `surveyreports_error_banner_empty_selection`.
  - **B —** warn and render a Total-only workbook.
  - **C —** let it flow to the existing downstream behavior.
- **Decision:** A.
- **Rationale:** it mirrors the existing `surveyreports_error_vars_empty_selection`
  and it contains the risk that "warn and drop" creates. Under B a mistyped
  banner returns a topline-shaped workbook under a crosstab file name, which is
  a different deliverable arriving silently. C makes an unspecified, untested
  path into the contract.

**Q: Open question 8 — what layout does a per-wave cover sheet use?**

- Options considered:
  - **A —** block per wave: a wave heading, then that wave's `Key` / `Value`
    rows, repeated.
  - **B —** row per wave: a `Wave` column plus one column per key.
- **Decision:** A.
- **Rationale:** A reuses the single-design writer with no second shape — the
  same two columns and the same bold column A. It also degrades cleanly when
  waves set different key sets: a key set in one wave only appears in that
  wave's block, where B leaves a blank cell that reads as an empty value rather
  than an unset one.

### Consequences

- Section 2.1's placement GAP is removed; `R/export-utils.R` is confirmed.
- Section 5.4 names the drop set `c("weight", "identifier", "paradata",
  "free_text")` and the keep set `c("item", "demographic", "treatment")`.
- Section 5.5's escalation is confirmed;
  `surveyreports_error_banner_empty_selection` stays in section VIII.
- Section 6.3 specifies the block-per-wave layout.
- The spec's "Still open — Stage 4" table is empty. The spec advances to
  Stage 3, the adversarial spec review.

---

## [2026-09-10] — Stage 3 resolve: the 21 spec-review issues

### Context

The adversarial spec review raised 21 issues: 4 blocking, 10 required, 7
suggestions. All 21 are resolved. Three of them could not be settled from the
documents, so they were measured against R 4.6.1, surveycore `1.1.0.9000` and
openxlsx2 `1.28` before the choice was made. Two of those measurements changed
which option was right.

### Measurements that changed a decision

**Two unlabelled codes on one banner column (issue 7).** The review offered two
readings and recommended recording whichever held. Neither reading was
survivable. `get_effective_n()` returns one row per unlabelled code and both
key as `NA`; `get_freqs()` agrees. So two distinct subgroups with different
counts share one key, the suppression filter removes both when one is below
threshold, and a crosstab renders two column groups under the same `NA`
heading. The decision moved from "record it" to "abort during validation".

**The active sheet (issue 14).** The review suspected `wb_add_worksheet()`
would steal the active sheet from the cover sheet, and offered a fix for that
case. It does not. `get_active_sheet()` is empty on a workbook in memory and
returns `1` after a save and reload. The claim holds; the assertions were
wrong, because they read a workbook that had not been written. The decision
moved from "fix the code" to "fix the test".

**A partially dropped battery (issue 11).** Three members classify as
`battery`; two still classify as `battery` with the group id unchanged; one
reclassifies to `single`. So the role guard changes a question's rendered shape
only when it leaves exactly one member. The rule needed covers one boundary,
not the general case.

### Questions & Decisions

Options are as stated in `plans/spec-review-export-metadata.md`. Every
resolution took the reviewer's recommendation except where the measurements
above moved it.

| # | Question | Decision |
|---|---|---|
| 1 | Three undefined test rows | **A** — define all three. Empty domain reports before the role guard, measured from the call order. An unused factor level is dropped, measured. |
| 2 | The spec duplicates the test gates | **A** — one gate list, in the test-spec. The spec keeps only source-tree checks. |
| 3 | `survey_nonprob` missing from the matrix | **A** — add the row, and make the generator gap a deliverable of this spec. |
| 4 | The warn-and-drop policy written twice | **A** — a shared `.apply_role_guard()`. |
| 5 | Three `wb_add_worksheet()` sites, or four | **B** — four. The literal-named stacked sheet is excluded, with the reason. |
| 6 | `.unique_sheet_name()` placement | **A** — move it to its single call-site file. |
| 7 | Two or more unlabelled banner codes | **A** — abort. See the measurement above. |
| 8 | Decayed line references | **B** — drop the line numbers; the helper is deleted whole. |
| 9 | The footnote changes twice | **A** — state both changes, and assert the corrected count. |
| 10 | `interactions` and a dropped banner column | **B** — re-validate after the guard, reusing the existing class. |
| 11 | Dropping a group member | **A** — define it, with the rule at the last-survivor boundary. |
| 12 | The reused `vars` empty-selection error | **A** — a new `surveyreports_error_vars_all_dropped`. |
| 13 | Routing only the add call | **A** — assign to `sheet_name` before both uses. |
| 14 | The active-sheet claim | **A** — keep it; assert after a save and reload. |
| 15 | Four cover-sheet labels unchecked | **A** — set all six keys and assert the order. |
| 16 | The `all_of()` snippet | **B** — one-line instruction, no snippet. |
| 17 | A class that was never in the table | **B** — delete the sentence and the gate clause. |
| 18 | Renumbering seams | **A** — fix the reference and the rule. |
| 19 | No documentation tier or roxygen change | **A** — add section VIII-A. Both functions are Tier 4, Dispatcher. |
| 20 | SATA, variance and the missing-label warning | **A** — add the SATA rows; state N/A with a reason for the rest. |
| 21 | Stacked layout and self-banner | **A** — add both scenarios. |

### Notable consequences

- **Two new conditions.** `surveyreports_error_multiple_unlabelled_codes`
  (issue 7) and `surveyreports_error_vars_all_dropped` (issue 12). The spec now
  carries 6 new classes, up from 4.
- **Two new deliverables.** The `survey_nonprob` fixture (issue 3) and the
  roxygen changes of section VIII-A (issue 19). Neither was in the original
  five workstreams.
- **Issue 13 was the most dangerous.** Following the spec's own instruction
  literally would have shipped a crosstab that writes a question block into its
  own cover sheet, and the existing assertion checked sheet names only, so it
  would have passed.

### Outcome

The spec reaches v0.5.0 with no open questions and no GAP markers. The
test-spec grows from 91 scenarios to 118. Both are ready for the Stage 3
verification pass.

---

## [2026-09-10] — Stage 3 resolve, pass 2

### Context

The pass 2 delta review returned BLOCK. Of the 21 Pass 1 issues it found 18
resolved, 2 partial, and 1 regressed, and it raised 9 new findings: 1 blocking,
4 required, 4 suggestions. All are now resolved. Every fix took the reviewer's
recommended option.

### The theme of pass 2

Three scenarios were filed against the wrong function. `export_topline()` has
no `pub_type` argument, raises no suppression footnote, and writes one fixed
sheet name. Two footnote rows and one sheet-name row were written against it
anyway. So two of the behaviors the pass 1 resolution set out to assert were
asserted nowhere a tester could reach them.

That is a failure of the resolution work, not of the spec. It is the risk of
resolving 21 findings across two documents in one sitting: a fix lands in the
section the issue named, and its scenario lands in the nearest table rather
than the correct one.

### Questions & Decisions

| # | Finding | Decision |
|---|---|---|
| 22 | `TN-05b` and `TN-05c` assert a footnote `export_topline()` never writes | **A** — move both to the crosstab table as `XN-08` and `XN-09`. The rows were right; the table was wrong. |
| 23 | Gate IX and section XI still place `.unique_sheet_name()` in the shared file | **A** — correct both, and declare `.design_universe()` and `.roles_of()`, which sections 4.4 and 5.6 used without ever introducing. The helper count goes from 8 to 10. |
| 24 | `TP-09f` asserts the sheet-name rule on the function with one sheet | **A** — move it to the crosstab table as `XP-18g`. |
| 25 | Section VIII-A assigns Tier 4 to two functions that do not meet it | **A** — state the shortfall, and make writing a full `@details` route overview and a full `@section Workbook Layout` a deliverable for both. Add `export_crosstab()` to `export_topline()`'s `@seealso`. Add a gate for the three Tier 4 requirements. |
| 26 | The two new banner aborts are absent from section VIII-A | **A** — add both to the 8a.2 table and the 8a.3 `@param banner` row. The gate reads that table, so an omission there is ungated. |
| 27 | `TC-05` misses the wave key order and the bold heading | **A** — the same edit `TP-11` already took. |
| 28 | The test-spec header still read v0.1.0 and DRAFT | **A** — v0.2.0, spec-reviewed. |
| 29 | Three structural seams | **A** — fix the malformed rule before VIII-A, normalize the sub-subsection heading levels, and put `TP-09` before its six extensions. |
| 30 | Two gates still stand in both lists | **A** — cut the runtime half from the spec, keep the source-tree half. |

Two partial resolutions from pass 1 also closed. Issue 11's sheet-name rule
moved to the function it applies to. Issue 14's residue \u2014 two Result structure
lists asserting the active sheet with no reload, "in every block" \u2014 is
replaced by a note that the assertion belongs only with the two scenarios that
save and load the file.

### Notable consequence

**Issue 25 grew the scope again.** The spec assigned Tier 4 to both functions
on the strength of the standards file naming them there. Neither function
currently has an `@details` block or any `@section`, so the tier was assigned
and not delivered. Writing both blocks whole, for both functions, is now a
deliverable. This is the third addition beyond the original five workstreams,
after the `survey_nonprob` fixture and the roxygen changes themselves.

### Outcome

The spec reaches v0.6.0 and the test-spec v0.2.0. The scenario set holds at 124
ids. Pass 3 is the final pass the review-loop budget allows.

---

## [2026-09-14] — Methodology lock: crosstab presentation and withholding

### Context

Stage 2 pass 3 raised 18 issues against `plans/spec-export-metadata.md` v0.8.0:
3 BLOCKING, 9 REQUIRED, 6 SUGGESTION. Twelve were unambiguous and were applied
as written. Six were judgment calls and are recorded below. The spec is now
v0.9.0.

Two measurements drive most of the session. `get_freqs()` returns `pct`, `se`,
`ci_low` and `ci_high` as proportions, not percentages, so the spec's rounding
threshold was wrong by a factor of 100. And `get_effective_n(method = "kish")`
measures weight variation alone: on 400 rows in 20 clusters it returns 370.4
where the size a simple random sample would need to match the design's standard
error is 139.7.

### Questions & Decisions

**Q: Issue 25 (BLOCKING) — the glossary defines the effective sample size as a
design-effect quantity, and the number printed is Kish. Change the words or
change the number?**

- Options considered:
  - **A — Keep Kish, fix the words:** describe the quantity the package already
    computes. Low effort, low risk. The floor keeps a weaker guarantee than the
    old wording claimed.
  - **B — Compute a design-effect ESS per estimate from the SE surveycore
    returns, and key the floor on it:** high effort, high risk. The ESS becomes
    one number per cell, so the two sample-size rows of section 3.4 lose their
    single value.
- **Decision:** A.
- **Rationale:** the arithmetic is right and the words are wrong.
  `get_effective_n(method = "deff")` routes to `get_means()` and aborts on a
  character variable, so a design-effect ESS is not reachable for the
  categorical questions a crosstab tabulates. B is a separate spec. The
  glossary entry now says the number adjusts for the weights and not for
  clustering, and the "too imprecise to report" sentence is gone.

**Q: Issue 28 (SUGGESTION) — the rounding mode is unstated, and R rounds half to
even. Name which?**

- Options considered:
  - **Half to even:** what `round()` and `sprintf()` already do, and what the
    current code does. No code change.
  - **Half away from zero:** the usual report convention. Needs a custom
    rounder and moves every boundary value.
- **Decision:** half to even.
- **Rationale:** it is the behavior in the package today, and naming it costs
  one sentence. Section 3.3 now records that a reader who hand-checks 41.25
  gets 41.3 while the workbook prints 41.2, so a tester does not file that as a
  defect.

**Q: Issue 29 (SUGGESTION) — the rule has a floor string and no ceiling, so a
cell can read `100.0%` when the value is below 100. Add the ceiling?**

- Options considered:
  - **A — Add the symmetric form:** `1 - 0.5 x 10^-decimals < p < 1` prints
    `>99.9%` at `decimals = 1`, scaling with `decimals` as the floor does. One
    more form joins invariant 8.1.
  - **B — Do nothing:** a near-unanimous cell reads as unanimous, and the spec
    does not record that it chose that.
- **Decision:** A.
- **Rationale:** the argument that earns `<0.1%` earns `>99.9%`. A reader who
  sees `100.0%` concludes the complement is empty, and section 3.9 already
  removed the `100%` row because the visible cells do not total 100.

**Q: Issue 31 (REQUIRED) — the interval is a Wald interval and is not clipped,
so a rare category prints a negative percentage. Clip or explain?**

- Options considered:
  - **A — Clip the printed bounds to 0 and 100:** no negative cell. The printed
    number is no longer what surveycore returned, which section 3.12 promises.
  - **B — Print as returned, and say in 3.12 and the glossary that the interval
    is a normal approximation that can fall outside 0 to 100 percent:** the
    delegation stays literal; a negative cell still ships, with an explanation.
- **Decision:** B.
- **Rationale:** section 3.12's whole argument is that the interval is
  surveycore's and is not restated here. Clipping breaks that and hides an
  approximation the reader should see. The measured case is real: a category
  held by 2 of 300 rows returns `ci_low = -0.00343`.

**Q: Issue 32 (SUGGESTION) — the legend row asserts 95% coverage while the spec
declines to characterize the interval. Drop the claim or record what it rests
on?**

- Options considered:
  - **Keep the legend and record the measurement** in section 1.4's
    upstream-state table: normal approximation, multiplier `qnorm(1 - alpha/2)`,
    no degrees of freedom, identical on taylor, replicate and twophase.
  - **Soften the legend:** costs the reader the one fact they need beside a
    bracketed number.
- **Decision:** keep the legend, record the measurement.
- **Rationale:** section 1.4 exists for facts about the dependency. If
  surveycore moves to a t interval on design df, every number changes and the
  legend does not; the recorded row gives that change something to be detected
  against.

**Q: Issue 37 (REQUIRED) — the floor is tested on a base that ignores the
tabulated variable, so a question with heavy item nonresponse can publish a
cell below the floor. Restate the guarantee or move the test?**

- Options considered:
  - **A — Keep the subgroup-level floor and state the limit** in section 3.5
    and the glossary. Low effort, low risk. The rule's guarantee becomes the
    one it delivers.
  - **B — Test the floor per variable**, on the design restricted to that
    variable's non-missing rows. High effort, high risk. Withholding becomes
    per question, so the column geometry differs between blocks on one sheet
    and the two sample-size rows stop being block-invariant.
- **Decision:** A.
- **Rationale:** B is a larger change than this spec is making, and it breaks
  the shared column geometry the stacked layout depends on. A costs two
  sentences and makes the claim true. Read with issue 25: both are the same gap
  between what `n_eff` measures and what the glossary said it means. Section VI
  also drops its claim that the per-response count is recoverable as percent x
  sample size, which item nonresponse makes false.

### Outcome

The spec reaches v0.9.0. Percentages, standard errors and interval bounds are
all rendered on the percentage-point scale, the cell rule gains a ceiling
string, the glossary describes Kish and states both limits of the floor, the
interval bounds print unclipped with a glossary entry explaining why, and
`min_eff_n` gains a validation step and the error class
`surveyreports_error_invalid_min_eff_n`.

---

## [2026-09-16] — Stage 3r resolve: the 33 Pass 4 issues

### Context

Pass 4 of `plans/spec-review-export-metadata.md` returned BLOCK against the
spec at v0.9.0 and the test-spec at v0.5.0: 2 BLOCKING, 16 REQUIRED, 15
SUGGESTION, issues 36 to 68. The pass also re-opened Passes 1 to 3 and found 5
regressed issues — 8, 15, 20, 23 and 30. None was the same defect the earlier
pass found; each was the same class of defect, put back by the v0.8.0 rewrite
at a new location.

All 33 issues are resolved, across 8 batches. The unambiguous fixes were
applied as written. The judgment calls are recorded below. The spec moves from
v0.9.0 to v0.17.0 and the test-spec from v0.5.0 to v0.13.0.

### Questions & Decisions

**Q: Issue 36 (REQUIRED) — the proportion-to-percentage conversion is a rule in
three sections and arithmetic at every call site. Who owns it?**

- Options considered:
  - **A — `.fmt_pct()` takes the proportion and multiplies by 100 itself:** no
    call site does arithmetic. One place to change if surveycore ever returns
    percentages.
  - **B — keep the caller contract and name the conversion with `.as_pp()`:**
    the multiplication still sits at every call site, behind a helper that is
    one expression.
- **Decision:** A.
- **Rationale:** the spec predicted the defect the design invited — a forgotten
  `* 100` prints every standard error as `0.0`. Two of the five shipped inline
  conversions retire: `R/export-crosstab.R:580` and `:905`. Three stay —
  `R/export-topline.R:379` and `:394`, and `R/export-utils.R:745` inside
  `.sata_pct_cell()`, which only `export_topline()` still calls. `.fmt_pct()`
  returns a string and a topline cell holds a number, so calling the formatter
  at any of the three would move output that section 4.1's scope line holds
  fixed. Section VI records the cost: one rule with two implementations for the
  life of this branch.

**Q: Issue 37 (REQUIRED) — the eight-step block sequence is implemented three
times. Extract it, and into which file?**

- Options considered:
  - **A — `.render_block_preamble()` and `.render_block_footer()` in
    `R/export-utils.R`,** which is what the review recommended, on the
    reasoning section 2.1 gives for `.fmt_pct()`: the topline pass adopts the
    same block shape.
  - **B — the same two helpers in `R/export-crosstab.R`,** below the exported
    function.
- **Decision:** B.
- **Rationale:** all three call sites are in that one file, which is what
  `code-style.md`'s placement table requires. The scheduled second call site
  does not apply here. Measured: `.render_topline_single()` and
  `.render_topline_sata()` write the title inline at `R/export-topline.R:244`
  and `:492`, they write no spanner row, and the name `col_groups` appears
  nowhere in that file. So the topline render helpers do not share the block
  shape today. The precedent is the 2026-09-10 decision, which moved
  `.unique_sheet_name()` back to its single call-site file on the same
  reasoning. Section 2.1 records that the topline pass promotes both helpers to
  the shared file when it adopts the shape.

**Q: Issue 40 (SUGGESTION) — the below-floor test reads as four applications
with no single owner. Add `.apply_eff_n_floor()`?**

- Options considered:
  - **A — a new helper returning `list(keep = , withheld = )`.**
  - **B — no new helper; state that one test over one frame serves all three
    subgroup kinds.**
- **Decision:** B.
- **Rationale:** `.build_withheld()` already holds the comparison
  `n_eff < min_eff_n`, so a second helper would duplicate the exact error the
  issue exists to prevent — a `<=` in two places. Section 3.5 now says that the
  three subgroup kinds are one test over the `.resolve_eff_n()` frame, that the
  kept levels are a set difference and run no second comparison, and that the
  full-sample test is separate and warns. The test-spec gains one boundary
  scenario, `XW-13`: a subgroup whose effective N equals `min_eff_n` stays
  published, so a `<=` implementation fails a row.

**Q: Issues 42 and 43 (SUGGESTION) — the two collided. Issue 42 asked for the
wave unanimity clause on `.design_universe()`'s declaration; issue 43 asked for
that helper to be folded away. Which?**

- Options considered:
  - **A — take issue 42 alone:** the clause lands on a declaration, and two
    helpers with one caller each keep their names.
  - **B — take issue 43 and move the clause to the surviving helper.**
- **Decision:** B.
- **Rationale:** writing both would put the rule on a declaration that no
  longer exists. `.roles_of()` folds into `.resolve_roles()`, which now reads
  each member itself and owns the coercion rule of section 3.10.
  `.design_universe()` folds into `.resolve_base_notes()`, which now reads the
  universe itself and owns the wave unanimity rule of section 3.6, so the rule
  stays visible after the helper that would have carried it disappears. This
  reverses the 2026-09-10 decision that declared the two helpers; section XI
  records the reversal. `.banner_heading()` stays, for its `fell_back` return:
  `.emit_missing_label_warning()` detects a fallback over a rendered `vars`
  frame, and a banner column has no row in that frame.

**Q: Issue 46 (SUGGESTION) — the snapshot obligation stands in both artifacts
and in gate VIII. Move it to the test-spec, or delete it?**

- Options considered:
  - **A — move it:** the obligation is a test-run gate, so the test-spec keeps
    it and the spec drops it.
  - **B — delete the generic obligation from both.**
- **Decision:** B.
- **Rationale:** `.claude/rules/testing.md` already owns the review procedure
  and loads into every session, so either artifact restating it is a third copy
  that can be edited alone. Each artifact keeps only the fact that belongs to
  it: the spec keeps section 5.1's row that every committed crosstab snapshot
  moves, and section 5.2's scope line on which topline snapshots may move; the
  test-spec keeps the same fact for the tester. Gate VIII lost the checkboxes
  that no reader could verify without running the suite, which its own opening
  sentence promises — it is source-tree checks only.

**Q: Issue 47 (BLOCKING) — `.build_workbook()` takes the withheld list, and the
list does not exist when the workbook is built. Which order?**

- Options considered:
  - **A — estimate, withhold, build, render.** The signature becomes honest and
    section 3.11 gains the step.
  - **B — build first with an empty `"About"`, render, then fill the cover
    sheet.** The sheet is written twice.
- **Decision:** A.
- **Rationale:** the shipped code already runs in this order, so the signature
  was wrong and the code was not. Measured: both call sites call
  `.build_workbook()` immediately after `.build_freq_frame()` returns —
  `R/export-crosstab.R:181` and `:193`, `R/export-topline.R:118` and `:128`.
  Sheet order in openxlsx2 is insertion order, `wb_add_worksheet()` takes no
  index and no `after`, so `"About"` is sheet 1 even though the build runs at
  step 16. Issue 64 is resolved in the same edit: `.write_cover_sheet()` takes
  no `withheld_note`, and the caller passes `withheld = NULL` unless
  `withheld_note` is `"once"`.

**Q: Issue 48 (BLOCKING) — `.total_col_group()` holds the two strings section
3.9 changes, and `export_topline()` calls it. Parameterize or fork?**

- Options considered:
  - **A — `.total_col_group(total_label = "Total", spanner = "Total")`,** so an
    argument-free call returns what it returns today.
  - **B — fork it into `.total_col_group_crosstab()`,** leaving two
    near-identical constructors in a shared file.
- **Decision:** A.
- **Rationale:** the topline output stays byte-identical. `.cell_rows()`
  branches on `identical(cg$type, "total_col")` and then filters
  `frame$subgroup_type == "total"`, so it reads neither `spanner` nor `levels`;
  every read site for those two fields is in `R/export-crosstab.R`. And
  `tests/testthat/_snaps/export-topline.md` holds nine snapshots, all error
  messages, none carrying `Total`, `Eff` or `spanner`. Option B would
  contradict gate VIII's helper count, which reads from section 2.1's file
  table. Measured as well: the helper has six call sites in three files, not
  the four the crosstab route suggests, and only the three crosstab sites pass
  arguments.

**Q: Issue 49 (REQUIRED) — a cell written at one decimal is asserted against an
unrounded oracle at tolerance `1e-8`. Round the oracle, or widen the
tolerance?**

- Options considered:
  - **A — round the oracle to the cell's precision** and keep the tolerance.
  - **B — widen the tolerance to `0.05`,** which hides a real error of `0.049`
    and breaks `testing.md`'s tolerance table.
- **Decision:** A, applied to all seven affected rows and not to the two the
  review named.
- **Rationale:** the effective sample size measures `184.979064` on the taylor
  design at `seed = 42` and the one-decimal cell holds `185.0`, a gap of
  `0.0209` — seven orders above `1e-8`. Every row with the same shape fails on
  correct code, so fixing two would leave five. `XS-03`, `XS-04`, `XN-02`,
  `XN-03` and `TN-04` round the oracle to one decimal. `TN-01` and `TN-03`
  assert an exact string instead, because those two cells are header text
  holding a whole number with a thousands separator. The tolerance section now
  states the rule once and says a tolerance is never widened to absorb
  rounding.

**Q: Issue 52 (REQUIRED) — B9 and the cover-sheet styling have no scenario. How
much of it can a test read back?**

- Options considered:
  - **A — a row for each stated property:** the widths, the wrapping and
    heading height, and the freeze pane under both values of
    `sample_size_display`.
  - **B — cover the freeze pane and the bold only,** and mark the widths and
    the wrapping N/A.
- **Decision:** A — four sheet-property rows, `XB-01` to `XB-04`, plus `XA-12`
  for the cover sheet's bold header and block headings. Section 3.16 also gains
  a heading-row height number, fixed at 30 points, so the row can assert a
  value.
- **Rationale:** four of the five properties read back cleanly from a saved
  workbook. A stored column width does not: a width set to 44 reads back a
  little above it, so `XB-01` compares on a rounded value rather than on the
  integer. `XB-02` then carries the claim the fixed-width rule rests on — two
  calls whose response labels differ in length give the same widths — so an
  auto-fit implementation fails a row instead of passing both.

**Q: Issue 53 (REQUIRED) — five warning rows cite a "dual pattern" that
`.claude/rules/testing.md` defines for errors only. Define it, or drop the
term?**

- Options considered:
  - **A — define the warning form in the test-spec** and apply it to every new
    or changed class.
  - **B — state that warnings are class-only** and remove the term from the
    five rows, which ships two new user-facing messages with nothing pinning
    their text.
- **Decision:** A, in the test-spec alone. `.claude/rules/testing.md` is
  flagged for the same addition as a separate change.
- **Rationale:** a warning message is user-facing text, so a class with no
  snapshot ships unpinned. The test-spec's conventions section now gives the
  warning form, records that no warning snapshot exists in the tree today, and
  says the repo rule needs the same addition. Editing a repo-wide standard
  inside this spec's PR was declined: the rule file serves every future change
  and its edit gets its own review.

**Q: Issue 61 (SUGGESTION) — the signature's argument order does not match
`code-style.md`. Move `interactions`, or replace the claim?**

- Options considered:
  - **A — move `interactions` ahead of `layout`,** which conforms and adds an
    eighth breaking change.
  - **B — keep the signature and replace the conformance claim with the
    reason.**
- **Decision:** B.
- **Rationale:** exactly one of the nineteen arguments sits outside its group,
  and it is `layout`, which ships in that position — measured 2026-09-16 as the
  fifth argument. Moving it would break a positional call that works today for
  no behavioral gain. `code-style.md` also contradicts itself: its numbered
  list puts an optional tidy-select ahead of every optional scalar, and its
  worked example for this very function puts them the other way round. The
  current signature matches the example. The rule file needs its own
  correction, as a separate change.

**Q: Issue 63 (SUGGESTION) — a design variable in `vars` or `banner` renders as
a question. The review recommended parking the case. Park it or close it?**

- Options considered:
  - **A — drop the column with the role warning,** treating the design's own
    columns as `role = "weight"`.
  - **B — park it in section 1.3,** on scope discipline.
  - **C — abort.**
- **Decision:** C. The user overrode the review's recommendation.
- **Rationale:** in the user's words, the fact a column is in the survey object
  design is enough to indicate the role even if the user does not state the
  role separately. Two follow-up decisions the user made set the reach: the
  scope is every column the design names in any slot, not weights, strata and
  PSU alone; and a column whose metadata `role` reads `"weight"` while the
  design does not name it keeps its existing drop-with-warning, so the two
  mechanisms stay separate. The result is the error class
  `surveyreports_error_design_variable_selected`, a new helper
  `.reject_design_vars()` holding a per-subclass slot reader, step 9 of section
  3.11 — after both tidy-select resolutions, before the role guard, so the
  error wins over the drop — and a breaking change in section 5.1. Measured old
  behavior on a 200-row taylor design: `vars = c(q1, wt)` returns the path and
  writes a second sheet named `wt` with 204 rows, raising only
  `surveyreports_warning_missing_variable_label`.

**Q: The unreachable effective-N branch, found mid-round and not by Pass 4 —
delete it, mark it, or make it fire?**

- Options considered:
  - **A — delete the branch.**
  - **B — mark it `# nocov`,** which keeps an unreachable branch in the file.
  - **C — compute a pooled effective N** so the branch has something to read.
- **Decision:** A. Recorded as decision 1, 2026-09-16.
- **Rationale:** the collection `Total` header's branch at
  `R/export-topline.R:288-296` reads the pooled `Total` row's `eff_n`, and
  `.build_freq_frame()` returns `NA_real_` for every row whose `subgroup_type`
  is `"total"`, so the branch never fires. Deleting it changes no cell, so
  section 5.1 does not list it as a breaking change. A `# nocov` marker would
  leave the next reader to derive again that the branch cannot fire. C is a
  methodology question, not a presentation one: a single pooled Kish effective
  N over waves with different designs is not a quantity this spec defines, and
  keeping `NA_real_` is the no-change option.

**Q: The `\dontrun{}` gap — `package-conventions.md` forbids it and both
functions still wrap their examples. Close it here?**

- Options considered:
  - **A — convert both to the `tempfile()` pattern** the rule file supplies.
  - **B — leave it out and park it in section 1.3.**
- **Decision:** B. Recorded as decision 2, 2026-09-16.
- **Rationale:** the conversion touches roxygen alone and has no dependency on
  anything in this spec, so it runs as its own documentation change. Section
  1.3 now names it, so a reader does not read the omission as an oversight.

**Q: Issue 66 (REQUIRED) — `"Full Sample"` labels a domain-restricted subset.
Change the heading, add a cover-sheet row, or both?**

- Options considered:
  - **A — `total_label` defaults to `NULL` and resolves to `"Total"`** when the
    design carries the domain column, and to `"Full Sample"` otherwise.
  - **B — a cover-sheet row naming the restriction** and its in-domain count.
- **Decision:** both A and B.
- **Rationale:** A removes the false claim without inventing a label the
  package cannot know — the design keeps no record of the expression that set
  the domain. B is necessary beside A, not a follow-on: with A alone, two
  workbooks from the same data show two headings over one column and nothing in
  either file explains the difference. The row reads `Restricted to` against
  `75 of 200 rows`, and `.has_domain()` is the check — surveycore exports no
  domain accessor, so testing `SURVEYCORE_DOMAIN_COL` against
  `names(design@data)` is the only route. No glossary entry was added for the
  row: every entry in that table explains a rule the cells follow, while this
  row states a fact about the design and carries its own two numbers. Section
  5.1 records that the `NULL` default adds no breaking change — `total_label`
  is new, and every crosstab snapshot moves in any case.

### Outcome

The spec reaches v0.17.0 and the test-spec v0.13.0.

The spec adds **18 new helpers: 15 in `R/export-utils.R` and 3 in
`R/export-crosstab.R`** — `.render_block_preamble()`, `.render_block_footer()`
and `.unique_sheet_name()`, all below the exported function. Section 2.1's file
table is the list, and gate VIII's counts read from it. Four helpers reach the
shared file on the ordinary two-file rule, and three reach it on a stated
exception that the PR description must repeat. Two existing helpers change
shape without counting toward the 18: `.empty_suppressed()` loses its
`pub_type` column, and `.total_col_group()` gains `total_label` and `spanner`
with string-preserving defaults.

`.fmt_pct()` owns the percentage scale, `.build_withheld()` owns the floor
test, and `.resolve_base_notes()` and `.resolve_roles()` each own the rule its
folded-away helper would have carried. One new error class ships:
`surveyreports_error_design_variable_selected`, raised in
`.reject_design_vars()` for `vars` and for `banner`, so it reaches both export
functions.

Part A's write surface in `R/export-topline.R` widened from three items to five
across the round, recorded each time rather than absorbed. The five are the
`all_of()` fix, the role guard, the threaded base notes, the design-variable
check and the deletion of the dead effective-N branch. The presentation in that
file does not change: the three remaining inline `* 100` conversions stay, and
gate VIII greps for exactly three.

---

## [2026-09-16] — Stage 3r addendum: versions 0.18.0 and 0.19.0

### Context

The entry above closes at spec v0.17.0. Three pieces of work followed it and
moved the spec to v0.19.0. None of the three was a judgment call, so each is
recorded here as a fact rather than as a question.

### What changed

**v0.18.0 — the class list and the citation policy.** `plans/error-messages.md`
was eight rows behind the spec. It gained four error classes
(`vars_all_dropped`, `banner_empty_selection`, `duplicate_value_label`,
`multiple_unlabelled_codes`) and four warning classes (`role_dropped`,
`unknown_role`, `banner_all_withheld`, `full_sample_below_min`).
`surveyreports_warning_subgroup_suppressed` was renamed
`surveyreports_warning_subgroup_withheld` in place, with no note of the old
name, because gate VIII greps the source tree for the old string.
`missing_variable_label`'s row was rewritten for its extended trigger. Fifteen
decaying line citations were replaced by helper names, under the policy stated
in the spec's Document purpose section.

**Two gate VIII defects, found and fixed.** The grep
`grep -rn "subgroup_suppressed" R/ plans/` could never pass, because sections
3.18, 5.1 and gate VIII itself all name the old class to record the rename. The
scope is now `R/ man/ tests/`, with the reason stated. One decaying citation in
section 4.2 was converted at the same time.

**v0.19.0 — Pass 5's two findings.** The delta pass returned PASS and raised two
rows that fail against correct code:

- Section 3.5 carried the headline "no second warning fires", while its own body
  said the narrower and correct thing — that this spec adds no warning class for
  the empty block. `surveyreports_warning_subgroup_withheld` does fire there,
  because subgroups fell below the floor. The headline now says what the body
  says, and `XX-13` asserts both classes.
- `has_banner` had no stated meaning, so `XA-05` was ambiguous at a floor that
  withholds every banner level. Section 3.15 now says `has_banner` records that
  the caller supplied a `banner`, not that a column survived the floor — so
  `Why a column is missing` still appears when every level is withheld, which is
  the case that most needs it. `XA-05`'s floor moved to `50`, below every
  `group` level's effective N, so the row is about the glossary alone and raises
  no withholding warning.

### Outcome

The spec is v0.19.0 and the test-spec is v0.14.0. `plans/error-messages.md`
holds every class the two functions raise. Two template rows in that file,
`surveyreports_error_not_data_frame` and `surveyreports_warning_example`, are
raised nowhere in `R/` and are left for a separate cleanup.
