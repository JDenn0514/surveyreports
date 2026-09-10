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
