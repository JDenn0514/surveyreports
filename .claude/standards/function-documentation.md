# Function Documentation Standards

How every exported function in surveyreports is documented. This is the
authoritative reference for documentation audits and for new function
implementations.

**Not auto-loaded.** `.claude/rules/*.md` load into every session; this file
does not, because it is long and only three roles need it. The planner, the
builder, and the reviewer Read it explicitly in their Step 0.

**Related rules** (auto-loaded — this file never restates them):

- `.claude/rules/package-conventions.md` — `@returns`, `@examples`, `@family`,
  export policy, `::` usage, NAMESPACE
- `.claude/rules/code-style.md` — `cli_abort()` / `cli_warn()` structure, S7
  patterns, argument order
- `.claude/rules/testing.md` — what the examples in a help page must not
  duplicate from the test suite

Where this file and a rule file disagree, the rule file wins.

---

## Universal Rules

These apply to every exported function, whatever its tier.

### Title

- Write an active verb phrase in the present tense: "Tabulate weighted
  frequencies", not "Frequency tabulation" or "Tabulating frequencies"
- Do not repeat the verb in the function name — use a second angle on intent
  (`export_topline()` → "Write a formatted topline workbook", not "Export a
  topline")
- Drop "survey" from the title where the package context already implies it
- Say what is unique about this function against its siblings in the same
  `@family`. If two functions in a family share a title, one of them is wrong
- Must be informative when skimmed in the pkgdown reference index, alone

### Description

- Add information the title does not carry — do not restate the title in prose
- Title is the high-level summary; the description gives the mechanism, the key
  nuance, or a behavioral constraint that would surprise a user
- No formulas in `@description` — formulas belong in the Algorithm section
- 1–3 sentences. Longer explanation goes in `@details` or a named `@section`

For a function that wraps a `surveycore::get_*()` call, the description states
the delegation. A user needs to know where the numbers come from:

```r
#' @description
#' Tabulates one or more categorical variables and returns one row per
#' variable and response category. Estimation is delegated to
#' [surveycore::get_freqs()]; this function adds the multi-variable loop, the
#' variable labels, and the grouped layout.
```

### `@param` format

**Type annotation.** Lead every `@param` with a type annotation:

```r
#' @param design A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#'   `survey_nonprob`.
```

**Defaults.** State the default first and call it the default:

```r
#' @param method `"holm"` (the default), or any value in
#'   `stats::p.adjust.methods`.
```

**Inline vs. bullets (complexity-based).** Inline if each option fits a single
phrase. A bullet list or a fenced block if any option needs its own sentence.

**Content rule.** `@param` describes the effect of the argument on behavior or
output — not the internal mechanism. Mechanism goes in `@details` or a named
section.

**`@param design` specifically.** Lead with the accepted classes, then say what
happens to the rest. Name the classes the function actually accepts:

```r
#' @param design A `survey_taylor`, `survey_replicate`, `survey_twophase`, or
#'   `survey_nonprob`, created by [surveycore::as_survey()],
#'   [surveycore::as_survey_replicate()], [surveycore::as_survey_twophase()],
#'   or [surveycore::as_survey_nonprob()]. A `survey_collection` produces trend
#'   output — see the **Design Types** section. A plain `data.frame` is an
#'   error.
```

**tidy-select arguments.** Every tidy-select argument carries the standard
link and shows the accepted forms:

```r
#' @param vars <[`tidy-select`][tidyselect::language]> Variable(s) to tabulate.
#'   Use bare column names (`q1`), `c(q1, q2, q3)`, or helpers such as
#'   `starts_with("q")`. Cannot include design variables (weights, strata, PSU).
```

**`@inheritParams`.** Use only when the argument is genuinely identical in
behavior, not just in name. Always put a comment above the tag naming the
source:

```r
# design, vars, and conf_level are identical in behavior to export_topline()
#' @inheritParams export_topline
```

### `@returns`

Use `@returns` on every exported function, per
`.claude/rules/package-conventions.md`. Never `@return`. roxygen2 treats the
two as aliases and generates the same `\value{}` block, so nothing breaks if
one slips through — which is exactly why it needs checking by eye rather than
by `R CMD check`.

- Describe the output's **shape** — class, one row per what — and its
  **behavioral guarantees**
- Enumerate the columns. For a function that returns data this is the
  contract, so name every column, its type, and when it is present:

```r
#' @returns A tibble with one row per variable and response category:
#'   - `variable`: the variable name
#'   - `label`: variable label from surveycore metadata, or `NA`
#'   - `value`: the response category
#'   - `n`: unweighted count
#'   - `prop`: survey-weighted proportion
#'   - `prop_se`: standard error of the proportion
#'   - `prop_low`, `prop_high`: confidence interval bounds, present only when
#'     `ci = TRUE`
#'   When `group` is supplied, a `group` column appears before `variable`.
```

- Enumerate by design type only where the output meaningfully differs. If every
  design type returns the same columns with the same meaning, one description
  is correct — do not enumerate for its own sake
- **Routing:** what the output *contains* belongs here; how it is *computed*
  belongs in the Algorithm section; how it differs *by design type* belongs in
  the Design Types section
- A function that writes a file states both the return value and the side
  effect:

```r
#' @returns Invisibly, the path to the written workbook. Called for its side
#'   effect: an `.xlsx` file at `file_name`.
```

### `@details`

- For content `@description` cannot carry
- Formulas live in `@details`, inside the Algorithm section — never in
  `@description`
- Mechanism and routing logic live in `@details`, not in `@param`
- Whether `@details` is required depends on the tier

### Named `@section` blocks

Use the canonical sections below, in this order, when they apply. Custom
sections are allowed when the content is genuinely distinct from all of them —
this list is not exhaustive.

**Format:** `@section Section Name:` for a top-level section; `**Bold text**`
for a sub-section inside one (roxygen2 does not nest `@section`).

1. **Output Columns** — the column contract in narrative form: which columns
   appear, under which argument combinations, and what each one means when its
   meaning is not obvious from the name. Required whenever the column set
   changes with an argument (`ci`, `group`, `total`, `banner`).

2. **Design Types** — how behavior differs across `survey_taylor`,
   `survey_replicate`, `survey_twophase`, `survey_nonprob`, and
   `survey_collection`. Documents
   *scope and availability* differences, not the variance formulas themselves —
   those are surveycore's. Include whenever the function accepts more than one
   design class and the handling differs.

3. **Algorithm** — the statistical work this function does *itself*: a CI
   formula, a degrees-of-freedom choice, a p-value combining rule, a base-n
   convention. Use `\eqn{}` / `\deqn{}` per the notation rules below. State
   explicitly what is delegated to surveycore and what is not. For a function
   with a `method` argument, use `**Bold sub-headers**` per method inside the
   one section.

4. **Domain Estimation** — how a subpopulation is handled: whether the design
   is subset before or after estimation, what happens to the base n, and what
   an empty domain produces. Include for any function that accepts a domain or
   filter argument.

5. **Missing Data** — how `NA` in the analysis variables, the grouping
   variable, or the weights is handled. Include whenever the behavior is
   non-obvious or the function exposes an argument that controls it.

6. **Workbook Layout** — for `export_*()` functions: sheet structure, header
   rows, the block layouts (single, SATA, battery), where base notes land, and
   how a Total column is placed. Required for every `export_*()` function.

7. **Limitations** — known failure modes, cases where the result is unreliable
   without an error being thrown, when to prefer a different function.

8. **Warnings** — when a warning may occur and how to resolve it. Plain
   language only; no warning class names in the help page.

surveywts has a **Convergence** section. surveyreports has nothing iterative,
so that section is not part of this list. Add it if an iterative function ever
lands.

### `@references`

- Required for any function implementing a published method — a p-value
  combining rule, a CI method with a named author, a degrees-of-freedom
  convention
- Standard academic citation format:

```
Rubin, D. B. (1987). _Multiple Imputation for Nonresponse in Surveys_.
John Wiley & Sons.
```

- **In-line citations** in the description or a section (e.g. "Holm (1979)")
  are optional, and only when verified against the `comprehension.md` for the
  relevant spec. With no `comprehension.md`, omit them. An incorrect in-line
  citation is worse than none

### `@seealso`

Required, not optional, in three cases:

1. **Dispatchers** — link to every function the dispatcher routes to
2. **Sibling functions** — link to every other function in the same `@family`
3. **The underlying surveycore function** — every function that delegates
   estimation links to the single-variable `surveycore::get_*()` it calls

```r
#' @seealso
#'   [export_topline()] for topline (no banner) output,
#'   [surveycore::get_freqs()] for the single-variable underlying function
```

### `@examples`

**All examples run.** Every example runs during `R CMD check`. No `\dontrun{}`
except for an example that genuinely needs an external resource. See
`.claude/rules/package-conventions.md` section 1.

**Which data to use.** Two acceptable sources, chosen by what the example has
to show:

| Function kind | Data |
|---|---|
| `export_*()` | Package data — `anes_2024`, `gss_2024`, `ns_wave1`, `pew_jewish_2020`. Real labels, real factor levels, and real missingness are part of what the example demonstrates. Write the output to `tempfile()` |
| Utilities with no design input (`pool_pvals()`) | A small inline object, as in `package-conventions.md` section 1 |

A small inline `data.frame` piped through `surveycore::as_survey()` stays
acceptable for an `export_*()` function whose point is the argument surface
rather than the data — but prefer package data where labels or missingness
matter to the output.

**Examples must load Imports packages explicitly.** `R CMD check` runs examples
in a fresh session with only `library(surveyreports)` loaded. An example
calling a bare function from an Imports package adds `library(pkg)` at the top
of the block.

**Required content:**

- Always: the simplest working call
- Always: a multi-variable call. surveyreports exists to run over many
  variables — a single-variable example alone understates the function
- One example per design type the function treats differently
- When an argument accepts multiple formats, show each format
- When a `group`, `banner`, or `by` argument exists, show its effect on the
  output shape
- When a `method` argument exists, demonstrate each method
- For an `export_*()` function, write to `tempdir()` and clean up

**Comment style:**

- Comments explain **why**, not what
- Section headers are the exception — use them to label the scenario
- Header format: `# Brief scenario label ----------------------------------`
  (dashes filling to about 76 characters, matching `air` style)

**Length.** Past about 25 lines, ask whether the longer cases belong in a
vignette.

`air` does not reformat code inside roxygen comments. Match `air` style by
hand: 2-space indent, 80-character width, `|>`, one argument per line for long
calls.

### Errors and warnings in help pages

- **Input validation errors** — do not document in the help page. This is
  redundant with `@param`, and `plans/error-messages.md` is the registry
- **Behavioral errors** (an empty domain, an unsupported design class) —
  document in the Domain Estimation or Design Types section
- **Warnings** — document in the Warnings section, in plain language, with no
  warning class names

### Mathematical notation

- **Inline code** (backticks) for simple arithmetic and ratios with no
  subscripts, superscripts, Greek letters, or summation:
  `sd(x) / sqrt(n)`, `[lower, upper]`
- **`\eqn{}`** for an inline expression containing any of those
- **`\deqn{}`** for a display equation containing any of those
- When uncertain: if the formula renders ambiguously in monospace, use
  `\eqn{}` or `\deqn{}`

### Internal function documentation

| Helper complexity | Documentation |
|---|---|
| One-liner (`.get_col()`) | No roxygen |
| Non-trivial, single call site | Roxygen with `@keywords internal` + `@noRd` |
| Non-trivial, in `R/utils.R` | Roxygen with `@keywords internal` + `@noRd`, plus a one-line note on which exported functions call it |

Never `@export` a `.`-prefixed helper.

---

## Tier 1 — Utility

> All Universal Rules apply.

### Criteria

A single-purpose transformation or extraction. It applies a defined operation,
possibly a published formula, but runs no multi-branch logic and produces no
survey estimate of its own.

- **`@details` / Algorithm section** — required only if there is a formula. If
  `@description` covers the mechanism without one, `@details` is likely not
  needed
- **Output Columns** — not applicable unless the function returns a table
- **Design Types** — include if the function accepts a design object and the
  behavior differs by class
- **Domain Estimation** — not applicable
- **Workbook Layout** — not applicable
- **`@references`** — required if it implements a published formula. A
  structural reshape does not need one

### Illustrative examples

- A formatter that turns a proportion column into a display string: no formula,
  `@description` covers it, no Algorithm section
- A label extractor that reads surveycore metadata: no `@references`, minimal
  `@details`

---

## Tier 2 — Standard

> All Universal Rules apply.

### Criteria

The workhorse tier for surveyreports. Multiple steps or decision paths, a
statistical table as output, and estimation delegated to
`surveycore::get_*()`. The mechanism matters enough to explain beyond
`@description`, but the function invents no statistics.

- **Output Columns** — **required.** This is the contract
- **Design Types** — required whenever the function accepts more than one
  design class
- **`@details` / Algorithm section** — required when the function computes
  anything itself beyond the delegated call: a CI on top of an SE, a Total row,
  a base-n convention. If it is a pure pass-through, say so explicitly in
  `@description` and skip the Algorithm section
- **Domain Estimation** — required if a domain or filter argument exists
- **Missing Data** — required when `NA` handling is non-obvious
- **`@references`** — required only if the function implements a published
  method itself

### Illustrative examples

- `export_topline()` — Output Columns section for the `show_n` and
  `show_eff_n` column sets; Design Types section for the `survey_collection`
  trend path; Algorithm section only for the CI construction it does on top of
  `surveycore::get_freqs()`
- `export_crosstab()` — same shape, plus an Output Columns note on the banner
  column groups and the Total column, and a Missing Data note on suppression
  under `pub_type`

---

## Tier 3 — Algorithmic

> All Universal Rules apply.

### Criteria

The function computes a statistical quantity itself rather than delegating it:
a p-value combining rule, a CI method with a named formula, a
degrees-of-freedom convention, a variance adjustment applied on top of what
surveycore returns.

- **`@section Algorithm`** — **required.** Include the formulas with `\eqn{}` /
  `\deqn{}`. State the delegation boundary explicitly: what surveycore returns
  and what this function does with it. For a function with a `method`
  argument, use `**Bold sub-headers**` per method inside the one section
- **Output Columns** — required if it returns a table
- **Missing Data** — required where `NA` in the inputs produces non-obvious
  behavior
- **`@details`** — required
- **`@references`** — **required.** A Tier 3 function implements a published
  method and cites its source

### Illustrative examples

- `pool_pvals()` — Algorithm section with the combining rule and the
  multiplicity correction; `@references` for the correction method;
  `@family multiplicity correction`

---

## Tier 4 — Dispatcher

> All Universal Rules apply.

### Criteria

The function routes to other functions or to other layouts based on an
argument value or an input class. It runs no algorithm of its own.

- **`@description`** — follow the Universal Rules, then end with a sentence
  naming what it routes to and which argument controls the routing
- **`@param`** — full, substantive documentation, in the same language as the
  functions dispatched to. Where an argument behaves the same across every
  route, document it fully here. Where it genuinely differs, write the
  description that holds across all routes and point to the specific functions
  for the differences. The dispatch argument lists every accepted value with a
  brief characterization — enough to choose without opening another help page
- **`@details`** — required. A high-level overview of each route: enough to
  understand the differences and choose. Do not replicate the full Algorithm
  sections of the functions dispatched to; point to them
- **`@section Algorithm`** — do not use. The overview lives in `@details`; the
  full algorithm lives in the dispatched function
- **Output Columns / Workbook Layout** — required. Even a pure dispatcher owes
  the reader the shape of what comes back
- **`@seealso`** — **required.** Link to every function it routes to
- **`@references`** — required when the routes implement published methods. The
  in-line citations in `@details` tie each reference to its route, and the
  `@references` block is the complete list. Because those in-line citations
  carry weight for a dispatcher, if they cannot be verified against a
  `comprehension.md`, the `@details` overview and the `@references` block both
  wait until verification is possible rather than being written uncited

### Illustrative examples

- `export_topline()` — routes single, SATA, and battery blocks by question
  structure; Workbook Layout section for the three block layouts and the base
  notes; `@seealso` to `export_crosstab()`
- `export_crosstab()` — routes by banner and interaction structure; Workbook
  Layout section for the Total column and the two-column battery layout

---

## Dataset documentation

Every exported dataset in `data/` — `anes_2024`, `gss_2024`, `ns_wave1`,
`pew_jewish_2020` — is documented in `R/data.R` with:

- `@format` — a `\describe{}` block naming every column a documented example
  uses, with its type and its meaning. A dataset with hundreds of columns
  documents the design columns (weights, strata, PSU) plus the columns the
  package's own examples touch, and says so
- The design variables, named explicitly, so a reader can build the design
  object without guessing
- `@source` — where the data came from, with a URL where one exists
- Whether variables carry surveycore label attributes, since the examples rely
  on them

`R CMD check` codoc rules apply: every name in `@format` must exist in the
data, and every column referenced by an example must be in `@format`.
