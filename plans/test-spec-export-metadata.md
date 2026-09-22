# Test-spec — export-metadata

**Status:** SPEC_READY
**Version:** 0.14.0
**Date:** 2026-09-16
**Id:** `export-metadata`
**Branch:** `feature/export-metadata`
**Standards read:** `.claude/rules/testing.md`,
`.claude/standards/function-documentation.md`

---

## Document purpose

This document is the validation contract for the metadata behavior of both
export functions and for the rebuilt output of `export_crosstab()`. It lists the
scenarios, the oracle, the fixtures, the tolerances and the gates. It describes
observable behavior only: the arguments a call receives, and the workbook or the
condition that follows.

`.claude/rules/testing.md` is authoritative for file structure, block naming,
assertion style, coverage, cross-design coverage and data generation. This
document does not restate those rules. It adds what is specific to this change.

It supersedes v0.3.0, which validated the metadata work alone against the old
crosstab output.

---

## Functions under test

| Function | Signature under test |
|---|---|
| `export_crosstab()` | `design, vars, banner, file_name, layout, interactions, min_eff_n, variance, variance_display, conf_level, sample_size_display, show_ess, decimals, show_total, total_label, na.rm, na_label, withheld_note, base_notes` |
| `export_topline()` | `design, vars, file_name, conf_level, decimals, variance, show_n, show_eff_n, base_notes` — **unchanged** |

`export_topline()` has no `banner` argument and no withholding. No banner
scenario and no withholding scenario is written against it.

`export_crosstab()` rejects a `survey_collection`. No collection scenario is
written against it.

`pub_type` and `show_n` no longer exist on `export_crosstab()`. A call passing
either must fail, and that is a scenario, not an assumption — `XE-07`.

---

## Template section coverage

`.claude/rules/testing.md` gives a section template for each test file: ten
sections for `test-export-topline.R` and twelve for `test-export-crosstab.R`.
The titles below are that file's, unchanged. Every section is either covered by
named scenarios or marked N/A with the reason. An N/A is a decision, not a gap.

### `test-export-crosstab.R`

| # | Template section | Status |
|---|---|---|
| 1 | Happy paths — a non-empty file with the expected sheet, all design types | covered — `XC-01`, `XS-01`, `XA-01`, `XA-13`, `XR-01`, `XR-02`, and the **Result structure** list |
| 2 | Multiple variables — every variable name appears in the workbook | covered — `XA-08`, `XW-09`, `XX-11` |
| 3 | Layout — per_question and stacked | covered — `XH-07`, `XX-11` |
| 4 | Banner columns — one column group per banner level, plus Total | covered — `XH-01`, `XH-02`, `XH-06`, `XH-08`, `XH-08a`, `XH-08b`, `XH-09`, `XH-09a` |
| 5 | Interactions — crossed banner variables | covered — `XH-03`, `XH-04`, `XH-05`, `XW-06`, `XW-07`, `XN-08` |
| 6 | Self-banner — a variable used as its own banner | covered — `XX-09` |
| 7 | var_type dispatch — SATA and battery blocks | covered — `XD-01` for the two block shapes, `XM-12` to `XM-15` for group survival, `XS-10` and `XC-07a` for single cells |
| 8 | Variance options — variance = NULL, "se", "ci" | covered — `XH-15` to `XH-20`, `XN-09`, `XN-10` |
| 9 | show_n and show_eff_n — the columns appear and disappear | covered, under the renamed arguments — `XS-05` for `show_ess`, `XS-08` for the removed `N` column, `XE-07` for a call still passing `show_n` |
| 10 | Suppression — pub_type = "external" and "internal", warning class | **N/A.** `pub_type` is removed, so neither mode exists to test. `XE-07` asserts the unused-argument error on a call that still passes it, and the `XW` rows carry the single `min_eff_n` floor that replaces both modes |
| 11 | Error paths — non-survey object, var not found, a collection | covered — `XE-10` (non-survey), `XE-08` (a collection), `XE-01` to `XE-15` for the rest, including `XE-12` to `XE-15` for a design column named in `vars` or in `banner`. The `var not found` case is unchanged by this work, and its existing block stays as it is |
| 12 | Numerical accuracy — cell percentages match surveycore::get_freqs() | covered — `XN-01` to `XN-10` |

### `test-export-topline.R`

| # | Template section | Status |
|---|---|---|
| 1 | Happy paths — a non-empty file with the expected sheet, all design types | covered — `TP-06`, `TP-09`, and the **Result structure** list |
| 2 | Multiple variables — every variable name appears in the workbook | covered — `TP-05`, `TP-08` |
| 3 | survey_collection wave columns — one column per wave | covered — `TC-01` to `TC-08` |
| 4 | var_type dispatch — SATA and battery blocks | covered — `TP-13` for the SATA shape, `TP-03` and `TP-04` for a battery group |
| 5 | Variance options — variance = NULL, "se", "ci" | **N/A.** This work gives `export_topline()` no presentation change, so `variance` renders exactly as it does today and no row here may assert otherwise. `TP-09` to `TP-12` hold that scope line, and `TP-06a` runs `variance = "ci"` for the one thing that does change — the glossary entry |
| 6 | show_n and show_eff_n — the columns appear and disappear | covered — `TP-10`, `TP-11` |
| 7 | Missing metadata warning — one warning listing every affected variable | **N/A.** `XV-06` covers the class and its message. This work extends the trigger to banner columns only, and `export_topline()` has no `banner` argument, so its own trigger is untouched |
| 8 | Error paths — non-survey object, var not found | covered — `TE-01`, `TE-02`, `TE-03`, `TE-04`. The `var not found` case is unchanged, as in crosstab section 11 |
| 9 | Edge cases — all-NA variable, single-row data, single-value variable | covered by the shared edge-case table — `XX-01` (single-row), `XX-03` (all-NA) and `XX-04` (single-value) each run against `export_topline()` too. The note under that table names which rows are shared and which are crosstab-only |
| 10 | Numerical accuracy — the frequency frame matches surveycore::get_freqs() | covered — `TN-01` to `TN-04` |

**Totals: 22 sections, 19 covered, 3 N/A.** Two entries a reader might expect to
be N/A are not: crosstab section 7 and topline section 4 both gained a new
scenario, because no prior row asserted a block shape.

One title above differs from the template by one phrase. The template writes
topline section 10 around the name of an internal frame builder. This document
carries no internal name, so the title reads "the frequency frame" instead. The
section is the same one.

---

## What changes in observable behavior

Every scenario below traces to one of these.

**Both functions**

1. The reported effective N follows the design's in-scope rows and the value
   labels of the grouping column.
2. A base note appears from the design's `universe` metadata when the caller
   supplies none, under a unanimity rule for a multi-variable block.
3. A column whose `role` metadata marks it non-substantive is dropped from
   `vars` or `banner`, with a warning.
4. A workbook gains an `"About"` cover sheet. On a design restricted to a
   domain the sheet carries one more row, naming the restriction and the
   in-domain row count.
5. The variable classification call no longer raises a tidyselect deprecation
   warning.
6. Naming a column the design itself names — a weight, a cluster id, a stratum,
   an FPC, a replicate weight, or a twophase subset column — in `vars` or in
   `banner` is now an error. It wrote a table of design values before.

**`export_crosstab()` only**

7. A percentage cell is a string carrying `%`, under a three-way rounding rule.
8. Two italic sample-size rows replace the per-response `N` column.
9. Every subgroup — banner level, interaction cell, missing-value level — is
   withheld when its effective N falls below `min_eff_n`.
10. Withheld subgroups are listed once, on the cover sheet.
11. Banner spanners read the variable label.
12. The Total column takes a caller-supplied heading, has no spanner, and the
    `100%` row is gone. With no heading supplied, the default follows the
    design: `Total` when it is restricted to a domain, `Full Sample`
    otherwise.
13. `na.rm = FALSE` adds a missing-value response row and a missing-value banner
    column.
14. `variance` renders in the estimate cell or on its own row, under a legend.

---

## Reference oracle

| Oracle | Compared columns | Used for |
|---|---|---|
| `surveycore::get_effective_n(design)` | `n`, `n_eff` | the full-sample row of the sample-size block |
| `surveycore::get_effective_n(design, group = <col>)` | the group column, `n`, `n_eff` | every subgroup's sample-size cells, and every withholding decision |
| `surveycore::get_freqs(design, <var>)` | the first column (the level), `pct` | the level vocabulary a workbook renders, and the estimates it renders |
| `surveycore::get_freqs(design, <var>, variance = , conf_level = )` | `se`, the interval bounds | the bracketed statistic under `variance` |
| base R `paste0()` + `round()` | — | the **expected string** for a rendered cell, built independently of the package |

The two `get_effective_n()` calls are the primary oracle. `get_freqs()` is the
secondary oracle: it fixes the vocabulary the frames must share. A level string
returned by `get_effective_n()` must match the level string `get_freqs()`
returns for the same column, compared as `as.character(level)`.

**The string oracle matters.** A rendered percentage is now text, so a numerical
assertion compares the cell against a string the test builds itself:

```r
paste0(round(pct * 100, decimals), "%")
```

Do **not** build the expected string by calling the package's own formatter.
That compares the code to a copy of its own arithmetic, and it passes while
both are wrong.

**A trailing zero is dropped, by design.** `round()` gives the shortest
correct string, so a value of 41.01 at one decimal renders `41%` and not
`41.0%`. `decimals` is therefore a **maximum** precision, not a fixed one, and
a column can hold `41%` and `32.4%` side by side. That is the contract, so a
test that expects `41.0%` is asserting the wrong thing. Build the expected
string with `round()` and the two strings agree by construction.

surveycore must supply `get_effective_n()`. A surveycore build without it fails
these tests at load, not at an assertion. Confirm the installed version before a
run.

---

## Datasets

| Source | Purpose |
|---|---|
| `make_all_designs(seed = 42)` | every design type; structure, error, warning and cross-design rows |
| `make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)` | a plain data frame, for a design built with non-default arguments |
| Package data — `anes_2024`, `gss_2024`, `ns_wave1`, `pew_jewish_2020` | not required by any row below. Real labels come from the inline fixtures instead, so the fixture and the assertion stay in one place |
| Edge case data | inline in the test block |

### The four subclasses

`.claude/rules/testing.md`, Cross-design testing, names four subclasses:
`survey_taylor`, `survey_replicate`, `survey_twophase` and `survey_nonprob`.

**Every cross-design row in this document is written against all four.**

`make_all_designs()` gains its fourth design, `nonprob`, as part of this work. A
run in which the generator returns three designs is a fail, not a partial pass:
the loops must report four. Check the count directly, so a silently short list
cannot pass a loop that iterates whatever it is given.

`survey_collection` does not inherit `survey_base`. It is not a column in the
cross-design matrix. It gets its own block, and that block applies to
`export_topline()` only.

### Inline fixtures

Build these in the test body. Do not add a parameter to `make_all_designs()` or
to `make_survey_data()`. Every design from `make_all_designs()` holds 200 rows,
so each fixture below is length 200.

**Each snippet is independent, and several rebuild the same column.** A
scenario applies only the snippets it names. So a scenario that does not name
the domain snippet runs on a design with no domain column, and a scenario that
does name it runs on a restricted one. `XH-08`, `XH-08a` and `XA-13` all turn
on that difference.

```r
# A labelled banner. The code and the label must differ, or the test proves
# nothing: a character column stores its own label.
d@data$gen <- c(rep(1, 180), rep(2, 20))
d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))
d <- surveycore::set_var_label(d, gen = "Gender")

# A partly labelled banner. Code 3 carries no label.
d@data$gen <- c(rep(1, 150), rep(2, 30), rep(3, 20))
d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2))

# Two unlabelled codes.
d@data$gen <- c(rep(1, 100), rep(2, 50), rep(3, 50))
d <- surveycore::set_val_labels(d, gen = c(Male = 1))

# A value label whose code appears in no row.
d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2, Other = 3))

# A duplicate value label: one label, two codes.
d <- surveycore::set_val_labels(d, gen = c(Male = 1, Female = 2, Female = 3))

# A second labelled banner, for the interaction rows.
d@data$reg <- c(rep(1, 120), rep(2, 80))
d <- surveycore::set_val_labels(d, reg = c(North = 1, South = 2))
d <- surveycore::set_var_label(d, reg = "Region")

# A banner with no variable label, for the missing-label warning.
d@data$nolab <- sample(c("x", "y"), 200, replace = TRUE)

# A factor banner whose level order is NOT alphabetical.
d@data$lik <- factor(
  sample(c("Low", "Medium", "High"), nrow(d@data), replace = TRUE),
  levels = c("Low", "Medium", "High")
)

# A banner with missing values, for the na.rm rows.
d@data$gen_na <- c(rep(1, 120), rep(2, 70), rep(NA, 10))
d <- surveycore::set_val_labels(d, gen_na = c(Male = 1, Female = 2))

# A variable with a response category almost nobody chose, for the
# rounding rule. One row in 200 is 0.5%; adjust until the rendered value
# sits below the decimals threshold under test.
d@data$rare <- c(rep("Agree", 199), "Prefer not to say")

# A domain-restricted design.
d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$group == "A"

# Universe, role and dataset metadata.
d <- surveycore::set_universe(d, q1 = "Asked of all respondents")
d <- surveycore::set_var_extra(d, q2 = list(role = "free_text"))
d <- surveycore::set_dataset_metadata(d, survey_name = "Test Survey")
```

**Fixture caution for the twophase design.** A column assigned into a twophase
design must reach the rows the design tabulates. If an assignment into `@data`
does not carry through for that subclass, build the frame first, then construct
the design with the same constructor arguments the generator uses. Confirm the
column is present before asserting on it.

**Fixture caution for withholding.** With the default floor of 100, a 200-row
design withholds almost every subgroup. Most happy-path rows below therefore set
`min_eff_n = 0` so the table under test is fully rendered, and the withholding
rows set it deliberately. A row that forgets this asserts on a table that is not
there.

---

## Per-function test plan

Every scenario carries an id. Read the **Designs** column as the list of design
types the scenario runs against.

### `export_crosstab`

#### Happy path — cell contents

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XC-01 | an estimate cell is a string carrying `%` | all four | `vars = q1`, `banner = group`, `min_eff_n = 0` | every estimate cell is character, and matches `^[0-9]+(\.[0-9]+)?%$` or one of the four special forms — `-`, `0%`, the floor string, the ceiling string. The decimal part is optional, because a value that rounds to a whole number drops it. **No estimate cell is numeric** | n/a |
| XC-02 | the rendered value matches the oracle | all four | the same call | each cell equals `paste0(round(pct * 100, 1), "%")` over the matching `get_freqs()` row, built in the test | exact string |
| XC-03 | `decimals` changes the rendered precision | all four | `decimals = 0`, then `2` | the same construction at `round(pct * 100, 0)` and `round(pct * 100, 2)` matches | exact string |
| XC-04 | a nonzero value that rounds to zero reads `<0.1%` | taylor | the `rare` fixture; `decimals = 1`, `min_eff_n = 0` | the cell for the rare category reads `<0.1%` | exact string |
| XC-05 | the floor string follows `decimals` | taylor | the same fixture at `decimals = 0`, then `2` | the cell reads `<1%`, then the actual rounded value, because at 2 places it no longer rounds to zero | exact string |
| XC-05a | a value below 100 that rounds to 100 reads `>99.9%` | taylor | a fixture where one category is held by all but 3 of 10,000 rows; `decimals = 1`, `min_eff_n = 0` | the cell reads `>99.9%`. **No cell in the sheet reads `100.0%`** | exact string |
| XC-05b | the ceiling string follows `decimals` | taylor | the same fixture at `decimals = 0`, then `2` | the cell reads `>99%`, then the actual rounded value, because at 2 places it no longer rounds to 100 | exact string |
| XC-06 | a true zero reads `0%` | taylor | a banner column where the question **was** answered — the `get_freqs()` rows for that column carry `n > 0` — and the estimate for one response category is exactly 0 | the cell reads `0%`, not `<0.1%` and not `-`. A true zero rounds to a whole number, so it drops its decimal like any other | exact string |
| XC-07 | a cell with no rows reads `-` | taylor | a banner column with no non-missing answers to the question, so `get_freqs()` returns **a row whose `n` is 0** | that cell reads `-`, not `0%`. Row presence alone must not drive the cell: the oracle here has a row, and the rule is `nrow(rows) > 0 && rows$n > 0`. The same value's cell in a column that has answers reads a percentage | exact string |
| XC-07a | a SATA item never asked in a subgroup also reads `-` | taylor | a SATA block where one item was never put to one banner column, beside an item that column was asked and nobody chose | **both cells read `-`.** The two are not distinguished, and no cell in the block is blank. This is the row that pins the dropped distinction, so a later implementer does not restore the blank-for-never-asked behavior | exact string |
| XC-08 | the special forms are distinguishable in one table | taylor | a fixture producing all four in the same block | the block holds `<0.1%`, `>99.9%`, `0%` and `-` in different cells, and a plain percentage elsewhere. This is the row that proves the rule separates every form rather than collapsing any pair | exact string |

#### Happy path — sample-size rows

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XS-01 | two sample-size rows are written by default | all four | `vars = q1`, `banner = group`, `min_eff_n = 0` | rows labelled `Unweighted sample size` and `Effective sample size` appear directly under the heading row, in that order | n/a |
| XS-02 | both rows are italic and smaller than the body | all four | the same call | the two label cells and their data cells carry an italic font one point smaller than an estimate cell in the same block. Read the style, not the value | n/a |
| XS-03 | the counts match the oracle | all four | the same call | each column's unweighted cell equals `get_effective_n(d, group = <banner>)$n` for that level, exactly. The effective cell equals `round(n_eff, 1)` over the same oracle row: the cell is written at one decimal, so the oracle is rounded to one decimal before the comparison. An unrounded oracle can differ from the cell by up to `0.05`, seven orders above the tolerance, and the row then fails on correct code | exact for n; 1e-8 for the rounded n_eff |
| XS-04 | the full-sample column carries the design's counts | all four | `show_total = TRUE` | the Total column's unweighted cell equals `get_effective_n(d)$n`, exactly. Its effective cell equals `round(get_effective_n(d)$n_eff, 1)`, rounded for the reason `XS-03` gives | exact for n; 1e-8 for the rounded n_eff |
| XS-05 | `show_ess = FALSE` removes only the second row | all four | `show_ess = FALSE` | the `Unweighted sample size` row is present; no row is labelled `Effective sample size` | n/a |
| XS-06 | `sample_size_display = "bottom"` moves both rows | all four | `sample_size_display = "bottom"` | both rows appear after the last estimate row and before any footnote; no sample-size row appears above the estimates | n/a |
| XS-07 | `sample_size_display = "none"` removes both | all four | `sample_size_display = "none"` | neither label appears anywhere in the sheet | n/a |
| XS-08 | no `N` column is written | all four | any call | no heading cell reads `N`, and the last data column is a banner level, not a count. `show_n` is gone — `XE-07` covers the argument itself | n/a |
| XS-09 | the counts ignore the tabulated variable | all four | a variable with 60 of 200 rows missing; `min_eff_n = 0` | the unweighted cell equals the design's in-scope row count, **not** the sum of the response rows below it. Assert the response rows total less, so the contract is visible | exact |
| XS-10 | a battery block leaves the second label column blank | all four | `vars = c(bat_1, bat_2, bat_3)` | the sample-size rows carry their label in column A and an empty cell in column B | n/a |

#### Happy path — withholding

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XW-01 | a subgroup below the floor loses its column | all four | the labelled `gen` fixture (180 Male, 20 Female); `banner = gen`, `min_eff_n = 100` | **the `Female` heading and its cells are absent from the sheet.** Assert absence, not success. A success-only assertion passes while the column is still written | n/a |
| XW-02 | the surviving column is unaffected | all four | the same call | the `Male` column's estimates equal the same call at `min_eff_n = 0` | exact string |
| XW-03 | the spanner span shrinks | all four | the same call | the `Gender` spanner spans one column, not two | n/a |
| XW-04 | `min_eff_n = 0` withholds nothing | all four | the same fixture, `min_eff_n = 0` | both columns are present; no withholding warning is raised | n/a |
| XW-05 | the floor is on effective N, not raw N | all four | a design whose weights give a subgroup a raw n above the floor and an effective N below it | the column is withheld. This is the row that proves the raw-N test is gone | n/a |
| XW-06 | an interaction cell below the floor loses its column | all four | labelled `gen` and `reg`; `interactions = list(c("gen", "reg"))`, `min_eff_n` set so some crossed cells fall below | the below-floor crossed headings are absent; the surviving ones are present. **This behavior did not exist before** | n/a |
| XW-07 | a withheld interaction cell is listed with its parents | all four | the same call | the cover sheet's withheld block names the crossed subgroup, not only the banner levels | n/a |
| XW-08 | the withheld list reports the effective N | all four | any withholding call | each line names the subgroup, its banner variable and its effective N. **The line does not report a raw N** — that was the confusion in the old footnote | n/a |
| XW-09 | withholding is reported once, not per table | all four | `vars = c(q1, q2)`, `withheld_note = "once"` | the withheld list appears on the cover sheet and appears under neither table | n/a |
| XW-10 | `withheld_note = "every"` writes it under each table | all four | the same call with `"every"` | each question block ends with the same lines; the cover sheet's withheld block is absent | n/a |
| XW-11 | `withheld_note = "none"` writes it nowhere | all four | the same call with `"none"` | no withheld line appears in any sheet. The console warning still fires — `XV-03` | n/a |
| XW-12 | a withheld column is not a blank column | all four | any withholding call | the sheet has one fewer data column than the same call at `min_eff_n = 0`. Assert the column count, so a blank-column implementation fails | n/a |
| XW-13 | a subgroup at the floor exactly stays published | all four | the labelled `gen` fixture; `banner = gen`, and `min_eff_n` set to the `Female` level's own effective N from the oracle, so the two are equal | the `Female` heading and its cells are present, and no withheld line names that level. The test is strictly less-than, so a `<=` implementation withholds the column and fails this row. Every other `XW-` row sits clear of the floor, so this is the only row that catches the boundary | n/a |

#### Happy path — headings, Total column, missing data, variance

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XH-01 | a banner spanner reads the variable label | all four | `gen` labelled `Gender`; `banner = gen` | the spanner reads `Gender`; no spanner reads `gen` | exact string |
| XH-02 | a banner with no variable label falls back to the name | all four | `banner = nolab` | the spanner reads `nolab`, and the missing-label warning fires — `XV-06` | exact string |
| XH-03 | an interaction spanner reads both labels | all four | labelled `gen` and `reg`; `interactions = list(c("gen", "reg"))` | a spanner reads `Gender × Region`; none reads `gen × reg` | exact string |
| XH-04 | interaction levels read value labels | all four | the same call | a crossed heading reads `Male × North`; none reads `1 × 1` | exact string |
| XH-05 | an interaction over a factor banner keeps its order | all four | the `lik` factor fixture crossed with `reg` | the crossed headings follow `Low`, `Medium`, `High` within each `reg` level; they are **not** sorted `High`, `Low`, `Medium` | n/a |
| XH-06 | a factor banner keeps its column order | all four | `banner = lik` | the headings read `Low`, `Medium`, `High`, in that order | n/a |
| XH-07 | sheet tabs keep the variable name | all four | `layout = "per_question"`, `vars = q1` with a long variable label | a sheet is named `q1`; no sheet is named for the label | exact string |
| XH-08 | the Total column takes `total_label` | all four | **a design with no domain column**; the default, then `total_label = "General Population"` | the heading reads `Full Sample`, then `General Population`. The `Full Sample` half holds only while the design carries no domain column, which is why the input names that condition. `XH-08a` carries the restricted case | exact string |
| XH-08a | a restricted design defaults to `Total` | all four | the domain snippet applied; `total_label` not set; `banner = gen`, `min_eff_n = 0`; then the same call on the same design without the domain column | with the domain column the heading reads `Total` and no heading reads `Full Sample`; without it the heading reads `Full Sample`. Run both and compare, so an implementation that hard-codes either string fails | exact string |
| XH-08b | a supplied `total_label` wins on a restricted design | all four | the domain snippet applied; `total_label = "Registered Voters"` | the heading reads `Registered Voters`, and it reads neither `Total` nor `Full Sample`. The restriction does not overrule the caller | exact string |
| XH-09 | the Total column has no spanner | all four | `show_total = TRUE` | the spanner cell above the Total heading is empty | n/a |
| XH-09a | `show_total = FALSE` removes the group | all four | `show_total = FALSE`, `banner = gen`, `min_eff_n = 0`; then the same call at `TRUE` | no heading reads `total_label` and none reads `Full Sample`; no column group is the total group; the sheet holds one column group fewer than the same call at `TRUE`. Compare the two column counts in the block, so an empty-column implementation fails. **Run on the single-response route alone**, and state the reason in the block description. The column groups are built before the block preamble and reach the header writer unread, so the three render routes cannot differ on this. `XM-14` states the opposite case for SATA and battery, where the routes do differ and a second row is required | n/a |
| XH-10 | no `100%` row is written | all four | any call | no cell in the sheet holds the string `100%` | n/a |
| XH-11 | `na.rm = FALSE` adds a response row | all four | a variable with missing values; `na.rm = FALSE`, `min_eff_n = 0` | a response row is labelled `No answer`; the same call at `na.rm = TRUE` has one fewer row | n/a |
| XH-12 | `na.rm = FALSE` adds a banner column | all four | `banner = gen_na`, `na.rm = FALSE`, `min_eff_n = 0` | a column heading reads `No answer` | n/a |
| XH-13 | `na_label` renames both | all four | `na.rm = FALSE`, `na_label = "Skipped"` | the response row and the banner heading both read `Skipped` | exact string |
| XH-14 | a missing-value banner column faces the floor | all four | `banner = gen_na`, `na.rm = FALSE`, `min_eff_n = 100` | the `No answer` column is absent, and the withheld list names it | n/a |
| XH-15 | `variance = "se"` writes a second line in the cell | all four | `variance = "se"`, default display | each estimate cell holds the percentage and a parenthesised value; the parenthesised value equals `paste0("(", round(se * 100, 1), "%)")` over the oracle. The `%` is required: one `%` per number | exact string |
| XH-16 | `variance = "ci"` writes the bounds | all four | `variance = "ci"` | the parenthesised value equals `paste0("(", round(ci_low * 100, 1), "% \u2013 ", round(ci_high * 100, 1), "%)")` over the oracle: one `%` per bound, and the separator is an en-dash (U+2013) with one space on each side. A hyphen-minus separator fails this row | exact string |
| XH-16a | a bound is printed as surveycore returns it, unclipped | taylor | `variance = "ci"`, `min_eff_n = 0`, and a fixture with a category held by 2 of 300 rows | the lower bound equals `round(ci_low * 100, 1)` from the oracle and **is negative** — the cell reads a negative percentage. Assert the printed value against the oracle, not against 0. A clipped implementation fails this row | exact string |
| XH-17 | `variance_display = "row"` writes its own row | all four | `variance = "se"`, `variance_display = "row"` | the sheet has twice as many estimate rows; the estimate cells hold no parenthesis | n/a |
| XH-18 | a legend row appears only under `variance` | all four | `variance = NULL`, then `"se"`, then `"ci"` | no legend row; `Percentages; standard error in parentheses.`; `Percentages; 95% confidence interval in parentheses.` | exact string |
| XH-19 | the legend names a non-default `conf_level` | all four | `variance = "ci"`, `conf_level = 0.9` | the legend names 90%, not 95% | exact string |
| XH-20 | a `-` cell carries no variance | all four | `variance = "se"` and a cell with no rows | that cell reads `-` alone, with no parenthesis | exact string |

#### Happy path — question type dispatch

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XD-01 | a SATA block and a battery block each render in their own shape | all four | one call over a SATA group, then one over a battery group; `banner = gen`, `min_eff_n = 0` | **the two block shapes differ, and each matches its own contract.** The SATA block holds one label column, headed `Item`, and one data row per item. The battery block holds two label columns, headed `Item` then `Response`, and one data row per response value within each item, so it is one column wider and has more rows than the SATA block over the same number of variables. Assert the label column count, the label headings and the row count for each block. `XS-10` asserts one cell of the battery shape and `XC-07a` one SATA cell; neither asserts the shape, so this row is not covered by either | n/a |

#### Happy path — the block row order

The rows above assert single elements of a block: `XS-01` places the two
sample-size rows under the heading row, `XH-18` asserts the legend appears only
under `variance`, `XM-01` asserts the base note. None of them asserts the whole
sequence, so a pair of rows written in the wrong order passes every one of them.

Both rows below switch on every optional element at once — a caller base note,
`variance`, `show_ess = TRUE`, and `withheld_note = "every"` over a floor that
withholds one subgroup — so the full sequence is present. They differ in
`sample_size_display` alone, which is the argument that moves rows inside a
block.

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XR-01 | the block row order under `sample_size_display = "top"` | all four | `vars = q1`, `banner = gen` on the labelled `gen` fixture (180 Male, 20 Female), `base_notes = c(q1 = "Base: all adults")`, `variance = "se"`, `show_ess = TRUE`, `withheld_note = "every"`, `min_eff_n = 100` so `Female` is withheld and `Male` survives, `layout = "per_question"` so the sheet holds one block | read column A from the block's first row through its last written row, and compare it against an expected ordered character vector: the question text, the base-note text, the legend text, one empty element for the spanner row, `Response`, `Unweighted sample size`, `Effective sample size`, then one element per response value in the oracle's order, then one element per withheld line. Assert as an **ordered character vector**, so a transposed pair fails. Build the response values from `get_freqs()` and the withheld lines from the wording `XW-08` fixes. An unwritten cell reads back as `NA` and not `""`; normalise the two before the comparison, so a blank-against-`NA` difference does not decide the row | exact string |
| XR-02 | the block row order under `sample_size_display = "bottom"` | all four | the same call at `sample_size_display = "bottom"` | the same construction with the two sample-size labels moved below the data: the question text, the base-note text, the legend text, one empty element, `Response`, then one element per response value, then `Unweighted sample size`, `Effective sample size`, then one element per withheld line. Assert as an **ordered character vector**. The two rows together pin the one argument that moves rows inside a block | exact string |

**What these two rows leave to others.** `sample_size_display = "none"` stays
with `XS-07`, which asserts that neither label appears anywhere in the sheet.
The interleaved variance rows stay with `XH-17`, which runs
`variance_display = "row"` and counts the estimate rows. Both rows above run the
default cell display, so their data rows are one per response value and the
expected vector stays readable.

#### Happy path — sheet properties

These rows read the sheet's stored presentation, not a cell value. Follow
`XS-02`: resolve the style and compare it against another cell's style in the
same workbook, rather than against a literal, wherever the workbook holds a
contrasting cell.

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XB-01 | the column widths are the stated ones | all four | `vars = q1`, `banner = gen`, `min_eff_n = 0` | the stored width of the label column is `44` and the stored width of every data column is `12`. **Compare on a rounded value.** A stored width carries a fractional offset: a width set to 44 reads back a little above it, so an exact integer comparison fails on correct code | rounded to the nearest whole number |
| XB-02 | the widths do not follow the label text | all four | two calls on the same design, one with short response labels and one with labels several times longer; nothing else differs | the two workbooks give the **same** column widths, compared column by column. This is the claim the fixed-width rule rests on: a width that followed the text would move with the labels and every committed snapshot would move with it. An auto-fit implementation fails this row and passes `XB-01` | rounded to the nearest whole number |
| XB-03 | the label column and the heading row wrap, and the heading row is taller | all four | the same call | the label column's cells and the heading row's cells resolve to a wrapping alignment; an estimate cell in the same block resolves to a non-wrapping one. The heading row's stored height is `30`; a data row in the same block carries no height of its own | n/a |
| XB-04 | the freeze pane follows `sample_size_display` | all four | `sample_size_display = "top"`, then `"bottom"` | under `"top"` the sheet carries a freeze pane, and its horizontal split sits below the last sample-size row, so the question text, the spanner, the heading row and both count rows stay in view. Under `"bottom"` the sheet carries **no** freeze pane. Assert the absence, not only the presence | n/a |

#### Happy path — the cover sheet

| Id | Scenario | Designs | Input | Expected observable result | Tolerance |
|---|---|---|---|---|---|
| XA-01 | the cover sheet is written and is first | all four | any call | a sheet named `About` exists and is sheet 1 | n/a |
| XA-02 | the cover sheet exists with no dataset metadata | all four | no metadata set | the sheet exists and carries the glossary block. **This is the change from v0.7.0**, which added no sheet in this case | n/a |
| XA-03 | every set key appears, in canonical order | all four | all six keys set | the survey block holds the six display labels in the oracle's canonical key order, each against its value. Assert as an **ordered character vector**, so a transposed pair fails | n/a |
| XA-04 | an unset key produces no row | all four | two keys set, four unset, **on a design with no domain column** | the survey block holds exactly two rows. No blank-valued row exists. The input names the domain condition because the domain row of `XA-13` would be a third row | n/a |
| XA-05 | the glossary writes only the terms that are true of the workbook | all four | `vars = q1`, `banner = group`, `min_eff_n = 50`, `variance = NULL`. The floor sits below every `group` level's effective N, so every banner column survives and the row raises no withholding warning — it is about the glossary alone | the glossary block holds **four** of the five terms, each with its text: `Unweighted sample size`, `Effective sample size (ESS)`, `Why a column is missing` and `Percentages`. `Confidence intervals` is **absent**, because `variance` is `NULL`. Assert the four texts and the one absence. The `Percentages` text now opens with a sentence on the percentage base — the people who answered that question, which can be fewer than the sample size above the table — so a run that asserts the four rounding forms alone fails | exact string |
| XA-05a | the two conditional entries flip with their arguments | all four | the same call at `min_eff_n = 0` and `variance = "ci"` | `Why a column is missing` is **absent**, and `Confidence intervals` is **present** with its text. The two sample-size terms and `Percentages` stay present, and `Percentages` carries the same longer text `XA-05` asserts. This is the row that justifies the `min_eff_n` and `variance` arguments: it differs from `XA-05` in those two alone, and exactly two entries change | exact string |
| XA-06 | the withheld block states `None` when nothing was withheld | all four | `min_eff_n = 100` on a design where every subgroup clears it | the block exists, names the minimum, and states that nothing was withheld | n/a |
| XA-07 | the withheld block is absent at `min_eff_n = 0` | all four | `min_eff_n = 0` | no withheld block; the glossary block is still present. `XA-05a` carries the absent-entry assertion for this floor, so this row does not repeat it | n/a |
| XA-13 | the domain row appears only on a restricted design | all four | the domain snippet applied, then the same call without the domain column | with the domain column the survey metadata block holds one more row, below the dataset keys. Its key reads `Restricted to`, and its value names the in-domain row count against the design's total rows. The count equals the oracle's `n` on the restricted design. Without the domain column the row is absent. Assert the presence and the absence, so a row written unconditionally fails | exact string |
| XA-08 | the written file opens on the cover sheet | all four | metadata set; `vars = c(q1, q2)` so data sheets follow | **save the file, then load it back** before asserting: the active sheet of the loaded workbook is 1. Do not read the active sheet from a workbook still in memory — nothing is set there, and the assertion would pass vacuously | n/a |
| XA-09 | a variable named `About` is suffixed | all four | a variable named `About` in `per_question` layout | the workbook holds `About` (the cover sheet) and `About_2` (the data sheet); the cover sheet still holds the glossary, proving the data block did not overwrite it | n/a |
| XA-10 | the collision check folds case | all four | a variable named `about` | the data sheet is suffixed, and the save succeeds. An exact-match implementation aborts here | n/a |
| XA-11 | two variables sharing 31 characters both get sheets | all four | two variables whose first 31 characters match | both sheets exist with distinct names. Pre-existing defect, closed by the same helper | n/a |
| XA-12 | the header row and each block heading are bold | all four | all six keys set; `min_eff_n = 100` so all three blocks have content | the two header cells `Key` and `Value` resolve to a bold font, and so does each block heading in column A. A value cell in the same block resolves to a non-bold font, which is the contrast the row rests on. Read the resolved font, not the cell text — `XS-02` gives the pattern. Assert every block heading, so a run that bolds the first and no other fails | n/a |

#### Happy path — metadata behavior shared with `export_topline()`

| Id | Scenario | Designs | Input | Expected observable result |
|---|---|---|---|---|
| XM-01 | a universe base note appears with no `base_notes` | all four | `universe` set on `q1` | a base-note row holds the universe text, **verbatim** — no `Base:` prefix is added |
| XM-02 | the caller's base note wins | all four | `base_notes = c(q1 = "Caller text")` with a universe also set | the row reads `Caller text` |
| XM-03 | a battery whose members agree prints the universe | all four | the same text on `bat_1`, `bat_2`, `bat_3` | one base-note row with that text |
| XM-04 | a battery whose members disagree prints none | all four | a different text on `bat_2` | no base-note row |
| XM-05 | a battery with one member unset prints none | all four | universe on `bat_1` and `bat_3` only | no base-note row |
| XM-06 | unanimity is judged on the survivors | all four | differing universe on `bat_2`, which is then dropped for its role; the survivors agree | the block prints the agreed universe |
| XM-07 | a SATA block prints a unanimous universe | all four | the same text on all SATA members | one base-note row |
| XM-08 | a non-substantive `vars` column is dropped | all four | `role = "free_text"` on `q2`; `vars = c(q1, q2)` | a block for `q1`, none for `q2` |
| XM-09 | each of the four non-substantive roles drops | all four | `role` in turn `weight`, `identifier`, `paradata`, `free_text` | the `q2` block is absent in all four runs |
| XM-10 | each of the three substantive roles keeps | all four | `role` in turn `item`, `demographic`, `treatment` | the `q2` block is present and no warning fires |
| XM-11 | a non-substantive `banner` column is dropped | all four | `role = "paradata"` on `reg`; `banner = c(gen, reg)` | no `Region` spanner; the `Gender` spanner is present |
| XM-12 | a battery keeps its type when 2 of 3 survive | all four | `role = "paradata"` on `bat_2` | one battery block holding `bat_1` and `bat_3`, preface intact. **Not** split into two single blocks |
| XM-13 | a battery reduced to one member becomes a single question | all four | `role = "paradata"` on `bat_2` and `bat_3` | `bat_1` renders as a single-response block **without** the preface. Assert the preface is absent |
| XM-14 | a SATA group keeps its type when 2 of 3 survive | all four | `role = "paradata"` on one SATA member | one SATA block with its preface. SATA and battery take different render paths, so this is not covered by `XM-12` |
| XM-15 | the sheet name follows the first survivor | all four | `role = "paradata"` on `bat_1`; `layout = "per_question"` | the sheet is named `bat_2` |
| XM-16 | a design with no `role` set keeps every column | all four | no `var_extra` written | every block present; no warning |
| XM-17 | the classification path raises no deprecation warning | all four | `vars = c(q1, q2)` | no `lifecycle_warning_deprecated` and no tidyselect deprecation warning |

#### Cross-design

Every row above and below runs against every design type in
`.claude/rules/testing.md`, Cross-design testing:

| Design type | Covered |
|---|---|
| `survey_taylor` | yes |
| `survey_replicate` | yes |
| `survey_twophase` | yes |
| `survey_nonprob` | yes — subject to the generator precondition above |

Loop over `names(designs)` and label every assertion with the design name, so a
failure says which design broke. A row that names one design type only is a gap.
Rows marked `taylor` in the tables above are the exception and are marked so
deliberately: each asserts a formatting rule that cannot vary by design, and each
has a companion row that does run across all four.

#### Error paths

| Id | Error class | Trigger | Pattern |
|---|---|---|---|
| XE-01 | `surveyreports_error_vars_all_dropped` | `role = "free_text"` on every column named by `vars` | `expect_error(class = )` and `expect_snapshot(error = TRUE)`. Assert the message names every dropped column and its role |
| XE-02 | `surveyreports_error_vars_all_dropped` is **not** the tidyselect class | the same input | assert the condition does not inherit `surveyreports_error_vars_empty_selection`. A caller filtering on one must not catch the other |
| XE-03 | `surveyreports_error_banner_empty_selection` | `role = "paradata"` on every column named by `banner` | dual pattern |
| XE-04 | `surveyreports_error_duplicate_value_label` | the duplicate-label fixture on a banner column | dual pattern. Assert the message names the column and the repeated label |
| XE-05 | `surveyreports_error_multiple_unlabelled_codes` | the two-unlabelled-codes fixture on a banner column | dual pattern. Assert the message names both codes |
| XE-06 | `surveyreports_error_interaction_not_in_banner` | `interactions` naming a column the role guard drops | dual pattern. This is the **re-validation** path: the same call passes the first check and must fail the second |
| XE-07 | an unused-argument error | `pub_type = "external"`, then `show_n = FALSE` | `expect_error()`. Both arguments are gone, and a call passing either must not silently succeed |
| XE-08 | `surveyreports_error_collection_not_supported_for_crosstab` | a `survey_collection` as `design` | `expect_error(class = )` only — the message is snapshotted elsewhere |
| XE-09 | `surveyreports_error_empty_domain` | the domain column `FALSE` for every row | dual pattern |
| XE-10 | `surveyreports_error_not_survey_object` | a plain data frame as `design` | `expect_error(class = )` only |
| XE-11 | `surveyreports_error_invalid_min_eff_n` | five inputs, one per run: `min_eff_n = -5`, then `NA`, then `Inf`, then `c(50, 100)`, then `"100"` | dual pattern. Snapshot the message once; assert the class on all five inputs. Each must abort — none may silently withhold, recycle, compare as a string, or treat `Inf` as a floor that no subgroup clears. `Inf` is the input a guard is most likely to miss, because `Inf >= 0` is `TRUE`. It aborts before any workbook is written, so it never reaches a degenerate render |

| XE-12 | `surveyreports_error_design_variable_selected` | the design's weight column named in `vars` — `vars = c(q1, wt)` | `expect_error(class = )` and `expect_snapshot(error = TRUE)`. Assert the message names the column and the argument `vars`. Assert no file is written. **Runs against every design the generator returns**, because every subclass names a weight column and the twophase design holds it one level down |
| XE-13 | `surveyreports_error_design_variable_selected` | the design's stratum column, then its cluster id column, named in `vars` — one run each | `expect_error(class = )` only; `XE-12` snapshots the `vars` wording. Runs on the taylor design, which is the design that sets both |
| XE-14 | `surveyreports_error_design_variable_selected` on `banner` | the design's weight column named in `banner` | `expect_error(class = )` and `expect_snapshot(error = TRUE)`. **Its own snapshot**, on the rule under **Assertion conventions** for a class whose message names the argument it was raised for: the `banner` wording is different text from the `vars` wording `XE-12` pins. Runs against every design the generator returns |
| XE-15 | `surveyreports_error_design_variable_selected` on a subclass-only slot | one of the replicate design's ten replicate-weight columns named in `vars`; then the twophase design's subset column named in `vars` | `expect_error(class = )` only, one run per design. These are the two cases the broad scope adds: neither column is a weight, a stratum or a cluster id, and a reader that takes `@variables` as a flat list of column names finds neither |

**`XE-12` to `XE-15` are the design-variable rows, and they run before the role
guard.** A column may be a design column and also carry `role = "weight"`; the
error still wins. Set no role in these fixtures, so the scenario proves the
design read and not the role table.

**Cross-design coverage of the design-variable rows.** `XE-12` and `XE-14` loop
`names(designs)` and label every assertion with the design name. `XE-13` runs on
taylor alone, because the other subclasses set no stratum and no cluster id, and
`XE-15` runs on replicate and on twophase alone, for the same reason. Together
the four rows reach every slot that holds a column name.
**`survey_nonprob` cannot be exercised yet.** `make_all_designs()` returns
taylor, replicate and twophase only, which is the gap
`.claude/rules/testing.md` records. When the generator gains a nonprob design,
`XE-12` and `XE-14` pick it up with no edit, because both loop the generator's
names.

`XE-04` and `XE-05` must be triggered on a **surviving** banner column. A fixture
that also gives the column a non-substantive role tests the wrong order: the
guard drops it first and no label error fires.

#### Warning paths

Capture the result from the return value:
`expect_warning(result <- export_crosstab(...), class = ...)`. A warning must not
stop the write, so assert the file exists and the return value is the path.

Every class below is user-facing, so the dual pattern of **Assertion
conventions** applies: the class assertion and one snapshot of the message. The
snapshot is taken once per class, on the row marked **dual pattern**. A second
row on the same class asserts the class alone.

| Id | Warning class | Trigger | Expected |
|---|---|---|---|
| XV-01 | `surveyreports_warning_role_dropped` | `role = "free_text"` on `q2` | one warning per argument, naming every dropped column and its role; the file is written. Dual pattern |
| XV-02 | `surveyreports_warning_role_dropped` on `banner` | `role = "paradata"` on one of two banner columns | a separate warning naming `banner`, not `vars`. **Dual pattern, with its own snapshot.** The guard names the argument in the message, so the `banner` wording is different text from the `vars` wording `XV-01` snapshots. Nothing else pins it |
| XV-03 | `surveyreports_warning_subgroup_withheld` | the labelled `gen` fixture at `min_eff_n = 100` | one warning per call, naming each withheld subgroup and its effective N. Fires even at `withheld_note = "none"`. Dual pattern |
| XV-04 | `surveyreports_warning_banner_all_withheld` | `min_eff_n` above every subgroup's effective N | one warning naming each emptied column group; the workbook is still written and holds the Total column alone. **No abort.** Dual pattern — the class is new, so the snapshot is its first |
| XV-05 | `surveyreports_warning_full_sample_below_min` | a design whose own effective N is below `min_eff_n` | one warning; the workbook is written in full, with every column. Dual pattern — the class is new, so the snapshot is its first |
| XV-06 | `surveyreports_warning_missing_variable_label` | `banner = nolab` | one warning naming the banner column. The trigger is **extended** to banner columns by this change, so the message names a banner column for the first time. Dual pattern, on the banner trigger |
| XV-07 | `surveyreports_warning_unknown_role` | `role = "curiosity"` on `q2` | one warning naming the column and the value; the `q2` block is present. Dual pattern |
| XV-08 | `surveyreports_warning_unknown_role` | `role = c("item", "demographic")` on `q2` | one warning; no abort; the block is present |
| XV-09 | `surveyreports_warning_unknown_role` | `role = 3L` on `q2` | one warning; no abort; the block is present |
| XV-10 | `surveyreports_warning_subgroup_suppressed` no longer exists | the withholding call of `XV-03` | assert the raised condition does **not** inherit the old class. The rename must be complete |
| XV-11 | warning order is fixed | a call raising a role drop, a missing label and a withholding at once | the conditions arrive in the contract's order: role dropped, unknown role, missing label, subgroup withheld, banner all withheld, full sample below minimum. Collect the classes in order and compare as a character vector |
| XV-12 | none raised | a design with `role` unset everywhere and every subgroup above the floor | neither role warning nor any withholding warning fires |
| XV-13 | none raised | a design whose weights put one group's effective N below 30 | no `surveycore_warning_small_cell` reaches the caller. Use `expect_no_warning()` on that class |

#### Edge cases

| Id | Case | Input | Expected behavior |
|---|---|---|---|
| XX-01 | single-row design | a design built from one row; `min_eff_n = 0` | the call succeeds; the unweighted sample size is `1` |
| XX-02 | single-row design at the default floor | the same design, default `min_eff_n` | every subgroup is withheld; `banner_all_withheld` and `full_sample_below_min` both fire; the file is written |
| XX-03 | all-NA variable | `vars = all_na_var`, `min_eff_n = 0` | the call succeeds; the sample-size rows report the design's in-scope rows, not `0` |
| XX-04 | single-value variable | `d@data$constant <- "Agree"` | one response row; the sample-size rows are unchanged against another variable on the same design |
| XX-06 | unused factor level on the banner | a factor banner with a level held by no row | no column for that level, and no withheld-list entry for it — surveycore drops it before the floor applies |
| XX-07 | unobserved value label on the banner | `Other = 3` with no row holding code 3 | no column, no withheld entry, no mention anywhere |
| XX-08 | exactly one unlabelled observed code | the partly labelled `gen` fixture | the unlabelled code is a real subgroup with its true unweighted count; at `min_eff_n = 100` it is withheld and the list names it as a missing label rather than as code `3` |
| XX-09 | self-banner | a variable named in both `vars` and `banner` | that banner column is skipped for that variable; unchanged |
| XX-10 | empty domain with a role-dropped column | the domain `FALSE` everywhere **and** `role = "free_text"` on one `vars` column | `surveyreports_error_empty_domain` fires. **No role warning is raised first.** The domain check always wins |
| XX-11 | `stacked` layout | `layout = "stacked"`, `vars = c(q1, q2)` | one `Crosstab` sheet plus the cover sheet; the two blocks are separated by one blank row; the second block's sample-size rows sit under its own heading row |
| XX-12 | a variable with missing values | 60 of 200 rows missing on `q1` | the response rows total less than the sample size above them, and the call raises no warning about it. The stated contract |
| XX-13 | zero data columns | `show_total = FALSE` with `min_eff_n` above every subgroup's effective N | the block holds **no data column**. Assert three things. First, no cell to the right of the label column holds a value, on every written row. Second, column A holds, in order: the question text, a blank cell for the spanner row, `Response`, `Unweighted sample size`, `Effective sample size`, then one response label per value of `q1` — the default `sample_size_display = "top"`, with no base note and no variance legend, so rows 2 and 3 of the block are absent. Third, the file opens and the return value is the path. Two warnings fire, and both are true: `banner_all_withheld`, and `subgroup_withheld` because subgroups fell below the floor. Assert both classes. Assert that no third warning arrives, since no class describes the empty block itself |

**Three of these rows run against both functions.** `XX-01` (a single-row
design), `XX-03` (an all-NA variable) and `XX-04` (a single-value variable) turn
on the design and the variable, not on a banner, so each one runs against
`export_topline()` as well as `export_crosstab()`. Loop the two functions, or
write the block twice, and label each assertion with the function name.

The rest belong to `export_crosstab()` alone: `XX-02`, `XX-06`, `XX-07`,
`XX-08`, `XX-09`, `XX-11` and `XX-13` are banner, withholding or layout cases,
and `XX-12` reads the sample-size rows, which `export_topline()` does not
write. `XX-13` turns on `show_total`, which `export_topline()` does not take.
`XX-10`'s topline companion is `TE-03`.

**Zero-weight rows have no scenario, and cannot have one.** A zero-weight row
cannot reach either export function. surveycore's constructor rejects a
non-positive weight and aborts with class
`surveycore_error_weights_nonpositive`. Measured on surveycore `1.1.0.9000`:
one weight of `0` in 20 rows aborts with "Weight column w has 1 non-positive
value(s). All non-NA weights must be strictly greater than 0." The case is
covered upstream, so no scenario here can build the fixture. The id `XX-05` is
retired and left vacant; no later row takes the number.


#### Result structure

Assert all of this before any numerical check, in every block:

- `withVisible(export_crosstab(...))` gives `visible = FALSE`, and `value`
  identical to the `file_name` argument.
- `file.exists(file_name)` is `TRUE` and the file size is above `0`.
- The workbook loads, and its first sheet is named `About`.
- In `per_question` layout, one sheet exists per surviving question group.
- In `stacked` layout, exactly two sheets exist: `About` and `Crosstab`.
- Every estimate cell is character.
- Every sample-size cell is numeric, and no sample-size cell holds a `%`.
- Cell values are compared with `expect_identical()` when they are text and
  `expect_equal()` when they are numeric.

#### Numerical accuracy

Tag every description `[numerical]`. Compare against the oracle, never against a
re-derivation of the Kish formula, and never against the package's own
formatter.

| Id | Estimand | Designs | Comparison | Tolerance |
|---|---|---|---|---|
| XN-01 | the full-sample unweighted count | all four | equals `get_effective_n(d)$n`, compared as integers | exact |
| XN-02 | the full-sample effective N | all four | equals `round(get_effective_n(d)$n_eff, 1)`. The cell is written at one decimal, so the oracle is rounded to one decimal before the comparison | 1e-8 against the rounded value |
| XN-03 | a subgroup's two counts | all four | the unweighted cell equals `get_effective_n(d, group = <banner>)$n` for the matching level, exactly. The effective cell equals `round(n_eff, 1)` for that same level | exact for n; 1e-8 against the rounded n_eff |
| XN-04 | the counts against the design's in-scope rows | all four | the unweighted count equals the number of rows the design tabulates. For the twophase design that is the phase-2 subset — 119 rows at `seed = 42` — not `nrow(d@data)`. Compute the expected count from the design in the test rather than hard-coding it for the other types | exact |
| XN-05 | the counts on a domain-restricted design | all four | the unweighted count equals the in-domain row count. Do **not** compare against the tabulated variable's N | exact |
| XN-06 | a Total-column estimate | all four | the cell equals `paste0(round(pct * 100, 1), "%")` over `get_freqs(d, q1)` for the matching level | exact string |
| XN-07 | a banner-column estimate | all four | the cell equals the same construction over `get_freqs(d, q1, group = <banner>)` for the matching level and column | exact string |
| XN-08 | an interaction-cell estimate | all four | the same, over the crossed grouping | exact string |
| XN-09 | the standard error in a cell | all four | the parenthesised value equals `paste0("(", round(se * 100, 1), "%)")` over the oracle's `se`. The `%` is required: one `%` per number | exact string |
| XN-10 | the interval bounds in a cell | all four | the parenthesised value equals `paste0("(", round(ci_low * 100, 1), "% \u2013 ", round(ci_high * 100, 1), "%)")` over the oracle: one `%` per bound, and the separator is an en-dash (U+2013) with one space on each side | exact string |

`XN-04` is the row that guards the twophase defect: an effective N above the raw
N of the table it labels. `XN-05` is the same guard for a domain-restricted
design.

---

### `export_topline`

`export_topline()` receives the metadata change and **no presentation change**.
Every row below asserts that boundary as much as it asserts the behavior.

#### Happy path

| Id | Scenario | Designs | Input | Expected observable result |
|---|---|---|---|---|
| TP-01 | a universe base note appears | all four | `universe` on `q1`, `base_notes = NULL` | a base-note row holds the universe text verbatim |
| TP-02 | the caller's note wins | all four | both sources set | the row reads the caller's text |
| TP-03 | a battery whose members agree prints the universe | all four | the same text on all three | one base-note row |
| TP-04 | a battery whose members disagree prints none | all four | a differing text on `bat_2` | no base-note row |
| TP-05 | a non-substantive `vars` column is dropped | all four | `role = "free_text"` on `q2` | a block for `q1`, none for `q2` |
| TP-06 | the cover sheet appears, with a topline glossary | all four | any call at `variance = NULL` | a sheet named `About` exists and is sheet 1, carrying the glossary. The glossary holds `Unweighted sample size` and `Effective sample size (ESS)`, and holds **neither** `Why a column is missing` **nor** `Percentages`. Assert both absences: a topline workbook withholds nothing and its cells are numbers, so both entries would be false |
| TP-06a | a topline glossary gains the interval entry under `variance` | all four | the same call at `variance = "ci"` | `Confidence intervals` is **present** with its text. The two absences of `TP-06` still hold. A topline workbook therefore carries two glossary entries or three, never more |
| TP-07 | the cover sheet carries no withheld block | all four | any call | no withheld block. `export_topline()` withholds nothing |
| TP-08 | the classification path raises no deprecation warning | all four | `vars = c(q1, q2)` | no tidyselect deprecation warning |
| TP-09 | **the percentage cells stay numeric** | all four | `vars = q1` | every estimate cell is numeric. This asserts the scope line: Part B did not leak |
| TP-10 | **the `N` column is still written** | all four | `show_n = TRUE` | a heading cell reads `N`. The topline layout is unchanged |
| TP-11 | **the effective N stays in the header** | all four | `show_eff_n = TRUE` | the percentage column's header holds the effective N as header text; no sample-size row exists. `TN-01` fixes the header's exact form |
| TP-12 | no subgroup is ever withheld | all four | a design with a tiny subgroup | no withholding warning of any class fires |
| TP-13 | a SATA block renders in its own shape | all four | `vars` naming the three SATA members; `base_notes = NULL` | one SATA block, with its preface and one data row per item. The block is **not** three single-response blocks, and its label column is not the battery pair of `Item` and `Response`. `TP-03` and `TP-04` run a battery group and assert its base note, not its shape, so the SATA route has no other row |

`TP-09` to `TP-12` are the scope-boundary rows. They fail if the crosstab
rebuild reaches shared render code it should not.

#### Collection path — `export_topline()` only

Build a two-wave collection from designs made by `make_all_designs(seed = 42)`
and `make_all_designs(seed = 7)`.

| Id | Scenario | Input | Expected observable result |
|---|---|---|---|
| TC-01 | a collection with universe metadata does not abort | `universe` on `q1` in both waves | the call returns the path; the file exists; a base-note row appears |
| TC-02 | differing universes across waves print none | a different text in wave 2 | the call succeeds; no base-note row for `q1` |
| TC-03 | the role guard on a collection does not abort | `role = "item"` on `q1` in both waves | the call returns the path; both blocks present |
| TC-04 | a role differing between waves keeps the column | `role = "paradata"` in wave 1 only | the `q2` block is present |
| TC-05 | dataset metadata writes one block per wave | four or more keys set in each wave | the `About` sheet holds a header row, then one block per wave in `@surveys` order: the wave name alone in column A, then that wave's set keys, then one blank row; none after the last. Assert each wave's labels as an **ordered character vector** |
| TC-06 | a wave with no keys still gets a heading | metadata in wave 1 only | the wave 2 heading is present, bold, with no rows under it |
| TC-07 | a collection with no metadata still gets the sheet | no metadata written | the `About` sheet exists and carries the glossary. **Changed from v0.3.0**, where no sheet was written |
| TC-08 | `show_eff_n` on a collection does not abort | `show_eff_n = TRUE` | the call returns the path and the file exists. The per-wave effective N is computed on a different join from the single-design one, so a missing branch aborts here and nowhere else. No workbook cell reports that value, which is what `TN-03` asserts, so this row asserts the call and not a cell |

**TC-01, TC-03 and TC-05 are the three highest-value rows in this document.
Write them first.** Each gates a metadata read that aborts on a collection. A
call that reaches one without a branch aborts, so these three turn a silent
regression in every trend workbook into a test failure.

#### Error and warning paths

| Id | Class | Trigger | Pattern |
|---|---|---|---|
| TE-01 | `surveyreports_error_vars_all_dropped` | every `vars` column non-substantive | dual pattern |
| TE-02 | `surveyreports_error_not_survey_object` | a plain data frame | `expect_error(class = )` only |
| TE-03 | `surveyreports_error_empty_domain` | the domain `FALSE` for every row **and** `role = "free_text"` on one `vars` column | dual pattern. **No role warning is raised first** — the domain check always wins. The topline companion to `XX-10` |
| TE-04 | `surveyreports_error_design_variable_selected` | the design's weight column named in `vars` — `vars = c(q1, wt)` | `expect_error(class = )` only; `XE-12` snapshots this class for the `vars` wording, and both functions raise the same text for the same argument. Assert no file is written. Runs against every design the generator returns. This row is the one that proves the error reaches `export_topline()`: the function takes `vars`, so the check applies to it |
| TW-01 | `surveyreports_warning_role_dropped` | `role = "free_text"` on `q2` | `expect_warning(class = )` only; the file is still written. `XV-01` snapshots this class. Both functions run the same guard on `vars`, so the two messages are the same text and a second snapshot adds a file without adding coverage |
| TW-02 | `surveyreports_warning_unknown_role` | `role = "curiosity"` on `q2` | `expect_warning(class = )` only; the block is present. `XV-07` snapshots this class, for the reason `TW-01` gives |

#### Numerical accuracy

| Id | Estimand | Designs | Comparison | Tolerance |
|---|---|---|---|---|
| TN-01 | the reported effective N | all four | the effective N sits inside the **percentage column's header cell** as text, not in a cell of its own. The header reads `%`, a line break, then `(Eff N=`, the number, then `)`. The number is a **whole number** with a thousands separator. Build the expected header string in the test from `round(get_effective_n(d)$n_eff)` and compare the header text exactly. A one-decimal oracle fails this row. A single design writes **no Total column**, so no header cell reads `Total`: that word appears only as the label of the final `100%` row. A row written against a `Total` header asserts a cell this route does not write | exact string |
| TN-02 | the reported N against in-scope rows | all four | equals the rows the design tabulates — the phase-2 subset for twophase, the in-domain rows for a domain-restricted design | exact |
| TN-03 | the per-wave header count | collection | **no header on a collection carries an effective N.** Each wave's header reads the wave name, a line break, `(n=`, a count, then `)`. The count is that wave's unweighted response count for the tabulated variable, so build it from `sum(get_freqs(<that member>, q1)$n)` and compare the header text exactly, wave by wave. It is a whole number with a thousands separator, and it is written whether or not `show_eff_n` is set. The `Total` column's header reads `Total` alone, because the pooled Total has no effective N to write. This row was written against the `Eff N` form and is corrected here against the measurement. The code path that would have written an effective N into the `Total` header is removed by this work, so the row asserts shipped behavior and not an unreachable path | exact string |
| TN-04 | frequencies are unchanged | all four | the rendered percentages equal `round(pct * 100, decimals)` over `get_freqs(d, q1)` for the matching level, compared **as numbers**. Two corrections to the obvious oracle: the cell holds percentage points, not a proportion, and the cell is already rounded to `decimals`. Run the row at the default `decimals = 1L`, so both sides are rounded to one decimal and the tolerance keeps its meaning | 1e-10 against the rounded value |

`TN-04` is the topline companion to `XN-06` and it compares numbers, not
strings. That difference is the scope line, asserted.

---

## Tolerances

| Estimand | Tolerance |
|---|---|
| Point estimates (proportion, mean, total) | `1e-10` |
| SE / variance | `1e-8` |
| CI bounds | `1e-6` |
| Effective N | `1e-8` — an SE-class quantity, not a point estimate |
| Unweighted counts | exact — integers |
| Rendered cell text | exact string |

**Deviations:** none. Effective N is listed under the SE tolerance rather than
the point-estimate tolerance because it is a variance-derived quantity; that is
a classification, not a loosening.

Rendered text is compared exactly because a string comparison has no tolerance
to relax. Where a rounded cell could sit on a boundary, the fixture is chosen so
it does not — a fixture that lands exactly on `0.05` at one decimal is a fixture
bug, not a tolerance question.

**A rounded cell is compared against a rounded oracle.** Where a workbook cell
is written at a fixed precision, the scenario rounds the oracle to that same
precision first, and the tolerance above then applies to the rounded pair.
`XS-03`, `XS-04`, `XN-02`, `XN-03` and `TN-04` do this; `TN-01` and `TN-03`
round to a whole number and compare the header text exactly. `TN-01` rounds an
effective N; `TN-03` sums integer counts, so its oracle needs no rounding. A tolerance is
never widened to absorb the rounding. The effective sample size measures
`184.979064` on the taylor design at `seed = 42` and the one-decimal cell holds
`185.0`, a gap of `0.0209`. That gap is seven orders above the `1e-8`
tolerance, so an unrounded oracle fails the row on correct code.

---

## Assertion conventions

- Structural (names, character vectors, column presence, `NULL`/`NA`):
  `expect_identical()`
- Numeric (proportions, estimates, SEs, effective N): `expect_equal()` with the
  tolerance above
- Rendered cell text: `expect_identical()`
- Errors: the dual pattern — `expect_error(class = )` **and**
  `expect_snapshot(error = TRUE)`
- Warnings: the dual pattern — `expect_warning(result <- ..., class = ...)`
  **and** `expect_snapshot()` of the message. Then assert the file exists and
  the return value is the path
- No `withCallingHandlers()` and no `tryCatch()` in tests

**Snapshot once per class, for an error and for a warning alike.** A second
scenario raising a class another scenario already snapshotted asserts the class
alone and says where the snapshot lives. A warning message is user-facing text,
so a class with no snapshot ships with nothing pinning its wording.

**One exception: a class whose message names the argument it was raised for.**
That class has one wording per argument, and the rule is one snapshot per
wording. `XV-01` and `XV-02` are the pair — the same class, raised for `vars`
and for `banner`, two texts, two snapshots. `TW-01` is the other side of the
same test: both functions raise that class for `vars`, the text is the same, and
the second scenario asserts the class alone.

**Where the warning form comes from.** `.claude/rules/testing.md` defines the
dual pattern for errors only. Its warning section gives the class assertion and
the file-still-written assertion, and it snapshots no warning. No warning
snapshot exists in the tree today: all three files under
`tests/testthat/_snaps/` hold error blocks. The warning form above is therefore
stated in this document. The repo rule needs the same addition, and that edit
is a separate change — this document does not make it.

**Snapshot handling for this change.** Every committed crosstab snapshot moves.
That is expected, not a failure. `testing.md` owns the review procedure and
loads into every session, so this document does not restate it.

---

## Profile gates

The tester runs all of these unless a skip condition applies.

- [ ] `devtools::document()` — `NAMESPACE` and `man/` unchanged after the run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD build`
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — site builds
- [ ] `covr::package_coverage()` — 95% floor, 98% target, no uncovered new lines
- [ ] `air format --check .` — every R file already formatted
- [ ] The warning count from `devtools::test()` has dropped from 88 to 8 or
      fewer. The deprecation fix removes 80 of them, and a count that has not
      moved means the fix did not land at both call sites
- [ ] `make_all_designs()` returns four designs. Assert the count, not the loop
