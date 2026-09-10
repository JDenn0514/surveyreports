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
