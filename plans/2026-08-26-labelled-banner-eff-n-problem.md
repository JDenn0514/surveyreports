# Problem: labelled banner columns break `eff_n` and suppression

**Date:** 2026-08-26
**Status:** Problem statement — ready for `/spec-workflow`
**Tier:** 2 (plan only). The defect is confirmed; the approach needs a decision.
**Scope:** `R/export-utils.R` and its tests. No change to `export_topline()` or
`export_crosstab()` signatures.

---

## Summary

`export_crosstab()` fails, or silently produces wrong output, when a banner
column is `haven_labelled`. This is the normal shape of our data: every
dataset in `adldata` reads through `haven::read_sav()`, so categorical
columns arrive as `haven_labelled` with numeric codes and value labels.

Two symptoms, one shared cause:

| Option | Symptom |
|---|---|
| `show_eff_n = TRUE` | Hard error from `vctrs` |
| `pub_type = "external"` or `"internal"` | Hard error from `vctrs`; if the error is bypassed, suppression silently does nothing |

Everything else works. With a character or factor banner all paths pass.

---

## Reproduction

```r
library(adldata)
library(haven)                     # see "Out of scope" below
d <- surveycore::as_survey(aaa_ipsos, weights = wts)

surveyreports::export_crosstab(
  d,
  vars = q901,
  banner = ppgender,
  show_eff_n = TRUE,
  file_name = "x.xlsx"
)
#> Error: Can't combine `x` <character> and `y` <double>.
```

The same call with a character banner succeeds:

```r
aa <- aaa_ipsos
aa$gender_chr <- as.character(haven::as_factor(aa$ppgender))
d2 <- surveycore::as_survey(aa, weights = wts)

surveyreports::export_crosstab(
  d2,
  vars = q901,
  banner = gender_chr,
  show_eff_n = TRUE,
  file_name = "ok.xlsx"
)
#> works
```

Verified against `aaa_ipsos` and `jrp_bsg` on 2026-08-25.

---

## Root cause

`.compute_eff_n()` subsets rows by comparing a banner column to a level
string.

`R/export-utils.R:145`

```r
data <- data[data[[col]] == level, , drop = FALSE]
```

Its two callers disagree about what `level` is, and neither one matches what
`@data` actually holds.

| Caller | Line | Passes as `level` | `@data` holds |
|---|---|---|---|
| `show_eff_n` path | `R/export-utils.R:518` | `"Male"` — the value label | `1`, `2` |
| suppression path | `R/export-utils.R:421` | `"1"` — the code, as character | `1`, `2` |

### Defect 1 — type error

`level` is always `character`. `data[[col]]` is a `haven_labelled` double.
`vctrs` refuses to compare those two types, so the call aborts before any
arithmetic happens.

### Defect 2 — identity mismatch, silent

Even with the types aligned, the two vocabularies never meet:

```
codes in @data:            "1" | "2"
labels from get_freqs():   "Male" | "Female"
intersect():               empty
```

Two consequences:

1. `.compute_eff_n()` filters to zero rows, so `eff_n` is computed from an
   empty subset.
2. The suppression filter at `R/export-utils.R:490`,
   `r[!r$subgroup_value %in% sup_vals, ]`, compares labels against codes.
   Nothing ever matches, so suppression is a no-op. A subgroup that should be
   withheld is published instead.

Defect 2 is the more serious of the two. Defect 1 is loud. Defect 2 is
silent, and it disables a publication-suppression control.

---

## Why the current tests miss this

`make_all_designs()` builds group columns as character and factor. For those
types the code and the label are the same string, so both defects are
invisible. Line coverage stays high while the behaviour is wrong.

Any fix must add a fixture with a `haven_labelled` banner — numeric codes
plus value labels, where the code and the label differ.

---

## The metadata needed is already available

No `surveycore` change is required. `@metadata@value_labels` gives a named
vector whose names are labels and whose values are codes:

```r
d@metadata@value_labels[["ppgender"]]
#>   Male Female
#>      1      2
```

`surveycore::meta(result)$group$ppgender$value_labels` carries the same
mapping for a banner variable.

---

## Proposed direction

Two changes in `R/export-utils.R`. Both are contained. Nothing outside this
file reads `suppressed$subgroup_value`.

1. **Canonicalize on labels.** Make the suppression loop
   (`R/export-utils.R:415-445`) store the value label in
   `suppressed$subgroup_value`, not the code. The filter at line 490 then
   compares labels against labels and starts working.

2. **Translate and strip inside `.compute_eff_n()`.** Look `level` up in
   `@metadata@value_labels[[col]]` to recover the code. When there is no
   match, use `level` unchanged — character and factor banners carry no value
   labels and must keep working. Compare against `as.vector(data[[col]])` so
   the class is gone before `==` runs.

Stripping the class in step 2 makes this path independent of the
`haven`-loading problem described under "Out of scope". That is deliberate.

### Decision for the spec

Canonicalizing on labels is the recommendation, because labels are what the
frequency frame already carries and what the workbook renders. The
alternative — canonicalize on codes and convert at render time — would need a
second translation at every call site. Confirm the choice before
implementation.

### Open question

Should a duplicate label across two codes be an error or a warning? A
label-keyed lookup is ambiguous when a vendor reuses one label for two codes.
This has not been observed in `adldata`, but the spec should state the rule
rather than leave it to `[[` returning the first match.

---

## Acceptance criteria

- `export_crosstab()` with `show_eff_n = TRUE` and a `haven_labelled` banner
  returns a workbook, and the reported `eff_n` equals the value computed from
  the correct row subset.
- `export_crosstab()` with `pub_type = "external"` and a `haven_labelled`
  banner actually removes the small subgroup from the rendered table.
- Character and factor banners keep their current behaviour unchanged.
- The `haven_labelled` path works whether or not `haven` is loaded.
- Coverage stays at or above the 98% floor.

## Test requirements

- A new fixture with a `haven_labelled` banner where codes and labels differ.
  Build it inline, per `.claude/rules/testing.md`. Do not add a parameter to
  `make_all_designs()`.
- Cross-design coverage: all three design types.
- A regression test asserting suppression removes rows, not merely that the
  call succeeds. The old bug passed a success-only assertion.
- No new error classes are expected. If the duplicate-label question above
  resolves to an error, add the class to `plans/error-messages.md` first.

---

## Out of scope

**`surveycore` issue #175 — `haven_labelled` failures upstream.**
Filed 2026-08-25 at `JDenn0514/surveycore#175`. Several `surveycore`
functions (`get_freqs()`, `get_means()`, `get_quantiles()`) fail on
`haven_labelled` columns unless the `haven` namespace happens to be loaded.
That is a separate fix in a separate package, and it is why the reproduction
above loads `haven` explicitly. Step 2 of the proposed direction removes this
package's exposure on the `eff_n` path, but does not fix the upstream
problem.

**Free-text columns rendered as frequency tables.**
`ald1_13_text` is selected by `starts_with("ald1_")` and renders as a 119-row
table of verbatim answers at 0.1% each. It does not inherit the battery's
`question_preface` — its preface differs, so it forms its own group and
classifies as `single`. There is no machine-readable signal that a column is
free text. That signal is the `role` property, which does not yet exist in
`surveycore`. Revisit once `role` ships.

**A banner-type validation error.**
Rejecting `haven_labelled` banners with a typed error was considered and
rejected. Handling the normal input is better than pushing a package defect
onto the data schema.
