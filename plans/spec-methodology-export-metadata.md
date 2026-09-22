# Methodology Review: export-metadata

Reviews of `plans/spec-export-metadata.md`. Append-only. Never overwrite a pass.

---

## Methodology Review: export-metadata — Pass 1 (2026-09-09)

### Scope assessment

Stage 2 **applies**. The spec changes `eff_n`, a published statistic, and it
changes the rule that decides whether a subgroup is published at all. It also
adds three delegation contracts with surveycore (`extract_universe()`,
`extract_var_extra()`, `extract_dataset_metadata()`) and states cross-design
behavior in section 1.4. Four of the five lenses apply. Lens 2 does not.

### Evidence base

Every claim below was measured on 2026-09-09 against surveycore `1.1.0.9000`,
the same version the spec cites. Commands ran in this repository against
`make_all_designs(seed = 42)`. Measurements are quoted inline with each issue.

---

### New Issues

#### Lens 1 — Output Column Contracts

**Issue 1: `export_crosstab()` never renders `eff_n`, so workstream 1's stated symptom is not user-visible for that function**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: JUDGMENT CALL

Section 3.2 says the first user-visible failure is
"`show_eff_n = TRUE` → `eff_n` is `NA`, silently". Section 9.2 row 1 asks a test
to assert that `eff_n` "is finite and equals the value computed from the correct
row subset".

`show_eff_n` reaches all three crosstab renderers and none of them read it.
Measured — the parameter appears at `R/export-crosstab.R:498`, `:653` and `:773`
and at no other line in the render bodies:

```
$ awk 'NR>=490 && NR<=944 && /eff_n/' R/export-crosstab.R
  show_eff_n,
  show_eff_n,
  show_eff_n,
```

The one place any workbook prints an effective N is the topline Total header,
`R/export-topline.R:288-289` and `:321-322`. Both read
`frame$eff_n[frame$subgroup_type == "total"]` — the whole-design value, computed
by `.compute_eff_n(design)` with no banner. That is the one call workstream 1
does not change.

Two consequences:

1. `show_eff_n = TRUE` on `export_crosstab()` is a no-op argument today. The spec
   does not say so, and a reader of section 3.2 will believe otherwise.
2. Test row 1 cannot assert on a workbook for crosstab. It can only assert on the
   internal frame, which `testing.md` treats as a last resort.

The suppression harm in section 3.2 row 2 is real and is unaffected by this.

Options:
- **[A]** State in section 3.2 that crosstab does not render `eff_n`, restrict
  test row 1 to `export_topline()`, and add a sixth workstream that renders
  `eff_n` in the crosstab spanner — Effort: medium, Risk: medium, Impact: every
  committed crosstab snapshot with `show_eff_n = TRUE` changes, which section 9.4
  currently forbids.
- **[B]** State the fact in section 3.2, restrict test row 1 to
  `export_topline()`, and park the unrendered crosstab `eff_n` in section 1.3
  next to `higher_is` and `var_note` — Effort: low, Risk: low, Impact: the spec
  becomes accurate; `show_eff_n` stays a no-op on crosstab.
- **[C] Do nothing** — the spec overstates the defect, and an implementer writes
  test row 1 against a column no workbook shows.

**Recommendation: B** — the spec's own scope in section 1.3 is narrow, and adding
a render changes snapshots that section 9.4 protects.

---

**Issue 2: the label-vocabulary decision skips interaction subgroups**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Section 3.4 makes `subgroup_value` canonicalize on the value label. It lists
three consequences, all about banner rows. Interaction rows also carry
`subgroup_value`, and they are built from a different source.

`.compute_interaction_freq()` at `R/export-utils.R:238-242` builds the grouping
column from `@data`:

```r
design@data[[interact_col]] <- do.call(
  interaction, c(design@data[banner_vars], list(sep = " × "))
)
```

`@data` holds codes. Measured on a design with
`gen = c(Male = 1, Female = 2)` and `reg = c(North = 1, South = 2)`:

```
levels(interaction(d@data[c("gen","reg")], sep = " x "))
[1] "1 x 1" "2 x 1" "1 x 2" "2 x 2"
```

The new interaction column carries no value labels, so `get_freqs()` returns
those code strings unchanged. `.build_col_groups()` at
`R/export-crosstab.R:384` takes the spanner levels straight from them.

The result is one workbook with two vocabularies: the `gen` spanner shows
`Male` and `Female`, and the `gen × reg` spanner shows `1 × 1`. Section 3.4
declares a single canonical vocabulary and does not deliver it.

Fix: translate each banner column to its labels before `interaction()` runs,
using the same label lookup `.banner_row_mask()` needs. A character or factor
banner already stores its label, so the lookup is a no-op there.

---

**Issue 3: the cover sheet contract omits sheet naming, ordering and header conflicts**
Severity: SUGGESTION
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Section 6.2 names the two columns and their order. Three things stay unstated:

1. **Header row.** The table has a display label and a value. The spec does not
   say whether row 1 is a header (`Key` / `Value`) or the first data row.
2. **Active sheet.** `openxlsx2::wb_workbook()` creates no sheets, so `"About"`
   becomes sheet 1 and the active sheet. Every workbook with dataset metadata
   opens on the cover sheet instead of the data. State this as intended.
3. **Name collision.** Sheet names come from the variable name, truncated to 31
   characters — `R/export-crosstab.R:207`. A variable named `About` in
   `per_question` layout collides with the cover sheet. openxlsx2 aborts on a
   duplicate sheet name.

All sheet references in both export functions are by name, not index, so
inserting a first sheet is otherwise safe. Measured — `wb_add_worksheet` and
every `sheet =` argument take the name.

Fix: add a header row, say the cover sheet is active on open, and state the
collision rule. Suffixing a colliding data sheet is the smaller change, because
the cover sheet name is fixed and a user cannot rename it.

---

**Issue 4: the universe fallback is per-variable, but the base note is per-table**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: JUDGMENT CALL

`.base_note_for()` at `R/export-utils.R:656-665` keys on
`frame$variable[[1L]]` — the sole variable of a single-choice table, or the
**first member** of a SATA or battery group. Its own comment says so.

Today that is harmless. `base_notes` is a caller-supplied vector, and a caller
who names only the first member of a battery gets what they asked for.

The universe fallback removes that intent. `extract_universe()` returns one
entry per variable, and a battery cleaned by the ADL schema will carry a
universe on all five members. `.base_note_for()` will read member 1's universe
and print it over the whole block, silently, whether or not the other four
members agree. If member 1 alone has no universe set, the block shows nothing
even when the other four do.

Section IV does not mention groups. It needs a rule.

Options:
- **[A]** Print the universe only when every member of the group carries the same
  text; otherwise print none — Effort: medium, Risk: low, Impact: never states a
  universe that is false for a member of the block.
- **[B]** Keep first-member semantics and document it — Effort: low, Risk: medium,
  Impact: a battery can carry a base note that is wrong for four of its five
  items, with no signal.
- **[C]** Print the universe only for single-choice tables; skip the fallback for
  SATA and battery blocks — Effort: low, Risk: low, Impact: no false text, and no
  universe on the blocks that most often need one.

**Recommendation: A** — it matches the rule the same question gets in section 4.4
for collections, and a block whose members disagree is exactly the case where a
single line cannot be correct. Note that A and the collection answer in open
question 7 should be decided together.

---

#### Lens 2 — Confidence Interval Specification

Lens 2 not applicable: the spec changes no estimate, no standard error, and no
confidence bound. `conf_level` is threaded to `surveycore::get_freqs()` unchanged
at `R/export-utils.R:283`, and none of the five workstreams touches that path.

---

#### Lens 3 — Statistical Delegation Accuracy

**Issue 5: `surveycore::get_effective_n()` already returns what workstream 1 reimplements, in the vocabulary workstream 1 is trying to reach**
Severity: BLOCKING
Lens: 3 — Statistical Delegation Accuracy
Resolution type: JUDGMENT CALL

Section 9.3 states: "`.compute_eff_n()` has no surveycore counterpart, so the
reference is a direct computation in the test."

That is false. surveycore `1.1.0.9000` exports `get_effective_n()`. Measured:

```
> get_effective_n(d, group = gen)
# A tibble: 2 × 4
  gen        n n_eff deff_kish
  <fct>  <int> <dbl>     <dbl>
1 Male     180 167.       1.08
2 Female    20  18.1      1.11
```

It returns, in one call and per banner level:

- `n` — the raw count the suppression loop computes at `R/export-utils.R:422`
- `n_eff` — the Kish effective N `.compute_eff_n()` computes at `:156`
- the level as a **factor labelled the same way `get_freqs()` labels it**

The numbers agree. Measured on 100 rows: `get_effective_n(d)$n_eff` is
`93.59602`, and `n / ((n * sum(w^2)) / sum(w)^2)` is `93.59602`. Section 3.6's
formula and surveycore's `method = "kish"` default are the same estimator.

This matters beyond DRY. The label-to-code translation is the whole subject of
workstream 1. `get_effective_n()` returns the label already, from the same
`.apply_group_labels()` path `get_freqs()` uses, so the two frames cannot
disagree. `.banner_row_mask()` is a second, independent implementation of a
join that surveycore performs. Sections 3.5 and 3.7 spend most of workstream 1
specifying its edge cases — the unobserved label, the duplicate label, the
`as.vector()` class strip. Delegation removes all of them, and issues 6, 9 and
12 below with them.

`CLAUDE.md` engineering principle 1 asks for a shared helper when logic repeats
across two functions. This is stronger: the logic already exists upstream, in the
package the spec's own section 1.3 says every estimate is delegated to.

Options:
- **[A]** Replace `.compute_eff_n()` and `.banner_row_mask()` with one
  `get_effective_n()` call per banner column, joined to the frame on the label —
  Effort: medium, Risk: low, Impact: workstream 1's edge cases collapse into
  surveycore's; issues 6, 9 and 12 are resolved as a side effect; section 9.3's
  reference becomes `get_effective_n()` per `testing.md`'s numerical-accuracy
  rule.
- **[B]** Keep the local implementation and fix its edge cases as specified —
  Effort: high, Risk: high, Impact: surveyreports carries a second Kish estimator
  that must track surveycore's domain, twophase and labelling rules by hand.
- **[C] Do nothing** — section 9.3 stays factually wrong, and the test compares
  the implementation to a copy of its own formula, which proves nothing about
  agreement with the frequencies it annotates.

**Recommendation: A** — verify first that `get_effective_n()`'s per-level output
joins cleanly to `get_freqs()`'s group column for character, factor and labelled
banners. If it does, workstream 1 becomes a deletion.

---

**Issue 6: the duplicate-value-label decision is unreachable — `get_freqs()` aborts first**
Severity: BLOCKING
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Section 3.5 confirms a decision: "a duplicate label warns and unions the codes."
Section VIII adds `surveyreports_warning_duplicate_value_label`. Section 9.2
row 5 asks for a test that the warning fires and "`eff_n` equals the union of
both codes".

Neither the union nor the workbook exists. `set_val_labels()` accepts a duplicate
label, and `get_freqs(group = )` then aborts inside surveycore. Measured with
`gen = c(Male = 1, Female = 2, Female = 3)`:

```
> get_freqs(d2, q1, group = gen)
Error in `levels<-`(`*tmp*`, value = as.character(levels)) :
  factor level [3] is duplicated
Calls: ... get_freqs -> .apply_group_labels -> factor
```

The suppression loop runs before `.compute_subgroup_freq()`, so the specified
behavior is: warn, compute a union effective N nobody sees, then abort with an
opaque error naming a surveycore internal. Test row 5 cannot assert the union.

Two things are wrong at once. The union semantics are unobservable, and the
failure the user actually gets is unhandled.

Fix: reverse the section 3.5 decision. A duplicate value label on a banner column
is not a case with a sensible reading — it is bad input that the render path
cannot process. Detect it during validation and abort with a named class, before
any estimate runs. Change `surveyreports_warning_duplicate_value_label` to
`surveyreports_error_duplicate_value_label` in section VIII, and change test
row 5 to the dual error pattern.

This issue survives issue 5. Delegating to `get_effective_n()` does not help,
because the abort is in `get_freqs()`, and both functions call
`.apply_group_labels()`.

---

**Issue 7: `.resolve_roles()`'s return contract breaks on the payloads surveycore allows**
Severity: REQUIRED
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Section 2.2 says `.resolve_roles()` returns "named character vector, one entry
per element of cols, `NA_character_` where no role is set".

Section 5.1 states the reason this cannot be assumed: surveycore "stores and
returns the payload unchanged and never reads it". There is no validation.
Measured:

```
> d <- set_var_extra(d1, q1 = list(role = c("item","demographic")),
+                        q2 = list(role = 3L))
> extract_var_extra(d)
$q1$role
[1] "item"        "demographic"
$q2$role
[1] 3
```

Both were accepted. A one-entry-per-column character vector cannot hold either.
The obvious `vapply(..., character(1))` implementation aborts on the first:

```
Error in vapply(...) : values must be length 1,
 but FUN(X[[1]]) result is length 2
```

The role guard reads foreign metadata written by a cleaning pipeline this package
does not control. It must not abort on a payload shape it did not expect.

Fix: state the coercion rule in section 5.2. A `role` that is not a length-1
character is treated as unset — the column is kept, and the existing
`surveyreports_warning_unknown_role` fires naming the column. Add a test row for
a length-2 and a non-character `role`.

---

**Issue 8: section 4.4's quoted abort message is not the message surveycore raises**
Severity: SUGGESTION
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Section 4.4 quotes, as measured evidence:

```
✖ `x` must be a survey design object or a data frame, not
  <surveycore::survey_collection>.
```

Measured on a two-wave collection today:

```
✖ A <survey_collection> has no single set of dimensions.
ℹ It holds 2 surveys, each with its own row and column counts.
✔ Extract one member with `[[` and ask that survey instead, e.g. the member
  named "wave1".
```

Section 6.3 says `extract_dataset_metadata()` aborts "with the same message" —
that part holds; both raise the dimensions message.

The conclusion of both sections is correct and the required branch is unchanged.
Only the quoted evidence is stale. Correct the quote, so a later reader does not
match on the wrong string.

---

#### Lens 4 — Cross-Design Consistency

**Issue 9: twophase `eff_n` is computed over phase-1 rows and published against a phase-2 frequency table**
Severity: BLOCKING
Lens: 4 — Cross-Design Consistency
Resolution type: UNAMBIGUOUS

Section 1.4 states that a twophase design needs nothing from workstreams 1 to 5,
because "`.compute_eff_n()` already falls back to `@variables$phase1$weights`".
That fallback is the defect, not the fix.

`.compute_eff_n()` reads `nrow(design@data)`. For a twophase design `@data`
holds every phase-1 row. `get_freqs()` estimates over the phase-2 subset.
Measured on `make_all_designs(seed = 42)$twophase`:

```
nrow(@data):                     200
get_freqs(tp, q1) total n:       119
current .compute_eff_n(design):  184.98
surveycore get_effective_n:      110.15
```

This number is published. `R/export-topline.R:321-322` writes it into the
percentage column header:

```
%
(Eff N=185)
```

over a column whose N column reads 119. An effective N above the raw N is
impossible, and a reader has no way to tell which figure is wrong.

It also drives suppression. `pub_type = "external"` suppresses below an effective
N of 100. A twophase subgroup whose true effective N is 60 reports 100 or more
and is published — the same harm section 3.2 row 2 describes for labelled
banners, on a design type section 1.4 declares clean.

Section 3.6 keeps the formula and moves only row selection, so workstream 1 does
not touch this.

Fix: this is issue 5's fix. `get_effective_n()` returns 110.15 for the same
design, because surveycore resolves the phase-2 subset. If issue 5 is resolved as
option B, section 3.6 must add an explicit phase-2 row filter and section 1.4's
twophase row must change.

---

**Issue 10: workstream 3 does reach collections, through `vars`**
Severity: REQUIRED
Lens: 4 — Cross-Design Consistency
Resolution type: UNAMBIGUOUS

Section 1.4 lists workstreams "2, 4, 5 only" for `survey_collection`, and gives
the reason: "`export_topline()` accepts one, and its wave path takes no banner,
so workstreams 1 and 3 do not reach it."

Workstream 1 does not reach it — that half is right. Workstream 3 does.
Section 5.2 guards **`vars`** as well as `banner`, and `export_topline()` takes
`vars` for a collection. So `.resolve_roles(design, vars_resolved)` runs on a
collection, and it reads `extract_var_extra()`.

Measured:

```
extract_var_extra(collection): ABORTS
```

Same abort as `extract_universe()` and `extract_dataset_metadata()`. This is the
third instance of the trap sections 4.4 and 6.3 document, and the spec's own
section 1.4 rules it out by mistake — so no branch is specified and no test in
section 9.2 covers it. Rows 17 and 18 gate workstreams 2 and 4 on a collection.
There is no row 19 for workstream 3.

Fix: correct the section 1.4 row to "2, 3, 4, 5", specify the collection branch
in section 5.2 the way section 4.4 specifies it, and add a test row — the role
guard on `vars` for `export_topline()` with a collection.

The branch itself is a judgment the same size as open question 7. Reading the
first member's roles, requiring agreement across members, or skipping the guard
for collections are the same three candidates.

---

**Issue 11: `export_topline()` has no `banner`, so section VIII and section 9.2 assign it tests it cannot have**
Severity: REQUIRED
Lens: 4 — Cross-Design Consistency
Resolution type: UNAMBIGUOUS

`export_topline()`'s signature is `design, vars, file_name, conf_level,
decimals, variance, show_n, show_eff_n, base_notes` —
`R/export-topline.R:54-64`. There is no `banner` argument, and its
`.build_freq_frame()` call at `:117` passes no `banner_resolved`.

Section VIII lists `surveyreports_warning_duplicate_value_label` as raised by
"`export_crosstab()`, `export_topline()`". Topline cannot raise it.

Section 9.2 opens with "Both `test-export-crosstab.R` and
`test-export-topline.R`" and then lists 18 rows. Rows 1 to 6 are labelled-banner
behavior, and row 10 is the role guard on `banner`. Seven of the eighteen rows
are unwritable for topline.

Fix: mark each row in the section 9.2 table with the function or functions it
applies to, and correct the section VIII "Raised by" column. Without this an
implementer either writes seven dead tests or quietly drops them and the coverage
gate does not notice.

---

#### Lens 5 — Domain and Grouping Behavior

**Issue 12: `.banner_row_mask()` and `.compute_eff_n()` ignore the surveycore domain column**
Severity: BLOCKING
Lens: 5 — Domain and Grouping Behavior
Resolution type: UNAMBIGUOUS

surveycore marks a domain with a column, `SURVEYCORE_DOMAIN_COL`, which resolves
to `..surveycore_domain..`. Both estimating functions honor it. Measured on 100
rows with the first 50 in domain:

```
get_freqs(d, q1, group = gen)      -> n = 25 + 25   (50 rows)
get_effective_n(d, group = gen)    -> n = 50, n_eff = 46.8
```

Section 3.5's `.banner_row_mask()` reads `design@data[[col]]` and returns a mask
over every row. Section 3.6 subsets by that mask and by nothing else. Neither
mentions the domain column. The package never references it — measured, the only
matches for "domain" in `R/` are the `surveyreports_error_empty_domain` class,
which fires on a zero-row design.

So for a domain-restricted design the spec produces an effective N and a raw N
over the full sample, printed against percentages estimated over the domain. On
the reproduction above that is 100 against 50 — a factor of two.

The suppression consequence is the same as issue 9 and section 3.2 row 2. A
subgroup whose in-domain effective N is 40 reports 90 and is published under a
threshold of 50.

Fix: this is issue 5's fix again. `get_effective_n()` applies the domain itself.
If issue 5 is resolved as option B, `.banner_row_mask()` must intersect with
`design@data[[surveycore::SURVEYCORE_DOMAIN_COL]]` when that column is present,
section 3.5's contract table needs a row for it, and section 9.2 needs a
domain-restricted test.

---

**Issue 13: interaction banner levels are codes, and no workstream addresses it**
Severity: REQUIRED
Lens: 5 — Domain and Grouping Behavior
Resolution type: UNAMBIGUOUS

Stated as the rendering half of issue 2, and repeated here because it is a
grouping defect, not only a column-name defect. The interaction grouping column
is constructed from codes, carries no value labels, and therefore groups and
labels on codes. A `gen × reg` crosstab reads `1 × 1`, `2 × 1`, `1 × 2`,
`2 × 2` — measured.

Workstream 1 is titled "canonicalize banner levels on value labels" and section
3.4 declares one canonical vocabulary. An interaction is a banner. Either bring
it in scope or state in section 1.3 that it is parked, with the reason.

---

**Issue 14: interaction subgroups are never evaluated for suppression**
Severity: SUGGESTION
Lens: 5 — Domain and Grouping Behavior
Resolution type: JUDGMENT CALL

The suppression loop iterates `banner_resolved` only —
`R/export-utils.R:415`. The `sup_vals` filter is applied to
`.compute_subgroup_freq()` output only, at `:490`. Interaction rows from
`.compute_interaction_freq()` pass through unfiltered.

An interaction cell is by construction smaller than either of its parents, so
this is where a below-threshold subgroup is most likely. A `gen × reg` cell can
hold 12 respondents and publish under `pub_type = "external"`, while the `gen`
column that contains it is withheld.

This is pre-existing and outside the five workstreams. It is raised because the
spec's central claim is that suppression is currently wrong and workstream 1
makes it right. After workstream 1 lands, suppression will still be unenforced on
the cells most at risk, and section X's gate — "the external run omits the Female
rows from the rendered frame" — will pass while that hole stays open.

Options:
- **[A]** Add interaction suppression to this spec as workstream 6 — Effort:
  medium, Risk: medium, Impact: closes the hole; changes any snapshot with
  interactions and a `pub_type`.
- **[B]** Record it in section 1.3 as parked, with the reason and a follow-up
  issue — Effort: low, Risk: low, Impact: the spec stops implying suppression is
  complete after workstream 1.
- **[C] Do nothing** — a later reader takes section 3.2 to mean suppression is
  correct.

**Recommendation: B** — the spec's scope is deliberately narrow, and this is a
distinct defect with its own test surface.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 14

| # | Title | Lens | Severity | Type |
|---|---|---|---|---|
| 1 | crosstab never renders `eff_n` | 1 | REQUIRED | JUDGMENT |
| 2 | interaction subgroups keep the code vocabulary | 1 | REQUIRED | UNAMBIGUOUS |
| 3 | cover sheet naming, ordering, header | 1 | SUGGESTION | UNAMBIGUOUS |
| 4 | universe fallback on a SATA or battery block | 1 | REQUIRED | JUDGMENT |
| 5 | `get_effective_n()` already does workstream 1 | 3 | BLOCKING | JUDGMENT |
| 6 | duplicate value label aborts in `get_freqs()` | 3 | BLOCKING | UNAMBIGUOUS |
| 7 | `.resolve_roles()` breaks on allowed payloads | 3 | REQUIRED | UNAMBIGUOUS |
| 8 | section 4.4 quotes the wrong abort message | 3 | SUGGESTION | UNAMBIGUOUS |
| 9 | twophase `eff_n` uses phase-1 rows | 4 | BLOCKING | UNAMBIGUOUS |
| 10 | workstream 3 reaches collections via `vars` | 4 | REQUIRED | UNAMBIGUOUS |
| 11 | topline has no `banner`; 7 test rows unwritable | 4 | REQUIRED | UNAMBIGUOUS |
| 12 | the domain column is ignored | 5 | BLOCKING | UNAMBIGUOUS |
| 13 | interaction banner levels are codes | 5 | REQUIRED | UNAMBIGUOUS |
| 14 | interactions are never suppression-evaluated | 5 | SUGGESTION | JUDGMENT |

**Overall assessment:** the spec correctly identifies that suppression compares
codes against labels and publishes a subgroup it reports as withheld, and its
metadata shape claims for workstreams 2, 4 and 5 all hold on measurement. The
methodology problem is that workstream 1 rebuilds a helper surveycore already
exports. `get_effective_n()` returns the raw N, the Kish effective N and the
value label in one call, and it resolves the two-phase subset and the domain
column that the local `.compute_eff_n()` silently ignores — issues 9 and 12 are
each a published effective N that exceeds the raw N of the table it labels, on
design types section 1.4 declares clean. Delegating closes three of the four
blocking issues at once. The fourth, the duplicate value label, needs the
confirmed section 3.5 decision reversed, because `get_freqs()` aborts before the
specified union can be observed.

**Issues that resolve together:** 5, 9 and 12 share one fix. 2 and 13 are the
same defect from two lenses. 4 and open question 7 are the same question about
metadata that varies within one rendered table, and should be decided in one
pass.

---

## Methodology Review: export-metadata — Pass 2 (2026-09-09)

### Scope assessment

Stage 2 **applies**, for the same reason Pass 1 gives. The spec changes `eff_n`,
a published statistic, and it changes the rule that decides whether a subgroup is
published. Lenses 1, 3, 4 and 5 apply. Lens 2 does not.

### Evidence base

Every measurement below ran on 2026-09-09 against surveycore `1.1.0.9000`, in
this repository, on `make_all_designs(seed = 42)` and on inline 300-row designs.
Two measurements re-checked spec claims and confirmed them: the twophase pair
119 / 110.15, and the domain pair 75 / 68.65. Both hold.

One thing Pass 1 did not have: the signature of the delegated function.

```r
get_effective_n(design, x = NULL, group = NULL, method = c("kish", "deff"),
                na.rm = TRUE, decimals = NULL, min_cell_n = 30L, ...)
```

`min_cell_n` and `x` each carry a consequence the spec does not state. Issues 19
and 15 below.

---

### Prior Issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | crosstab never renders `eff_n` | 1 | Resolved — 1.3.1 parks it |
| 2 | interaction subgroups keep the code vocabulary | 1 | Resolved — 3.7 |
| 3 | cover sheet naming, ordering, header | 1 | Resolved — 6.2.1 |
| 4 | universe fallback on a SATA or battery block | 1 | Resolved — 4.5, unanimous-only |
| 5 | `get_effective_n()` already does workstream 1 | 3 | Resolved — III delegates |
| 6 | duplicate value label aborts in `get_freqs()` | 3 | Resolved — 3.6 aborts |
| 7 | `.resolve_roles()` breaks on allowed payloads | 3 | Resolved — 5.3 |
| 8 | 4.4 quotes the wrong abort message | 3 | **Regressed** — see issue 21 |
| 9 | twophase `eff_n` uses phase-1 rows | 4 | Resolved — measured 110.15 |
| 10 | workstream 3 reaches collections via `vars` | 4 | Resolved — 5.6 |
| 11 | topline has no `banner` | 4 | Resolved — 9.2 **Applies to** |
| 12 | the domain column is ignored | 5 | Resolved — measured 68.65 |
| 13 | interaction banner levels are codes | 5 | Resolved — 3.7 |
| 14 | interactions are never suppression-evaluated | 5 | Resolved — 1.3.2 parks it |

Thirteen of fourteen are closed. Issue 8 is the one regression: the correction
replaced an accurate quote with an inaccurate one.

---

### New Issues

#### Lens 1 — Output Column Contracts

**Issue 15: `n` and `n_eff` ignore the tabulated variable, so the Total header can still print an effective N above the table's N**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: JUDGMENT CALL

Section 1.2.1 defines the defect as "an effective N above the raw N of the table
it labels". Section 9.2 row 6 asks a test to assert "the rendered Total-header
effective N is at or below the table's raw N". Section X repeats it as a gate.

Delegation fixes two of the three causes. It does not fix the third.

`get_effective_n()` counts rows. It does not look at the variable being
tabulated. The `x` argument exists but is inert under the default estimator —
surveycore prints `x is ignored when method = 'kish'`. Measured on 300 rows with
60 missing values on `q1`:

```
get_effective_n(d)         n = 300   n_eff = 278.6
get_freqs(d, q1)           n = 130 + 110 = 240
```

The topline header would read `(Eff N=279)` over a column whose N sums to 240.
That is the same shape as the 185-against-119 case, at a smaller scale, and the
delegation does not remove it.

This is pre-existing and unchanged by the spec — the current `.compute_eff_n()`
returns 278.6 for the same design. The methodology problem is the claim, not a
new defect. The spec states an invariant it does not deliver, and an implementer
who writes test row 6 as written will write an assertion that passes on
`make_all_designs()` and fails on any variable with missing values.

Options:
- **[A]** State the contract: `n` and `n_eff` are design-level or banner-level
  row counts, independent of the tabulated variable, and may exceed the N shown
  for a variable that has missing values. Restate row 6 and the section X gate
  against the design's in-scope row count — 119 for twophase, 75 for the domain
  case — not against the table's N. Add a note to 1.2.1 that variable-level
  missingness is a third, unaddressed cause — Effort: low, Risk: low, Impact: the
  spec becomes true; the header keeps today's meaning.
- **[B]** Make `eff_n` per variable: subset the design to the variable's
  non-missing rows before calling `get_effective_n()` — Effort: medium, Risk:
  medium, Impact: the header matches the table; `show_eff_n` output changes for
  every variable with missing values, so 9.4's snapshot gate needs checking, and
  `eff_n` becomes one value per variable rather than one per table.
- **[C] Do nothing** — the spec asserts an invariant that measurement
  contradicts, and test row 6 encodes it.

**Recommendation: A** — the fix the spec set out to make is the twophase and
domain pair, and both are done. Widening the scope to variable-level missingness
is a separate change with its own snapshot risk. State the limit instead.

---

**Issue 16: section 3.5's pseudocode contradicts section 3.5's own contract table for a collection**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

The contract table's last row reads:

> `survey_collection`, `banner_var = NULL` | one row per member; the `.survey`
> column supplies `level`

The pseudocode three lines above it reads:

```r
level = if (is.null(banner_var)) {
  NA_character_
} else {
  as.character(out[[banner_var]])
}
```

For a collection, `banner_var` is always `NULL`, so the pseudocode returns
`NA_character_` for every member. The table says `.survey`. Both cannot hold.

Measured on a two-wave collection:

```
> get_effective_n(coll)
  .survey   n    n_eff deff_kish
1   wave1 200 184.9791  1.081203
2   wave2 200 186.6479  1.071536
```

The return has two rows and a `.survey` key column. The pseudocode would give
two rows both labelled `NA_character_`, which no caller can use.

Fix: branch on the design type, not on `banner_var`. When `design` is a
`survey_collection`, take `level` from `out$.survey`. State that the return has
one row per member, so a caller that expects a single row must select its member
first.

---

**Issue 17: a partially labelled banner produces a real NA level, and section 3.5 has no row for it**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Section 3.5's contract table covers three label cases: the observed code, the
missing value in the column, and the unobserved label. Both missing-value rows
were re-measured and both hold. A fourth case is absent, and it is the common one
in real data — a banner where some codes carry a label and some do not.

Measured with codes 1, 2 and 3 in the column and labels for 1 and 2 only:

```
> get_effective_n(da, group = gen)
     gen   n     n_eff
1   Male 150 138.91417
2 Female  30  28.13456
3   <NA>  20  18.05558

> unique(as.character(get_freqs(da, q1, group = gen)[[1]]))
[1] "Male"   "Female" NA
```

The two frames agree, so the join is safe. Three things follow that the spec does
not state:

1. `.resolve_eff_n()` returns a row whose `level` is `NA_character_` and whose
   `n` is 20. It is a real subgroup, and it is suppressible.
2. The suppression footnote changes text. Today the loop iterates codes, so the
   entry reads `gen=3`. After the change it reads `gen=NA`.
3. `%in%` matches a missing value to a missing value, so the `sup_vals` filter at
   `R/export-utils.R:490` still removes the right rows. No further change is
   needed there.

Fix: add the row to 3.5's contract table, state the footnote text change in 3.4
consequence 3, and add a test — a partially labelled banner suppresses the
unlabelled group and names it in the footnote.

---

**Issue 18: `.banner_levels_labelled()` returns character, which re-sorts a factor banner's interaction spanners**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Section 2.2 gives `.banner_levels_labelled()` the return type "character vector,
length `nrow(design@data)`". Section 3.7 says a factor banner "already stores its
label, so the lookup returns the column unchanged".

It does not return it unchanged. It returns a character vector, and
`interaction()` orders character input alphabetically. Measured:

```
f1 <- factor(c("Low","High",...), levels = c("Low","High"))
levels(interaction(list(f1, f2), sep = " x "))
[1] "Low x N"  "High x N"  "Low x S"  "High x S"

levels(interaction(list(as.character(f1), as.character(f2)), sep = " x "))
[1] "High x N"  "Low x N"  "High x S"  "Low x S"
```

`.build_col_groups()` at `R/export-crosstab.R:384` takes the spanner order
straight from those levels. So any factor banner whose level order is not
alphabetical gets its interaction columns reordered. A Likert banner ordered
`Low`, `Medium`, `High` renders `High`, `Low`, `Medium`.

Section 9.4 names one possible snapshot exception and reasons about it:
`make_all_designs()` "builds group columns as character and factor, so most
likely none is". The premise is wrong. Measured — `helper-test-data.R` builds
`q1`, `q2` and `group` with `sample()` over character vectors, and the file has
no `factor()` call. Every fixture column is character. The same wrong claim
appears in 3.3.

So no committed snapshot is at risk, and 9.4 holds — but for a reason the spec
does not give, and the ordering defect is invisible to the whole test suite.

Fix: make `.banner_levels_labelled()` preserve the factor and its level order,
returning a factor for a factor input and a character vector otherwise. Correct
the fixture claim in 3.3 and 9.4. Add a test with a factor banner whose levels
are not alphabetical, asserting the interaction spanner order.

---

#### Lens 2 — Confidence Interval Specification

Lens 2 not applicable, for the reason Pass 1 gives. The spec changes no estimate,
no standard error and no confidence bound. `conf_level` still reaches
`surveycore::get_freqs()` unchanged at `R/export-utils.R:283`, and none of the
five workstreams touches that path.

---

#### Lens 3 — Statistical Delegation Accuracy

**Issue 19: `get_effective_n()` warns on every cell under 30, and `.resolve_eff_n()` does not muffle it**
Severity: REQUIRED
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

`get_effective_n()` takes `min_cell_n = 30L` and raises
`surveycore_warning_small_cell` for any group level below it. Measured on a
banner with 280 Male and 20 Female:

```
WARNING class: surveycore_warning_small_cell, rlang_warning, warning, condition
  msg: ! 1 cell has fewer than 30 unweighted observations. Estimates in these
       cells may be unreliable for public reporting (AAPOR guidance).
```

The values are unaffected. `min_cell_n = 1L` returns the identical frame.

The suppression loop exists to find small subgroups, so this warning fires on
exactly the runs the spec is fixing. Section 3.5's pseudocode calls
`get_effective_n()` bare, so every crosstab with a small banner cell gains a
surveycore warning that surveyreports does not own and did not raise before.

The package already has one answer to this warning. `.compute_subgroup_freq()`
and `.compute_interaction_freq()` both wrap their `get_freqs()` call:

```r
withCallingHandlers(
  surveycore::get_freqs(...),
  surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
)
```

Two gates are exposed. Section X requires the suite's 88 warnings to fall to 8 or
fewer. Section 9.4 requires no committed snapshot to change, and a snapshot
records warnings.

Fix: wrap the `get_effective_n()` call in `.resolve_eff_n()` with the same
`withCallingHandlers()` muffle the two frequency helpers use, and state in 3.5
that the helper raises no warning of its own. Suppression already reports small
subgroups through `surveyreports_warning_subgroup_suppressed`, which is the
package's own class and carries the threshold that actually applies.

---

**Issue 20: section 3.8 misses a fourth `.compute_eff_n()` call site, on the collection path**
Severity: REQUIRED
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Section 3.4 consequence 1 deletes `.compute_eff_n()`. Section 3.8 lists the call
sites to change: the suppression loop at `:415-445`, the `show_eff_n` block at
`:517-524`, the interaction column at `:238-242`, and the body at `:134-158`.

There is a fourth. `.build_freq_frame()`'s `survey_collection` branch computes
`eff_n` per wave at `R/export-utils.R:381-396`:

```r
if (show_eff_n) {
  all_rows$eff_n <- mapply(
    function(stype, svar) {
      if (stype == "total") return(NA_real_)
      wd <- design@surveys[[svar]]
      ...
      .compute_eff_n(wd)
    },
    all_rows$subgroup_type, all_rows$subgroup_var, SIMPLIFY = TRUE
  )
}
```

Deleting the helper breaks `export_topline(collection, show_eff_n = TRUE)` at
load. Section X's `grep -rn "compute_eff_n" R/` gate would catch it, but only
after the implementer has to invent the replacement unaided.

The join key differs here, which is why this is not a copy of the `show_eff_n`
change. Wave rows carry `subgroup_value = NA_character_` and hold the wave name
in `subgroup_var`. Section 3.8's rule — join "on `as.character(subgroup_value)`"
— matches nothing on this path.

A second fact belongs in the spec. The same block hard-codes `NA_real_` for
`total` rows, and `R/export-topline.R:288-289` reads exactly
`frame$eff_n[frame$subgroup_type == "total"]`. So a trend workbook with
`show_eff_n = TRUE` prints `Total` with no effective N today, on the one path
where `get_effective_n()` could supply one — measured, it returns one row per
member for a collection.

Fix: add the call site to 3.8 with its own rule. The direct replacement is
`.resolve_eff_n(design@surveys[[svar]], NULL)` per wave, joined on
`subgroup_var`. State whether the pooled `Total` row keeps `NA_real_` — keeping
it is the no-change option and needs one sentence, not silence.

---

**Issue 21: section 4.4's abort quote regressed — the message Pass 1 called stale is the message surveycore raises**
Severity: SUGGESTION
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Pass 1 issue 8 said 4.4 quoted the wrong abort and should quote the "no single
set of dimensions" message. Stage 2 Resolve applied that change, and 6.3 now
refers back to it.

Measured today on a two-wave collection, all three readers raise the message
Pass 1 called stale:

```
x `x` must be a survey design object or a data frame, not
  <surveycore::survey_collection>.
v Create a survey object with `as_survey()`, `as_survey_replicate()`, or
  `as_survey_twophase()`.
```

`extract_universe()`, `extract_var_extra()` and `extract_dataset_metadata()` all
give that text. The dimensions message comes from some other surveycore entry
point, not from these three.

The conclusion of 4.4, 5.6 and 6.3 is unchanged: all three abort, and all three
need a design-type branch. Only the quoted evidence is wrong, and it is wrong
because Pass 1 was wrong. Restore the original quote and drop the reference to it
in 6.3, or replace both with "aborts — it does not accept a collection", which is
the fact the branch depends on and does not decay.

---

#### Lens 4 — Cross-Design Consistency

**Issue 22: section 6.2.1's sheet-suffix rule has no owner in section 2.1**
Severity: SUGGESTION
Lens: 4 — Cross-Design Consistency
Resolution type: UNAMBIGUOUS

Section 6.2.1 requires a colliding **data** sheet to be suffixed — `About_2`,
then `About_3`. Section 9.2 row 20 tests it.

Section 2.1's file table gives `R/export-crosstab.R` four changes: the `all_of()`
fix, the role guard, the duplicate-label validation, and threading the resolved
base notes. Sheet naming is not among them, and no deduplication logic exists
today. Measured — `R/export-crosstab.R:207` is `substr(var, 1L, 31L)` with no
uniqueness check, and `wb_add_worksheet()` is called directly at `:209`, `:231`
and `:253`.

So the rule is specified, tested, and assigned to no file.

`export_topline()` is unaffected. Measured — it writes one sheet, `"Topline"`, at
`R/export-topline.R:129`, and has no `per_question` layout. Section 9.2 row 20 is
correctly marked crosstab-only.

Fix: add the sheet-name change to 2.1's `R/export-crosstab.R` row. A shared
`.unique_sheet_name()` helper covering all three `wb_add_worksheet()` call sites
is the smaller change, and it also fixes the pre-existing case of two variables
sharing their first 31 characters.

---

#### Lens 5 — Domain and Grouping Behavior

**Issue 23: `.unanimous_across()`'s contract fits the collection case and not the battery case**
Severity: REQUIRED
Lens: 5 — Domain and Grouping Behavior
Resolution type: UNAMBIGUOUS

Section 4.5 says one helper implements the unanimity rule everywhere. Section 2.2
gives its contract:

```r
.unanimous_across <- function(entries)
# entries: list of named character vectors, one per member
# -> keys whose value is identical and non-missing across every member
```

That shape is the collection case. `entries[[i]]` is wave `i`'s universe vector,
keyed by variable, and "keys identical across members" is the right question.

The battery case is a different shape. There is one universe vector and several
variable names, and the question is whether `u["bat_1"]`, `u["bat_2"]` and
`u["bat_3"]` are the same text. Passing those as three named vectors gives three
members with three different keys, and no key is present in all three, so the
helper returns nothing. Applied literally, the rule 4.5 states for batteries
never prints a base note.

Section 4.5 also says `.base_note_for()` "changes from reading
`frame$variable[[1L]]` to applying `.unanimous_across()` over
`unique(frame$variable)`". `unique(frame$variable)` is a character vector of
names, not a list of named character vectors. The two contracts do not meet.

Measured, so the shape is not in doubt. `extract_universe()` returns a named
character vector, unset variables absent, `character(0)` when nothing is set:

```
> extract_universe(d)
                    q1                           q2
 "Asked of all adults" "Asked of registered voters"
```

Fix: specify the battery call explicitly. The straightforward form is
`.unanimous_across(lapply(vars, function(v) c(note = unname(u[v]))))`, which
makes every member share one key and reduces the battery question to the
collection question. State it in 4.5, and state the composition order for a
battery inside a collection — resolve each wave's universe first, then apply the
battery rule to the unanimous result.

A second detail belongs with it. Section 4.5 exempts a caller-supplied
`base_notes` entry from the rule, and 4.2's merge writes the caller's entries
over the universe vector by name. After the merge the two sources are
indistinguishable, so a battery whose first member carries a caller note and
whose other members carry a differing universe would be judged by unanimity and
print nothing — the opposite of the stated exemption. Say whether the merge keeps
the two sources separate, or whether `.base_note_for()` checks the caller's
vector first and only falls back to the unanimity rule.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 7 |
| SUGGESTION | 2 |

**Total issues:** 9

| # | Title | Lens | Severity | Type |
|---|---|---|---|---|
| 15 | `eff_n` ignores the tabulated variable | 1 | REQUIRED | JUDGMENT |
| 16 | 3.5 pseudocode contradicts its collection row | 1 | REQUIRED | UNAMBIGUOUS |
| 17 | a partially labelled banner yields an NA level | 1 | REQUIRED | UNAMBIGUOUS |
| 18 | character coercion re-sorts factor interaction spanners | 1 | REQUIRED | UNAMBIGUOUS |
| 19 | `surveycore_warning_small_cell` leaks from `.resolve_eff_n()` | 3 | REQUIRED | UNAMBIGUOUS |
| 20 | 3.8 misses the collection wave call site | 3 | REQUIRED | UNAMBIGUOUS |
| 21 | 4.4's abort quote regressed | 3 | SUGGESTION | UNAMBIGUOUS |
| 22 | 6.2.1's sheet-suffix rule has no owner | 4 | SUGGESTION | UNAMBIGUOUS |
| 23 | `.unanimous_across()` does not fit the battery case | 5 | REQUIRED | UNAMBIGUOUS |

**Overall assessment:** the delegation decision holds under measurement. The two
numbers Pass 1 called wrong are now right — twophase returns 110.15 against a
table of 119, and the domain case returns 68.65 against 75 — and the label
vocabularies of `get_effective_n()` and `get_freqs()` agree on every banner shape
tested, including the partially labelled one. Nothing in Pass 2 is blocking. What
Pass 2 found is that the delegation contract is written against a
three-argument mental model of `get_effective_n()`, and the real function has
seven arguments, two of which matter: `min_cell_n = 30L` makes the helper warn on
exactly the small cells suppression exists to find, and `x` is inert under the
Kish estimator, so `eff_n` stays variable-independent and the invariant 9.2 row 6
and X assert does not hold for a variable with missing values. The remaining
issues are internal contradictions rather than statistical errors: 3.5 disagrees
with itself about collections, 3.8 lists three of four call sites, 2.2's shared
unanimity helper has a signature that fits one of its two jobs, and 6.2.1
specifies a sheet rule that 2.1 assigns to no file.

**Issues that resolve together:** 16 and 20 are both the collection path through
workstream 1, and one edit to 3.5 plus one row in 3.8 closes both. 15 and 19 are
both consequences of the `get_effective_n()` signature and should be read as one
pass over 3.5. 23 pulls 4.2's merge with it — decide the caller-versus-universe
precedence and the helper's signature in the same sitting.

---

## Methodology Review: export-metadata — Pass 3 (2026-09-14)

### Scope assessment

Stage 2 **applies**, and it applies harder than in Passes 1 and 2. v0.8.0 adds
three things the earlier versions did not have:

- a published statistical decision rule the package now owns outright — the
  `min_eff_n` floor of section 3.5, with the raw-N test removed
- a written definition of `effective sample size` in the glossary of section
  3.15, which ships inside every workbook
- a variance contract, section 3.12, that renders SE and CI values into cells

All five lenses apply. Lens 2 was declared not applicable in Passes 1 and 2. It
applies now, because section 3.12 writes CI bounds into the deliverable and
section 3.3 decides how a number is printed.

### Evidence base

Every measurement below ran on 2026-09-14 against surveycore `1.1.0.9000` and
openxlsx2 `1.28`, in this repository, through `Rscript`. Each issue says whether
it rests on a measurement or on reading the spec.

Four measurements drive most of Pass 3:

```
# 1. get_freqs() returns proportions, not percentages
get_freqs(d, q1)                     pct = 0.356, 0.306, 0.337   (sums to 1)
get_freqs(d, q1, variance = "se")    se = 0.0290, 0.0278, 0.0286
get_freqs(d, q1, variance = "ci")    ci_low = 0.300, ci_high = 0.413

# 2. the interval is a normal-approximation Wald interval, on every design type
(ci_high - ci_low) / 2 / se = 1.959964 = qnorm(0.975)   taylor, replicate, twophase
qt(0.975, 299) would be 1.96793.  No df is used.

# 3. the bounds are not clipped to the support
rare category, 2 of 300:  pct = 0.00719, ci_low = -0.00343, ci_high = 0.0178

# 4. Kish n_eff is not the SRS-equivalent sample size
400 rows, 20 clusters, real intra-cluster correlation on q1:
  get_effective_n(d, method = "kish")   n = 400, n_eff = 370.4, deff_kish = 1.08
  design SE for pct(Agree) = 0.04133;  p(1-p)/se^2 = 139.7
```

Measurement 4 is the one that matters most. The workbook would print `370.4`
where the glossary's own sentence describes `139.7`.

Two further facts, both measured:

```
get_effective_n(coll)                            2 rows, keyed by .survey
get_effective_n(d, group = gen)                  drops the NA level
get_effective_n(d, group = gen, na.rm = FALSE)   keeps it: <NA> n = 25, n_eff = 23.1
get_freqs(d, q1, group = gen, na.rm = FALSE)     every pct re-based on the larger denominator
as_survey(df_with_zero_weights)                  aborts on non-positive weights
```

One spec claim I set out to falsify and could not: `survey_nonprob`. Measured —
`get_effective_n()`, `get_freqs(variance = "ci")`, `extract_universe()`,
`extract_var_extra()` and `extract_dataset_metadata()` all work on a design built
with `as_survey_nonprob()`. Section 1.5's "no difference in behavior" holds, and
section 1.6's fixture deliverable is buildable as written.

---

### Prior Issues (Passes 1 and 2)

Each row was re-checked against the v0.8.0 text. A row reads Resolved only where
a v0.8.0 section carries the resolution, named in the last column.

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | crosstab never renders `eff_n` | 1 | ✅ Resolved — 3.4 renders it, in two rows; 3.2 records that `show_eff_n` was a no-op |
| 2 | interaction subgroups keep the code vocabulary | 1 | ✅ Resolved — 3.8, "Interaction levels read labels, not codes" |
| 3 | cover sheet naming, ordering, header | 1 | ✅ Resolved — 3.14, all four rows present |
| 4 | universe fallback on a SATA or battery block | 1 | ✅ Resolved — 3.6, the unanimity table |
| 5 | `get_effective_n()` already does workstream 1 | 3 | ✅ Resolved — 1.4.1 and 2.2 `.resolve_eff_n()` |
| 6 | duplicate value label aborts in `get_freqs()` | 3 | ✅ Resolved — 3.7 aborts, with a named class |
| 7 | `.resolve_roles()` breaks on allowed payloads | 3 | ✅ Resolved — 3.10, the five-row coercion table |
| 8 / 21 | the abort message quote | 3 | ✅ Resolved — 1.5 quotes no message and says why |
| 9 | twophase `eff_n` uses phase-1 rows | 4 | ✅ Resolved — 1.4.1 table, 3.20 |
| 10 | the role guard reaches collections through `vars` | 4 | ✅ Resolved — 1.5, "Every metadata read in A2, A3 and A4 must branch on the design type". But 2.2 contradicts it — issue 35 |
| 11 | topline has no `banner` | 4 | ✅ Resolved — 4.1, the paragraph before the pooled-Total note |
| 12 | the domain column is ignored | 5 | ✅ Resolved — 1.4.1 table, 3.20 |
| 13 | interaction banner levels are codes | 5 | ✅ Resolved — 3.8 |
| 14 | interactions are never suppression-evaluated | 5 | ✅ Resolved — 3.5 brings them in scope |
| 15 | `eff_n` ignores the tabulated variable | 1 | ✅ Resolved — 1.4.1 "A third cause stays unaddressed", 3.4. The floor built on it is new — issue 37 |
| 16 | 3.5 pseudocode contradicts its collection row | 1 | ⚠️ **Regressed** — the pseudocode is gone, and 2.2's replacement contract carries the same error. Issue 33 |
| 17 | a partially labelled banner yields an NA level | 1 | ✅ Resolved — 3.7 row 3, 3.19 |
| 18 | character coercion re-sorts factor spanners | 1 | ✅ Resolved — 2.2, "factor in -> factor out, LEVEL ORDER PRESERVED" |
| 19 | `surveycore_warning_small_cell` leaks | 3 | ✅ Resolved — 2.2, `.resolve_eff_n()` muffles it |
| 20 | the collection wave call site | 3 | ✅ Resolved — 4.1, last two paragraphs |
| 22 | the sheet-suffix rule has no owner | 4 | ✅ Resolved — 2.1 and 2.2 `.unique_sheet_name()` |
| 23 | `.unanimous_across()` misses the battery case | 5 | ✅ Resolved — 2.2 states the transpose; 3.6 keeps the two sources separate |

Twenty-two of twenty-three survive the rewrite. One regressed: issue 16.

---

### New Issues

#### Lens 1 — Output Column Contracts

**Issue 24: section 3.3's rounds-to-zero threshold is wrong by a factor of 100**
Severity: BLOCKING
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Measured. Section 2.2 defines the input: "`p`: the proportion from
`get_freqs()`". Section 3.3 row 3 then tests

> `0 < p < 0.5 × 10^-decimals`

At `decimals = 1` that threshold is `0.05`. On the proportion scale `0.05` is
five percent. So an implementer writing `.fmt_pct()` from the table prints
`<0.1%` for every estimate below 5 percent.

`get_freqs()` returns a proportion, measured:

```
> get_freqs(d, q1)
  q1         pct     n
  Agree    0.356   107
```

Worked through the rule as written, at `decimals = 1`:

| `p` | rule fires? | the cell it should hold |
|---|---|---|
| 0.0004 | yes | `<0.1%` — correct |
| 0.0040 | yes | `0.4%` — **wrong** |
| 0.0400 | yes | `4.0%` — **wrong** |
| 0.4000 | no | `40.0%` — correct |

The existing code already converts. `R/export-utils.R:746` reads
`round(one_rows$pct[[1L]] * 100, decimals)`. The spec drops the `* 100`.

This passes every structure test. Each cell is a string, each carries `%`, each
matches one of the four forms in invariant 8.1. Only the numbers are wrong, and
they are wrong on small estimates, which is where a rounding rule is read most
closely.

Fix: state the scale once, in section 2.2 and in section 3.3. Either
`.fmt_pct()` takes a proportion and the threshold is `0.5 × 10^-(decimals + 2)`,
or `.fmt_pct()` takes percentage points and section 2.2 says the caller
multiplies by 100 first. The second is clearer, because `decimals` already
counts decimal places on a percentage.

---

**Issue 25: the glossary defines the effective sample size as a design-effect quantity, and the number printed is Kish**
Severity: BLOCKING
Lens: 1 — Output Column Contracts
Resolution type: JUDGMENT CALL

Measured. Section 3.15 writes this sentence into every workbook:

> **Effective sample size (ESS)** — The number of people a simple random sample
> would need to measure this group as precisely as the weighted sample does.

That sentence defines `n / deff`, where `deff` is the full design effect. The
number printed is `n / deff_kish`, and Kish's `deff_kish` measures weight
variation alone. It excludes clustering and stratification.

On a clustered design the two differ by more than a factor of two. Measured, 400
rows in 20 clusters with real intra-cluster correlation on `q1`:

```
get_effective_n(d, method = "kish")     n = 400   n_eff = 370.4   deff_kish = 1.08
design SE for pct(Agree)                0.04133
SRS-equivalent size, p(1-p)/se^2        139.7
```

The workbook prints `370.4`. Its own glossary says that number is `139.7`.

The entry's second sentence is Kish-accurate — "the more the weights vary, the
smaller it gets" — so the entry holds both definitions and they disagree.

Three consequences, not one:

1. The printed statistic carries a false definition, in the deliverable, in
   plain language aimed at a reader who cannot check it.
2. The `min_eff_n` floor of section 3.5 keys on the same number. A clustered
   subgroup at `n_eff = 105` is published, and its estimates carry the precision
   of about 40 respondents. Section 3.15 tells the reader the opposite: "its
   estimates are too imprecise to report" is the stated reason a column is
   missing, so a column that is present reads as precise enough.
3. surveyreports supports Taylor, replicate and two-phase designs. Clustering is
   the normal case here, not the exception.

Switching estimator is not a one-word change. Measured —
`get_effective_n(method = "deff")` routes to `get_means()` and aborts on a
character variable:

```
> get_effective_n(d, x = q1, method = "deff")
x `x` must be numeric, not <character>.
i Column q1 cannot be used with `get_means()`.
```

So a design-effect ESS is not reachable through that API for a categorical
question, which is what a crosstab tabulates.

Options:
- **[A]** Keep Kish and rewrite the glossary entry to describe it: the effective
  sample size after weighting, which accounts for unequal weights and not for
  clustering — Effort: low, Risk: low, Impact: the definition becomes true; the
  floor keeps its current, weaker guarantee, and section 3.15's "too imprecise
  to report" sentence needs the same correction.
- **[B]** Compute a design-effect ESS per rendered estimate from the SE
  surveycore already returns, and key the floor on it — Effort: high, Risk:
  high, Impact: the floor matches its stated meaning; the ESS becomes one number
  per cell rather than one per subgroup, so the two sample-size rows of section
  3.4 no longer have a single value to hold.
- **[C] Do nothing** — the workbook states a definition measurement contradicts
  by a factor of 2.6 on a clustered design, and the floor over-publishes.

**Recommendation: A** — the quantity is the one the package already computes and
delegates, and the defect is in the words, not the arithmetic. B is a separate
spec.

---

**Issue 26: `has_rows` has no derivation rule, and `get_freqs()` returns present rows with `n = 0`**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Measured. Section 3.3 row 1 says a cell holds `-` when "the response value
appears nowhere in this column". Section 2.2 gives `.fmt_pct()` a `has_rows`
argument and never says how the caller computes it.

Row absence is the wrong test. `get_freqs()` emits a row with `n = 0`. Measured
with `na.rm = FALSE` on a banner and a variable that both carry missing values:

```
   gen    q1         pct     n
 9 <NA>   Agree    0.303     8
12 <NA>   <NA>     0         0
```

The last row is present, `n` is `0`, and `pct` is `0`. Under section 3.3 as
written, the implementer finds a row, finds `p == 0`, and prints `0.0%` — the
"exactly 0" form — where the rule intends `-`.

The package already knows this. `R/export-utils.R:733-739` carries the comment:

> `get_freqs()` emits a placeholder row (n = 0, pct = NA) for a subgroup with
> zero non-NA observations even when the item was never asked there at all, so
> "a row exists" alone is not sufficient: the row's own n must be > 0.

A second contract goes with it. That comment records a **third** state for SATA
— asked and nobody chose it prints `0`, never asked prints blank. Section 3.3
has four forms and invariant 8.1 fixes the set at four. So a SATA item never
asked in a subgroup now renders `-`, the same cell as an item nobody chose. The
spec does not say it is dropping that distinction.

Fix: define `has_rows` as `nrow(rows) > 0 && rows$n > 0`, and add a fifth row to
3.3 for the SATA never-asked case, or state that the distinction is dropped and
why. Amend invariant 8.1 to match.

---

**Issue 27: `.write_sample_size_rows()` cannot produce its cells from its arguments**
Severity: REQUIRED
Lens: 1 — Output Column Contracts
Resolution type: UNAMBIGUOUS

Read from the spec. Section 2.2:

```r
.write_sample_size_rows <- function(wb, sheet, start_row, label_cols,
                                    levels, show_ess)
```

Section 3.4 says the two rows hold "the subgroup's `n` from `.resolve_eff_n()`"
and "the subgroup's `n_eff`, at one decimal". Neither reaches the helper. There
is no `counts` argument and no `design` argument, so `levels` would have to
carry the numbers, and section 2.2 says nothing about its type.

The Total column needs a value in both rows too. It is not a banner level, so it
is not in `levels` either.

This is the one helper in section 2.2 whose signature does not support its job.
Every other one states its return shape and its inputs.

Fix: give it the resolved counts — a frame of `level`, `n`, `n_eff` including a
row for the Total column — and state the type of `levels` and the column order
the cells are written in.

---

**Issue 28: the rounding mode is unstated, and R rounds half to even**
Severity: SUGGESTION
Lens: 1 — Output Column Contracts
Resolution type: JUDGMENT CALL

Measured. Section 3.3's fourth row says "the rounded value with a `%` suffix".
It does not say which rounding.

```
round(41.25, 1)          41.2
sprintf("%.1f", 41.25)   41.2
round(0.35, 1)           0.3
round(2.5)               2
```

R rounds half to even, in both `round()` and `sprintf()`. Report convention is
usually half away from zero, so a reader who checks `41.25` by hand gets `41.3`
and the workbook says `41.2`.

The rule matters twice: it decides the printed value, and it decides whether a
value sits on the `<0.1%` boundary of issue 24.

Fix: name the mode in 3.3. Half to even, as R does it, is the low-effort choice
and matches the current code. Say so, so the tester does not treat a half-even
result as a defect.

---

**Issue 29: the rule has a floor and no ceiling, so a cell can read `100.0%` when it is not 100**
Severity: SUGGESTION
Lens: 1 — Output Column Contracts
Resolution type: JUDGMENT CALL

Measured. Section 3.3 separates "rounds to zero" from "is zero" and gives the
first its own string, `<0.1%`. It makes no such separation at the other end.
`sprintf("%.1f%%", 0.99997 * 100)` gives `100.0%`.

So a category that 3 respondents in 10,000 did not choose reads as unanimous.
The argument for `<0.1%` applies unchanged: a reader who sees `100.0%` concludes
the complement is empty.

Section 3.9 removes the `100%` row partly because "the visible cells routinely
do not total 100". A cell that reads `100.0%` next to a nonzero sibling makes
that worse.

Options:
- **[A]** Add a symmetric row: `1 - 0.5 × 10^-decimals < p < 1` prints `>99.9%`
  — Effort: low, Risk: low, Impact: the rule is symmetric and one more form
  joins invariant 8.1.
- **[B] Do nothing** — a near-unanimous cell reads as unanimous, and the spec
  does not say it chose that.

**Recommendation: A** — the asymmetry is not a decision the spec records, and
the fix is one row in `.fmt_pct()`.

---

#### Lens 2 — Confidence Interval Specification

**Issue 30: SE and CI values come back as proportions, and section 3.12 calls them percentage points**
Severity: BLOCKING
Lens: 2 — Confidence Interval Specification
Resolution type: UNAMBIGUOUS

Measured. Section 3.12's Units column reads "percentage points, at `decimals`
places" for both `"se"` and `"ci"`. surveycore returns neither on that scale:

```
> get_freqs(d, q1, variance = "se")
  q1         pct     se     n
  Agree    0.356 0.0290   107

> get_freqs(d, q1, variance = "ci")
  q1         pct ci_low ci_high     n
  Agree    0.356  0.300   0.413   107
```

`se` is `0.0290` — 2.9 percentage points. Written at `decimals = 1` with no
conversion it prints `(0.0)`. Every standard error in the workbook becomes
`0.0`, and nothing in the structure fails.

This is issue 24 on a second path, and it needs its own fix, because section
3.12 does not route through `.fmt_pct()` and section 2.2 gives the variance
values no formatter at all.

Two smaller gaps sit in the same rows and should be closed with it:

- Whether each CI bound carries its own `%`, or the pair carries one. Section
  3.12 says only "in parentheses, en-dash separated".
- Whether a variance value uses the three-way rule of section 3.3. An SE of
  0.0004 proportion is 0.04 percentage points, which rounds to `0.0`. Nothing
  says whether that prints `<0.1` or `0.0`.

Fix: state that the render multiplies `se`, `ci_low` and `ci_high` by 100, name
the formatter, and give one worked example of each string.

---

**Issue 31: the interval is a normal-approximation Wald interval and is not clipped to the support**
Severity: REQUIRED
Lens: 2 — Confidence Interval Specification
Resolution type: JUDGMENT CALL

Measured. Section 3.12 delegates the interval entirely and states no formula, no
df and no distribution. The delegation itself is correct — `variance = "ci"` and
`conf_level` are both real `get_freqs()` arguments, and `conf_level` changes the
width, measured at 0.95 and 0.99.

What the delegation leaves unspecified is what surveyreports prints when the
delegated value falls outside the estimand's support. It does:

```
rare category, 2 of 300
  pct = 0.00719   ci_low = -0.00343   ci_high = 0.0178
```

Under section 3.12 as written that cell reads `(-0.3% – 1.8%)`. A negative
percentage of respondents is not a quantity, and the cell offers no clue that it
is an artifact of the normal approximation.

The interval is a Wald interval on the proportion scale, measured on every
design type:

```
(ci_high - ci_low) / 2 / se = 1.959964 on taylor, replicate and twophase
qnorm(0.975) = 1.959964      qt(0.975, 299) = 1.96793
```

So no degrees of freedom enter, the multiplier is identical across subclasses,
and the interval is symmetric about `pct`. For a replicate design with 10
replicates a t interval on 9 df would be 15 percent wider; surveycore does not
use one. That is surveycore's choice to make, and section 3.12 is right not to
restate it. It is not right to be silent about the consequence that reaches the
cell.

The degenerate case is the other end. Measured, a variable with one value gives
`pct = 1`, `ci_low = 1`, `ci_high = 1` — a zero-width interval, printed as
`(100.0% – 100.0%)`.

Options:
- **[A]** Clip the printed bounds to `[0, 100]` and say so in 3.12 — Effort:
  low, Risk: low, Impact: no negative cell; the printed interval is no longer
  exactly what surveycore returned, which 3.12 currently promises.
- **[B]** Print the bound as returned and add one sentence to 3.12 and to the
  glossary saying the interval is a normal approximation that can fall outside
  0 to 100 percent for a rare category — Effort: low, Risk: low, Impact: the
  delegation stays literal; a negative cell still ships, with an explanation.
- **[C] Do nothing** — a published crosstab can carry a negative percentage, and
  no section of the spec predicts it.

**Recommendation: B** — section 3.12's whole argument is that the interval is
surveycore's and is not restated here. Clipping breaks that and hides an
approximation the reader should see. State the fact instead.

---

**Issue 32: the legend row asserts a coverage level that the spec declines to characterize**
Severity: SUGGESTION
Lens: 2 — Confidence Interval Specification
Resolution type: JUDGMENT CALL

Read from the spec, with issue 31's measurement behind it. Section 3.12 writes
`Percentages; 95% confidence interval in parentheses.` into the sheet, and two
paragraphs earlier declines to state the distribution the interval assumes.

Both positions are defensible on their own. Together they put a coverage claim
in the deliverable that the spec will not describe, so nothing in the repository
records what the claim rests on. If surveycore moves from a z interval to a
t interval on design df, every legend row keeps reading `95%`, every number
changes, and no gate notices.

Fix: keep the legend and add one row to section 1.4's upstream-state table,
recording what was measured — normal approximation, multiplier `qnorm(1 - α/2)`,
no degrees of freedom, identical on all three design types tested. That is a
fact about the dependency, which is what 1.4 exists for, and it gives the change
something to be detected against.

---

#### Lens 3 — Statistical Delegation Accuracy

**Issue 33: `.resolve_eff_n()`'s one-row contract is false for a collection — Pass 2 issue 16, regressed**
Severity: REQUIRED
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Measured. Section 2.2:

```
.resolve_eff_n <- function(design, group_var = NULL)
#    group_var = NULL -> one row, level = NA_character_
```

Section 1.4.1 says the opposite for a collection, in the same document:

> `survey_collection` — **Accepted.** Returns one row per member with a
> `.survey` key column.

Measured on a two-wave collection:

```
> get_effective_n(coll)
  .survey     n n_eff deff_kish
1 wave1     200  185.      1.08
2 wave2     200  186.      1.08
```

This is Pass 2 issue 16 in a new place. v0.7.0 carried it in pseudocode, the
rewrite deleted the pseudocode, and the replacement contract restates the error.

The path is live. Section 4.1 says `export_topline()` takes "its effective N per
wave, joined on the wave name rather than on the subgroup level". An implementer
who trusts 2.2 writes a helper that returns one row and joins nothing.

Fix: state the collection branch in 2.2. Either the helper rejects a collection
and the caller loops `design@surveys`, or it returns one row per member with
`level` taken from `.survey`. Say which, and say what `level` holds.

---

**Issue 34: `.resolve_eff_n()` has no `na.rm`, so the missing-value banner level never gets an effective N**
Severity: REQUIRED
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Measured. Section 3.5 promises that a missing-value banner level under
`na.rm = FALSE` is "evaluated and removed" when it falls below the floor.
Section 3.13 repeats it: "A missing-value banner level is a real subgroup and
faces `min_eff_n` like any other."

`get_effective_n()` excludes missing values from the group unless it is told not
to. Its signature carries `na.rm = TRUE`, and section 2.2 gives
`.resolve_eff_n()` no way to pass anything else:

```
> get_effective_n(d, group = gen)
  gen        n n_eff
  Female   139 128.
  Male     136 125.

> get_effective_n(d, group = gen, na.rm = FALSE)
  gen        n n_eff
  Female   139 128.
  Male     136 125.
  <NA>      25  23.1
```

So under `na.rm = FALSE` the frequency frame holds a missing-value column group
and the counts frame holds no row for it. Three things follow, and the spec
predicts none of them:

1. The level cannot be tested against `min_eff_n`, so it is published whatever
   its size — the one subgroup most likely to be small.
2. Its two sample-size cells have no value, so section 3.4's rows are incomplete
   for that column.
3. Invariant 8.1's first bullet is violated by a workbook the spec says is
   correct.

A second gap sits beside it. Section 3.13 says `na.rm` is "Passed to
`surveycore::get_freqs()`", and there are four `get_freqs()` call sites —
`.compute_total_freq()`, `.compute_subgroup_freq()`, `.compute_interaction_freq()`
and the collection path. The spec names none of them.

Fix: add `na.rm` to `.resolve_eff_n()`, state that the exported function passes
the same value it passes to `get_freqs()`, and name the four call sites.

---

**Issue 35: the role helpers carry no collection branch, while `.design_universe()` does**
Severity: REQUIRED
Lens: 3 — Statistical Delegation Accuracy
Resolution type: UNAMBIGUOUS

Measured, and read from the spec. Section 1.5 says `extract_var_extra()` aborts
on a collection, names A3 as its user, and requires that "Every metadata read in
A2, A3 and A4 must branch on the design type". Measured, the abort is real:

```
> extract_universe(coll)
x `x` must be a survey design object or a data frame, not
  <surveycore::survey_collection>.
```

Section 2.2 then gives A2's helper the branch, in writing:

```
.design_universe <- function(design)
#    Never aborts on a collection.
```

and gives A3's two helpers neither the branch nor a mention of it:

```
.roles_of <- function(extra)
.resolve_roles <- function(design, cols)
#    Never aborts on a foreign payload.
```

A reader of 2.2 sees one helper told to survive a collection and two told to
survive a bad payload, and concludes the difference is deliberate.
`export_topline()` accepts a collection and runs the role guard on `vars`, so
the direct implementation aborts on a supported call.

Section 3.6's unanimity table does carry the rule — "a role lookup on a
collection | the same rule" — but it sits in the base-notes section, four
sections away from the helper that has to implement it.

Fix: add the collection branch to `.resolve_roles()` in 2.2, with the same
sentence `.design_universe()` gets, and cross-reference 3.6's unanimity row from
section 3.10.

---

#### Lens 4 — Cross-Design Consistency

**Issue 36: the glossary ships in every topline workbook, where no floor is in force and no cell is a string**
Severity: REQUIRED
Lens: 4 — Cross-Design Consistency
Resolution type: UNAMBIGUOUS

Read from the spec. This is the split of section 1.1 producing an incoherent
deliverable, which is the thing the split has to be checked for.

Section 3.14 makes the glossary block unconditional — "What these numbers mean |
the glossary of section 3.15 | always" — and section 4.1 confirms the sheet
reaches the other function: "a topline workbook gains the cover sheet, with the
glossary".

Two of the four glossary entries are false in a topline workbook.

| Entry | What it says | Topline reality |
|---|---|---|
| `Why a column is missing` | "A subgroup whose effective sample size falls below the minimum is not shown… The minimum for this workbook is listed above." | Nothing is withheld — section 4.2, "never withheld". Nothing is listed above either: the withheld block is absent, and `.build_workbook()` receives `min_eff_n = NULL` |
| `Percentages` | describes `<0.1%`, `0.0%` and the dash | Topline percentages are numbers — section 4.2 |

The `Why a column is missing` entry is the worse of the two. It tells the reader
of a trend workbook that small subgroups were removed for imprecision. Section
4.2 says the opposite in the same spec: "a trend workbook can still publish a
wave with an effective N of 60".

The effective-N vocabulary split in section 4.2 — `Eff N` against
`effective sample size` — is only a wording difference, and it is documented.
The two functions compute the same quantity from the same delegated call, so
neither is wrong about the number. This is different: one function's cover sheet
states the other function's rules.

Fix: make the glossary entries conditional on what the workbook does.
`Why a column is missing` when `min_eff_n > 0` and a banner exists;
`Percentages` when the cells are strings. Section 3.14's block table needs a
fourth column, or `.write_cover_sheet()` needs to take the two facts.

---

#### Lens 5 — Domain, Banner, and Suppression Behavior

**Issue 37: the floor is tested on a base that ignores the tabulated variable, and B2 removes the only signal of the gap**
Severity: REQUIRED
Lens: 5 — Domain, Banner, and Suppression Behavior
Resolution type: JUDGMENT CALL

Measured. Section 3.4 states the limit honestly: "Both counts ignore the
tabulated variable". Section 1.4.1 records the decision to state it and not
widen scope, and Pass 2 issue 15 accepted that.

v0.8.0 changes what rests on it. In v0.7.0 the variable-independent count fed a
displayed number. Now it feeds the publication rule, and the rule is the
package's own:

```
get_effective_n(d)        n = 300   n_eff = 278.6
get_freqs(d, q1)          n sums to 240        (60 missing on q1)
```

A subgroup at `n_eff = 105` on a question that 40 percent of it skipped carries
an effective base near 63 for that question, and the floor publishes it. The
withheld list on the cover sheet says the rule was applied. The glossary says
the survivors are precise enough to report.

Two changes in the same spec remove the reader's ability to see the gap:

1. B2 deletes the per-response `N` column, so the workbook no longer shows the
   base any single estimate rests on.
2. Section VI records the loss as recoverable — "percent × sample size, though
   not exactly". With item nonresponse it is not recoverable: the percentage is
   based on responders and the sample size counts everyone, so the product
   overstates by the nonresponse rate.

Section 3.19 has the row — "a variable with missing values | the response rows
total less than the sample size above them. This is the stated contract of
section 3.4, not a defect" — and that is true of the display. It is not an
argument about the floor.

Options:
- **[A]** Keep the subgroup-level floor and say, in 3.5 and in the glossary,
  that the floor is tested on the subgroup's size and not on the base of any one
  question, so a question with heavy item nonresponse can be published below the
  floor — Effort: low, Risk: low, Impact: the rule's guarantee becomes the one
  it delivers.
- **[B]** Test the floor per variable: call `.resolve_eff_n()` on the design
  restricted to the variable's non-missing rows — Effort: high, Risk: high,
  Impact: the floor matches its claim; withholding becomes per question, so the
  column geometry differs between blocks on one sheet and the two sample-size
  rows stop being block-invariant.
- **[C] Do nothing** — the spec's own words carry a guarantee the rule does not
  deliver, and the reader has no way to check it.

**Recommendation: A** — B is a larger change than the one this spec is making,
and it breaks the shared column geometry the stacked layout depends on. A costs
two sentences and makes the claim true. Read this together with issue 25; both
are the gap between what `n_eff` measures and what section 3.15 says it means.

---

**Issue 38: `min_eff_n` has no validation and no error class**
Severity: REQUIRED
Lens: 5 — Domain, Banner, and Suppression Behavior
Resolution type: UNAMBIGUOUS

Read from the spec. Section 3.2 types the argument "numeric(1), >= 0". Section
3.17 lists four new error classes and none of them validates it. Section 3.11's
ordering contract has no validation step for it either.

`conf_level` and `decimals` are both validated today —
`R/export-utils.R:91-105` raises `surveyreports_error_invalid_conf_level`.
`min_eff_n` is the sole parameter of the rule that decides what gets published,
and it takes any value silently:

| Value | What happens, unvalidated |
|---|---|
| `-5` | nothing is withheld; the same as `0`, with no warning |
| `NA` | `n_eff < NA` is `NA`; the filter is undefined |
| `c(50, 100)` | the comparison recycles and withholds alternate levels |
| `"100"` | a character comparison; `"23.1" < "100"` is `FALSE`, so a small subgroup is published |

The same gap covers the other new scalars — `total_label`, `na_label`,
`variance_display`, `sample_size_display`, `withheld_note`, `show_ess` — but
`min_eff_n` is the one whose bad value changes what is published rather than how
it looks.

Fix: validate `min_eff_n` in `.validate_export_inputs()` as a length-1,
non-missing, finite, non-negative numeric, add the error class to 3.17 and to
`plans/error-messages.md`, and add the step to section 3.11's order, before the
role guard.

---

**Issue 39: invariant 8.1 contradicts section 3.5's full-sample row**
Severity: SUGGESTION
Lens: 5 — Domain, Banner, and Suppression Behavior
Resolution type: UNAMBIGUOUS

Read from the spec. Invariant 8.1, first bullet:

> Every rendered column has a heading, and every heading names a subgroup whose
> effective N is at or above `min_eff_n`.

Section 3.5, last row of the degenerate table:

> the full sample's own effective N is below `min_eff_n` |
> `surveyreports_warning_full_sample_below_min`, and the workbook is written in
> full.

Both cannot hold. The Total column is a rendered column with a heading, and 3.5
requires it to stay. A reviewer applying 8.1 literally flags correct code, and a
tester writing the invariant as an assertion writes a failing test.

3.5 is the rule and wins. Fix: exclude the Total column from the invariant.

---

**Issue 40: dropping the raw-N test is safe, and the spec does not say why**
Severity: SUGGESTION
Lens: 5 — Domain, Banner, and Suppression Behavior
Resolution type: UNAMBIGUOUS

Measured and derived. Section 3.5 states "Raw N: **not tested.** The effective N
is the number the rule is about", and leaves it there. A reader with the
`pub_type` history asks whether a subgroup can now pass the floor on a small raw
count.

It cannot. Kish's `deff = n·Σw² / (Σw)²` is at least 1 by Cauchy–Schwarz, so
`n_eff ≤ n` always, and `n_eff ≥ min_eff_n` forces `n ≥ min_eff_n`. Every
measurement in this pass agrees: `deff_kish` ran 1.07 to 1.11 and never fell
below 1. The raw-N test is subsumed by the effective-N test, not discarded.

One consequence does deserve a line. surveycore's own raw-N warning,
`surveycore_warning_small_cell` at `min_cell_n = 30`, is muffled by
`.resolve_eff_n()` and by the three frequency helpers — correctly, per Pass 2
issue 19. At the default floor of 100 nothing is lost, because 100 exceeds 30.
At `min_eff_n = 0`, the QA setting section VI names, every raw-N signal in the
call is silenced at once.

Fix: record the `n_eff ≤ n` reasoning in 3.5, in one sentence, and note that
`min_eff_n = 0` silences the AAPOR raw-N warning as well as the floor.

---

**Issue 41: section 3.19's zero-weight row cannot occur — `as_survey()` rejects it**
Severity: SUGGESTION
Lens: 5 — Domain, Banner, and Suppression Behavior
Resolution type: UNAMBIGUOUS

Measured. Section 3.19 has the row "zero-weight rows | the call succeeds; both
counts follow surveycore. This package adds no missing-value path of its own".
No such design can be built:

```
> as_survey(df_with_40_zero_weights, weights = wt)
x Weight column wt has 40 non-positive value(s).
i All non-NA weights must be strictly greater than 0.
v Remove or replace rows where wt is 0 or negative.
```

surveycore validates at construction, so the case never reaches an export
function. The row is harmless in the spec and will cost a tester a test that
cannot be written — `testing.md` lists zero-weight rows as a required edge case,
so somebody will try.

Fix: change the row to record that surveycore rejects a non-positive weight at
construction, and that no export function can receive one.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 9 |
| SUGGESTION | 6 |

**Total issues:** 18

| # | Title | Lens | Severity | Type |
|---|---|---|---|---|
| 24 | the rounds-to-zero threshold is off by 100 | 1 | BLOCKING | UNAMBIGUOUS |
| 25 | the glossary defines ESS as deff-based; the number is Kish | 1 | BLOCKING | JUDGMENT |
| 26 | `has_rows` has no rule; `n = 0` rows are present | 1 | REQUIRED | UNAMBIGUOUS |
| 27 | `.write_sample_size_rows()` gets no counts | 1 | REQUIRED | UNAMBIGUOUS |
| 28 | the rounding mode is unstated | 1 | SUGGESTION | JUDGMENT |
| 29 | no ceiling rule, so `100.0%` can be untrue | 1 | SUGGESTION | JUDGMENT |
| 30 | SE and CI are proportions, called percentage points | 2 | BLOCKING | UNAMBIGUOUS |
| 31 | the Wald interval is not clipped to the support | 2 | REQUIRED | JUDGMENT |
| 32 | the legend asserts an uncharacterized level | 2 | SUGGESTION | JUDGMENT |
| 33 | `.resolve_eff_n()` one-row contract, collection | 3 | REQUIRED | UNAMBIGUOUS |
| 34 | `.resolve_eff_n()` has no `na.rm` | 3 | REQUIRED | UNAMBIGUOUS |
| 35 | the role helpers carry no collection branch | 3 | REQUIRED | UNAMBIGUOUS |
| 36 | the glossary ships in topline workbooks | 4 | REQUIRED | UNAMBIGUOUS |
| 37 | the floor ignores the tabulated variable | 5 | REQUIRED | JUDGMENT |
| 38 | `min_eff_n` has no validation | 5 | REQUIRED | UNAMBIGUOUS |
| 39 | invariant 8.1 contradicts 3.5 | 5 | SUGGESTION | UNAMBIGUOUS |
| 40 | the raw-N reasoning is unrecorded | 5 | SUGGESTION | UNAMBIGUOUS |
| 41 | zero-weight rows cannot occur | 5 | SUGGESTION | UNAMBIGUOUS |

**Overall assessment:** the rewrite kept 22 of the 23 earlier resolutions, and
the delegation work Passes 1 and 2 argued for is sound — the twophase, domain,
label-vocabulary and factor-order fixes all survive, and `survey_nonprob` works
on every surveycore reader this spec calls. What v0.8.0 adds is weaker than what
it kept. Part B writes numbers into cells and never states the scale surveycore
returns them on, so the rounding rule mislabels every estimate under 5 percent
and every standard error prints as `0.0`. The `min_eff_n` floor is a reasonable
rule, and dropping the raw-N test is safe because Kish's `n_eff` never exceeds
`n` — but the glossary tells the reader the floor measures a design-effect
effective sample size, and on a clustered design that number is 2.6 times
smaller than the one printed, so the definition and the precision claim built on
it are both wrong. Lens 2, unused in two passes, was the right place to look:
the interval is a normal-approximation Wald interval with no degrees of freedom,
and a rare category returns a negative lower bound that section 3.12 would print
as a negative percentage.

**Issues that resolve together:** 24 and 30 are one scale decision and should be
fixed in one edit to 2.2 and 3.3. 25 and 37 are both the gap between what
`n_eff` measures and what section 3.15 says it means; decide the glossary
wording once. 33, 34 and 35 are `.resolve_eff_n()` and the role helpers missing
a branch section I already requires — one pass over section 2.2 closes them. 26
and 29 both add a row to `.fmt_pct()`, and 39 follows whichever rows land.
