# Spec — export-metadata

**Status:** SPEC_READY
**Version:** 0.20.0
**Date:** 2026-09-22
**Methodology locked:** 2026-09-14, after Pass 3 of
`plans/spec-methodology-export-metadata.md`
**Target version:** 0.1.0.9000
**Id:** `export-metadata`
**Branch:** `feature/export-metadata`
**Tier:** 1 (spec → plan → implement)
**PR range:** PR 1–4 — the map is the implementation plan's output, not this
document's
**Standards read:** `.claude/rules/code-style.md`,
`.claude/rules/package-conventions.md`, `.claude/rules/testing.md`,
`.claude/rules/github-strategy.md`,
`.claude/standards/function-documentation.md`

---

## Document purpose

This document is the source of truth for two changes that land together: the
metadata integration between the export functions and surveycore 1.1.0.9000,
and a rebuild of what `export_crosstab()` writes into a cell. It supersedes
v0.7.0 of this file, which froze on 2026-09-10 and covered the metadata work
alone.

v0.7.0 stated that the signature of neither export function would change. That
is no longer true. Section V carries the breaking changes and the reasoning.

**How this document cites the source.** A citation carries a line number only
when the builder must edit that exact expression — a conversion that retires,
a row that goes, a branch that is deleted. A citation that describes a
behavior names the helper alone. Line numbers move as the files change, so a
behavior citation decays into a wrong number, and a reader who finds one wrong
number distrusts the rest. Pass 1 issue 8 and Pass 4 issue 65 of
`plans/spec-review-export-metadata.md` both found the same regression: the
first pass removed every decaying line range, and the v0.8.0 rewrite put new
ones back. The policy is here so a third pass does not find it again.

---

## I. Scope

### 1.1 The scope line

This spec has two parts, and they have different reach.

| Part | What it changes | Reaches |
|---|---|---|
| **A — Metadata** | effective N, `universe` base notes, the `role` guard, the cover sheet, the `all_of()` fix | `export_crosstab()` **and** `export_topline()` |
| **B — Crosstab presentation** | what a cell holds, the sample-size rows, withholding, banner headings, the Total column, missing data, variance rendering | `export_crosstab()` **only** |

Part A is behavior that produces no visible mismatch between the two functions,
and three of its five pieces live in helpers both functions call. Splitting it
would mean writing a compatibility shim in a shared helper for the life of one
branch.

Part B is presentation. `export_topline()` keeps the look it has until its own
pass. Section 4.2 states exactly what that leaves inconsistent, because a
reader who builds both workbooks from one script will see it.

### 1.2 In

**Part A — metadata, both functions**

| # | Workstream | Type |
|---|---|---|
| A1 | Delegate effective N to `surveycore::get_effective_n()` | Defect fix |
| A2 | `base_notes` falls back to `universe` metadata | New behavior |
| A3 | `role` guard on `vars` and `banner` | New behavior |
| A4 | Dataset metadata cover sheet | New behavior |
| A5 | `all_of()` on the `classify_question_type()` call | Cleanup |

**Part B — presentation, `export_crosstab()` only**

| # | Change | Type |
|---|---|---|
| B1 | A percentage cell is a string carrying `%`, under the rounding rule of section 3.3 | Breaking |
| B2 | `show_n` removed; two sample-size rows replace the per-response `N` column | Breaking |
| B3 | `pub_type` removed; a `min_eff_n` floor applies to every subgroup including interactions | Breaking |
| B4 | Withheld subgroups are reported once, on the cover sheet | New behavior |
| B5 | Banner spanners read the variable label | New behavior |
| B6 | `total_label`; the Total column loses its spanner; the `100%` row is removed | Breaking |
| B7 | `na.rm` and `na_label` | New behavior |
| B8 | `variance_display`, and a legend row | New behavior |
| B9 | Column widths, text wrapping, and a freeze pane | New behavior |

### 1.3 Out

- No `report_*()` function. This spec touches the export layer only.
- No change to how surveycore computes a frequency. Every estimate stays
  delegated.
- No fix for `higher_is`, `missing_codes`, `var_note` or `reverse_coded`. These
  properties exist upstream and stay unread. Parked.
- No cleanup of the 39 existing `adldata` datasets.
- **No presentation change to `export_topline()`.** Its own pass follows.
- **No `crosstab_style()` options object.** Six of the arguments below are
  presentation, and collapsing them into one object buys a shorter signature and
  a reusable house default. It is deferred: the payoff is a look shared with
  `export_topline()`, and that function has not been rebuilt yet. Revisit when
  the topline pass would otherwise duplicate all six.
- **No significance testing between banner columns.** Unrelated to this spec and
  named here only because a crosstab rebuild invites it.
- **No `\dontrun{}` conversion.** Both functions still wrap their `@examples` in
  `\dontrun{}`. `package-conventions.md` forbids it, calls it a current gap, and
  gives the pattern that closes it: write the file to `tempfile()`, never to the
  working directory. This spec does not close it. The conversion touches roxygen
  alone, so it runs as its own documentation change. **Decision (2026-09-16,
  decision 2): park it.**

### 1.4 Upstream state — verified, not assumed

Every fact below was measured against surveycore `1.1.0.9000`, commit
`a0f2a7ac61`, on 2026-09-09, and openxlsx2 `1.28` on 2026-09-11.

| Fact | Evidence |
|---|---|
| A design no longer stores the `haven_labelled` class on any column. It keeps `label`, `labels`, `na_values` and `na_range`. | surveycore NEWS, breaking change (#175) |
| `@data` holds the numeric **code**. `get_freqs()` returns the group column as a **factor**, so `as.character()` gives the **label**. | measured |
| `surveycore::get_freqs()` takes `na.rm`, defaulting to `TRUE`. | signature, measured 2026-09-11 |
| `get_freqs()` returns `pct`, `se`, `ci_low` and `ci_high` as **proportions**, not percentages. `pct = 0.356`, `se = 0.0290`. | measured 2026-09-14 |
| The interval from `variance = "ci"` is a normal approximation. The multiplier is `qnorm(1 - alpha/2)` — `1.959964` at `conf_level = 0.95`. No degrees of freedom enter, and the value is identical on taylor, replicate and twophase. | measured 2026-09-14: `(ci_high - ci_low) / 2 / se = 1.959964` on all three; `qt(0.975, 299)` would be `1.96793` |
| The interval is not clipped to `[0, 1]`. A category held by 2 of 300 rows returns `ci_low = -0.00343`. | measured 2026-09-14 |
| `as_survey()` aborts on a non-positive weight, so no design reaching an export function holds a zero-weight row. | measured 2026-09-14 |
| All 17 surveycore functions the package calls are still exported. | `NAMESPACE` diff |
| The test suite passes unchanged: 430 pass, 0 fail, 0 error, 88 warnings. | `devtools::test()` |
| `set_universe()`, `set_var_extra()` and `set_dataset_metadata()` work on all three measured design types. | measured |
| openxlsx2 exports `wb_set_col_widths()`, `wb_set_row_heights()`, `wb_add_cell_style()`, `wb_freeze_pane()` and `fmt_txt()`. | `getNamespaceExports()`, measured 2026-09-11 |

#### 1.4.1 `get_effective_n()` — measured 2026-09-09

surveycore `1.1.0.9000` exports `get_effective_n()`. It returns the raw N, the
Kish effective N, and the group level **labelled the way `get_freqs()` labels
it**, in one call.

| Property | Measurement |
|---|---|
| Columns returned | `<group>`, `n`, `n_eff`, `deff_kish`. With no `group`, one row and no group column. |
| Estimator | `method = "kish"` default. `n_eff` is `93.59602` where `n / ((n * sum(w^2)) / sum(w)^2)` is `93.59602` — the same estimator the current `.compute_eff_n()` implements. |
| Label vocabulary | The group column comes back `character` for a character banner and `factor` for a factor or labelled banner, with the **same** levels `get_freqs()` returns. Joining the two frames on `as.character(level)` left 0 of 4 rows unmatched on all three banner types. |
| Unobserved value label | Dropped. A label `Other = 3` whose code appears in no row is absent from both frames. |
| `NA` in the banner column | Excluded from every level's `n` and `n_eff`. |
| Duplicate value label | **Aborts**, in `.apply_group_labels()`, with the base-R message `factor level [3] is duplicated`. See section 3.7. |
| Two-phase design | Resolves the phase-2 subset. |
| Domain-restricted design | Applies `..surveycore_domain..`. |
| `survey_collection` | **Accepted.** Returns one row per member with a `.survey` key column. Unlike `extract_universe()` and `extract_dataset_metadata()`, it does not abort. |

The four rows that drive A1, measured on the standard 200-row test designs and
on a 200-row taylor design with 75 rows in domain:

| Design | `nrow(@data)` | `get_freqs()` total n | current `.compute_eff_n()` | `get_effective_n()` |
|---|---|---|---|---|
| taylor | 200 | 200 | 184.98 | 184.98 |
| replicate | 200 | 200 | 184.98 | 184.98 |
| twophase | 200 | **119** | **184.98** | **110.15** |
| taylor, domain-restricted | 200 | **75** | **184.98** | **68.65** |

The current helper publishes an effective N above the raw N of the table it
labels, on two paths.

**A third cause stays unaddressed.** `get_effective_n()` counts rows and does
not look at the tabulated variable. Its `x` argument is inert under the Kish
estimator — surveycore prints `x is ignored when method = 'kish'`. A variable
with missing values therefore still shows a table N below the reported effective
N. Measured on 300 rows with 60 missing on `q1`: `get_effective_n(d)` gives
`n = 300`, `n_eff = 278.6`, while `get_freqs(d, q1)` totals `240`.

This is pre-existing and unchanged here. **Decision (2026-09-09, issue 15,
option A): state the limit, do not widen the scope.** The sample-size rows are
design-level or subgroup-level row counts, and section 3.4 carries the contract.

### 1.5 Design support matrix

| Design type | Supported | Notes |
|---|---|---|
| `survey_taylor` | yes | reference implementation |
| `survey_replicate` | yes | no difference in behavior |
| `survey_twophase` | yes | `get_effective_n()` resolves the phase-2 subset; the current helper does not — section 1.4.1 |
| `survey_nonprob` | yes | no difference in behavior. `make_all_designs()` does not build one yet; closing that gap is a deliverable — section 1.6 |
| `survey_collection` | no, for `export_crosstab()` | `export_crosstab()` rejects a collection, unchanged. `export_topline()` accepts one and receives Part A only |

Metadata extraction is design-type independent across the four **design** types.
Collections are the exception, and they are a trap. Three surveycore readers
**abort** on a `survey_collection`:

| Reader | Collection | Used by |
|---|---|---|
| `extract_universe()` | aborts | A2 |
| `extract_var_extra()` | aborts | A3 |
| `extract_dataset_metadata()` | aborts | A4 |
| `get_effective_n()` | **works**, one row per member | A1 |

Every metadata read in A2, A3 and A4 must branch on the design type. The exact
abort message is deliberately not quoted anywhere in this document: two
methodology passes measured two different texts for it, and a later reader who
matches on a quoted string will match on the wrong one. The fact the branch
depends on is that the three readers abort, and that fact does not decay.

### 1.6 The `survey_nonprob` fixture is a deliverable

`.claude/rules/testing.md`, Cross-design testing, names four `survey_base`
subclasses. `make_all_designs()` returns three. It builds no `survey_nonprob`
design, and the rule records the same gap.

Required: `make_all_designs()` gains a fourth element, `nonprob`, built with
`surveycore::as_survey_nonprob()` over the same `make_survey_data()` frame the
other three use. The column set does not change. `testing.md` forbids adding an
edge-case parameter to the generator, and this is not one — it is the missing
member of the canonical list.

Two consequences: every cross-design loop in both export test files gains a
fourth design, and the "Gap to close" note in `testing.md` is removed in the
same PR. Leaving it would state a gap the repository no longer has.

---

## II. Architecture

### 2.1 Files touched

| File | Change |
|---|---|
| `R/export-utils.R` | new `.resolve_eff_n()`, `.banner_levels_labelled()`, `.banner_heading()`, `.unanimous_across()`, `.resolve_base_notes()`, `.resolve_roles()`, `.apply_role_guard()`, `.write_cover_sheet()`, `.fmt_pct()`, `.fmt_variance()`, `.write_sample_size_rows()`, `.build_withheld()`, `.format_withheld_lines()`, `.reject_design_vars()`, `.has_domain()`; **delete `.compute_eff_n()`**; change `.empty_suppressed()`; change `.total_col_group()`; rewrite the withholding loop; change `.build_freq_frame()`; change `.compute_interaction_freq()`; change `.base_note_for()`; change `.build_workbook()`; delete the `show_eff_n` join block |
| `R/export-crosstab.R` | the new signature; the design-variable check; the role guard; banner label validation; the rewritten render helpers; `label_cols` added to `.write_crosstab_headers()`, which the battery route now calls; new `.render_block_preamble()`, `.render_block_footer()` and `.unique_sheet_name()` below the exported function |
| `R/export-topline.R` | `all_of()` fix; the design-variable check; role guard; threaded base notes; **delete the dead effective-N branch in the collection `Total` header** — section 2.3. Its two inline `round(pct * 100, decimals)` sites stay. **No presentation change**: the deleted branch never fires |
| `plans/error-messages.md` | 6 new error classes, 4 new warning classes, 1 renamed warning class, 1 extended trigger. The edit lands **before** implementation, per `code-style.md` |
| `tests/testthat/test-export-crosstab.R` | rewritten sections |
| `tests/testthat/test-export-topline.R` | new and changed sections |
| `tests/testthat/helper-test-data.R` | `make_all_designs()` gains a `survey_nonprob` design — section 1.6 |
| `man/export_topline.Rd`, `man/export_crosstab.Rd` | regenerated from the roxygen changes of section VII |

**This spec adds 18 new helpers: 15 in `R/export-utils.R` and 3 in
`R/export-crosstab.R`.** The table above is the list, and the counts in gate
VIII read from it. `code-style.md` sends a helper used in 2 or more source files
to `R/export-utils.R`.

**Three helpers have one call-site file today and go to the shared file
anyway.** `.fmt_variance()`, `.write_sample_size_rows()` and `.build_withheld()`
are reached from `R/export-crosstab.R` alone in this spec, and `code-style.md`'s
first row would place them in that file. They go to `R/export-utils.R` because
the second call site is scheduled: the `export_topline()` pass adopts the same
cell format, the same variance string and the same sample-size rows, and
`.build_withheld()` belongs beside the formatter that reads its frame. Placing
them correctly now and moving them later is two edits and a reviewer
conversation; placing them in the shared file now is neither. **The PR
description must say this**, or a reviewer applying `code-style.md` literally
will move them back.

**Four more reach the shared file on the ordinary rule**, and not by the
exception above. `.fmt_pct()` is called from the three crosstab render routes
and from `.fmt_variance()`, which lives in `R/export-utils.R`.
`.reject_design_vars()` is called from `R/export-topline.R` for `vars` and from
`R/export-crosstab.R` for `vars` and again for `banner` — three sites in two
files.
`.format_withheld_lines()` is called from `.write_cover_sheet()` in
`R/export-utils.R` and from two sites in `R/export-crosstab.R` — the block
footer and the console warning. `.has_domain()` is called from
`.write_cover_sheet()` in `R/export-utils.R`, for the domain row of section
3.14, and from `export_crosstab()` in `R/export-crosstab.R`, to resolve the
`NULL` default of `total_label` — section 3.9. Two files, so the ordinary rule
places it and no exception is needed. Its predecessor already has two call-site files:
`.write_suppression_footnote()` is defined in `R/export-utils.R` and called
from six sites, three in `R/export-topline.R` and three in
`R/export-crosstab.R`.

**Three helpers stay in `R/export-crosstab.R`, below the exported function.**
`.render_block_preamble()` and `.render_block_footer()` each have three call
sites, and all three are in that file, so `code-style.md`'s placement table puts
them there. The topline render helpers do not share this block shape today.
Measured: `.render_topline_single()` and `.render_topline_sata()` write the
title inline instead of calling `.write_question_title()`. They write no
spanner row, and the name `col_groups` appears nowhere in
`R/export-topline.R`. So `col_groups` has no
topline caller, and the scheduled second call site above does not apply to these
two. The topline pass promotes both helpers to `R/export-utils.R` when it adopts
the block shape. The precedent is the 2026-09-10 decision on
`.unique_sheet_name()`, which moved that helper back to its single call-site
file on the same reasoning.

`.unique_sheet_name()` is the third. All three routed `wb_add_worksheet()` calls
are in `R/export-crosstab.R`, and `export_topline()` writes one sheet and cannot
collide.

**One existing helper changes shape: `.empty_suppressed()`, in
`R/export-utils.R`.** It returns the zero-row tibble the withholding loop
starts from, and that tibble carries a `pub_type` column. B3 removes
`pub_type`, so the column goes. The `threshold` column stays, because
`.write_suppression_footnote()` reads it and that writer stays in the tree —
section 2.3. The helper has two call sites, both inside
`.build_freq_frame()`. It is an existing helper, so it does not count toward
the 18 new ones above.

**A second existing helper changes shape: `.total_col_group()`, in
`R/export-utils.R`.** It holds the two strings section 3.9 changes — the
`Total` heading and the `Total` spanner. It gains two arguments, `total_label`
and `spanner`, both defaulting to the current strings, so an argument-free call
returns exactly what it returns today. Section 2.3 carries the signature. It is
an existing helper, so it does not count toward the 18 new ones above either.

Measured: the helper has **six call sites in three files**, not the four a
reader would guess from the crosstab route alone. Three are in
`R/export-crosstab.R` — `:518`, `:670` and `:790` — and each one gains the two
new arguments. The other three are unchanged and call it with no arguments:
one in `export_topline()` and two inside `.sata_n_cell()`.

**`export_topline()` keeps its current output, byte for byte.** No topline code
path reads `spanner` or `levels`. `.cell_rows()`, in `R/export-utils.R`,
branches on `identical(cg$type, "total_col")` and then filters
`frame$subgroup_type == "total"`, so it reads neither field; `.sata_n_cell()`
reaches the same branch. Every read site for `spanner` and `levels` is in
`R/export-crosstab.R`. Measured as well:
`tests/testthat/_snaps/export-topline.md` holds nine snapshots, all error
messages, and none carries the text `Total`, `Eff` or `spanner`. This is what
keeps section 4.1 true where it says the presentation does not change, and it
is what satisfies section 5.2's snapshot gate.

### 2.2 New helper signatures

```r
# Raw N and effective N per subgroup, delegated to surveycore.
# The single source of truth for both counts.
.resolve_eff_n <- function(design, group_var = NULL, na.rm = TRUE)
# -> tibble: level (chr), n (int), n_eff (dbl)
#    group_var = NULL, single design -> one row, level = NA_character_
#    group_var = NULL, survey_collection -> ONE ROW PER MEMBER, level taken
#      from the .survey column. get_effective_n() accepts a collection and
#      returns a keyed frame — section 1.4.1. The caller joins on the wave
#      name, not on a subgroup level — section 4.1. This is the contract
#      section 3.5 describes; the two must not diverge again.
#    Levels are LABELS, in get_freqs() vocabulary. Unobserved levels absent.
#    group_var may name a banner column OR the synthetic interaction column,
#    which is what extends withholding to crossed cells.
#    na.rm is passed straight to surveycore::get_effective_n(). The exported
#    function passes the SAME value it passes to get_freqs(), so a
#    missing-value banner level has a row here whenever it has a column
#    there — section 3.13.
#    Muffles surveycore_warning_small_cell, as the two frequency helpers
#    already do. Raises no warning of its own.

# Banner column translated from codes to value labels.
.banner_levels_labelled <- function(design, col)
# -> vector of length nrow(design@data), NA preserved.
#    factor in -> factor out, LEVEL ORDER PRESERVED. Anything else -> character.
#    Coercing a factor to character re-sorts the interaction spanners
#    alphabetically. See section 3.8.

# The display heading for a banner column: its variable label from
# surveycore::extract_var_label(), falling back to the column name.
.banner_heading <- function(design, col)
# -> list(heading = chr(1), fell_back = lgl(1))
#    The caller collects fell_back across columns and raises ONE warning.

# Keys whose value is identical and non-missing across every member.
.unanimous_across <- function(entries)
# entries: list of named character vectors, ONE PER MEMBER.
# -> named character vector; a key that disagrees or is missing anywhere
#    is omitted.
#    The battery case is the transposed shape: one vector, several variables.
#    Reshape so every member shares one key before calling.

# The caller's base_notes and the design's universe, kept SEPARATE.
.resolve_base_notes <- function(design, base_notes)
# -> list(caller = <named chr or NULL>, universe = <named chr>),
#    or NULL when both sources are empty
#    This helper reads the design's universe itself. The universe element is
#    a named character vector, keyed by variable, and character(0) when
#    nothing is set.
#    It never aborts on a collection. On one it reads every member and
#    applies the WAVE UNANIMITY RULE of section 3.6: a variable whose
#    universe disagrees across members, or is missing in any member, is
#    omitted.
#    The BATTERY RULE runs later, in .base_note_for(). Section 3.6 states
#    that the two rules never run in the other order, so this helper applies
#    the wave rule and no other.

# role lookup for a set of columns. A LOOKUP ONLY: it does not classify,
# warn, or drop.
.resolve_roles <- function(design, cols)
# -> named character vector, one entry per element of cols,
#    NA_character_ where no role is set OR the payload is not a
#    length-1 character. Never aborts on a foreign payload.
#    It owns the PER-VARIABLE COERCION RULE of section 3.10, applied to the
#    `role` key of each extract_var_extra() payload. A length-0 payload, a
#    length-2 or longer payload, and a non-character payload all resolve to
#    NA_character_ here, so a foreign payload never reaches the caller. The
#    obvious vapply(..., character(1)) implementation aborts on the first of
#    those three, so this helper cannot use it.
#    Never aborts on a collection either. extract_var_extra() aborts on one
#    — section 1.5 — so this helper branches on the design type and reads
#    each member, then applies the unanimity rule of section 3.6: a role
#    that disagrees across members, or is missing in any member, resolves
#    to NA_character_. export_topline() accepts a collection and runs the
#    guard on `vars`, so the branch is on a supported path.

# The warn-and-drop policy in one place. Both export functions call it for
# `vars`; export_crosstab() calls it again for `banner`.
.apply_role_guard <- function(design, cols, arg, empty_class)
# arg:         "vars" or "banner" — names the argument in both messages.
# empty_class: the error class raised when nothing survives.
# -> character vector of the surviving column names, in input order.

# Every column the design names, checked against one selection. Aborts on a
# match. It runs BEFORE the role guard — section 3.11.
.reject_design_vars <- function(design, cols, arg)
# cols: the resolved `vars` or `banner` names, in input order.
# arg:  "vars" or "banner" — names the argument in the message.
# -> invisible(TRUE) when no column matches. Otherwise it aborts with
#    surveyreports_error_design_variable_selected, naming the offending
#    column and `arg` — section 3.17.
#    IT READS THE DESIGN PER SUBCLASS. @variables is not a flat list of
#    column names, and its slots differ by subclass. The reader takes the
#    slots that hold column names and skips the slots that hold non-column
#    values, so no comparison runs against TRUE, 0.9 or "JK1":
#      survey_taylor    -> ids, weights, strata, fpc
#      survey_replicate -> weights, repweights, fpc. repweights holds ten
#                          columns in the test fixture, and every one of
#                          them counts.
#      survey_twophase  -> the same kind of slots nested inside phase1 and
#                          inside phase2, plus subset. Twophase holds its
#                          column names one level deeper, so a flat read of
#                          @variables finds none of them.
#      survey_nonprob   -> the slots that subclass names. make_all_designs()
#                          returns no nonprob design yet — section 1.6 — so
#                          this branch ships without a fixture to exercise
#                          it.
#    Skipped, because they hold no column name: nest, probs_provided,
#    visible_vars, type, scale, rscales, fpctype, mse, method.
#    A column whose metadata `role` reads "weight" and which the design does
#    NOT name is not this helper's case. It keeps the drop-with-warning
#    behavior of section 3.10. The two mechanisms stay separate.

# TRUE when the design is restricted to a domain. A DIRECT COLUMN TEST:
# surveycore exports no domain accessor, so the helper checks
# surveycore::SURVEYCORE_DOMAIN_COL against names(design@data) — section 3.9.
.has_domain <- function(design)
# -> logical(1)
#    Two readers: export_crosstab() resolves the NULL default of total_label
#    from it — section 3.9 — and .write_cover_sheet() writes the domain row
#    from it — section 3.14.
#    It reads the column name only. It never reads the column's values, so a
#    domain that selects every row still counts as a restriction.

# One percentage cell, as a string. The rule of section 3.3.
.fmt_pct <- function(p, decimals, has_rows)
# p: the estimate as a PROPORTION, or NA — the value surveycore returns,
#     passed through unchanged. The helper multiplies by 100 itself, so
#     0.356 reaches it as 0.356 and no call site does arithmetic. It
#     applies the thresholds of section 3.3 to the percentage-point value
#     after it multiplies, and `decimals` counts decimal places on a
#     percentage.
# has_rows: nrow(rows) > 0 && rows$n > 0, computed by the caller over the
#     get_freqs() rows for this cell. Row presence alone is the wrong test:
#     get_freqs() emits a placeholder row with n = 0 — section 3.3.
# -> character(1)

# One variance string, as it appears beside an estimate. The rule of
# section 3.12.
.fmt_variance <- function(rows, variance, decimals, has_rows)
# rows: the get_freqs() rows for this cell. The helper reads se, or
#     ci_low and ci_high, as surveycore returns them — proportions.
# variance: NULL, "se" or "ci".
# -> character(1). Empty when variance is NULL or has_rows is FALSE.
#    The helper owns both forms, the parentheses, the one % per number and
#    the separator. It formats every number with .fmt_pct(), so it does no
#    arithmetic of its own and it inherits the rounding mode, the floor
#    string and the ceiling string. The separator is an en-dash (U+2013)
#    with one space on each side — section 3.12. A lower bound can be
#    negative, because the bounds print unclipped, so the helper must
#    accept one.

# The two sample-size rows. Returns the next free row.
.write_sample_size_rows <- function(wb, sheet, start_row, label_cols,
                                    counts, show_ess)
# label_cols: integer(1), the number of label columns in this block — 1 for
#     a single-response or SATA block, 2 for a battery. The helper leaves
#     them blank apart from the row label in column A.
# counts: tibble of level (chr), n (int), n_eff (dbl), ONE ROW PER RENDERED
#     DATA COLUMN, in the order the columns are written. The Total column
#     is a row like any other, with level = the RESOLVED total_label, never
#     NULL. The exported function resolves the NULL default before it builds
#     this frame — section 3.9. Withheld subgroups
#     are already absent. The helper reads the numbers from here and takes
#     no design.
#     A ZERO-ROW FRAME IS VALID. It means the block has no rendered data
#     column. The helper then writes the row label, leaves any second label
#     column blank, writes no data cell, and returns the next free row as
#     usual — sections 3.4 and 3.5.
# -> list(wb = , next_row = )

# The withheld-subgroup frame. One row per subgroup below the floor.
.build_withheld <- function(counts, min_eff_n, banner_var)
# counts: the .resolve_eff_n() frame for one banner column or for the
#     synthetic interaction column — level, n, n_eff.
# banner_var: the column the levels came from. It is carried onto every
#     row, so a reader can tell two banner columns apart.
# -> tibble: level (chr), banner_var (chr), n_eff (dbl), one row per
#    withheld subgroup, in the order the levels were resolved.
#    THE SOLE OWNER OF THE FLOOR TEST. The comparison n_eff < min_eff_n
#    lives here and nowhere else — section 3.5. The kept levels are the
#    complement of this frame over the same counts frame, taken as a set
#    difference on level, so no second comparison exists.
#    THIS HELPER NEVER RETURNS NULL. A zero-row frame means the floor ran
#    and withheld nothing, and section 3.14 writes the block with its None
#    row. The NULL that .write_cover_sheet() can receive comes from the
#    CALLER, which passes NULL in place of this frame when withheld_note is
#    not "once". That NULL is an instruction to the cover sheet, and never a
#    result of the floor. Withholding removes the columns at every
#    withheld_note value — section 3.5. The two facts must not be conflated.

# The withheld lines, as text. One wording, three consumers.
.format_withheld_lines <- function(withheld, min_eff_n)
# withheld: the .build_withheld() frame, or NULL.
# -> character vector, one element per withheld subgroup, in the frame's
#    order. character(0) when the frame has no rows or is NULL.
#    Section 3.14 fixes the wording of one line. The cover sheet, the
#    per-table block and the console warning all read this vector, so the
#    three agree by construction.

# Cover sheet. Written whenever any of its three blocks has content.
.write_cover_sheet <- function(wb, design, withheld, min_eff_n,
                               has_banner, string_cells, variance)
# withheld: the .build_withheld() frame, or NULL. The caller passes NULL
#   when withheld_note is not "once", and NULL suppresses the block. NULL
#   never means the floor withheld nothing — a zero-row frame means that,
#   and it writes the block with its None row. Sections 3.5 and 3.14.
#   THIS HELPER TAKES NO withheld_note ARGUMENT AND READS NONE. The caller
#   owns that decision. Do not add the argument.
# The helper calls .has_domain(design) itself and writes the domain row of
#   section 3.14 when it returns TRUE. No argument carries that fact.
# has_banner, string_cells, variance: the three facts that decide which
#   glossary entries are true of THIS workbook — section 3.15. Both export
#   functions call this helper, and a topline workbook withholds nothing
#   and writes numeric cells, so an unconditional glossary would describe
#   rules that workbook does not follow.
# -> wb

# The opening sequence of one question block: the title, the base note,
# the variance legend, the spanner row, the heading row, and the two
# sample-size rows under sample_size_display == "top".
.render_block_preamble <- function(wb, sheet, start_row, question_text,
                                   base_note, legend, col_groups,
                                   label_cols, counts,
                                   sample_size_display, show_ess)
# base_note, legend: character(1) or NULL. NULL writes no row.
# col_groups: the rendered column groups, withheld levels already absent.
# label_cols: character vector of the label-column headings — "Response",
#     "Item", or "Item" and "Response" for a battery. The same vector
#     reaches .write_crosstab_headers(). Its length is the number of label
#     columns, which is what .write_sample_size_rows() takes as its own
#     label_cols argument.
# counts: the counts frame of section 3.4.
# -> list(wb = , next_row = ), where next_row is the first data row.
#    Calls .write_question_title(), .write_crosstab_headers() and
#    .write_sample_size_rows(). The row order is the contract of
#    section 3.16.

# The closing sequence of one question block: the two sample-size rows
# under sample_size_display == "bottom", then the withheld lines under
# withheld_note == "every".
.render_block_footer <- function(wb, sheet, start_row, label_cols, counts,
                                 sample_size_display, show_ess,
                                 withheld_lines)
# label_cols: the same headings vector the preamble received. This helper
#     needs its length alone.
# withheld_lines: the .format_withheld_lines() vector, or character(0).
# -> list(wb = , next_row = )
#    The sample_size_display branch lives in these two helpers and nowhere
#    else. Before this spec it would have stood in all three render
#    routes, twice each.

# A sheet name that does not collide with one already in wb. Truncates to
# 31 characters first, then suffixes _2, _3, ... Comparison is CASE-FOLDED,
# because Excel and openxlsx2 both treat sheet names case-insensitively:
# an exact-match check misses `about` against `About` and the save aborts.
.unique_sheet_name <- function(wb, name)
# -> character(1)
```

### 2.3 Changed and deleted helper signatures

```r
# DELETED. surveycore::get_effective_n() replaces it, including all three
# `# nocov` markers inside it.
.compute_eff_n <- function(design, col = NULL, level = NULL)

# Before
.build_workbook <- function()
# After
.build_workbook <- function(design, withheld = NULL, min_eff_n = NULL,
                            has_banner = FALSE, string_cells = FALSE,
                            variance = NULL)
# The last three are passed straight to .write_cover_sheet(). The defaults
# are the export_topline() case for the first two: no banner, numeric
# cells. `variance` is NOT defaulted away by that function.
# export_topline() PASSES ITS OWN `variance` THROUGH, because it takes the
# argument too and section 3.15 makes the Confidence intervals entry true
# whenever `variance` is "ci". A topline call that set "ci" and reached the
# NULL default would get a workbook whose glossary omits an entry the cells
# need — section 4.1.
# This helper runs after withholding, at step 16 of section 3.11, so
# `withheld` is populated by then. The caller decides what to pass: the
# withheld frame when `withheld_note == "once"`, and NULL otherwise.
# .write_cover_sheet() never reads `withheld_note` and takes no such
# argument — section 3.14.

# Signature unchanged. `base_notes` now carries the two-element list of
# section 3.6, and the lookup gains the caller-first, then-unanimity rule.
.base_note_for <- function(frame, base_notes)

# CHANGED. It holds the two strings section 3.9 changes: the Total heading
# and the Total spanner. Both become arguments, and both default to the
# current string, so an argument-free call returns what it returns today.
# Before
.total_col_group <- function()
# After
.total_col_group <- function(total_label = "Total", spanner = "Total")
# export_crosstab() passes the RESOLVED `total_label` and `spanner = ""` at
# all three of its call sites — R/export-crosstab.R:518, :670 and :790.
# export_topline() and .sata_n_cell() call it with NO ARGUMENTS and are
# unchanged. Neither reads `spanner` or `levels`: .cell_rows() dispatches
# on `type` — section 2.1.

# CHANGED. `label_col1` becomes `label_cols`, a character vector of the
# label-column headings, so the battery route can call this helper instead
# of writing its own spanner and heading rows. The banner spanners start at
# column length(label_cols) + 1.
# Before
.write_crosstab_headers <- function(wb, sheet, spanner_row, header_row,
                                    col_groups, label_col1)
# After
.write_crosstab_headers <- function(wb, sheet, spanner_row, header_row,
                                    col_groups, label_cols)

# KEPT, unchanged, and now inconsistent with the withheld wording of
# section 3.14. Its text is "* %s: %s suppressed (n=%d, threshold=%d)": a
# raw N, a threshold, and the word "suppressed". The three
# R/export-crosstab.R call sites go; the three R/export-topline.R sites
# keep it, so the helper and its text stay in the tree. Section VI records
# the cost.
.write_suppression_footnote <- function(wb, sheet, suppressed, start_row)
```

**One dead branch is deleted.** The collection `Total` header's effective-N
branch, at `R/export-topline.R:288-296`, reads the pooled `Total` row's
`eff_n`. `.build_freq_frame()` returns `NA_real_` for every row whose
`subgroup_type` is `"total"`, and section 4.1 keeps it that way, so the branch
never fires. Deleting it changes no cell: the `Total` header reads `Total`
alone before and after. **Decision (2026-09-16, decision 1): delete the branch;
do not mark it `# nocov`.** A marker would keep an unreachable branch in the
file, and the next reader would have to derive again that it cannot fire. This
is the fifth item on Part A's write surface in `R/export-topline.R` —
section 4.1.

**The five inline percentage conversions.** All five hold the same expression,
`round(x$pct[[1L]] * 100, decimals)`. Two retire and three stay:

| Site | What happens |
|---|---|
| `R/export-crosstab.R:580` — the single route | retires. Part B's string render calls `.fmt_pct()`, which takes the proportion |
| `R/export-crosstab.R:905` — the battery route | retires, the same way |
| `R/export-utils.R:745`, inside `.sata_pct_cell()` | **stays** |
| `R/export-topline.R:379` — the subgroup cell | **stays** |
| `R/export-topline.R:394` — the total cell | **stays** |

`.sata_pct_cell()` stays unchanged and keeps serving `export_topline()`. The
helper has two call sites today, `R/export-crosstab.R:731` and one in
`R/export-topline.R`. The crosstab SATA route stops calling it and builds
its cell from the new string formatters instead, so the helper loses its
crosstab call site and keeps its topline one. It also keeps the
never-asked-versus-chosen-by-nobody distinction, because `export_topline()`
still prints it. Section 3.3 drops that distinction from the crosstab cell
only.

`.sata_n_cell()`, in `R/export-utils.R`, follows the same reasoning. It copies
the same never-asked-versus-chosen-by-nobody rule and it has the same two call
sites, `R/export-crosstab.R:745` and one in `R/export-topline.R`. B2 removes
`show_n`, so the crosstab block writes no per-response `N` cell and stops
calling it. The helper stays unchanged for `export_topline()`.

The three remaining sites stay because `.fmt_pct()` returns a string and an
`export_topline()` cell is a number — section 4.2. Calling the formatter there
would change the output that section 4.1 promises not to change. **So the
presentation does not change.** Part A's write surface in
`R/export-topline.R` is the five items section 2.1 lists: the `all_of()` fix,
the design-variable check, the role guard, the threaded base notes and the
deletion of the dead effective-N branch above. Section
4.1 records the fourth as a widening.

The cost is one rule with two implementations for the life of this branch.
Section VI records it, section 4.2 lists it as a stated inconsistency, and the
`export_topline()` pass closes it when a topline cell becomes a string.

---

## III. `export_crosstab()` contract

### 3.1 Signature

**Documentation tier:** 4 — Dispatcher. It routes single-response, SATA and
battery blocks to three render helpers by question structure, and runs no
algorithm of its own. The tier does not change; section 7.1 records that the
function does not currently meet it.

```r
export_crosstab(
  design,
  vars,
  banner,
  file_name,
  layout              = c("per_question", "stacked"),
  interactions        = NULL,
  min_eff_n           = 100,
  variance            = NULL,
  variance_display    = c("cell", "row"),
  conf_level          = 0.95,
  sample_size_display = c("top", "bottom", "none"),
  show_ess            = TRUE,
  decimals            = 1L,
  show_total          = TRUE,
  total_label         = NULL,
  na.rm               = TRUE,
  na_label            = "No answer",
  withheld_note       = c("once", "every", "none"),
  base_notes          = NULL
)
```

**Argument order follows `code-style.md`'s groups, with one deviation.** The
groups run `design`, required NSE, required scalar, optional scalar, then
optional tidy-select. `layout`, an optional scalar, precedes `interactions`, an
optional tidy-select, which is the order the groups give. The optional scalars
from `min_eff_n` onward follow `interactions`, which is not. Every argument
this spec adds is an optional scalar and joins that trailing run.

**No shipped argument moves.** Measured 2026-09-16: `export_crosstab()` takes
`layout` as its fifth argument and `interactions` as its sixth. Moving
`interactions` ahead of the trailing optional scalars would change a shipped
argument's position for no behavioral gain, and it would break a positional
call that works today. The release is already breaking, so this is a choice and
not a constraint; the choice is to leave a working signature alone.

### 3.2 Arguments

| Argument | Type | Default | Semantics |
|---|---|---|---|
| `design` | `survey_base` subclass | — | A `survey_collection` aborts, unchanged |
| `vars` | tidy-select | — | Variables to tabulate. Resolved to a character vector before any validation |
| `banner` | tidy-select | — | Variables whose levels become column groups |
| `file_name` | character(1) | — | Must end in `.xlsx` |
| `layout` | character(1) | `"per_question"` | One sheet per question group, or one `"Crosstab"` sheet |
| `interactions` | list or `NULL` | `NULL` | Each element names 2 or more `banner` variables to cross |
| `min_eff_n` | numeric(1), >= 0 | `100` | A subgroup whose effective N is below this is not written. `0` disables withholding. Replaces `pub_type` |
| `variance` | `NULL`, `"se"`, `"ci"` | `NULL` | What appears beside each percentage |
| `variance_display` | character(1) | `"cell"` | `"cell"`: a second line inside the estimate cell. `"row"`: its own row under each estimate row. Inert when `variance` is `NULL` |
| `conf_level` | numeric(1) in (0,1) | `0.95` | Confidence level when `variance = "ci"` |
| `sample_size_display` | character(1) | `"top"` | Where the sample-size rows sit, or `"none"` to omit them |
| `show_ess` | logical(1) | `TRUE` | Whether the second sample-size row is written. Replaces `show_eff_n`, which was a no-op |
| `decimals` | integer(1), >= 0 | `1L` | Decimal places on every percentage, and the precision the rounding rule of section 3.3 keys on |
| `show_total` | logical(1) | `TRUE` | Whether the full-sample column group is written first |
| `total_label` | character(1) or `NULL` | `NULL` | The heading of that column. `NULL` resolves to `"Total"` when the design carries the domain column, and to `"Full Sample"` otherwise. A caller-supplied value is used as given, on any design — section 3.9 |
| `na.rm` | logical(1) | `TRUE` | Passed to `surveycore::get_freqs()`. `FALSE` adds a missing-value response row **and** a missing-value banner column group |
| `na_label` | character(1) | `"No answer"` | The text written for a missing-value response row and a missing-value banner level |
| `withheld_note` | character(1) | `"once"` | Where the withheld-subgroup list is written |
| `base_notes` | named character or `NULL` | `NULL` | Caller-supplied base text, keyed by variable |

`na.rm` reaches both `vars` and `banner` — one argument, not two. A missing value
in a banner column is a real subgroup of respondents, and it faces the
`min_eff_n` floor like any other.

### 3.3 A percentage cell

**Decision (2026-09-12): a cell is a string.** An Excel Percentage number format
would keep the cell numeric, but the cell must also be able to carry a second
line under `variance_display = "cell"`, and a cell holds one value. The string is
the choice that serves both, and the cost is stated in section VI.

**The printed scale is percentage points.** `get_freqs()` returns `pct` as a
proportion — `0.356`, not `35.6` — and section 1.4 records the measurement.
**`.fmt_pct()` owns the conversion.** It takes the proportion as surveycore
returns it and multiplies by 100 itself, so no call site does arithmetic. Every
threshold below is written on the percentage-point value, and the helper applies
each one after it multiplies. `decimals` counts decimal places on a percentage.
Section 3.12 uses the same scale for `se`, `ci_low` and `ci_high`, which
surveycore also returns as proportions.

The rule separates five facts, because a rounded-to-zero value, a true zero, a
near-unanimous value and an absent cell are not the same fact:

| Condition, on `pp`, the estimate in percentage points — the proportion times 100, computed inside `.fmt_pct()` | Cell |
|---|---|
| no rows in this cell — `has_rows` is false | `-` |
| the estimate is exactly `0` | `0%` |
| `0 < pp < 0.5 × 10^-decimals` — nonzero, rounds to zero at this precision | `<0.1%` at `decimals = 1`; `<1%` at `0`; `<0.01%` at `2` |
| `100 - 0.5 × 10^-decimals < pp < 100` — below 100, rounds to 100 at this precision | `>99.9%` at `decimals = 1`; `>99%` at `0`; `>99.99%` at `2` |
| otherwise | `paste0(round(pp, decimals), "%")`, e.g. `41.2%` |

Both thresholds and both printed strings follow `decimals`. `.fmt_pct()` is the
one implementation.

**The ceiling mirrors the floor.** A category that 3 respondents in 10,000 did
not choose gives `pp = 99.97`, and `round(99.97, 1)` prints `100.0%`. A reader
who sees `100.0%` concludes the complement is empty. The argument that earns
`<0.1%` earns `>99.9%`, and section 3.9 removed the `100%` row partly because
the visible cells routinely do not total 100 — a cell reading `100.0%` beside a
nonzero sibling makes that worse.

**`has_rows` is `nrow(rows) > 0 && rows$n > 0`.** Row presence alone is the
wrong test. `get_freqs()` emits a placeholder row with `n = 0` for a subgroup
with no non-missing observations, so an implementer who tests for a row finds
one, reads `p == 0`, and writes `0%` where the rule intends `-`.

**A SATA item never asked in a subgroup renders `-`, the same as an item nobody
chose.** The distinction is dropped, deliberately. The cell has four special
forms and one plain percentage, and three states — never asked, asked and
chosen by nobody, asked and chosen — cannot map onto them without adding a
form nobody asked for. `.sata_pct_cell()` makes the distinction today, printing
a blank for never-asked and `0` for chosen-by-nobody. The crosstab SATA route
stops calling that helper, so the distinction leaves the crosstab cell. The
helper itself stays unchanged and keeps the distinction for
`export_topline()` — section 2.3.

**The rounding mode is half to even**, which is what `round()` and `sprintf()`
both do in R and what the current code already does. A reader who hand-checks
`41.25` at one decimal gets `41.3`; the workbook prints `41.2`. That is the
stated rule, not a defect.

**`decimals` is a maximum, not a fixed width.** `round()` gives the shortest
correct string, so 41.01 at one decimal renders `41%` and a true zero renders
`0%`. A column can therefore hold `41%` and `32.4%` side by side, and the
decimal points do not line up.

**Decision (2026-09-14): accept the ragged column.** A fixed width would align
the points, at the cost of printing a decimal place the estimate does not
carry. `round()` is also the shorter implementation and the one a test can
reproduce without copying the package's own formatter.

### 3.4 The sample-size rows

Two rows, always two — no argument controls the count. Each cell holds one short
number, so a data column stays as wide as the percentage it shows.

| Row | Label in the first column | Cell | Present when |
|---|---|---|---|
| 1 | `Unweighted sample size` | the subgroup's `n` from `.resolve_eff_n()` | `sample_size_display != "none"` |
| 2 | `Effective sample size` | the subgroup's `n_eff`, at one decimal | `sample_size_display != "none"` and `show_ess` |

Both rows are **italic and one point smaller than the body text**. Nothing else
distinguishes them: no fill, no border, no second colour.

Labels are spelled out and parallel, so the pair reads as two measures of one
quantity. The abbreviation `ESS` appears nowhere in the workbook body; it
survives as a parenthetical in the cover sheet glossary, for a reader who meets
it in report prose.

`sample_size_display` is one argument with three values rather than a
`show_sample_size` plus a position argument, because `"none"` is a value the same
argument can carry.

**The numbers reach the writer as a frame, not as a design.** The caller
resolves them once and hands `.write_sample_size_rows()` a `counts` frame of
`level`, `n` and `n_eff` — one row per rendered data column, in the order the
columns are written, with the Total column carried as a row whose `level` is
the resolved `total_label`. Withheld subgroups are already absent from the
frame, so the
writer never decides what to render. It writes the label in column A, leaves any
second label column blank, and then writes one cell per row of `counts`, left to
right.

**One row per rendered data column, and zero rows is a real case.** A block with
no rendered data column hands the writer a zero-row `counts` frame. Both rows
are still written, under the presence conditions above:
`.write_sample_size_rows()` writes the row label in column A, leaves any second
label column blank, writes no data cell, and returns the next free row. It does
not abort and it does not skip the rows. Section 3.5 gives the input that
produces the frame: `show_total = FALSE` with every banner level withheld.

**Both counts ignore the tabulated variable**, per section 1.4.1. They are
design-level or subgroup-level row counts. A variable with item nonresponse
therefore shows response rows that total less than the sample size above them.

**`sample_size_display = "top"` is the default.** A freeze pane below the rows
then holds the question, the headings and both counts in view for the whole
table. `"bottom"` puts them below the last estimate, where a battery of 3 items
at 4 scale points places them 11 rows from the heading and no freeze pane can
reach them.

### 3.5 Withholding

**Decision (2026-09-12): `pub_type` is removed.** It offered three modes over two
thresholds, each mixing an effective-N test with a raw-N test, and its `"none"`
default meant the common call published every small cell. One floor replaces it.

| Rule | Value |
|---|---|
| The test | `n_eff < min_eff_n` |
| Default | `100` |
| Raw N | **not tested.** The effective N is the number the rule is about |
| Disabled by | `min_eff_n = 0` |

**Dropping the raw-N test loses nothing.** Kish's
`deff = n·Σw² / (Σw)²` is at least 1 by Cauchy–Schwarz, so `n_eff ≤ n` always,
and `n_eff ≥ min_eff_n` forces `n ≥ min_eff_n`. Every measurement in Pass 3
agreed: `deff_kish` ran 1.07 to 1.11 and never fell below 1. The raw-N test is
subsumed, not discarded.

One consequence of `min_eff_n = 0`, the QA setting of section VI: surveycore's
own raw-N warning, `surveycore_warning_small_cell` at `min_cell_n = 30`, is
muffled by `.resolve_eff_n()` and by the three frequency helpers. At the default
floor of 100 nothing is lost, because 100 exceeds 30. At `min_eff_n = 0` the
floor and that warning go silent together, so the call reports no small-sample
signal at all.

**The floor keys on a weights-only quantity.** `n_eff` is Kish's effective
sample size: it adjusts for unequal weights and not for clustering — section
3.15. On a clustered design a subgroup can clear the floor and still carry the
precision of far fewer respondents.

**The floor is tested on the subgroup's own size, not on the base of any one
question.** `get_effective_n()` counts rows and ignores the tabulated variable —
section 1.4.1. A subgroup at `n_eff = 105` on a question that 40 percent of it
skipped carries an effective base near 63 for that question, and the floor
publishes it. Read this with the Kish point above and with section 3.15: both
are the same gap between what `n_eff` measures and what the word "effective"
suggests it measures.

**Every subgroup faces the floor**, and that is a change in reach, not only in
threshold:

| Subgroup kind | Before | Now |
|---|---|---|
| a banner level | evaluated, but the filter never matched — section 3.11 | evaluated and removed |
| an interaction cell | **never evaluated** | evaluated and removed |
| a missing-value banner level under `na.rm = FALSE` | did not exist | evaluated and removed |

Extending the floor to crossed cells is the change with the largest visible
effect. A crossed cell is by construction smaller than either parent: on a
620-row design with a 2-level and a 4-level banner, 6 of 8 crossed columns fall
below 100. That is the correct outcome — the alternative is publishing a
48-person cell — and the workbook now says so.

**What "withheld" means visibly: the column is gone.** Its heading, its cells and
its share of the spanner are all absent, and the table is narrower. It is not a
blank column and not a column of dashes. A dash means "no rows in this cell" and
already has a meaning under section 3.3.

Implementation: the rows for a withheld subgroup are filtered out of the
frequency frame, and the column-group builder reads its levels from that frame,
so the level has no heading and no cells.

**One helper owns the floor test.** `.build_withheld()` holds the comparison
`n_eff < min_eff_n`. No other code compares an effective N against
`min_eff_n`.

The three subgroup kinds in the reach table above are **one test over one
frame**, not three features. `.resolve_eff_n()` returns the same `level, n,
n_eff` shape for a banner column, for the synthetic interaction column, and for
a column holding a missing-value level, so one test serves all three.

**The kept levels are the complement of the withheld frame.** The caller takes
a set difference on `level`, between the `counts` frame it passed in and the
frame `.build_withheld()` returned. It runs no second comparison, so a `<=`
can appear in one place only.

The caller calls `.build_withheld()` once per banner column, and once per
interaction.

**The full-sample test is separate.** It warns with
`surveyreports_warning_full_sample_below_min` and removes nothing — the last
row of the table below. It is not a subgroup test and it does not read the
withheld frame.

**`withheld_note` does not change what is withheld.** At every value of the
argument, a subgroup below the floor loses its column. The argument decides
where the withheld lines are written, and nothing else — sections 3.14 and
3.16. The `NULL` frame that section 2.2 describes is an instruction from the
caller to the cover sheet. `.build_withheld()` never returns it.

| Degenerate case | Behavior |
|---|---|
| every level of one banner column is withheld | that column group is absent. `surveyreports_warning_banner_all_withheld` names the column. The call still writes the workbook |
| every level of every banner column is withheld | every group is absent. The tables render with the Total column alone — a topline under a crosstab file name. The same warning names every column. **Do not abort** |
| every cell of one interaction is withheld | that interaction's column group is absent, and the same warning names it |
| the full sample's own effective N is below `min_eff_n` | `surveyreports_warning_full_sample_below_min`, and the workbook is written in full. The full sample is not a subgroup, and withholding the whole deliverable is not a service to the caller |
| `show_total = FALSE` **and** every banner level withheld | the block has **zero data columns**. It is written, not skipped, and the call does not abort. The paragraph below gives it row by row |

**The zero-data-column block, row by row.** At `show_total = FALSE` the caller
builds no total column group — section 3.9 — and with every banner level below
the floor no banner column group survives either. Nothing is left to write a
data cell for. The block keeps its rows and loses its cells:

- the spanner row holds blank label cells and nothing else
- the heading row holds the label headings alone — `Response`, or `Item`, or
  `Item` then `Response` for a battery — and no data headings
- each response row holds its label in column A and no data cell
- the two sample-size rows hold their labels in column A and no data cell.
  `show_ess` still decides whether the second row is written — section 3.4
- the call does not abort. It returns the path, and the file opens

**The existing warnings still cover it, and this spec adds no class for it.**
`surveyreports_warning_banner_all_withheld` fires, and every word of it stays
true: its trigger reads the floor and never reads `show_total`.
`surveyreports_warning_subgroup_withheld` fires beside it, because subgroups did
fall below the floor — section 3.18. Two warnings, both true, and neither one
is about the empty block. The empty block is not a new condition. The columns went the way they go at
`show_total = TRUE`, and `show_total` removed one more. So this spec adds no
warning class for the empty block — section 3.18.

### 3.6 Base notes and the universe fallback

`surveycore::extract_universe()` returns the same kind of text for the same
purpose: the population a question was asked of. Resolve both sources once, in
the exported function:

| Source | Precedence |
|---|---|
| `base_notes[[var]]` supplied by the caller | wins, and is **exempt** from the unanimity rule below |
| `universe` metadata on the design | used when the caller supplies nothing for that variable, subject to unanimity |
| neither | no base-note row, exactly as today |

**The two sources stay separate** in the resolved object. A single merged vector
would satisfy the precedence table and break the exemption: after a merge nothing
distinguishes a caller entry from a universe entry, so a battery whose first
member carries a caller note and whose others carry a differing universe would be
judged by unanimity and print nothing.

**The text is written verbatim.** No `Base:` prefix is added. The strings are
authored for display in the cleaning schema — *Asked of all U.S. adults.* — and a
prefix would produce *Base: Asked of all U.S. adults.* A house style that wants
the prefix adds it where the text is written, not in the export layer, which
cannot see the wording.

**The unanimity rule.** `.base_note_for()` keys on the frame's first variable,
which is the sole variable of a single-response table or the first member of a
SATA or battery group. First-member semantics are harmless for a caller-supplied
vector and wrong for the universe fallback, because `extract_universe()` returns
one entry per variable and a cleaned battery carries a universe on every member.

| Scope | Rule |
|---|---|
| a single-response table | print the variable's universe |
| a SATA or battery block | print the universe only when **every** member carries the **same** text; otherwise print none |
| a collection | print only when **every** member survey carries the same text for that variable |
| a role lookup on a collection | the same rule |

Unanimity is judged on the members that **reach the frame**. A member dropped by
the role guard is not in the block the reader sees, so it does not veto the note.

For a battery inside a collection, resolve each wave first, then apply the
battery rule to the unanimous result. A variable that fails wave unanimity is
already absent, so the battery rule sees a missing value for it and prints
nothing. The two rules never run in the other order.

`.validate_base_notes()` runs on the caller's vector alone, before the merge.
Metadata written by surveycore is not the caller's error to fix, and a validation
message naming a variable the caller never mentioned is wrong.

### 3.7 Banner validation

Two conditions abort, both checked on the **surviving** banner columns after the
role guard and before any estimate runs. There is no point aborting over a label
collision on a column that is about to be dropped.

| Condition | Behavior |
|---|---|
| one value label mapped to 2 or more codes | abort, `surveyreports_error_duplicate_value_label` |
| 2 or more labels mapped to one code | keep — not a factor-level collision, and surveycore accepts it |
| exactly one **observed** code carries no label | keep. It is a real subgroup whose level is `NA_character_`, it faces the floor like any other, and `get_freqs()` returns the same level so the join is exact |
| 2 or more **observed** codes carry no label | abort, `surveyreports_error_multiple_unlabelled_codes` |

**Why the duplicate label aborts rather than warns.** `set_val_labels()` accepts
a duplicate. Both `get_freqs()` and `get_effective_n()` then abort inside
`.apply_group_labels()` with the base-R message `factor level [3] is duplicated`.
Warning and continuing would compute a union nobody sees and then abort with a
message naming a surveycore internal.

**Why two unlabelled codes abort.** Both key as a missing value, so two subgroups
with different counts share one key. The `.resolve_eff_n()` join matches one key
to two rows, the withheld list names the same missing key twice with no way to
tell them apart, the withholding filter removes both when one falls below the
floor, and the sheet renders two column groups with the same heading and
different numbers. None of that is fixable downstream.

An unlabelled code observed in no row is dropped by surveycore before this check
and does not count. The check counts **observed** codes only.

### 3.8 Banner headings and interaction spanners

**A banner spanner reads the variable label**, falling back to the column name.
`Gender`, not `gen`. An interaction spanner reads the labels of its parts:
`Gender × Region`.

Sheet tabs keep the **variable name**. A tab holds 31 characters and a variable
label can run to 80.

A banner column with no variable label joins the existing
`surveyreports_warning_missing_variable_label`, which today covers `vars` only.
It is the same defect with the same fix, and the column name is now visible as a
heading.

**Interaction levels read labels, not codes.** `.compute_interaction_freq()`
builds its grouping column from `@data`, which holds codes and carries no value
labels, so `get_freqs()` returns the code strings unchanged. One workbook, two
vocabularies: the `Gender` spanner reads `Male` while the crossed spanner reads
`1 × 1`.

Required: translate each banner column with `.banner_levels_labelled()` before
`interaction()` runs.

**A factor must come back as a factor, with its level order intact.**
`interaction()` orders character input alphabetically, and the column-group
builder takes the spanner order straight from those levels. A character return
re-sorts every non-alphabetical factor banner: a Likert banner ordered `Low`,
`Medium`, `High` would render `High`, `Low`, `Medium`.

### 3.9 The Total column, and the row that said 100%

| Change | Detail |
|---|---|
| Heading | `total_label`. Its `NULL` default resolves to `"Total"` on a domain-restricted design and to `"Full Sample"` on every other design |
| Spanner | **none.** The total group's spanner cell is empty. Today the word `Total` appears as a spanner, as a heading and as the last row label, naming three different things |
| The `100%` row | **removed.** It was the only row proving a column sums, and it never did: with `na.rm = TRUE` and rounding, the visible cells routinely do not total 100. That check belongs in a test, not in the deliverable |

`"Full Sample"` is right for a general-population study and wrong for one fielded
on a panel of donors, which is why it is an argument.

**A domain-restricted design takes `"Total"`.** When the design carries the
domain column and the caller did not set `total_label`, the heading reads
`Total`. On such a design the Total column holds in-domain estimates and its
sample-size rows hold the in-domain counts — section 3.20 — so
`"Full Sample"` would be a false claim about a subset. A caller-supplied
`total_label` is used as given on any design: the caller knows what the domain
is, and the package does not overrule the label.

**The check is a direct column test, in `.has_domain()`.** surveycore exports
no domain accessor. Measured 2026-09-16: its namespace gives
`SURVEYCORE_DOMAIN_COL` and `get_effective_n()`, so testing that constant
against `names(design@data)` is the only route. On the 200-row taylor fixture
with 75 rows in domain, the column is a full-length logical with `TRUE` on 75
rows, and `get_effective_n()` returns `n = 75` and `n_eff = 68.65` against
`200` and `184.98` unrestricted. So the in-domain base is recoverable and the
heading can follow it. Two files read the check — `export_crosstab()`
resolves the default, and `.write_cover_sheet()` writes the domain row of
section 3.14 — so the helper lives in `R/export-utils.R`, per
`code-style.md`.

**This returns the word `Total` to one place, and to one only.** The table
above removes `Total` from the spanner, and it removes the `100%` row that
carried the word as a last row label. The heading is the third place, and it is
the place the word comes back to, under the `NULL` default on a
domain-restricted design. The spanner cell stays empty on every design and no
row label reads `Total`, so the workbook never uses the word for two things at
once.

**One helper holds both strings: `.total_col_group()`, in
`R/export-utils.R`.** Its `levels` field is the heading and its `spanner`
field is the spanner. Both become arguments — section 2.3 — and the crosstab
route passes both: the resolved `total_label` for the heading, and
`spanner = ""` for the empty spanner. `export_topline()` calls the helper with no arguments, so it
keeps `Total` in each place. Section 2.1 gives the six call sites and names why
the topline output does not move.

**`.render_block_preamble()` needs no change for this.** It receives
`col_groups` already built, so an empty spanner reaches it as data and travels
on to `.write_crosstab_headers()` unread. No helper in the render path tests the
spanner string. An empty spanner is a blank cell, not a missing column group:
the total group still holds one level and still gets one data column.

**`show_total = FALSE` removes the group.** The caller does not build the total
column group at all. Its heading, its empty spanner cell and its data cells are
all absent, and every table in the workbook holds one column group fewer. A
banner of one three-level column therefore writes three data columns rather
than four.

**The base note and the sample-size rows do not move.** The base note is a
property of the question, so row 2 of section 3.16 is unchanged. The
sample-size rows are per subgroup: each surviving banner level keeps its own
unweighted and effective cells, and the two rows lose the pair of cells that
stood under the total heading. The rows themselves stay, and
`sample_size_display` still decides where they sit. The same argument applies
to a spanner: `show_total = FALSE` removes a group, not a row.

**One combination needs both sections.** `show_total = FALSE` with every banner
level withheld leaves the block with zero data columns. Section 3.5 states it:
its degenerate table carries the row, and the paragraph under that table gives
the block row by row. The neighbouring row of the same table reads "with the
Total column alone" and assumes `show_total = TRUE`. The two rows are separate
cases, and both are stated.

### 3.10 The role guard

`role` is not a first-class surveycore property. It is a key inside the
per-variable extension slot `var_extra`. surveycore stores and returns the
payload unchanged and never reads it. The seven values come from the ADL cleaning
schema, section 7 of `adldata/plans/survey-cleaning-skill-design.md`.

| Set | Values |
|---|---|
| Non-substantive — drop | `weight`, `identifier`, `paradata`, `free_text` |
| Substantive — keep | `item`, `demographic`, `treatment` |

`treatment` stays substantive: an experimental arm is a common banner variable,
so dropping it would remove the column an experimental report crosses on.

| Condition | Behavior |
|---|---|
| a `vars` or `banner` column carries a non-substantive role | drop it; warn once per argument, listing every dropped column |
| a column carries no `role` | keep — substantive by default |
| a column carries an unrecognized `role` string | keep, warn |
| a column's `role` is not a length-1 character | **keep, warn** |
| a `vars` or `banner` column is one the design itself names | **it never reaches this table.** `.reject_design_vars()` aborts first, at step 9 of section 3.11 — sections 3.11 and 3.17. A design variable is not dropped; the call errors |

**A design-named column and a metadata `role` are two mechanisms, and they stay
separate.** The design names its own weight, cluster id, stratum, FPC,
replicate-weight and twophase-subset columns, and naming one of those in `vars`
or `banner` is an error. A column whose metadata `role` reads `"weight"` and
which the design does **not** name keeps the drop-with-warning behavior of the
table above. The first mechanism reads the design object; the second reads
`var_extra`. Neither reads the other.

An absent role means substantive. `role` is new and almost no existing dataset
sets it; any other default breaks current data.

This closes a real defect: `ald1_13_text` is selected by `starts_with("ald1_")`
and renders as a 119-row table of verbatim answers at 0.1% each. With
`role = "free_text"` set, it drops.

**The guard must not abort on a foreign payload.** surveycore does not validate
`var_extra`. Measured: `role = c("item","demographic")` and `role = 3L` are both
accepted and returned unchanged, and the obvious `vapply(..., character(1))`
implementation aborts on the first.

| Payload | `.resolve_roles()` returns | Guard behavior |
|---|---|---|
| a length-1 character | that string | classify normally |
| a length-0 value, or the key is absent | `NA_character_` | keep, no warning |
| a length-2 or longer vector | `NA_character_` | keep, warn `unknown_role` |
| a non-character of any length | `NA_character_` | keep, warn `unknown_role` |
| a length-1 character outside the seven | that string | keep, warn `unknown_role` |

**The guard must not abort on a collection either.** `extract_var_extra()`
aborts on one — section 1.5 — and `export_topline()` accepts a collection and
runs the guard on `vars`. `.resolve_roles()` branches on the design type and
reads each member. A role resolves only when every member agrees, by the
unanimity rule of section 3.6, whose table carries the row "a role lookup on a
collection | the same rule". A role that disagrees across members, or is missing
in any member, resolves to `NA_character_`, which the table above keeps with no
warning.

**Degenerate cases.**

| Case | Behavior |
|---|---|
| `vars` drops to zero columns | abort, `surveyreports_error_vars_all_dropped` |
| `banner` drops to zero columns | abort, `surveyreports_error_banner_empty_selection` |
| an `interactions` element names a dropped `banner` column | abort, existing `surveyreports_error_interaction_not_in_banner` |

`vars` gets its own class rather than reusing
`surveyreports_error_vars_empty_selection`, whose `"i"` and `"v"` bullets both
become false for the new trigger: tidyselect resolved correctly, the guard
emptied the set afterwards, and the existing message sends the caller to fix an
expression that is already right. The existing class keeps its trigger and its
message, so no committed snapshot moves.

The banner abort fires only when **every** banner column is dropped. One
surviving column is a valid banner, and the drop is reported by
`surveyreports_warning_role_dropped` as usual.

`interactions` is validated **twice** — once against the resolved banner, and
again against the surviving banner immediately after the guard. `demographic` is
a role the guard keeps, so a banner mixing substantive and non-substantive
columns is the ordinary input, and without the second check
`interactions = list(c("gen","reg"))` passes validation and then names a column
the banner no longer holds.

**Dropping a member of a battery or SATA group.** Measured 2026-09-10: a group
survives a partial drop and does not survive being reduced to one member.

| Members reaching classification | `type` | `group` |
|---|---|---|
| `bat_1`, `bat_2`, `bat_3` | `battery` | 1 |
| `bat_1`, `bat_2` | `battery` | 1 |
| `bat_1` alone | **`single`** | 1 |

| Case | Behavior |
|---|---|
| 2 or more members survive | the group is kept, classified as before, group id unchanged. No extra warning |
| exactly 1 member survives | the survivor renders as a single-response question, loses the question preface, and gets its own block. No second warning — `role_dropped` already names every dropped column |
| every member is dropped | the group is absent. If nothing else survives, the `vars` abort fires |

The sheet name follows the first **survivor**: dropping `bat_1` renames the sheet
to `bat_2`. The sheet is named for the block it holds.

### 3.11 Ordering constraints

The order below is a contract, not an implementation note. Several of these
checks would report the wrong condition if they ran out of turn.

1. `survey_collection` rejection
2. design class check
3. `vars` tidy-select resolution
4. `.validate_export_inputs()` — including the **empty-domain check**
5. `banner` tidy-select resolution
6. `interactions` shape and membership validation
7. `.validate_base_notes()` on the caller's vector alone
8. **`min_eff_n` validation** — length-1, non-missing, finite, numeric, and
   `>= 0`, or `surveyreports_error_invalid_min_eff_n`
9. **the design-variable check** — `.reject_design_vars()` on `vars`, then on
   `banner`
10. **the role guard** on `vars`, then on `banner`
11. `interactions` membership re-validated against the surviving banner
12. banner label validation — section 3.7
13. `classify_question_type()`, with `tidyselect::all_of()` on the resolved vector
14. estimation
15. **withholding** — `.build_withheld()` returns the withheld frame
16. **the workbook build** — `.build_workbook()`, which writes the `"About"`
    sheet
17. rendering

**Steps 15 and 16 are in this order because `.build_workbook()` receives the
withheld frame.** The build cannot run before withholding decides it. Section
2.3 gives the signature and section 3.14 gives the sheet.

`min_eff_n` is validated in `.validate_export_inputs()`, beside the existing
`conf_level` and `decimals` checks, and before the role guard. It is the sole
parameter of the rule that decides what gets published, and today it is the only
one of the three that takes any value silently: `-5` withholds nothing, `NA`
makes every comparison `NA`, a length-2 vector recycles and withholds alternate
levels, and `"100"` compares as a string, so `"23.1" < "100"` is `FALSE` and a
small subgroup is published.

**Step 9 runs after both tidy-select resolutions and before the role guard.**
After the resolutions, because the check compares column names and a
tidy-select expression is not one yet. Before the role guard, because a
design-named column must error and not be dropped: the guard reads the
`var_extra` role table, and a design variable that also carries
`role = "weight"` would be dropped with a warning and the call would then
succeed. The error has to win, so it is raised before the role table is read —
section 3.10. The check runs on `vars` first and on `banner` second, so a call
naming a design column in both reports `vars`.

The empty-domain check precedes the role guard, so a design with an empty domain
and a role-dropped column raises `surveyreports_error_empty_domain` and not a
role warning. A dropped column must not reach classification, or it forms its own
question group and shifts the group numbering of everything after it.

**`export_topline()` runs ten of the seventeen steps, in this order:**

1. the design class check
2. the `vars` tidy-select resolution
3. `.validate_export_inputs()` — including the **empty-domain check**
4. `.validate_base_notes()` on the caller's vector alone
5. **the design-variable check** — `.reject_design_vars()` on `vars`
6. **the role guard** on `vars`
7. `classify_question_type()`, with `tidyselect::all_of()` on the resolved
   vector
8. estimation
9. the workbook build — `.build_workbook()`
10. rendering

Its step 5 sits where the crosstab step 9 sits, and for the same two reasons:
after the tidy-select resolution and before the role guard.

Seven steps of the seventeen-step list do not apply, and they are its steps 1,
5, 6, 8, 11, 12 and 15. `export_topline()` accepts a `survey_collection`, so
its step 1 has nothing to reject. It has no `banner` argument, so its steps 5,
6, 11 and 12 have nothing to validate. It has no `min_eff_n` argument, so its
step 8 has nothing to check. It withholds nothing, so step 15 does not run —
section 4.2. It therefore passes `withheld = NULL` to `.build_workbook()`, and
the cover sheet carries no withheld block — section 3.14.

The order protects the same constraint the crosstab order does: the
empty-domain check runs before the role guard. A design with an empty domain
and a role-dropped `vars` column raises `surveyreports_error_empty_domain`, and
no role warning is raised first.

**This paragraph prevents a guess. It does not correct shipped behavior.**
`R/export-topline.R` already runs the design class check, then the `vars`
resolution, then `.validate_export_inputs()`, then `.validate_base_notes()`,
then `classify_question_type()`. That agrees with the order above. Neither the
design-variable check nor the role guard exists in the file yet, and this spec
adds both, so the list fixes where the two new steps land.

Step 7's `all_of()` is a change to `R/export-topline.R`. The shipped call
passes the resolved vector bare. Section 2.1 lists the `all_of()` fix as one of
that file's five items, and section 4.1 counts the same five inside Part A's
write surface, so the step is already in scope and section 4.1 stands.

**No shared helper owns the opening steps.** Extracting one would rewrite
`R/export-topline.R`'s opening, and section 4.1 holds Part A's write surface in
that file to five items. The two functions keep two implementations of one
order, and this section is the only statement of it.

**Warning emission order is fixed** — selection, then metadata, then results:

1. `surveyreports_warning_role_dropped`
2. `surveyreports_warning_unknown_role`
3. `surveyreports_warning_missing_variable_label`
4. `surveyreports_warning_subgroup_withheld`
5. `surveyreports_warning_banner_all_withheld`
6. `surveyreports_warning_full_sample_below_min`

It is the order the caller can act in, and it is already the order the call
sequence produces. Fixing it in writing makes the snapshots deterministic.

### 3.12 Variance

| `variance` | What appears | Units |
|---|---|---|
| `NULL` | nothing. The default | — |
| `"se"` | the standard error, in parentheses | percentage points, at `decimals` places |
| `"ci"` | the interval bounds, in parentheses, en-dash separated | percentage points, at `decimals` places |

**`.fmt_pct()` and `.fmt_variance()` own the conversion**, so the render passes
surveycore's values through unchanged. surveycore returns `se`, `ci_low` and
`ci_high` as proportions — `se = 0.0290` for an estimate of `0.356`, measured in
section 1.4. A render that wrote a proportion straight into a cell would print
every standard error as `0.0`. The two formatters remove that defect, because
the render no longer holds the conversion.

**`.fmt_variance()` owns the string.** It returns the whole parenthesised value
for one cell: both forms, the parentheses, the one `%` per number and the
separator. It formats each number with `.fmt_pct()`, so a variance number obeys
the same rounding mode and the same floor and ceiling strings as an estimate.
`has_rows` is the estimate cell's own value, so a variance number is never `-`
on its own. The helper returns an empty string when `variance` is `NULL` or the
cell has no rows.

**One `%` per number.** Each bound and each standard error carries its own `%`.
Worked examples at `decimals = 1`:

| Input from `get_freqs()` | Cell |
|---|---|
| `pct = 0.356`, `se = 0.0290` | `35.6%` and `(2.9%)` |
| `pct = 0.356`, `ci_low = 0.300`, `ci_high = 0.413` | `35.6%` and `(30.0% – 41.3%)` |
| `se = 0.0004` | `(<0.1%)` — the floor string of section 3.3, not `(0.0%)` |

**Two characters, two jobs.** The separator between the two bounds is an
en-dash, U+2013, with one space on each side: `30.0% – 41.3%`. The minus sign on
a negative bound is a hyphen-minus, U+002D, and takes no space: `-0.3%`. One
cell can hold both, as `(-0.3% – 1.8%)` does. An implementer who writes a
hyphen-minus as the separator, or an en-dash as the minus sign, produces a
string that does not match this contract. `.fmt_variance()` is the one place
either character is written.

The interval is whatever `surveycore::get_freqs(variance = "ci", conf_level =)`
returns. This package computes no interval of its own and states no formula, no
degrees of freedom and no distribution choice: all three are surveycore's, and
duplicating them here would create a second specification to keep in sync.

**The bounds print exactly as surveycore returns them. They are not clipped.**
The interval is a normal approximation, so for a rare category the lower bound
can fall below 0 percent and for a near-unanimous one the upper bound can rise
above 100 percent. Measured in section 1.4: a category held by 2 of 300 rows
returns `ci_low = -0.00343`, and the cell reads `(-0.3% – 1.8%)`. Clipping would
break the delegation above — the printed number would no longer be surveycore's
— and would hide the approximation from the reader. The glossary entry of
section 3.15 states the fact instead. **Decision (2026-09-14, issue 31, option
B).** `.fmt_variance()` must therefore accept a negative lower bound and print
it.

| `variance_display` | Where it goes |
|---|---|
| `"cell"` | a second line inside the estimate cell, written with `openxlsx2::fmt_txt()` at a smaller size and a lighter colour. The default |
| `"row"` | its own row directly under each estimate row, with the label columns blank |

**A legend row is written under the question title whenever `variance` is set**,
and only then:

- `variance = "se"` → `Percentages; standard error in parentheses.`
- `variance = "ci"` at `conf_level = 0.95` → `Percentages; 95% confidence interval in parentheses.`
- any other `conf_level` → the same sentence naming that level.

A bracketed number with no legend is unreadable. The row costs one line and
exists only when there is something to explain. The cover sheet glossary carries
a fuller entry; the two are not alternatives, because a reader looking at a
bracketed number needs the answer in the same view.

A cell with no rows carries no variance under either display: `-` stands alone,
and the variance row is blank in that column.

### 3.13 Missing data

| `na.rm` | Effect |
|---|---|
| `TRUE` (default) | as today — surveycore drops missing values from both the tabulated variable and the banner |
| `FALSE` | a response row labelled `na_label` appears in every block, and each banner column with missing values gains a level labelled `na_label` |

A missing-value banner level is a real subgroup and faces `min_eff_n` like any
other. On most designs it is small and the floor removes it again — that is the
correct interaction, not a defect.

**`na.rm` reaches five call sites, and the same value reaches all five.** Four
are `get_freqs()` calls; the fifth is `get_effective_n()`:

| Call site | Function called |
|---|---|
| `.compute_total_freq()` | `surveycore::get_freqs()` |
| `.compute_subgroup_freq()` | `surveycore::get_freqs()` |
| `.compute_interaction_freq()` | `surveycore::get_freqs()` |
| the collection path of `export_topline()` | `surveycore::get_freqs()` |
| `.resolve_eff_n()` | `surveycore::get_effective_n()` |

`get_effective_n()` also defaults to `na.rm = TRUE` and drops the missing-value
level when it is not told otherwise. Missing the fifth site produces a workbook
that holds a missing-value column group with no row in the counts frame: the
level cannot be tested against `min_eff_n`, so the one subgroup most likely to
be small is published whatever its size, and its two sample-size cells are
empty.

### 3.14 The cover sheet

**Decision (2026-09-14): one sheet, three blocks.** Named `"About"`, added by
`.build_workbook()`.

**`"About"` is the first sheet because it is the first sheet added.**
`wb_workbook()` creates no sheets, `.build_workbook()` adds `"About"` before
any question sheet, and openxlsx2 orders sheets by insertion. There is no
position argument: `wb_add_worksheet()` takes no index and no `after`, and no
call in the package passes one. So sheet 1 is a property of position, and it
holds even though `.build_workbook()` runs at step 16 of section 3.11, after
estimation and withholding.

| Block | Content | Present when |
|---|---|---|
| Survey metadata | one row per set dataset key, in surveycore's canonical key order, under a `Key` / `Value` header, then the domain row below them | any key is set, or the design carries the domain column |
| Subgroups not shown | the `min_eff_n` in force, then the lines of `.format_withheld_lines()`, one per withheld subgroup. States `None` when the frame has no rows, so the reader learns the rule applied | `withheld_note == "once"` and `min_eff_n > 0` |
| What these numbers mean | the glossary of section 3.15 | always. Its entries are individually conditional — section 3.15 |

**The domain row.** A design restricted to a domain gets one more row in the
survey metadata block, below the dataset keys. Its key reads `Restricted to`,
and its value reads the in-domain row count against the design's total rows, as
`75 of 200 rows`. The row is written only when the design carries the domain
column, and `.has_domain()` is the check — section 3.9 gives it and the
measurement behind it. The in-domain count is `get_effective_n()`'s `n`,
reached through `.resolve_eff_n()` with no `group_var`. Section 3.4 reads the
same number for the unweighted sample size, so the cover sheet and that row
cannot disagree. The total is `nrow(design@data)`.

**The row names the restriction by its size, not by its condition.** The design
keeps no record of the expression that set the domain, so the package cannot
print one. Two numbers are what it holds, and they are what the reader needs:
the base the workbook is built on, and the base it would have had.

**One wording, three places.** `.build_withheld()` produces the frame and
`.format_withheld_lines()` produces the text. Each line names the subgroup, its
banner variable and its effective N, and reports no raw N: the floor tests the
effective N and section 3.5 tests no raw N, so a raw N on the line would name a
number the rule never read. Section 3.16's per-table block and section 3.18's
console warning read the same vector, so the three cannot disagree.

**A zero-row frame and `NULL` are different facts.** A zero-row frame means the
floor ran and withheld nothing, and the block is written with its `None` row.
`NULL` means no withheld block is written at all.

**The caller owns the decision.** `.write_cover_sheet()` never reads
`withheld_note` and takes no such argument. The caller passes `withheld = NULL`
when `withheld_note` is not `"once"`, and passes the withheld frame otherwise.
That choice is only possible because withholding runs at step 15 and the
workbook build at step 16 — section 3.11. The frame exists by the time the
caller has to choose.

The `NULL` reaches this sheet from the caller alone. `.build_withheld()` never
returns it, and withholding still removes the columns at every `withheld_note`
value — section 3.5. A `NULL` here says the caller asked for no block on this
sheet. It does not say the floor withheld nothing.

The sheet is written **whenever any block has content**. Because the glossary
block always has content, the sheet is present in every workbook. This supersedes
v0.7.0 §6.1, which made the sheet conditional on dataset metadata and claimed a
byte-identical workbook when none was set. That property is gone, and it was
load-bearing for the old no-snapshot-change gate.

Three sheets — survey, withheld, glossary — were rejected. The three blocks total
about twenty rows, so two of the three tabs would be nearly empty, and a reader
asking why a column is missing would have to visit two of them: the withheld list
and then the glossary that explains the rule. If the content grows, the split
that survives is two sheets: `About` for where the data came from, `Notes` for
why the table looks as it does.

| Item | Rule |
|---|---|
| Header row | `Key` in A1, `Value` in B1, both bold |
| Position | sheet 1, by insertion order — see the paragraph above |
| Active sheet | The written file opens on `"About"`. Measured on openxlsx2 1.28: `get_active_sheet()` returns `numeric(0)` while the workbook is in memory and `1` after a save and reload. Adding later sheets does not move it. A check that reads the active sheet from a workbook still in memory proves nothing |
| Block headings | bold, in column A, with column B empty; one blank row between blocks, none after the last |
| Name collision | a data sheet named `About` is suffixed `About_2`, then `About_3`, because the cover sheet's name is fixed and a caller cannot rename it. The comparison folds case — section 2.2 |
| Styling | bold, the block structure, and the column widths of section 3.16. No merged cells |

`.unique_sheet_name()` serves the three per-question `wb_add_worksheet()` calls
in `R/export-crosstab.R`. The fourth writes the stacked-layout sheet under the
literal name `"Crosstab"`, which cannot collide, and is deliberately not routed.

**Assign the result back to the sheet-name variable**, before the sheet is added
and before it is rendered into. Each call site computes the name once and uses it
twice — to add the sheet and to render into it. Wrapping only the
`wb_add_worksheet()` argument splits the two apart: the workbook gains `About_2`
while the render helper writes its question block into `About`, destroying the
cover sheet and leaving the new one empty.

A shared helper also closes a pre-existing case: two variables whose names share
their first 31 characters abort today, for the same reason.

**A collection writes one block per wave**, in `@surveys` order: the wave name
alone in column A, then that wave's set keys, then one blank row. None after the
last. A wave with no keys set still gets its heading, so the sheet shows that the
wave carries no metadata. This path belongs to `export_topline()`. The unanimity
rule of section 3.6 does **not** apply: a cover sheet has room to show every
wave's value, so there is no need to collapse disagreement into silence.

### 3.15 The glossary

Written verbatim. The `Present when` column is the condition for that entry, not
for the block. `.write_cover_sheet()` takes seven arguments — section 2.2 — and
four of them decide which glossary entries it writes:

- `min_eff_n` and `has_banner` together drive `Why a column is missing`. The
  entry appears when `min_eff_n > 0` and a banner was rendered. `has_banner`
  records that the caller supplied a `banner`, not that a column survived the
  floor. So the entry still appears when every banner level is withheld, which
  is the case that most needs it.
- `string_cells` drives `Percentages`.
- `variance` drives `Confidence intervals`. The entry appears when `variance`
  is `"ci"`.

The other three arguments — `wb`, `design` and `withheld` — feed the survey
block and the withheld block. No glossary entry reads them. The helper writes
only the entries that are true of the workbook in hand:

| Term | Text | Present when |
|---|---|---|
| `Unweighted sample size` | The number of people who answered. It does not change when weights are applied. Report text writes this as N for the full sample and n for a subgroup. | always |
| `Effective sample size (ESS)` | The sample size left after weighting. Weights make some people count for more than others, and that costs precision, so this number is smaller than the unweighted sample size — the more the weights vary, the smaller it gets. It adjusts for the weights alone. It does not adjust for clustered sampling, so on a clustered survey the true precision is lower than this number suggests. | always |
| `Why a column is missing` | A subgroup whose effective sample size falls below the minimum is not shown. The minimum for this workbook is listed above. The test is on the size of the subgroup itself, not on how many of its members answered any one question, so a question that many people skipped can still be shown for a subgroup that clears the minimum. | `min_eff_n > 0` and a banner was rendered |
| `Percentages` | Each percentage is based on the people who answered that question, which can be fewer than the sample size shown above the table. A value that is not zero but rounds to zero at the shown precision reads `<0.1%`. A value below 100 that rounds to 100 reads `>99.9%`. A true zero reads `0%`. A dash means the answer was not chosen in that column, or was never offered there. | the cells are strings |
| `Confidence intervals` | The interval is a normal approximation. For a very rare or a near-unanimous answer a bound can fall below 0 percent or rise above 100 percent. That is a property of the approximation, not a count of people. | `variance = "ci"` |

**Each glossary term for a workbook row matches the row label the reader saw.**
`Unweighted sample size` is byte-identical to the label in section 3.4. The
`(ESS)` parenthetical on the effective-N term is the single deliberate
departure, and section 3.4 gives the reason: the abbreviation appears nowhere
in the workbook body, and the glossary is where a reader who met it in report
prose can look it up. No other term adds or drops a word.

No shared constant binds the two strings. The label lives in
`.write_sample_size_rows()` and the term lives in `.write_cover_sheet()`, and
the two are not identical by design, so a constant would have to be overridden
at one of the two sites. Keep them as literals and keep this rule as the check.

One entry covers `N` and `n` rather than two. In the table the column heading
already says which group a number describes, so the capital makes no distinction
there; the convention earns its keep in report prose, which one sentence can
explain.

**The ESS entry describes Kish, because Kish is what the workbook prints.**
`get_effective_n(method = "kish")` measures weight variation alone. Measured on
400 rows in 20 clusters with real intra-cluster correlation: Kish gives
`n_eff = 370.4`, while the size a simple random sample would need to match the
design's standard error is `139.7`. An entry promising the second number while
the cell holds the first would be false by a factor of 2.6 on an ordinary
clustered design. The same limit is why the `Why a column is missing` entry no
longer says the withheld estimates are "too imprecise to report": the floor
tests a weights-only quantity on the whole subgroup, and that is a weaker
guarantee than the phrase claims. Section 3.5 records the same two limits at the
rule.

The `Percentages` entry is written at the precision `decimals` is set to, so its
examples match the cells.

**No glossary entry for the domain row.** The cover-sheet domain row of section
3.14 reads `Restricted to` against a count of rows, and neither the key nor the
value needs a definition. Every entry in the table above explains a rule the
cells follow: how a percentage rounds, why a column is missing, what an
interval bound can do. The domain row states a fact about the design instead,
and it carries its own two numbers. An entry would also add a fourth condition
to the three this section already has, and it would move the term count that
two scenarios assert. **Decision (2026-09-16, issue 66): the glossary stays at
five terms.**

When `variance` is set to `"se"`, an entry names the statistic in the brackets
in the same words as the legend row of section 3.12. When it is set to `"ci"`,
the `Confidence intervals` entry above does that job.

**Two entries are false in an `export_topline()` workbook**, which is why they
are conditional. Topline withholds nothing — section 4.2 — so
`Why a column is missing` would tell the reader of a trend workbook that small
waves were removed, and there would be no minimum listed above it either.
Topline percentages are numbers, not strings, so the `Percentages` entry would
describe forms no cell holds.

### 3.16 Workbook contract

The row order within one question block, with the presence condition for each.
The builder threads a row cursor through the block and every helper returns the
next free row, per `code-style.md`.

| Row | Content | Present when |
|---|---|---|
| 1 | question text or group preface, bold, merged across the block | always |
| 2 | base note, italic | a caller note or a unanimous universe resolves — section 3.6 |
| 3 | variance legend, italic | `variance` is not `NULL` — section 3.12 |
| 4 | spanner row: one merged cell per column group; the Total group's cell is empty | always |
| 5 | heading row: the label column(s), then one heading per level | always |
| 6 | `Unweighted sample size` | `sample_size_display == "top"` |
| 7 | `Effective sample size` | `sample_size_display == "top"` and `show_ess` |
| 8…k | one row per response value (single, battery) or per item (SATA) | always |
| — | a variance row after each estimate row | `variance` set and `variance_display == "row"` |
| k+1 | the two sample-size rows | `sample_size_display == "bottom"` |
| k+2… | the withheld lines of `.format_withheld_lines()` — section 3.14 fixes the wording | `withheld_note == "every"` and the frame has rows |

The label column is `Response` for a single-response block, `Item` for SATA, and
`Item` plus `Response` for a battery. A battery block is therefore one column
wider than the others, and its sample-size rows leave the second label column
blank.

**Two helpers own the sequence.** `.render_block_preamble()` writes rows 1 to 7.
`.render_block_footer()` writes row k+1 and after. Each one returns the next
free row, per `code-style.md`. The three render routes then differ in two things
only: the data rows between, and `label_cols`. The row order above stays the
contract, and it gains one implementation, so a row added to this table is one
edit rather than three.

**The preamble depends on one earlier step.** The battery route cannot call a
shared preamble as it stands. Measured: `.render_crosstab_battery()` adds `1L`
to `n_cols` at `R/export-crosstab.R:797` for its second label column, then
writes 47 lines of spanner and heading sequence inline at `:813-859`, instead of
calling `.write_crosstab_headers()`. The single and the SATA route both call
that helper. So `.write_crosstab_headers()` gains `label_cols` first — section
2.3 — and the battery route adopts it. The preamble extraction depends on that
step, and section IX carries the order.

**The single route also writes a row the other two do not.**
`.render_crosstab_single()` writes a `Total` row of `100%` cells at
`R/export-crosstab.R:612-633`. B6 removes that row and nothing replaces it. The
three routes then share one closing sequence, in which the bottom sample-size
rows and the withheld lines are the only things below the data rows.

| Sheet property | Rule |
|---|---|
| Column widths | fixed: 44 characters for the label column, 12 for each data column. **Not auto-fit** — openxlsx2 estimates width from character counts, so an auto-fit workbook shifts whenever a label changes and every snapshot moves with it |
| Wrapping | on for the label column and the heading row |
| Heading row height | fixed at **30 points**. The default row height is 15 points and holds one line, so 30 points holds the two lines a wrapped heading takes at a data column width of 12. **Not auto-fit** — a height that follows the text moves whenever a heading changes, for the same reason the widths are fixed |
| Freeze pane | below the last heading or sample-size row, so the question, the headings and the counts stay in view. Not written when `sample_size_display == "bottom"` |

### 3.17 Errors

Every class below must be added to `plans/error-messages.md` **before**
implementation. Message structure follows `code-style.md`: `"x"`, then `"i"`,
then an imperative `"v"`.

| Class | Trigger condition |
|---|---|
| `surveyreports_error_vars_all_dropped` | every `vars` column was dropped by the role guard. The `"i"` bullet lists each dropped column with its role; the `"v"` bullet points at selecting a substantive column or clearing the role |
| `surveyreports_error_banner_empty_selection` | every `banner` column was dropped by the role guard |
| `surveyreports_error_duplicate_value_label` | a surviving `banner` column carries one value label on 2 or more codes. Names the column and the repeated label; the `"v"` bullet points at `surveycore::set_val_labels()` |
| `surveyreports_error_multiple_unlabelled_codes` | a surviving `banner` column carries 2 or more observed codes with no value label. Names the column and the codes |
| `surveyreports_error_design_variable_selected` | a `vars` or `banner` column is a column the design itself names — a weight, a cluster id, a stratum, an FPC, a replicate weight, or a twophase subset column. The `"x"` bullet names the column and the argument it appeared in; the `"i"` bullet names the design slot the column was found in; the `"v"` bullet points at removing the column from the selection. Raised in `.reject_design_vars()`, at step 9 of section 3.11 |
| `surveyreports_error_invalid_min_eff_n` | `min_eff_n` is not a length-1, non-missing, finite, non-negative numeric. The `"i"` bullet reports what was received; the `"v"` bullet points at a single number at or above 0. Raised in `.validate_export_inputs()`, at step 8 of section 3.11 |

All existing error classes keep their triggers and their messages.

### 3.18 Warnings

| Class | Trigger condition |
|---|---|
| `surveyreports_warning_role_dropped` | one or more columns dropped from `vars` or `banner` for a non-substantive role. Once per argument, listing every column and its role |
| `surveyreports_warning_unknown_role` | a column's `role` is outside the seven known values, or is not a length-1 character. Once per call, listing every affected column; the column is kept |
| `surveyreports_warning_subgroup_withheld` | one or more subgroups fall below `min_eff_n`. Once per call. Its bullets are the lines of `.format_withheld_lines()`, so section 3.14 fixes the wording. **Renames `surveyreports_warning_subgroup_suppressed`**, whose trigger referenced `pub_type` |
| `surveyreports_warning_banner_all_withheld` | every level of one or more banner column groups, or every cell of an interaction, falls below `min_eff_n`. Names each affected group |
| `surveyreports_warning_full_sample_below_min` | the full sample's own effective N is below `min_eff_n`. The workbook is written in full |
| `surveyreports_warning_missing_variable_label` | **trigger extended** — a `vars` column or a `banner` column has no variable label. Once per call, listing every affected column |

`surveyreports_warning_subgroup_suppressed` is removed from
`plans/error-messages.md` in the same edit that adds `_withheld`.

A warning must never stop the write. Every warning path still returns
`invisible(file_name)` and leaves a readable file on disk.

### 3.19 Edge cases

| Case | Behavior |
|---|---|
| empty domain | `surveyreports_error_empty_domain`, raised before the role guard — section 3.11 |
| single-row design | the call succeeds; the unweighted sample size is `1`. With the default floor every subgroup is withheld and the all-withheld warning fires |
| `show_total = FALSE` with every banner level withheld | the block has zero data columns. Every row is written with its label and no data cell; `banner_all_withheld` fires and nothing else; the call returns the path — section 3.5 |
| a `vars` or `banner` column the design names | `surveyreports_error_design_variable_selected`, raised after the tidy-select resolution and before the role guard — sections 3.11 and 3.17. The scope is every slot that holds a column name, so a replicate weight and a twophase subset column both abort |
| single-value variable | one response row; the sample-size rows are unchanged, because they do not depend on the tabulated variable |
| all-NA variable | the call succeeds; the sample-size rows report the design's in-scope rows, not `0` |
| a variable with missing values | the call succeeds. The response rows total less than the sample size above them. This is the stated contract of section 3.4, not a defect |
| zero-weight rows | **cannot reach an export function.** `as_survey()` aborts at construction on a non-positive weight — section 1.4. No design holding one can be built, so there is no behavior here to specify. `testing.md`'s required edge-case list does not name this case — it names an all-NA variable, single-row data, a single-value variable, an empty banner level and a missing variable label. This row stands because a reader looking for a zero-weight rule needs the reason it is absent |
| unused factor level on the banner | no column. surveycore drops a factor level that no row uses, exactly as it drops an unobserved labelled code |
| unused factor level on the tabulated variable | no response row; the sample-size rows are unchanged |
| a banner level with exactly one unlabelled observed code | a real subgroup whose level is `NA_character_` — section 3.7 |
| a self-banner (a variable named in both `vars` and `banner`) | unchanged: that banner column is skipped for that variable |
| `decimals = 0` | the rounding rule's floor string becomes `<1%` and its ceiling string becomes `>99%` — section 3.3 |
| a category held by almost every row | the cell reads `>99.9%` at `decimals = 1`, never `100.0%` — section 3.3 |
| a rare category under `variance = "ci"` | the lower bound can print as a negative percentage. Not clipped — section 3.12 |
| `min_eff_n = 0` | nothing is withheld; no withheld block is written; the cover sheet still carries the glossary, without the `Why a column is missing` entry — section 3.15. surveycore's raw-N warning is muffled as well — section 3.5 |
| `min_eff_n` is `NA`, `Inf`, negative, character, or longer than 1 | `surveyreports_error_invalid_min_eff_n`, before the role guard — section 3.11. `Inf` fails the finite test of section 3.17, so it aborts and writes no workbook. It never reaches the degenerate case of section 3.5 |

### 3.20 Cross-design behavior

| Design type | What differs |
|---|---|
| `survey_taylor` | nothing — the reference |
| `survey_replicate` | nothing |
| `survey_twophase` | both sample-size counts follow the phase-2 subset. This is a **change in value** from the current code, which counts phase-1 rows |
| `survey_nonprob` | nothing |
| a domain-restricted design of any type | both counts follow the in-domain rows. Also a change in value. The Total column's default heading reads `Total` rather than `Full Sample`, and the cover sheet gains the domain row, because in-domain is what the column holds — sections 3.9 and 3.14 |

No workstream branches on the subclass. The twophase and domain corrections
arrive through delegation, not through a special case.

One branch reads the domain, and it is not a branch on the subclass.
`.has_domain()` tests one column name. The two things that read it — the
`total_label` default and the cover-sheet domain row — behave the same way
on all four subclasses.

---

## IV. `export_topline()` — what it inherits

### 4.1 The bounded change

`export_topline()` receives Part A and no part of B. Its signature does not
change. Three things reach it anyway, and all three are unavoidable without a
compatibility shim in a shared helper.

| What reaches it | Why | Visible effect |
|---|---|---|
| `.resolve_eff_n()` | it replaces `.compute_eff_n()`, and `export_topline()` reads `frame$eff_n` for its percentage-column header — section 4.2 gives the header's form | the reported effective N becomes correct on twophase and domain-restricted designs. Its committed `show_eff_n` snapshots move |
| The `"About"` sheet | `.build_workbook()` is shared, and its new signature makes every caller pass `design`, so the topline call site changes in any case. `export_topline()` passes its own `variance` on the same line — section 2.3 | a topline workbook gains the cover sheet, with the glossary and, for a collection, one block per wave. On a domain-restricted design it also gains the domain row, because `.write_cover_sheet()` is shared — section 3.14. No withheld block: topline withholds nothing. The glossary carries the two sample-size entries always, and `Confidence intervals` when the call sets `variance = "ci"`. `Why a column is missing` and `Percentages` are false in every topline workbook: topline withholds nothing and its cells are numbers. Section 3.15 makes each of the three conditional, so a topline workbook carries two entries or three |
| `.reject_design_vars()` | `export_topline()` takes `vars`, and a column the design names is an error in both functions — sections 3.11 and 3.17 | a call naming a weight, a cluster id, a stratum, an FPC or a replicate-weight column in `vars` now aborts. Measured on a 200-row taylor design, `vars = c(q1, wt)` returns the path today and writes a second sheet named `wt` with 204 rows — one response row per distinct weight value — raising only `surveyreports_warning_missing_variable_label`. That sheet is gone |
| A2, A3, A5 | `.base_note_for()`, `.apply_role_guard()` and the classification call are shared | universe base notes, the role guard on `vars`, and the loss of 80 deprecation warnings |

**Part A's write surface in `R/export-topline.R` widens from three items to
five.** Recorded, not absorbed, the way the earlier widenings were. The five
are the `all_of()` fix, the role guard, the threaded base notes, the
design-variable check and the deletion of the dead effective-N branch.

The design-variable check is the fourth item: `.reject_design_vars()` lives in
the shared file, but the call to it is a new line in this one. The check
applies to `vars`, `export_topline()` takes `vars`, and no shim keeps it out
without leaving the documented contract false in one function and true in the
other.

The dead branch is the fifth item — decision 1, 2026-09-16. It is a removal
inside `.render_topline_single()`, and it changes no cell, because the branch
never fires. Section 2.3 names the site. Section 2.1's file table carries all
five items and section 3.11 carries the step for the fourth.

**The presentation in `R/export-topline.R` does not change.** The two
inline `round(pct * 100, decimals)` sites at `:379` and `:394` stay as they are.
`.sata_pct_cell()` and `.sata_n_cell()` also stay unchanged, and
`export_topline()` keeps calling both, so the third inline conversion at
`R/export-utils.R:745` stays as well. `.fmt_pct()` returns a string and a
topline cell is a number, so calling the formatter at any of the three would
change the presentation this section holds fixed. Section 2.3 lists all five
inline conversions and names the two that retire.

`export_topline()` has no `banner` argument, so every banner-only condition in
section III is `export_crosstab()`-only: the two label aborts, the banner role
error, and all three withholding warnings.
`surveyreports_error_design_variable_selected` is **not** in that set. It is
raised for `vars` as well as for `banner`, so both functions raise it —
sections 3.11 and 3.17.

**The pooled `Total` row of a collection keeps `NA_real_`.** `get_effective_n()`
could supply a figure — it returns one row per member — but a single pooled
number over waves with different designs is not a quantity this spec defines.
Keeping the current value is the no-change option and is deliberate.

The collection wave path takes its effective N per wave, joined on the wave name
rather than on the subgroup level. That is a separate call site from the header
join, and missing it breaks `export_topline(collection, show_eff_n = TRUE)` at
load.

### 4.2 What stays inconsistent until the topline pass

Stated here so it is a known cost and not a discovery:

| Aspect | `export_crosstab()` after this spec | `export_topline()` |
|---|---|---|
| A percentage cell | the string `41.2%` | a number |
| Sample size | two italic rows, spelled-out labels | an `N` column, and the effective N inside a header cell. The single-design route writes `%\n(Eff N=1,234)` into the percentage header. The collection wave route writes no effective N at all, and the note below this table gives the reason |
| The term | `effective sample size` | `Eff N` |
| The effective N's precision | one decimal, in the second sample-size row — section 3.4 | a whole number with a thousands separator, inside a header cell. The value is rounded to 0 decimals before it is written. `.render_topline_single()` writes it. The collection wave route writes none: this spec deletes the branch that would have written one — section 2.3 and the note below this table |
| The glossary | up to five entries. `Why a column is missing` and `Percentages` can both be true | three entries at most. Both of those are always false — topline withholds nothing and its cells are numbers — so the workbook carries the two sample-size entries, plus `Confidence intervals` under `variance = "ci"` — sections 3.15 and 4.1 |
| The `100%` row | removed under B6. The single route's `Total` row of `100%` cells goes — section 3.16 | still written. `.render_topline_single()` writes the literal string `100%` at two sites, and both stay. The first row of this table does not cover it: `100%` is a string in both workbooks, and it is the row itself that differs |
| Banner headings | variable labels | no banner |
| Small subgroups | withheld below `min_eff_n` | never withheld — a trend workbook can still publish a wave with an effective N of 60 |
| The proportion-to-percentage conversion | inside `.fmt_pct()`, one implementation | three inline `round(pct * 100, decimals)` sites — two in `R/export-topline.R`, one in `.sata_pct_cell()`, which only this function still calls — section 2.3 |
| The withheld-note writer | `.format_withheld_lines()`, naming the effective N | `.write_suppression_footnote()`, printing a raw N, a threshold and the word "suppressed" |
| A SATA item never asked | `-`, the same as an item nobody chose — section 3.3 | a blank for never asked, `0` for chosen by nobody. `.sata_pct_cell()` keeps the distinction for this function alone — section 2.3 |

Withholding is genuinely absent rather than deferred by accident: the loop runs
only when a banner is resolved, and `export_topline()` never resolves one.

**The `Total\n(Eff N=…)` form never reached a cell, and this spec deletes
the branch that would have written it.** The branch at
`R/export-topline.R:288-296` reads the pooled `Total` row's `eff_n`. That value
is `NA_real_` on every collection: `.build_freq_frame()` returns `NA_real_` for
a row whose `subgroup_type` is `"total"`, and section 4.1 keeps it that way. So
the branch never fired, and it carried no `# nocov` marker while the
single-design fallback beside it did. Measured on a collection: the `Total`
header reads `Total` alone, and each wave header reads the wave name plus
`(n=…)`, a raw count that `show_eff_n` does not switch.

**Decision (2026-09-16, decision 1): the branch goes now, not in the topline
pass.** It is one removal inside a topline render helper and it changes no
cell, so it does not reach the presentation this section holds fixed. Section
2.3 names the site and the write surface below counts it.

---

## V. Breaking changes

### 5.1 The list

| Change | Who breaks |
|---|---|
| `pub_type` removed | every `export_crosstab()` call that passes it errors on an unused argument |
| `show_n` removed | the same, and the per-response unweighted count leaves the workbook |
| `show_eff_n` renamed `show_ess`, default `FALSE` → `TRUE` | the same, and every crosstab gains a second sample-size row by default |
| `surveyreports_warning_subgroup_suppressed` renamed `_withheld` | any caller filtering on the class name |
| a design variable in `vars` or `banner` now errors | any call that names a column the design itself names. Old behavior: `vars = c(q1, wt)` wrote a sheet of weight values and warned only about the missing variable label. New behavior: `surveyreports_error_design_variable_selected`, and no workbook. A caller who relied on the old behavior removes the column from the selection — `vars = q1` — and tabulates the design column outside the export functions if the table is wanted. This reaches **both** export functions — section 4.1 |
| percentage cells become strings | any downstream read of a crosstab workbook that expects a number |
| the `100%` row removed | any downstream read keyed on the last row |
| every committed crosstab snapshot | moves |

**The deleted dead branch is not on this list either.** It never fires, so no
call's output moves — section 4.2 carries the measurement, and section 2.3
names the site. **Decision (2026-09-16, decision 1): not a breaking change.**

**The `total_label` default is not on this list.** `total_label` is new in this
spec, so changing its default from a literal to `NULL` changes no shipped call.
The heading it resolves to is the one thing a caller could see move. On a
domain-restricted design it resolves to `Total`, which is the string the
current `.total_col_group()` default already writes, so nothing moves there. On
every other design it resolves to `"Full Sample"`, and the last row of the
table above already covers that: every committed crosstab snapshot moves.
**Decision (2026-09-16, issue 66): no new breaking change.**

The package is `0.1.0.9000` and pre-1.0, so a second breaking change during the
`export_topline()` pass is affordable. That is the reasoning behind deferring
`crosstab_style()` in section 1.3 rather than taking it now.

### 5.2 The gate that has to change

v0.7.0 §IX gated on **no committed snapshot moving**. Part B moves every crosstab
snapshot, so that gate cannot survive and must not be quietly dropped.

The review procedure itself is not restated here. `testing.md` already owns it,
and it loads into every session.

What this change adds is a scope line. `export_topline()` snapshots are the
narrow case: only its `show_eff_n` snapshots on twophase and domain-restricted
designs should move. **A moved topline snapshot outside that set is a defect in
Part A's scope line**, not a snapshot to accept.

---

## VI. Costs this spec accepts

Each row is a decision with a price, recorded so a later reader does not
rediscover it as a bug.

| Cost | Why it is accepted |
|---|---|
| A percentage cell is text: no Excel Percentage format, no numeric sort, no formula, no chart from the cell | The cell must also carry a second line under `variance_display = "cell"`, and a cell holds one value. These are reading deliverables |
| The per-response unweighted count leaves the workbook | The sample-size rows answer the question that actually gets asked — is this column big enough. The count is **not** recoverable from the workbook when a variable has item nonresponse: the percentage is based on responders and the sample size counts everyone, so percent × sample size overstates by the nonresponse rate. Section 3.5 records the same gap at the floor |
| Withholding cannot be turned off without naming `min_eff_n = 0` | An analyst doing QA needs the small cells. The escape hatch is why this is an argument rather than a constant |
| The workbook records nothing about role-dropped columns | The console warning is the only trace. Whoever opens the file later cannot tell that `ald1_13_text` was requested and dropped. **Decision (2026-09-14): console only.** The cover sheet reports what the reader can see is missing — a column — and not what the caller asked for |
| Interaction cells are now withheld, so most crossed columns vanish at the default floor | A crossed cell that survives is one worth reading. The alternative is publishing a 48-person cell |
| Interaction cells that survive carry no effective N of their own in the table | The sample-size rows cover every rendered column, crossed cells included, so this cost is paid off by B2 — it was open in v0.7.0 §1.3.2 and is closed here |
| Three helpers sit in `R/export-utils.R` against the letter of `code-style.md` | Section 2.1 names the three and the reason for each |
| The proportion-to-percentage conversion has two implementations for the life of this branch | `.fmt_pct()` owns it in the crosstab render path. Three sites keep their inline `* 100` — `R/export-topline.R:379` and `:394`, and `R/export-utils.R:745` inside `.sata_pct_cell()` — because a topline cell is a number and Part A's scope line forbids changing that output. Sections 2.3 and 4.1 name all three. The topline pass retires them |
| A 41-sheet workbook has no index | The `About` sheet carries the survey metadata, the subgroups not shown and the glossary. It does not list the question sheets, and a tab reads the variable name rather than the label — section 3.8 gives that reason. A fourth cover-sheet block, one row per sheet against its variable label, would need an eighth argument on `.write_cover_sheet()`, a change to the step 16 and step 17 order of section 3.11 so the final sheet names are known before the cover sheet is written, and a condition for the stacked layout's single `"Crosstab"` sheet. `surveycore::extract_var_label()` supplies the label, so the information is available. **Decision (2026-09-16, issue 68): out of scope for this spec.** |
| `.write_suppression_footnote()` stays, and its text contradicts the withheld wording | It prints `(n=…, threshold=…)` — a raw N — and the word "suppressed", while `.format_withheld_lines()` names the effective N and the word "withheld". The three `R/export-crosstab.R` call sites go; the three `R/export-topline.R` sites keep it, so the helper and its text stay in the tree. **Decision (2026-09-15): do not retire it in this round.** Retiring it means editing the topline render helpers, which Part A's scope line excludes. The topline pass resolves it |

---

## VII. Documentation

### 7.1 Tier

`export_crosstab()` is **Tier 4 — Dispatcher**. Tier 4 requires `@details`, a
Workbook Layout section and a `@seealso` naming every function it routes to, and
forbids `@section Algorithm`.

**Neither export function currently meets that tier.** Measured 2026-09-10 and
re-measured 2026-09-16. Both files hold `@returns`, `@family`, `@seealso` and a
`@description` that names the classifier. They hold nothing else of the Tier 4
set:

| Tier 4 requirement | `export_topline()` | `export_crosstab()` |
|---|---|---|
| `@description` ends by naming what the function routes to and what selects the route | **satisfied** | **satisfied** |
| `@param` — the argument that selects a route lists every accepted value | **n/a** — no argument selects a route | **partly** — `layout` and `variance` list their values; the four new arguments of section 3.2 have no entry yet |
| `@details` route overview | **absent** | **absent** |
| `@section Workbook Layout` | **absent** | **absent** |
| `@seealso` links every routed function | links `surveycore::get_freqs()` only | links `export_topline()` |
| no `@section Algorithm` | satisfied | satisfied |
| `@returns` describes the written sheets | **present, names no sheet** | **present, names no sheet** |

The last row comes from `package-conventions.md` and not from the tier. That
rule requires an `export_*()` function's `@returns` to describe the written
file and its sheets. Both functions hold the block, and both hold one line that
names the path alone. Section 7.2 carries the required content and gate VIII
carries the check.

The first two rows were measured on 2026-09-16. Both `@description` blocks
already close by naming `surveycore::classify_question_type()` as the
classifier, so both satisfy the rule; `export_crosstab()` also names `layout`.
Both `@param layout` and `@param variance` entries already list their accepted
values with a short characterization, which is why the `@param` row reads
"partly" for that function and not "absent". Section 7.2 carries what each block
must hold.

So section 7.2 cannot be read as "edit these blocks". Two of them do not exist,
and writing them whole is a deliverable.

### 7.2 Required roxygen changes

| Function | Block | Change |
|---|---|---|
| both | `@description` | **Keep the closing sentence and correct it where it is wrong.** Tier 4 requires the block to end by naming what the function routes to and what selects the route. Both blocks do — section 7.1 measured it. State plainly what drives the routing: `surveycore::classify_question_type()` reads the resolved `vars` and returns the value that selects the render route. **No argument selects the render route.** For `export_crosstab()` keep the reference to `layout`, and say what `layout` actually chooses — the sheet arrangement, one sheet per question group or one `"Crosstab"` sheet — not the render route. For `export_topline()` drop nothing: its sentence already names the classifier and the one sheet |
| `export_crosstab()` | `@param` | Every new and changed argument of section 3.2 gets a full entry. `layout`, `min_eff_n`, `variance`, `variance_display`, `sample_size_display` and `withheld_note` each list their accepted values with a brief characterization, per the Tier 4 rule for an argument that selects a route. `layout` is the closest thing this function has to a dispatch argument: it selects between two sheet arrangements, and it must list both values. The render route is not an argument's to choose |
| `export_topline()` | `@param` | `vars` is the argument the routing reads, and it enumerates no values, because a tidy-select expression has none. So the Tier 4 list-every-value rule has no dispatch argument to apply to in this function. `@param variance` still lists its three values, as it does today. Say in `@param vars` that the question structure of the selected columns decides the block shape, and point at `@details` for the three routes |
| `export_crosstab()` | `@details` | **Write it.** Name each render route — single, SATA, battery — and what selects it. Name the role guard and the withholding step as stages that run before dispatch. Do not restate the render algorithms |
| `export_crosstab()` | `@section Workbook Layout` | **Write it.** The cover sheet, the Total column, the banner column groups, the two layouts, the sample-size rows, and the row order of section 3.16 |
| `export_crosstab()` | `@param banner` | The role rule with its own error; the two label aborts of section 3.7; that an `interactions` element naming a dropped column aborts |
| both | `@param base_notes` | The universe fallback, the unanimity rule for a group, and that a caller entry always wins |
| both | `@param vars` | The role drop and the all-dropped abort |
| both | `@param design` | Add `[surveycore::as_survey_nonprob()]` to the constructor list. Both entries name three constructors; `package-conventions.md` requires every accepted subclass, which `testing.md` puts at four |
| both | `@returns` | **Rewrite both.** Each block holds one line today and names no sheet — section 7.1. Keep `invisible(file_name)` and then describe the workbook. For `export_crosstab()`: a first sheet named `"About"` carrying its three blocks — the survey metadata, the subgroups not shown, and the glossary (section 3.14); then the question sheets as `layout` arranges them; percentage cells that are now strings (section 3.3); the two italic sample-size rows (section 3.4); the Total column, which takes the `total_label` heading and has an empty spanner (section 3.9); and the loss of both the per-response `N` column and the `100%` row (sections 3.9 and 5.1). For `export_topline()`: the one sheet named `"Topline"`, whose cells stay numbers; the new `"About"` first sheet; the corrected effective N on twophase and domain-restricted designs; and the universe base notes. That is section 4.1's list in full, and the entry adds nothing beyond it |
| `export_topline()` | `@details` | **Write it whole.** The file holds no `@details` tag, so there is nothing to edit. Cover: the three render routes — single-response, select-all-that-apply and battery; that `surveycore::classify_question_type()` returns the value which selects the route; that a select-all or a battery group renders once for the whole group, however many of its members `vars` names; that the battery route renders one sub-block per item through the single-response route; and that a `survey_collection` classifies on its first member, then renders one column per wave. Name the role guard and the base-note lookup as stages that run before dispatch. Do not restate the render algorithms. Measured, so the roxygen author needs no second pass. Every fact above sits in `R/export-topline.R`. The three render routes are `.render_topline_single()`, `.render_topline_sata()` and `.render_topline_battery()`. `export_topline()` itself holds the `surveycore::classify_question_type()` call, the collection branch on `design@surveys[[1L]]`, and the once-per-group `groups_done` vector. `.render_topline_battery()` holds the per-item call to the single-response route, and `.render_topline_single()` holds the wave branch on `any(frame$subgroup_type == "wave")`. The author documents behavior and edits no expression, so each name above is a `grep` target and carries no line number |
| `export_topline()` | `@section Workbook Layout` | **Write it whole.** The file holds no `@section` tag either. Cover the sheets first: `"About"` is sheet 1 and one sheet named `"Topline"` follows it. The `"About"` sheet carries the survey metadata block and the glossary, one metadata block per wave for a collection, and no withheld block, because `export_topline()` withholds nothing — sections 3.14 and 4.1. The `"Topline"` sheet carries one block per variable or per group. Then state the measured block row order: row 1 the question text, bold and merged across the block; row 2 an optional italic base note; then the header row; then one row per response value; then a `Total` row of `100%` cells, with the total N under `show_n`. State the header row's cells: `Response` in the label column, then the percentage header, then `N` when `show_n` is `TRUE`. The percentage header reads `%`, or `%\n(Eff N=…)` under `show_eff_n`. On the collection path the header row carries one cell per wave instead, each reading the wave name and `(n=…)`, plus a `Total` cell — section 4.2 records which form carries the effective N. State the select-all block separately: its headings are `Item`, `%` and `N`, it writes one row per item, and it writes **no** `Total` row. State the battery block: a bold merged preface row, then the single-response shape once per item, each sub-block titled with that item's variable label. Close with the two facts a crosstab reader will get wrong: the cells are numbers and not strings, and a base note comes from the caller first and from a unanimous universe second — section 3.6 |
| `export_topline()` | `@seealso` | Add `[export_crosstab()]` and keep `surveycore::get_freqs()`. The block links the frequency function alone today — section 7.1 — and Tier 4 requires a link to every function it routes to |

**`@examples` are out of scope here, and they are not correct as they stand.**
This spec changes no example: the existing ones set no metadata and no role, so
they take the unchanged path, and the only thing that moves is the printed
value, which no example asserts on. What stays wrong is the wrapper. Both
blocks sit inside `\dontrun{}`, which `package-conventions.md` forbids, and
neither is converted here. Section 1.3 records the decision to park the
conversion and names the `tempfile()` pattern that closes it.

`@references` stays absent. This spec implements no published method.

### 7.3 Why this section exists

`devtools::document()` regenerates `man/` from **unchanged** roxygen, so it
passes while the help pages describe behavior the package no longer has.
`R CMD check` raises nothing either. Without this section, no gate catches the
omission.

---

## VIII. Quality gates

Source-tree checks only. Every line is a file check or a `grep`, verifiable
without running the suite. The suite gates live with the scenarios.

- [ ] `grep -rn "compute_eff_n" R/` returns nothing — the helper and all three
      `# nocov` markers inside it are gone
- [ ] `grep -rn "pub_type" R/ man/` returns nothing
- [ ] `grep -rn "show_n" R/export-crosstab.R` returns nothing
- [ ] `grep -rn "subgroup_suppressed" R/ man/ tests/` returns nothing. The scope
      excludes `plans/`, because this section and sections 3.18 and 5.1 all name
      the old class to record the rename
- [ ] `plans/error-messages.md` holds all 6 new error classes and all 4 new
      warning classes plus the renamed one, and no longer holds
      `surveyreports_warning_subgroup_suppressed`. The edit lands **before**
      implementation
- [ ] `R/export-utils.R` holds the 15 shared helpers of section 2.1, and
      `R/export-crosstab.R` holds the 3 helpers section 2.1 assigns to it —
      `.render_block_preamble()`, `.render_block_footer()` and
      `.unique_sheet_name()` — below the exported function. No `R/utils.R` was
      created
- [ ] The PR description states why `.fmt_variance()`,
      `.write_sample_size_rows()` and `.build_withheld()` sit in
      `R/export-utils.R` with one call-site file today — section 2.1
- [ ] `grep -rn "\* 100" R/` returns three lines, across two files: two in
      `R/export-topline.R` and one in `R/export-utils.R`, inside
      `.sata_pct_cell()`. `R/export-crosstab.R` holds no inline `* 100` —
      section 2.3
- [ ] `grep -rn "design_variable_selected" R/` returns lines in
      `R/export-utils.R` only — the abort lives in `.reject_design_vars()` and
      nowhere else — and `plans/error-messages.md` holds the class
- [ ] `grep -n "phase1" R/export-utils.R` returns a line inside
      `.reject_design_vars()`. `survey_twophase` holds its column names one
      level below `@variables`, so a reader with no such line cannot see them —
      section 2.2
- [ ] `testing.md`'s "Gap to close" note under Cross-design testing is removed
- [ ] `man/export_topline.Rd` and `man/export_crosstab.Rd` are regenerated and
      tracked
- [ ] Both functions meet Tier 4 per section 7.1: each has an `@details` route
      overview and a `@section Workbook Layout`, `export_topline()`'s `@seealso`
      names `export_crosstab()`, and neither has an `@section Algorithm`
- [ ] The `\value{}` block of each generated `.Rd` names its sheets. Extract
      the block with `sed -n '/\\value{/,/^}/p' man/export_crosstab.Rd` and grep
      it for `About`; do the same on `man/export_topline.Rd` and grep for both
      `Topline` and `About`. An unchanged `@returns` is one line, names no
      sheet, and fails this check — sections 7.2 and 7.3
- [ ] `DESCRIPTION` pins `Remotes: JDenn0514/surveycore@develop` and raises the
      `surveycore` floor — section IX

### 8.1 Invariants

These must hold across all inputs, and are the checks a reviewer can apply
without reading the spec twice:

- Every rendered column has a heading, and every **banner or interaction**
  heading names a subgroup whose effective N is at or above `min_eff_n`. The
  Total column is excluded: section 3.5 keeps it and writes the workbook in
  full when the full sample itself falls below the floor.
- Every rendered percentage cell matches one of the five forms in section 3.3 —
  `-`, `0%`, the floor string, the ceiling string, or a rounded percentage. No
  cell holds a bare number.
- No estimate cell reads `100.0%`, at any `decimals`. A value below 100 takes
  the ceiling string — section 3.3.
- The two sample-size rows are present together or absent together, except that
  the second is also absent when `show_ess` is `FALSE`.
- A withheld subgroup appears in no heading, no cell and no spanner span.
- The workbook's first sheet is `"About"`. `.build_workbook()` adds it before
  any question sheet, and openxlsx2 orders sheets by insertion — section 3.14.
- Every warning path returns `invisible(file_name)` and leaves a readable file.
- No `%` appears in a sample-size cell, and no bare integer appears in an
  estimate cell.
- No call site in `export_crosstab()`'s render path multiplies an estimate by
  100, and it reaches no helper that does. `.fmt_pct()` owns the scale, and
  every variance number reaches it through `.fmt_variance()`. The scope is the
  crosstab render path alone. Three sites outside it keep their inline `* 100`
  and are the stated exceptions: `R/export-topline.R:379` and `:394`, and
  `R/export-utils.R:745` inside `.sata_pct_cell()`, which only
  `export_topline()` still calls — sections 2.3 and 4.1.
- The separator between two interval bounds is an en-dash, U+2013, with one
  space on each side. The minus sign on a negative bound is a hyphen-minus,
  U+002D — section 3.12.

---

## IX. Dependency sequencing

This spec depends on unreleased surveycore.

1. `Remotes: JDenn0514/surveycore` resolves to the GitHub default branch, `main`.
   `main` is 82 commits behind `develop` and has none of the metadata API this
   spec reads.
2. CI installs surveycore from that `Remotes:` line, so CI would test against the
   wrong version.

A1 raises the stakes: `get_effective_n()` is not on `main`, so an unpinned CI run
fails at load rather than at a subtle numeric assertion.

Required: pin `Remotes: JDenn0514/surveycore@develop` for the life of this
branch, and raise the `Imports:` floor to `surveycore (>= 1.1.0.9000)`. The
`Remotes:` entry itself must stay — `CLAUDE.md` forbids removing it or moving
surveycore to `Suggests`.

This is a development-version floor, not a permanent one. **The PR description
must say so**, so the `@develop` pin is not merged and forgotten. When surveycore
releases to `main`, drop `@develop` and set the floor to the released version in
one commit.

**Within Part B, one ordering is forced.** `.write_crosstab_headers()` gains
`label_cols`, and the battery route adopts it, **before**
`.render_block_preamble()` is extracted. The battery route writes its spanner
and heading rows inline today — section 3.16 — so a preamble extracted first
would serve two routes of three and leave the third to drift. Part A still lands
before Part B, per section X.

---

## X. Pipeline split

**recommended.**

The write surfaces separate cleanly and no two concurrent units share a file:

| Unit | Write surface |
|---|---|
| Part A, shared helpers and both functions | `R/export-utils.R`, `R/export-topline.R`, `tests/testthat/helper-test-data.R` |
| Part B, the crosstab rebuild | `R/export-crosstab.R` |
| Documentation | `man/`, roxygen blocks in both files |

Part A must land first: Part B's withholding reads `.resolve_eff_n()`, and its
cover sheet reads `.write_cover_sheet()`. The implementation plan owns the PR
map.

---

## XI. Decision provenance

Decisions carried from v0.7.0 are logged in `plans/decisions-export-metadata.md`
under the 2026-09-09 and 2026-09-10 entries. The Pass 3 methodology decisions —
the percentage-point scale, the Kish glossary wording, the rounding mode, the
ceiling string, the unclipped interval bounds and the subgroup-level floor — are
logged under 2026-09-14. The Part B decisions were settled
interactively on 12–14 September 2026 against a rendered mockup of the workbook,
and are logged under those dates.

**One 2026-09-10 decision is reversed.** That entry declared
`.design_universe()` and `.roles_of()`, because sections then in the document
used both names and introduced neither, and it raised the helper count from 8
to 10. The later rewrite removed those call sites. `.resolve_roles()` now reads
each member itself and owns the coercion rule of section 3.10, and
`.resolve_base_notes()` now reads the universe itself and owns the wave
unanimity rule of section 3.6. Each of the two helpers had one caller, so
neither earns a name. Both are gone from sections 2.1 and 2.2.

No open questions remain. Every question this spec raises is answered inside it.
