# Spec: surveycore metadata integration for the export functions

**Version:** 0.3.0
**Date:** 2026-09-09
**Status:** **Methodology-locked** (Stage 2 Resolve, pass 2, 2026-09-09) — not spec-reviewed
**Id:** `export-metadata`
**Branch:** `feature/export-metadata`
**Tier:** 1 (spec → plan → implement)

---

## Document purpose

This document is the source of truth for the changes that connect
`export_crosstab()` and `export_topline()` to the metadata system in
surveycore 1.1.0.9000. It supersedes
`plans/2026-08-26-labelled-banner-eff-n-problem.md`, which covers workstream 1
only and predates the surveycore breaking change described in section 1.2.

Methodology review: `plans/spec-methodology-export-metadata.md`, passes 1 and 2.
All 14 issues from pass 1 and all 9 from pass 2 are resolved. Decisions are
logged in `plans/decisions-export-metadata.md`.

---

## I. Scope

### 1.1 What this spec delivers

Five workstreams. Workstream 1 fixes a defect. The others add behavior.

| # | Workstream | Type |
|---|---|---|
| 1 | Delegate effective N to `surveycore::get_effective_n()` | Defect fix |
| 2 | `base_notes` falls back to `universe` metadata | New behavior |
| 3 | `role` guard on `vars` and `banner` | New behavior |
| 4 | Dataset metadata cover sheet | New behavior |
| 5 | `all_of()` on the `classify_question_type()` call | Cleanup |

### 1.2 Upstream state — verified, not assumed

Every fact below was measured against surveycore `1.1.0.9000`, commit
`a0f2a7ac61`, on 2026-09-09.

| Fact | Evidence |
|---|---|
| A design no longer stores the `haven_labelled` class on any column. It keeps `label`, `labels`, `na_values` and `na_range`. | surveycore NEWS, breaking change (#175) |
| `@data` holds the numeric **code**. `get_freqs()` returns the group column as a **factor**, so `as.character()` gives the **label**. | measured |
| All 17 surveycore functions the package calls are still exported. | `NAMESPACE` diff |
| The test suite passes unchanged: 430 pass, 0 fail, 0 error, 88 warnings. | `devtools::test()` |
| `set_universe()`, `set_var_extra()` and `set_dataset_metadata()` work on all three design types. | measured |

surveycore issue #175 is closed by that breaking change. The acceptance
criterion "the labelled path works whether or not `haven` is loaded", carried
by the superseded plan, no longer applies inside a design.

#### 1.2.1 `get_effective_n()` — measured 2026-09-09

surveycore `1.1.0.9000` exports `get_effective_n()`. It returns the raw N, the
Kish effective N, and the group level **labelled the way `get_freqs()` labels
it**, in one call. Workstream 1 delegates to it. Every row below was measured.

| Property | Measurement |
|---|---|
| Columns returned | `<group>`, `n`, `n_eff`, `deff_kish`. With no `group`, one row and no group column. |
| Estimator | `method = "kish"` default. `n_eff` is `93.59602` where `n / ((n * sum(w^2)) / sum(w)^2)` is `93.59602`. The same estimator the current `.compute_eff_n()` implements. |
| Label vocabulary | The group column comes back `character` for a character banner and `factor` for a factor or labelled banner, with the **same** levels `get_freqs()` returns. Joining the two frames on `as.character(level)` left 0 of 4 rows unmatched on all three banner types. |
| Unobserved value label | Dropped. A label `Other = 3` whose code appears in no row is absent from both `get_effective_n()` and `get_freqs()`. |
| `NA` in the banner column | Excluded from every level's `n` and `n_eff`. |
| Duplicate value label | **Aborts**, in `.apply_group_labels()`, with the base-R message `factor level [3] is duplicated`. Both `get_effective_n()` and `get_freqs()` abort. See section 3.6. |
| Two-phase design | Resolves the phase-2 subset. See the table below. |
| Domain-restricted design | Applies `..surveycore_domain..`. See the table below. |
| `survey_collection` | **Accepted.** Returns one row per member with a `.survey` key column. Unlike `extract_universe()` and `extract_dataset_metadata()`, it does not abort. |

The two rows that matter most, measured on `make_all_designs(seed = 42)` and on
a 200-row taylor design with 75 rows in domain:

| Design | `nrow(@data)` | `get_freqs()` total n | current `.compute_eff_n()` | `get_effective_n()` |
|---|---|---|---|---|
| taylor | 200 | 200 | 184.98 | 184.98 |
| replicate | 200 | 200 | 184.98 | 184.98 |
| twophase | 200 | **119** | **184.98** | **110.15** |
| taylor, domain-restricted | 200 | **75** | **184.98** | **68.65** |

The current helper publishes an effective N above the raw N of the table it
labels, on two paths the previous draft's section 1.4 declared clean.

**A third cause stays unaddressed.** `get_effective_n()` counts rows and does
not look at the tabulated variable. Its `x` argument is inert under the Kish
estimator — surveycore prints `x is ignored when method = 'kish'`. So a variable
with missing values still shows a table N below the header's effective N.
Measured on 300 rows with 60 missing on `q1`:

| Call | Result |
|---|---|
| `get_effective_n(d)` | `n = 300`, `n_eff = 278.6` |
| `get_freqs(d, q1)` | `n = 130 + 110 = 240` |

This is pre-existing and unchanged by this spec — the current `.compute_eff_n()`
returns `278.6` for the same design. **Decision (Stage 2 Resolve, 2026-09-09,
issue 15, option A): state the limit, do not widen the scope.** `n` and `n_eff`
are design-level or banner-level row counts. Section 3.5 carries the contract.
Making `eff_n` per variable is a separate change with its own snapshot risk.

### 1.3 What this spec does NOT deliver

- No change to the signature of `export_crosstab()` or `export_topline()`, other
  than what section IV states. No new user-facing argument.
- No fix for `higher_is`, `missing_codes`, `var_note` or `reverse_coded`. These
  properties exist upstream and stay unread. Parked.
- No cleanup of the 39 existing `adldata` datasets.
- No `report_*()` function. This spec touches the export layer only.
- No change to how surveycore computes a frequency. The package still delegates
  every estimate.
- **No `eff_n` rendering in `export_crosstab()`.** Parked — see section 1.3.1.
- **No suppression of interaction cells.** Parked — see section 1.3.2.

#### 1.3.1 Parked: `show_eff_n` is a no-op on `export_crosstab()`

`show_eff_n` reaches all three crosstab renderers and none of them read it.
Measured — the parameter appears at `R/export-crosstab.R:498`, `:653` and
`:773` and at no other line in the render bodies.

The one place any workbook prints an effective N is the topline Total header,
`R/export-topline.R:288-289` and `:321-322`.

Workstream 1 therefore fixes the number `export_topline()` prints and the
number that drives suppression in both functions. It does not make
`show_eff_n = TRUE` visible in a crosstab workbook. Rendering it would change
every committed crosstab snapshot taken with `show_eff_n = TRUE`, which
section 9.4 forbids.

**Decision (Stage 2 Resolve, 2026-09-09, issue 1, option B.)** Follow-up work,
not this spec.

#### 1.3.2 Parked: interaction cells are never suppression-evaluated

The suppression loop iterates `banner_resolved` only, `R/export-utils.R:415`.
The `sup_vals` filter is applied to `.compute_subgroup_freq()` output only, at
`:490`. Rows from `.compute_interaction_freq()` pass through unfiltered.

An interaction cell is by construction smaller than either of its parents, so
it is where a below-threshold subgroup is most likely. A `gen × reg` cell can
hold 12 respondents and publish under `pub_type = "external"` while the `gen`
column that contains it is withheld.

This is pre-existing and outside the five workstreams. It is recorded here so
no reader takes section 3.1 to mean suppression is complete after workstream 1.
Workstream 1 corrects the vocabulary and the row selection that suppression
uses. It does not extend suppression to a new row type.

**Decision (Stage 2 Resolve, 2026-09-09, issue 14, option B.)** Open a
follow-up issue with its own test surface.

### 1.4 Design support matrix

| Design type | Workstreams 1–5 | Notes |
|---|---|---|
| `survey_taylor` | all | reference implementation |
| `survey_replicate` | all | no difference in behavior |
| `survey_twophase` | all | **`get_effective_n()` resolves the phase-2 subset. The current `.compute_eff_n()` does not — see section 1.2.1.** |
| `survey_collection` | 2, 3, 4, 5 | `export_crosstab()` rejects a collection. `export_topline()` accepts one. Its wave path takes no banner, so workstream 1's banner path does not reach it — but `get_effective_n()` accepts a collection, and **workstream 3 does reach it through `vars`.** |

Metadata extraction is design-type independent across the three **design**
types. Measured on all three.

Collections are the exception, and they are a trap. Three surveycore readers
**abort** on a `survey_collection`:

| Reader | Collection | Used by |
|---|---|---|
| `extract_universe()` | aborts | workstream 2 |
| `extract_var_extra()` | aborts | workstream 3 |
| `extract_dataset_metadata()` | aborts | workstream 4 |
| `get_effective_n()` | **works**, one row per member | workstream 1 |

Every metadata read in workstreams 2, 3 and 4 must branch on the design type.
Sections 4.4, 5.6 and 6.3 carry the measurements and the required branch.

---

## II. Architecture

### 2.1 Files touched

| File | Change |
|---|---|
| `R/export-utils.R` | new `.resolve_eff_n()`, `.banner_levels_labelled()`, `.unanimous_across()`, `.resolve_base_notes()`, `.resolve_roles()`, `.write_cover_sheet()`, `.unique_sheet_name()`; **delete `.compute_eff_n()`**; change the suppression loop; change the `show_eff_n` block; change the `.build_freq_frame()` collection branch (section 3.8); change `.compute_interaction_freq()`; change `.base_note_for()`; change `.build_workbook()` |
| `R/export-crosstab.R` | `all_of()` fix; role guard; duplicate-label validation; thread the resolved base notes; **route all three `wb_add_worksheet()` calls through `.unique_sheet_name()`** (section 6.2.1) |
| `R/export-topline.R` | `all_of()` fix; role guard; thread the resolved base notes |
| `plans/error-messages.md` | 2 new error classes, 2 new warning classes |
| `tests/testthat/test-export-crosstab.R` | new sections, see section IX |
| `tests/testthat/test-export-topline.R` | new sections, see section IX |

> ⚠️ GAP: `code-style.md` says a helper used in 2 or more source files lives in
> `R/utils.R`. No `R/utils.R` exists. `R/export-utils.R` already holds the
> shared helpers for both export functions. This spec follows the existing
> placement rather than creating a second shared file. Confirm in Stage 4, or
> rename the rule's target. (Open question 6.)

### 2.2 New helper signatures

```r
# Raw N and effective N per banner level, delegated to surveycore.
# The single source of truth for both counts.
.resolve_eff_n <- function(design, banner_var = NULL)
# -> tibble: level (chr), n (int), n_eff (dbl)
#    banner_var = NULL -> one row, level = NA_character_
#    Levels are LABELS, in get_freqs() vocabulary. Unobserved levels absent.

# Banner column translated from codes to value labels. Used by
# .compute_interaction_freq() so an interaction spanner reads
# "Male × North", not "1 × 1".
.banner_levels_labelled <- function(design, col)
# -> vector of length nrow(design@data), NA preserved.
#    factor in -> factor out, LEVEL ORDER PRESERVED. Anything else -> character.
#    Coercing a factor to character re-sorts the interaction spanners
#    alphabetically. See section 3.7.

# Keys whose value is identical and non-missing across every member.
# The one implementation of the unanimity rule in section 4.5.
.unanimous_across <- function(entries)
# entries: list of named character vectors, ONE PER MEMBER.
# -> named character vector; a key that disagrees or is missing anywhere
#    is omitted.
# The battery case has one vector and several variables, which is the
# transposed shape. Section 4.5 gives the call that reshapes it.

# The caller's base_notes and the design's universe, kept SEPARATE.
# They must not be merged into one vector: section 4.5 exempts the
# caller's entries from the unanimity rule, and after a merge the two
# sources are indistinguishable.
.resolve_base_notes <- function(design, base_notes)
# -> list(caller = <named chr or NULL>, universe = <named chr>),
#    or NULL when both sources are empty

# role lookup for a set of columns.
.resolve_roles <- function(design, cols)
# -> named character vector, one entry per element of cols,
#    NA_character_ where no role is set OR the payload is not a
#    length-1 character. Never aborts on a foreign payload.

# Cover sheet. No-op when the design carries no dataset metadata.
.write_cover_sheet <- function(wb, design)
# -> wb

# A sheet name that does not collide with one already in wb. Truncates to
# 31 characters first, then suffixes _2, _3, ... See section 6.2.1.
.unique_sheet_name <- function(wb, name)
# -> character(1)
```

### 2.3 Changed and deleted helper signatures

```r
# DELETED. surveycore::get_effective_n() replaces it.
.compute_eff_n <- function(design, col = NULL, level = NULL)

# Before
.build_workbook <- function()
# After
.build_workbook <- function(design)

# Signature unchanged. `base_notes` now carries the two-element list of
# section 4.2, and the lookup gains the caller-first, then-unanimity rule
# of section 4.5.
.base_note_for <- function(frame, base_notes)
```

Workstream 2 resolves the universe fallback before the render helpers run, so
no render signature moves. This is deliberate: it keeps workstream 2 out of
nine call sites.

---

## III. Workstream 1 — delegate effective N to surveycore

### 3.1 The defect

`.compute_eff_n()` subsets rows by comparing a banner column to a level string,
at `R/export-utils.R:145`:

```r
data <- data[data[[col]] == level, , drop = FALSE]
```

Two callers pass different vocabularies into the same parameter.

| Caller | Line | Passes | Source |
|---|---|---|---|
| suppression loop | `export-utils.R:421` | the code, `"2"` | `unique(design@data[[col]])` |
| `show_eff_n` | `export-utils.R:518` | the label, `"Female"` | `get_freqs()`, via `subgroup_value` |

`@data` holds codes. So the label caller matches nothing.

Three further defects sit in the same helper. All were measured — section 1.2.1.

| # | Defect | Effect |
|---|---|---|
| a | label-versus-code mismatch | `eff_n` is `NA`; suppression removes no row |
| b | `nrow(design@data)` counts phase-1 rows on a twophase design | `eff_n` 184.98 against a table whose n is 119 |
| c | `..surveycore_domain..` is never read | `eff_n` 184.98 against a table whose n is 75 |

Defects b and c are the serious ones for suppression, because they inflate the
number the threshold is compared against. A twophase subgroup whose true
effective N is 60 reports 100 or more and is published under
`pub_type = "external"`.

### 3.2 Measured behavior, before and after the upstream change

Reproduction: 300 rows, banner `gen` labelled `c(Male = 1, Female = 2)`, 20
rows Female.

| Path | surveycore 1.1.0 | surveycore 1.1.0.9000 |
|---|---|---|
| `show_eff_n = TRUE` (topline) | aborts, `vctrs` type error | **`eff_n` is `NA`, silently** |
| `pub_type = "external"` | aborts, `vctrs` type error | **flags Female, then publishes it** |

The upgrade fixes the suppression loop's own comparison, because that loop
compares codes against codes. It converts both user-visible failures from a
hard error into a wrong number.

The second row is the serious one. `R/export-utils.R:490` reads:

```r
r <- r[!r$subgroup_value %in% sup_vals, , drop = FALSE]
```

`sup_vals` holds codes. `r$subgroup_value` holds labels. The intersection is
always empty, so suppression removes no row. A subgroup below the publication
threshold is written to the workbook while the suppression footnote reports it
as withheld.

### 3.3 Why the existing tests miss it

`make_all_designs()` builds **every** group column as character. Measured —
`helper-test-data.R` builds `q1`, `q2` and `group` with `sample()` over
character vectors, and the file contains no `factor()` call. For a character
column the stored value and the label are the same string, so defect a is
invisible. Defects b and c are invisible because no test asserts on the value
of `eff_n` at all. Line coverage stays above the floor while the behavior is
wrong.

The same gap hides the factor level-order defect of section 3.7: no fixture is
a factor, so no test can see a re-sorted interaction spanner. Section 9.1 adds
one.

### 3.4 Required behavior

**Decision (Stage 2 Resolve, 2026-09-09, issue 5, option A): delegate.**
`surveycore::get_effective_n()` returns the raw N, the Kish effective N and the
value label in one call, and it resolves the phase-2 subset and the domain
column the local helper ignores. Rebuilding that join in this package would
carry a second Kish estimator that must track surveycore's domain, twophase and
labelling rules by hand.

`subgroup_value` canonicalizes on the **value label**, which is what
`get_effective_n()` already returns and what the workbook renders.

Consequences:

1. `.compute_eff_n()` is deleted.
2. The suppression loop iterates the rows of `.resolve_eff_n()`, so it stores
   the **label** in `suppressed$subgroup_value` and takes `raw_n` from the same
   frame.
3. `.write_suppression_footnote()` prints the label with no change, because it
   reads `row$subgroup_value`. **The footnote text changes for an unlabelled
   code.** The loop iterates codes today, so an unlabelled code 3 reads
   `gen=3`. After the change it reads `gen=NA`. `%in%` matches a missing value
   to a missing value, so the `sup_vals` filter at `R/export-utils.R:490` still
   removes the right rows with no further change.
4. The unobserved-label problem disappears. `get_effective_n()` drops a level
   whose code appears in no row, exactly as `get_freqs()` does — measured. No
   intersection against observed codes is needed.
5. Twophase and domain-restricted designs become correct with no further branch.

### 3.5 `.resolve_eff_n()` contract

```r
.resolve_eff_n <- function(design, banner_var = NULL) {
  is_coll <- S7::S7_inherits(design, surveycore::survey_collection)

  # min_cell_n = 30L makes get_effective_n() warn on exactly the small cells
  # suppression exists to find. Muffle it the way .compute_subgroup_freq()
  # and .compute_interaction_freq() already muffle the same class.
  out <- withCallingHandlers(
    if (is.null(banner_var)) {
      surveycore::get_effective_n(design)
    } else {
      surveycore::get_effective_n(design, group = !!rlang::sym(banner_var))
    },
    surveycore_warning_small_cell = function(w) invokeRestart("muffleWarning")
  )

  # Branch on the design type, not on banner_var. A collection always has
  # banner_var = NULL and still returns one row per member, keyed by .survey.
  level <- if (is_coll) {
    as.character(out$.survey)
  } else if (is.null(banner_var)) {
    NA_character_
  } else {
    as.character(out[[banner_var]])
  }

  tibble::tibble(
    level = level,
    n = as.integer(out$n),
    n_eff = as.numeric(out$n_eff)
  )
}
```

| Input shape | Behavior |
|---|---|
| `banner_var = NULL` | one row, `level` is `NA_character_`, counts over the whole design |
| labelled banner | one row per **observed** code, `level` is the value label |
| character or factor banner | one row per observed level, `level` is that level |
| `NA` in the banner column | excluded from every level's `n` and `n_eff` |
| a value label whose code appears in no row | **no row** — surveycore drops it |
| twophase design | counts over the phase-2 subset |
| domain-restricted design | counts over the in-domain rows |
| a banner where some codes carry a label and some do not | one row per observed code. Labelled codes give the label; an unlabelled code gives `level = NA_character_`. This is a **real subgroup** with a real `n`, and it is suppressible. Measured — `get_freqs()` returns the same `NA` level, so the join is exact. |
| `survey_collection` | one row per member; the `.survey` column supplies `level`. A caller that expects a single row must select its member first. |

`n_eff` is `NA_real_` only where surveycore returns `NA_real_`. This package
adds no `NA` path of its own.

The helper raises **no warning of its own**. `surveycore_warning_small_cell` is
muffled in the body, as the pseudocode above shows. Suppression reports a small
subgroup through `surveyreports_warning_subgroup_suppressed`, which is this
package's own class and carries the threshold that actually applies.

**`n` and `n_eff` do not depend on the tabulated variable.** `get_effective_n()`
counts rows. Its `x` argument is inert under the Kish estimator — surveycore
prints `x is ignored when method = 'kish'`. So both counts are design-level or
banner-level, and both may exceed the N shown for a variable that has missing
values. Section 1.2.1 records this as the third, unaddressed cause of a header
effective N above a table's N.

### 3.6 Duplicate value labels — abort, do not warn

The previous draft confirmed a decision that a duplicate label warns and unions
the codes. **That decision is reversed** (Stage 2 Resolve, 2026-09-09, issue 6).

The union is unobservable and the specified path ends in an opaque abort.
`set_val_labels()` accepts a duplicate label. Both `get_freqs()` and
`get_effective_n()` then abort inside `.apply_group_labels()`. Measured with
`gen = c(Male = 1, Female = 2, Female = 3)`:

```
Error in `levels<-`(`*tmp*`, value = as.character(levels)) :
  factor level [3] is duplicated
```

So the specified behavior would be: warn, compute a union effective N nobody
sees, then abort with a base-R message naming a surveycore internal.

Required: detect a duplicate value label on a `banner` column during
validation, **before any estimate runs**, and abort with a named class.

| Condition | Behavior |
|---|---|
| a `banner` column carries one label mapped to 2 or more codes | abort, `surveyreports_error_duplicate_value_label` |
| a `banner` column carries 2 or more labels mapped to one code | keep — this is not a factor-level collision and surveycore accepts it |

The message names the column and the repeated label, and its `"v"` bullet
points at `surveycore::set_val_labels()`.

`surveyreports_warning_duplicate_value_label` is removed from section VIII.

### 3.7 Interaction spanners read codes, not labels

`.compute_interaction_freq()` at `R/export-utils.R:238-242` builds its grouping
column from `@data`:

```r
design@data[[interact_col]] <- do.call(
  interaction, c(design@data[banner_vars], list(sep = " × "))
)
```

`@data` holds codes, and the new column carries no value labels, so
`get_freqs()` returns the code strings unchanged. `.build_col_groups()` at
`R/export-crosstab.R:384` takes the spanner levels straight from them.
Measured with `gen = c(Male = 1, Female = 2)` and `reg = c(North = 1,
South = 2)`:

```
levels(interaction(d@data[c("gen","reg")], sep = " × "))
[1] "1 × 1" "2 × 1" "1 × 2" "2 × 2"
```

One workbook, two vocabularies: the `gen` spanner reads `Male` and the
`gen × reg` spanner reads `1 × 1`. Section 3.4 declares a single canonical
vocabulary, so this is in scope.

Required: translate each banner column with `.banner_levels_labelled()` before
`interaction()` runs.

```r
design@data[[interact_col]] <- do.call(
  interaction,
  c(
    lapply(banner_vars, function(v) .banner_levels_labelled(design, v)),
    list(sep = " × ")
  )
)
```

`.banner_levels_labelled()` maps a code to its label through
`design@metadata@value_labels[[col]]`. A character or factor banner already
stores its label, so the lookup returns the column unchanged. `NA` stays `NA`.

**A factor must come back as a factor, with its level order intact.**
`interaction()` orders character input alphabetically, and
`.build_col_groups()` at `R/export-crosstab.R:384` takes the spanner order
straight from those levels. Measured:

```
f1 <- factor(c("Low", "High", ...), levels = c("Low", "High"))
levels(interaction(list(f1, f2), sep = " x "))
[1] "Low x N"  "High x N"  "Low x S"  "High x S"

levels(interaction(list(as.character(f1), as.character(f2)), sep = " x "))
[1] "High x N"  "Low x N"  "High x S"  "Low x S"
```

So a character return re-sorts every non-alphabetical factor banner: a Likert
banner ordered `Low`, `Medium`, `High` would render `High`, `Low`, `Medium`.
The helper returns a factor for a factor input and a character vector
otherwise.

Interaction rows keep `eff_n = NA_real_`, as today —
`R/export-utils.R:517-524`. Section 1.3.2 records why.

### 3.8 Call site changes

| Site | Before | After |
|---|---|---|
| `export-utils.R:415-445` suppression loop | iterate `unique(col_vals)`, store the code, call `.compute_eff_n()` and `sum(col_vals == level)` per level | iterate the rows of `.resolve_eff_n(design, banner_var)`; store `level`, `n_eff` and `n` from that frame |
| `export-utils.R:517-524` `show_eff_n` block | `.compute_eff_n(design)` / `.compute_eff_n(design, svar, sval)` | join `all_rows` to `.resolve_eff_n(design, NULL)` for `total` rows and `.resolve_eff_n(design, svar)` for `banner` rows, on `as.character(subgroup_value)`; `interaction` rows stay `NA_real_` |
| `export-utils.R:238-242` interaction column | `interaction(design@data[banner_vars])` | `interaction()` over `.banner_levels_labelled()` output |
| `export-utils.R:381-396` `.build_freq_frame()` collection branch | `mapply()` over `.compute_eff_n(design@surveys[[svar]])` per wave | `.resolve_eff_n(design@surveys[[svar]], NULL)` per wave, joined on **`subgroup_var`** |
| `export-utils.R:134-158` | `.compute_eff_n()` body | deleted, including the `# nocov` block at `:148-153` |

The collection branch is not a copy of the `show_eff_n` change, because its join
key differs. A wave row carries `subgroup_value = NA_character_` and holds the
wave name in `subgroup_var`, so the "join on `as.character(subgroup_value)`"
rule of the second row matches nothing on this path. Missing this call site
breaks `export_topline(collection, show_eff_n = TRUE)` at load.

**The pooled `Total` row keeps `NA_real_`.** The current block hard-codes it,
and `R/export-topline.R:288-289` reads `frame$eff_n[frame$subgroup_type ==
"total"]`, so a trend workbook prints `Total` with no effective N today.
`get_effective_n()` could supply one — it returns a row per member for a
collection — but a single pooled figure over waves with different designs is
not a number this spec defines. Keeping `NA_real_` is the no-change option and
is deliberate.

Call `.resolve_eff_n()` once per banner column, not once per level. The
suppression loop and the `show_eff_n` block may share one cached result per
column.

The `# nocov` block at `R/export-utils.R:148-153` states that `n == 0` "cannot
occur via the public API". Deleting the helper deletes the annotation. Per
`testing.md`, a `# nocov` marker is never acceptable as cover for a missing
test.

---

## IV. Workstream 2 — `base_notes` falls back to `universe`

### 4.1 Current behavior

`base_notes` is an optional named character vector supplied by the caller. The
lookup is one helper:

```r
.base_note_for <- function(frame, base_notes) {
  if (is.null(base_notes)) return(NULL)
  var <- frame$variable[[1L]]
  if (!var %in% names(base_notes)) return(NULL)
  base_notes[[var]]
}
```

Nine render call sites pass `base_notes` through unchanged.

### 4.2 Required behavior

`surveycore::extract_universe()` returns the same kind of text for the same
purpose: the population a question was asked of. The caller should not retype
it.

Resolve both sources into one vector, once, in each export function:

```r
.resolve_base_notes <- function(design, base_notes) {
  universe <- .design_universe(design)      # branches on design type, see 4.4
  if (length(universe) == 0L && is.null(base_notes)) return(NULL)
  list(caller = base_notes, universe = universe)
}
```

The two sources stay **separate**. A single merged vector would satisfy the
precedence table below, but it would break section 4.5: after a merge nothing
distinguishes a caller entry from a universe entry, so a battery whose first
member carries a caller note and whose other members carry a differing universe
would be judged by unanimity and print nothing — the opposite of the exemption
4.5 states. `.base_note_for()` resolves the precedence at lookup time instead.

| Source | Precedence |
|---|---|
| `base_notes[[var]]` supplied by the caller | wins, and is **exempt** from the unanimity rule of section 4.5 |
| `universe` metadata on the design | used when the caller supplies nothing for that variable, subject to unanimity |
| neither | no base-note row, exactly as today |

`extract_universe()` omits a variable with no universe set, so an unset variable
never produces an empty italic row.

### 4.3 Ordering constraint

`.validate_base_notes(base_notes)` validates the **caller's** input. It must run
before the merge, on the caller's vector alone. Metadata written by surveycore
is not the caller's error to fix, and a validation message that names a variable
the caller never mentioned is wrong.

### 4.4 Collections — a hard constraint, measured

**Measured 2026-09-09.** `extract_universe()` does **not** accept a
`survey_collection`. It **aborts**. So do `extract_var_extra()` and
`extract_dataset_metadata()`.

The exact message is deliberately not quoted here. Two methodology passes
measured two different texts for it, and a later reader who matches on a quoted
string will match on the wrong one. The fact the branch depends on is that the
three readers abort, and that fact does not decay. Assert on the branch, not on
the message.

`export_topline()` accepts a collection and has a dedicated wave path. So a
`.resolve_base_notes()` that calls `extract_universe(design)` unconditionally
would abort **every trend workbook**. The naive implementation of this
workstream is a regression, not a feature.

Required: branch on the design type before reading metadata.

```r
.design_universe <- function(design) {
  if (!S7::S7_inherits(design, surveycore::survey_collection)) {
    return(surveycore::extract_universe(design))
  }
  .unanimous_across(lapply(design@surveys, surveycore::extract_universe))
}
```

Per-member metadata stays reachable — `design@surveys[[i]]` is an ordinary
design, and `extract_universe()` works on it. Measured.

### 4.5 The unanimity rule

`.base_note_for()` keys on `frame$variable[[1L]]` — the sole variable of a
single-choice table, or the **first member** of a SATA or battery group. With a
caller-supplied vector that is harmless: a caller who names only the first
member gets what they asked for.

The universe fallback removes that intent. `extract_universe()` returns one
entry per variable, and a battery cleaned by the ADL schema carries a universe
on all five members. First-member semantics would print member 1's universe over
the whole block, whether or not the other four agree, and would print nothing
when member 1 alone has no universe set.

**Decision (Stage 2 Resolve, 2026-09-09, issue 4 and old open question 7,
option A): unanimous-only, one rule everywhere.**

| Scope | Rule |
|---|---|
| a single-choice table | print the variable's universe |
| a SATA or battery block | print the universe only when **every** member of the group carries the **same** text; otherwise print none |
| a collection | print the universe only when **every** member survey carries the same text for that variable; otherwise print none |
| a role lookup on a collection (section 5.6) | the same `.unanimous_across()` rule |

A caller-supplied `base_notes` entry is exempt. The caller named the group's
first variable on purpose, and their text always wins — precedence is
section 4.2's table.

One shared helper implements the rule:

```r
.unanimous_across <- function(entries) {
  # entries: list of named character vectors, one per member
  # -> named character vector of the keys whose value is identical
  #    and non-missing across every member; other keys omitted
}
```

**The two callers pass different shapes, and only one of them fits directly.**
The collection case is the native shape: `entries[[i]]` is wave `i`'s universe
vector, keyed by variable, and "keys identical across members" is the right
question.

The battery case is transposed. There is **one** universe vector and **several**
variable names, and the question is whether `u["bat_1"]`, `u["bat_2"]` and
`u["bat_3"]` hold the same text. Passing those as three named vectors gives
three members with three different keys, no key is present in all three, and the
helper returns nothing — applied literally, a battery would never print a base
note. Reshape so every member shares one key:

```r
.unanimous_across(lapply(vars, function(v) c(note = unname(u[v]))))
```

An unset variable makes `u[v]` an `NA`, which the helper's non-missing test
rejects. That is the "one member unset → no base-note row" row of the table
above.

**Composition order for a battery inside a collection:** resolve each wave's
universe first with the collection rule, then apply the battery rule to the
unanimous result. A variable that fails wave unanimity is already absent, so the
battery rule sees an `NA` for it and prints nothing. The two rules never run in
the other order.

`.base_note_for()` changes as follows. Its signature is unchanged, but
`base_notes` now carries the two-element list of section 4.2.

1. **Caller first.** If `caller[[frame$variable[[1L]]]]` is set, return it. This
   is today's path, byte for byte, and it is the exemption this section states.
2. **Otherwise the universe, under unanimity.** A single-variable frame reads
   `universe[[frame$variable[[1L]]]]`. A multi-variable frame applies the
   reshaped `.unanimous_across()` call above over `unique(frame$variable)`.
3. **Otherwise `NULL`**, exactly as today.

This never states a universe that is false for a member of the block. A block
whose members disagree is the case where a single line cannot be correct.

---

## V. Workstream 3 — `role` guard on `vars` and `banner`

### 5.1 Where `role` lives

`role` is **not** a first-class surveycore property. It is a key inside the
per-variable extension slot `var_extra`. surveycore stores and returns the
payload unchanged and never reads it.

```r
surveycore::extract_var_extra(design)          # -> list, $var$role
surveycore::extract_var_extra(design, q1)$q1$role
```

`extract_var_extra()` on a variable with no payload returns an empty named list.
The `format = "data_frame"` shape returns `variable` / `key` / `value` with
`value` as a **list column**. This spec uses the list format.

The seven role values come from the ADL cleaning schema, section 7 of
`adldata/plans/survey-cleaning-skill-design.md`: `item`, `demographic`,
`treatment`, `weight`, `identifier`, `paradata`, `free_text`.

### 5.2 Required behavior

**Decision (confirmed 2026-09-09): warn and drop, for both `vars` and
`banner`.**

| Condition | Behavior |
|---|---|
| a column in `vars` carries a non-substantive role | drop it, warn once listing every dropped column |
| a column in `banner` carries a non-substantive role | drop it, warn once listing every dropped column |
| a column carries no `role` | keep it — substantive by default |
| a column carries an unrecognized `role` string | keep it, warn |
| a column's `role` is not a length-1 character | **keep it, warn** — see section 5.3 |

`role` is new, and almost no existing dataset sets it. Treating an absent role as
substantive is the only choice that keeps current data working.

This closes the free-text defect the superseded plan parked. `ald1_13_text` is
selected by `starts_with("ald1_")` and renders as a 119-row table of verbatim
answers at 0.1% each. With `role = "free_text"` set, it drops.

### 5.3 `.resolve_roles()` must not abort on a foreign payload

surveycore does not validate a `var_extra` payload. Measured:

```r
d <- set_var_extra(d1, q1 = list(role = c("item","demographic")),
                       q2 = list(role = 3L))
extract_var_extra(d)
#> $q1$role
#> [1] "item"        "demographic"
#> $q2$role
#> [1] 3
```

Both were accepted. A one-entry-per-column character vector cannot hold either,
and the obvious `vapply(..., character(1))` implementation aborts on the first:

```
Error in vapply(...) : values must be length 1,
 but FUN(X[[1]]) result is length 2
```

The role guard reads foreign metadata written by a cleaning pipeline this
package does not control. It must not abort on a payload shape it did not
expect.

Required coercion rule, applied per column before any classification:

| Payload | `.resolve_roles()` returns | Guard behavior |
|---|---|---|
| a length-1 character | that string | classify normally |
| a length-0 value, or the key is absent | `NA_character_` | keep, no warning |
| a length-2 or longer vector | `NA_character_` | keep, warn `surveyreports_warning_unknown_role` |
| a non-character of any length | `NA_character_` | keep, warn `surveyreports_warning_unknown_role` |
| a length-1 character outside the seven known values | that string | keep, warn `surveyreports_warning_unknown_role` |

The warning names the column and, when the payload is a length-1 string, the
value. It fires once per call listing every affected column.

### 5.4 Non-substantive roles

> ⚠️ GAP: the confirmed decision names `paradata` and `free_text`. This spec
> proposes the drop set `c("weight", "identifier", "paradata", "free_text")`,
> keeping `c("item", "demographic", "treatment")`. Confirm the set in Stage 4.
> (Open question 3.)

### 5.5 Degenerate cases the decision creates

Dropping columns can empty a required argument. Both cases must be specified,
because a warning-only policy cannot render a table from nothing.

| Case | Behavior |
|---|---|
| `vars` drops to zero columns | abort, existing `surveyreports_error_vars_empty_selection` |
| `banner` drops to zero columns | abort, **new** `surveyreports_error_banner_empty_selection` |

> ⚠️ GAP: this is a consequence of "warn and drop", not a separate choice. It was
> flagged to the author as the risk of that option — a mistyped banner produces a
> workbook with no banner. Escalating the all-dropped case to an error contains
> that risk without reversing the decision. Confirm in Stage 4. (Open question 4.)

### 5.6 Collections — the third instance of the same trap

The previous draft's section 1.4 ruled workstream 3 out for collections, because
"its wave path takes no banner". That reasoning covers `banner` only.
Section 5.2 guards **`vars`** as well, and `export_topline()` takes `vars` for a
collection. So `.resolve_roles(design, vars_resolved)` runs on a collection, and
it reads `extract_var_extra()`.

Measured 2026-09-09: `extract_var_extra()` **aborts** on a `survey_collection`,
for the reason section 4.4 gives.

Required: branch on the design type, using the same unanimity rule section 4.5
sets.

```r
.resolve_roles <- function(design, cols) {
  extra <- if (!S7::S7_inherits(design, surveycore::survey_collection)) {
    surveycore::extract_var_extra(design)
  } else {
    .unanimous_across(
      lapply(design@surveys, function(s) {
        .roles_of(surveycore::extract_var_extra(s))
      })
    )
  }
  # ... coercion rule from section 5.3 ...
}
```

A column whose role differs between waves resolves to `NA_character_` and is
kept. Dropping a variable from a trend workbook because one wave labelled it
`paradata` would silently shorten the series.

### 5.7 Ordering constraint

The role guard runs **after** tidyselect resolution and **after** the existing
not-found checks, and **before** `classify_question_type()`. A dropped column
must not reach classification, or it will form its own question group and change
the group numbering of everything after it.

The duplicate-value-label check of section 3.6 runs on the **surviving**
`banner` columns, after the role guard. There is no point aborting over a label
collision on a column that is about to be dropped.

---

## VI. Workstream 4 — dataset metadata cover sheet

### 6.1 Required behavior

**Decision (confirmed 2026-09-09): a dedicated cover sheet.** It is written once
regardless of layout, and it does not disturb the `start_row` arithmetic that
every render helper computes. A per-sheet title block would repeat six keys on
every question sheet in `per_question` layout and shift every offset.

```r
.build_workbook <- function(design) {
  wb <- openxlsx2::wb_workbook()
  .write_cover_sheet(wb, design)
}
```

| Condition | Behavior |
|---|---|
| the design carries no dataset metadata | **no sheet is added**; the workbook is byte-identical to today's |
| one or more keys are set | add a sheet named `"About"` as the first sheet, one row per set key |

The empty case matters. It keeps all 430 existing tests and every committed
snapshot valid, because no fixture in `make_all_designs()` sets dataset
metadata.

### 6.2 Sheet contents

Read with `extract_dataset_metadata(design, format = "data_frame")` and no
`fill`, so only set keys appear, in surveycore's canonical key order. Two
columns: a display label, then the value.

| Key | Display label |
|---|---|
| `survey_name` | Survey |
| `data_name` | Dataset |
| `vendor` | Vendor |
| `field_start` | Field start |
| `field_end` | Field end |
| `field_period` | Field period |

Column A is bold. No merged cells, no styling beyond bold, so the sheet stays
readable and the writer stays short.

### 6.2.1 Sheet mechanics — header, position, name collision

| Item | Rule |
|---|---|
| **Header row** | Row 1 is a header: `Key` in A1, `Value` in B1, both bold. Data starts at row 2. |
| **Position and active sheet** | `openxlsx2::wb_workbook()` creates no sheets, so `"About"` becomes sheet 1 and the active sheet. A workbook with dataset metadata **opens on the cover sheet**. This is intended. |
| **Name collision** | Data sheet names come from the variable name, truncated to 31 characters — `R/export-crosstab.R:207`. A variable named `About` in `per_question` layout collides, and openxlsx2 aborts on a duplicate sheet name. The **data** sheet is suffixed — `About_2`, then `About_3` — because the cover sheet name is fixed and a user cannot rename it. |
| **Owner** | `.unique_sheet_name(wb, name)` in `R/export-utils.R`. `R/export-crosstab.R` routes all three `wb_add_worksheet()` calls — `:209`, `:231`, `:253` — through it. No deduplication exists today: `:207` is `substr(var, 1L, 31L)` with no uniqueness check. |

A shared helper is the smaller change and it also closes a pre-existing case:
two variables whose names share their first 31 characters abort today for the
same reason.

`export_topline()` is unaffected. Measured — it writes one sheet, `"Topline"`,
at `R/export-topline.R:129`, and has no `per_question` layout. Section 9.2
row 20 is correctly marked crosstab-only.

Inserting a first sheet is otherwise safe. Measured — `wb_add_worksheet()` and
every `sheet =` argument in both export functions take the sheet **name**, not
an index.

### 6.3 Design types, and the same collection constraint

`set_dataset_metadata()` and `extract_dataset_metadata()` were measured on
taylor, replicate and twophase designs. All three round-trip. For a twophase
design surveycore exposes the phase-1 keys.

**Measured 2026-09-09.** `extract_dataset_metadata()` **aborts** on a
`survey_collection`, for the reason section 4.4 gives. So
`.build_workbook(design)` must branch on the design type for the same reason
section 4.4 gives, or `export_topline()` breaks for every collection.

Per-member keys stay reachable. Measured on a two-wave collection:

```
$wave1  "Wave 1 Survey"
$wave2  "Wave 2 Survey"
```

Required: for a collection, write one row per wave, reading each
`design@surveys[[i]]`. A trend workbook covers more than one survey, so a single
`survey_name` would be wrong. This is the shape the data already has.

The unanimity rule of section 4.5 does **not** apply here. A cover sheet has room
to show every wave's value, so there is no need to collapse disagreement into
silence.

> ⚠️ GAP: the per-wave cover sheet is a layout this spec asserts but has not
> designed. Column per key and row per wave, or a block per wave. Decide in
> Stage 4. (Open question 8.) The single-design case in sections 6.2 and 6.2.1 is
> unaffected and can ship first.

---

## VII. Workstream 5 — `all_of()` on the classification call

### 7.1 The defect

`R/export-crosstab.R:179` and `R/export-topline.R:112` pass the resolved
character vector straight into a tidy-select argument:

```r
classify_out <- surveycore::classify_question_type(design, vars_resolved)
```

surveycore forwards `...` to `tidyselect::eval_select(rlang::expr(c(...)))`.
tidyselect sees a bare external vector and raises the 1.1.0 deprecation warning.
This accounts for 80 of the 88 warnings in the current suite.

### 7.2 Required behavior

```r
classify_out <- surveycore::classify_question_type(
  design,
  tidyselect::all_of(vars_resolved)
)
```

Measured on 2026-09-09: the warning goes, and the returned frame is
`identical()` to the frame the bare vector produces. tidyselect may promote this
deprecation to an error, so the fix also removes a future break.

---

## VIII. Error and warning classes

Add these rows to `plans/error-messages.md` **before** implementation, per
`code-style.md`.

### Errors

| Class | Thrown by | Condition |
|---|---|---|
| `surveyreports_error_banner_empty_selection` | `export_crosstab()` | every `banner` column was dropped by the role guard |
| `surveyreports_error_duplicate_value_label` | `export_crosstab()` | a surviving `banner` column carries one value label mapped to 2 or more codes; `get_freqs()` would abort downstream |

### Warnings

| Class | Raised by | Condition |
|---|---|---|
| `surveyreports_warning_role_dropped` | `export_crosstab()`, `export_topline()` | one or more columns were dropped from `vars` or `banner` for a non-substantive `role` |
| `surveyreports_warning_unknown_role` | `export_crosstab()`, `export_topline()` | a column's `role` is outside the seven known values, or is not a length-1 character; the column is kept |

`export_topline()` has no `banner` argument — its signature is `design, vars,
file_name, conf_level, decimals, variance, show_n, show_eff_n, base_notes`,
`R/export-topline.R:54-64`. Every banner-only class above is therefore
`export_crosstab()` only. The two warning classes reach both functions through
`vars`.

`surveyreports_warning_duplicate_value_label` from the previous draft is
**removed**. Section 3.6 replaces it with an error.

Message structure follows `code-style.md`: `"x"` or `"!"`, then `"i"`, then an
optional `"v"`; declarative for the first two, imperative for the fix.

---

## IX. Testing

`testing.md` is authoritative for structure, assertions, coverage and data
generation. This section lists only what is specific to this spec.

### 9.1 The fixtures this work requires

Every existing banner fixture hides the defect. Per `testing.md`, build the new
fixtures **inline**. Do not add a parameter to `make_all_designs()`.

```r
# Labelled banner. Codes and labels must differ, or the test proves nothing.
d@data$gen <- c(rep(1, 280), rep(2, 20))
d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))

# Domain-restricted design, for row 7.
d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$group == "A"

# Partially labelled banner, for row 26. Code 3 carries no label, so it comes
# back as a real NA level with a real n. Measured — get_freqs() agrees.
d@data$gen <- c(rep(1, 150), rep(2, 30), rep(3, 20))
d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))

# Factor banner whose level order is NOT alphabetical, for row 27.
# No make_all_designs() column is a factor, so this cannot be borrowed.
d@data$lik <- factor(
  sample(c("Low", "Medium", "High"), nrow(d@data), replace = TRUE),
  levels = c("Low", "Medium", "High")
)
```

### 9.2 Test sections to add

The **Applies to** column is required. `export_topline()` has no `banner`, so a
banner row cannot be written against it — see section VIII. All three design
types per `testing.md` unless a row says otherwise.

| # | Section | Applies to | Must assert |
|---|---|---|---|
| 1 | labelled banner, suppression | crosstab | the flagged subgroup's rows are **absent** from the rendered frame. The superseded bug passed a success-only assertion. |
| 2 | labelled banner, footnote | crosstab | the footnote prints the label, not the code |
| 3 | character and factor banners | crosstab | behavior byte-identical to today, **except** a factor banner's interaction spanner order, which section 3.7 fixes — see row 27 |
| 4 | duplicate value label on a banner | crosstab | aborts `surveyreports_error_duplicate_value_label` **before** any estimate; the base-R `factor level is duplicated` message never surfaces |
| 5 | `eff_n` matches `get_effective_n()` | both | `.resolve_eff_n()` output equals `surveycore::get_effective_n()` for the same design and group, `n` exactly and `n_eff` to `1e-8` |
| 6 | twophase `eff_n` | topline | the rendered Total-header effective N is at or below the **design's in-scope row count** — 119 for the twophase fixture, not `nrow(@data)`. Guards the 184.98-against-119 defect of section 1.2.1. Do **not** assert against the table's N: section 3.5 states that `n_eff` ignores the tabulated variable, so the assertion would fail for any variable with missing values. |
| 7 | domain-restricted `eff_n` | both | `n` equals the in-domain row count, not `nrow(@data)`. Guards the 184.98-against-75 defect. Same caveat as row 6. |
| 8 | unobserved value label | crosstab | a label whose code appears in no row produces **no** suppression entry and no footnote line |
| 9 | interaction spanner vocabulary | crosstab | a `gen × reg` spanner reads `Male × North`, not `1 × 1` |
| 10 | `universe` fallback | both | a base-note row appears with no `base_notes` argument |
| 11 | `base_notes` precedence | both | the caller's text wins over `universe` for the same variable |
| 12 | universe unanimity, battery | both | all members agree → the text prints; one member differs → **no** base-note row; one member unset → **no** base-note row |
| 13 | role guard, `vars` | both | a `free_text` column drops; warns; the remaining variables are unchanged |
| 14 | role guard, `banner` | crosstab | a `paradata` column drops; warns |
| 15 | role guard, all dropped | `vars` both, `banner` crosstab | `vars` → `surveyreports_error_vars_empty_selection`; `banner` → `surveyreports_error_banner_empty_selection` |
| 16 | no `role` set | both | every column is kept, no warning |
| 17 | malformed `role` payload | both | a length-2 character and a non-character `role` each keep the column and warn `surveyreports_warning_unknown_role`; **no abort** |
| 18 | cover sheet, metadata set | both | an `"About"` sheet exists, is first, is active, has a `Key` / `Value` header, and holds only the set keys |
| 19 | cover sheet, no metadata | both | **no** `"About"` sheet; workbook unchanged |
| 20 | cover sheet, name collision | crosstab | a variable named `About` in `per_question` layout produces `About` plus `About_2`; no openxlsx2 abort |
| 21 | `all_of()` | both | no tidyselect deprecation warning is raised |
| 22 | collection, workstream 2 | topline | the call succeeds. A guard-free `extract_universe()` aborts here, so this test is the regression gate for section 4.4. |
| 23 | collection, workstream 3 | topline | the role guard on `vars` succeeds. A guard-free `extract_var_extra()` aborts here — the gate for section 5.6. |
| 24 | collection, workstream 4 | topline | the call succeeds and the cover sheet reflects every wave. The gate for section 6.3. |
| 25 | collection, role differs by wave | topline | a variable labelled `paradata` in one wave only is **kept**, per section 5.6 |
| 26 | partially labelled banner | crosstab | an unlabelled code produces a row whose `level` is `NA_character_` with its true `n`; when it falls below the threshold it is suppressed and the footnote reads `gen=NA`, not `gen=3` |
| 27 | factor banner, interaction order | crosstab | a banner with levels `Low`, `Medium`, `High` renders its interaction spanners in that order, **not** alphabetically. Guards section 3.7's factor return. |
| 28 | no warning leaks from `.resolve_eff_n()` | both | a banner with a cell under 30 raises **no** `surveycore_warning_small_cell`. Guards section 3.5's muffle and section X's warning-count gate. |
| 29 | collection, `show_eff_n` | topline | `export_topline(collection, show_eff_n = TRUE)` succeeds; each wave row carries a finite `eff_n`; the pooled `Total` row stays `NA_real_`. The gate for section 3.8's fourth call site. |
| 30 | caller exemption on a battery | both | a battery whose first member has a caller `base_notes` entry and whose members carry **differing** universes prints the caller's text. Guards the separate-sources rule of section 4.2. |

Rows 22, 23 and 24 are the three tests that would have caught the defects
sections 4.4, 5.6 and 6.3 describe. Write them first.

Every error and warning class in section VIII gets the dual pattern from
`testing.md`: `expect_error(class=)` or `expect_warning(class=)`, plus
`expect_snapshot()`.

### 9.3 Numerical accuracy

`.resolve_eff_n()` **does** have a surveycore counterpart. Per `testing.md`'s
numerical-accuracy rule, the reference is that function, not a re-derivation of
the formula:

```r
ref <- surveycore::get_effective_n(d, group = gen)
out <- surveyreports:::.resolve_eff_n(d, "gen")
expect_identical(out$n, as.integer(ref$n))
expect_equal(out$n_eff, ref$n_eff, tolerance = 1e-8)
```

The previous draft's direct formula computation is removed. It compared the
implementation to a copy of its own arithmetic, which proved nothing about
agreement with the frequencies it annotates.

Tolerance `1e-8`, per the SE row of `testing.md`.

### 9.4 Regression guard on the existing suite

The 430 passing tests must still pass with no snapshot update. Any snapshot
change means a workstream leaked into the no-metadata path, which section 6.1
forbids.

One exception is possible and must be confirmed deliberately: a committed
snapshot that renders an **interaction spanner** changes if its banner columns
are labelled, because section 3.7 turns `1 × 1` into `Male × North`.

No committed snapshot is affected. Measured — `helper-test-data.R` builds every
group column with `sample()` over a character vector and contains no `factor()`
call, so no fixture column carries value labels and none is a factor. Section
9.4 therefore holds with no exception. Confirm the measurement at
implementation rather than the earlier claim that the fixtures are "character
and factor", which is wrong.

---

## X. Quality gates

Objectively verifiable. Every line is a command or a file check.

- [ ] `devtools::test()` — 0 failures, 0 errors
- [ ] The 88 current warnings drop to 8 or fewer. 80 are the tidyselect
      deprecation that workstream 5 removes.
- [ ] `devtools::check()` — 0 errors, 0 warnings, at most 2 pre-approved notes
- [ ] `covr::package_coverage()` — at or above 98%
- [ ] No committed snapshot changed, per section 9.4
- [ ] `grep -rn "compute_eff_n" R/` returns nothing — the helper and its
      `# nocov` block are gone
- [ ] `plans/error-messages.md` holds all 4 new classes, and no longer lists
      `surveyreports_warning_duplicate_value_label`
- [ ] `devtools::document()` run; `man/` and `NAMESPACE` current
- [ ] `air format .` run in its own commit
- [ ] The reproduction in section 3.2 reports a finite `eff_n`, and the external
      run omits the Female rows from the rendered frame
- [ ] The twophase Total header reports an effective N at or below the design's
      in-scope row count — 119, not 185. The gate is the in-scope row count, not
      the table's N; section 3.5 states why
- [ ] `DESCRIPTION` pins `Remotes: JDenn0514/surveycore@develop` and raises the
      `surveycore` floor. See section XI.

---

## XI. Dependency sequencing

This spec depends on unreleased surveycore. Two facts:

1. `Remotes: JDenn0514/surveycore` resolves to the GitHub default branch,
   `main`. `main` is 82 commits behind `develop` and has none of the metadata
   API this spec reads.
2. CI installs surveycore from that `Remotes:` line, so CI would test against the
   wrong version.

Workstream 1 raises the stakes. `get_effective_n()` is not on `main`, so an
unpinned CI run fails at load, not at a subtle numeric assertion.

Required: pin `Remotes: JDenn0514/surveycore@develop` for the life of this
branch, and raise the `Imports:` floor from `surveycore (>= 0.8.2)`. The
`Remotes:` entry itself must stay — `CLAUDE.md` forbids removing it or moving
surveycore to `Suggests`.

When surveycore releases to `main`, drop `@develop` and set the floor to the
released version in one commit.

> ⚠️ GAP: the floor cannot be a real released version yet. Pin
> `surveycore (>= 1.1.0.9000)` on the branch and change it at release. State this
> in the PR description so it is not merged and forgotten.

---

## XII. Open questions

### Closed by measurement (Stage 1, 2026-09-09)

| # | Question | Answer | Section |
|---|---|---|---|
| 1 | Iterate `value_labels`, or intersect against the observed codes? | **Moot.** Workstream 1 delegates to `get_effective_n()`, which returns observed levels only. | 3.4, 3.5 |
| 2 | What does `extract_universe()` return for a collection? | **It aborts.** Collections are not accepted. A naive workstream 2 would break every trend workbook. | 4.4 |
| 5 | What does `extract_dataset_metadata()` return for a collection? | **It aborts**, like the other two readers. Per-member keys stay reachable via `@surveys[[i]]`. | 6.3 |

### Closed by decision (Stage 2 Resolve, 2026-09-09)

| Issue | Question | Decision | Section |
|---|---|---|---|
| 5 | Rebuild the effective-N join, or delegate to `get_effective_n()`? | **Delegate.** Resolves the twophase and domain defects at the same time. | III |
| 1 | Render `eff_n` in a crosstab, or state that it is not rendered? | **State and park.** | 1.3.1 |
| 4, old q7 | First-member, unanimous-only, or single-choice-only for a universe that varies within a table? | **Unanimous-only**, applied to batteries, collections and collection roles alike. | 4.5 |
| 14 | Add interaction suppression, or park it? | **Park**, with a follow-up issue. | 1.3.2 |
| 6 | Duplicate value label — warn and union, or abort? | **Abort**, during validation. The union is unobservable; `get_freqs()` aborts first. | 3.6 |
| 7 | What does `.resolve_roles()` do with a malformed payload? | **Treat as unset**, keep the column, warn. Never abort. | 5.3 |
| 10 | Does workstream 3 reach a collection? | **Yes**, through `vars`. Branch required. | 5.6 |
| 11 | Which tests apply to which function? | Marked per row in section 9.2. | 9.2 |
| 3 | Cover-sheet header, position, name collision | Header row; first and active; suffix the **data** sheet. | 6.2.1 |
| 2, 13 | Interaction spanner vocabulary | **In scope.** Label the banner columns before `interaction()`. | 3.7 |
| 8, 21 | Which abort message does section 4.4 quote? | **Quote nothing.** Pass 1 and pass 2 measured two different texts, so the quote was corrected once and regressed. The branch depends on the fact that the three readers abort, and that fact does not decay. | 4.4 |
| 9, 12 | Twophase phase-1 rows; the domain column | Both resolved by delegation. | 1.2.1, III |

### Closed by decision (Stage 2 Resolve, pass 2, 2026-09-09)

| Issue | Question | Decision | Section |
|---|---|---|---|
| 15 | `eff_n` ignores the tabulated variable — state the limit, or make `eff_n` per variable? | **State the limit.** `n` and `n_eff` are design- or banner-level row counts. The gate is the in-scope row count, not the table's N. Variable-level missingness is a third, unaddressed cause. | 1.2.1, 3.5, 9.2, X |
| 16 | Does `.resolve_eff_n()` branch on `banner_var` or on the design type? | **Design type.** A collection always has `banner_var = NULL` and still needs `.survey`. | 3.5 |
| 17 | What happens to an unlabelled code on a partly labelled banner? | A **real subgroup** with `level = NA_character_`. It is suppressible, and the footnote reads `gen=NA`. | 3.4, 3.5 |
| 18 | Does `.banner_levels_labelled()` return character or preserve the factor? | **Preserve the factor and its level order.** Character re-sorts the interaction spanners alphabetically. | 2.2, 3.7 |
| 19 | Does `.resolve_eff_n()` muffle `surveycore_warning_small_cell`? | **Yes**, the same way the two frequency helpers do. The helper raises no warning of its own. | 3.5 |
| 20 | Does the pooled `Total` row of a collection get an effective N? | **No — it keeps `NA_real_`.** A single pooled figure over waves with different designs is not a number this spec defines. | 3.8 |
| 22 | Who owns the sheet-name suffix rule? | A shared `.unique_sheet_name()` in `R/export-utils.R`, over all three `wb_add_worksheet()` call sites. | 2.1, 2.2, 6.2.1 |
| 23 | How does `.unanimous_across()` serve both the collection and the battery case? | The battery call **reshapes** to one shared key. A battery inside a collection resolves waves first, then the battery. | 4.5 |
| 23 | Does `.resolve_base_notes()` merge the caller and the universe? | **No — it keeps them separate.** A merge makes the two sources indistinguishable and defeats the caller exemption of 4.5. | 2.2, 4.2, 4.5 |

### Still open — Stage 4

| # | Question | Section | Blocks |
|---|---|---|---|
| 3 | Is the non-substantive role set `c("weight", "identifier", "paradata", "free_text")`? | 5.4 | implementation |
| 4 | Is escalating the all-banner-dropped case to an error acceptable under a "warn and drop" policy? | 5.5 | implementation |
| 6 | Do the shared helpers stay in `R/export-utils.R`, or does `R/utils.R` get created? | 2.1 | implementation |
| 8 | What layout should a per-wave cover sheet use — row per wave, or block per wave? | 6.3 | workstream 4 |
