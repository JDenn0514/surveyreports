# Code Style

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Indentation | 2 spaces |
| Line length | 80 characters |
| Auto-formatter | `air` (Posit's R formatter) — run before committing |
| Pipe operator | Native `\|>` only |
| Assignment | `<-` for assignments; `=` for function arguments only |
| Property access | Direct `@` everywhere on surveycore objects |
| Class membership test | `S7::S7_inherits(x, surveycore::survey_base)` — class object, never a string |
| NSE forwarding | `{{ var }}` first; `!!sym(var_chr)` for resolved strings |
| Export function return values | `invisible(file_name)` — the path written |
| Print method return values | `invisible(x)` |
| Computed-result return values | Visible (no `invisible()`) |
| Argument order | `design` → required NSE → required scalar → optional scalar → `...` → named-only |
| Internal helper placement | Same file (below exports) if used in 1 file; `R/export-utils.R` if used in 2+ files |
| Error structure | `"x"` + `"i"` + optional `"v"` bullets; `class=` on every `cli_abort()` |
| Warning classes | `class=` on every `cli_warn()` too |
| Message language | Declarative for `"x"`/`"i"` bullets; imperative for `"v"` bullet |

---

## 1. General R Style

**Indentation:** 2 spaces per level. No tabs.

**Line length:** 80 characters. Break long function signatures after `(`:

```r
export_topline <- function(
  design,
  vars,
  file_name,
  conf_level = 0.95,
  decimals = 1L,
  show_n = TRUE
) {
```

Break long `cli_abort()` calls across lines:

```r
cli::cli_abort(
  c(
    "x" = "{.arg design} must be a survey design object.",
    "i" = "Got class {.cls {class(design)}}.",
    "v" = "Use {.fn surveycore::as_survey} to create a design object."
  ),
  class = "surveyreports_error_not_survey_object"
)
```

**Pipe:** `|>` only. Never `%>%`.

**Assignment:** `<-` for all assignments. `=` only for function arguments.

**Auto-formatter:** `air` rewrites R files to conform — it is not `lintr`. Do not manually undo its changes. Run `air format .` before opening a PR; reformat in a separate commit from functional changes.

---

## 2. Working With S7 Survey Objects

### Property access

Use `@` directly for surveycore object properties in internal code:

```r
wt_col <- design@data[[design@variables$weights]]
domain_col <- design@data[["..surveycore_domain.."]]

# Also fine — use surveycore accessor functions where provided
df <- surveycore::survey_data(design)
```

Do not expose `@` in user-facing documentation or examples.

### Class membership testing

Always use `S7::S7_inherits(x, ClassName)` with the class object — never a string.
A string-based check silently breaks if the class is renamed.

```r
if (!S7::S7_inherits(design, surveycore::survey_base)) {
  cli::cli_abort(...)
}
```

### Design classes

`survey_base` has four subclasses. A function that takes a `design` must work
with all four:

| Class | Created by |
|-------|-----------|
| `survey_taylor` | `surveycore::as_survey()` |
| `survey_replicate` | `surveycore::as_survey_replicate()` |
| `survey_twophase` | `surveycore::as_survey_twophase()` |
| `survey_nonprob` | `surveycore::as_survey_nonprob()` |

`survey_collection` is separate — it holds several designs for wave comparison
and does NOT inherit `survey_base`. Check for it explicitly:

```r
# export_topline() accepts either
if (
  !(S7::S7_inherits(design, surveycore::survey_base) ||
    S7::S7_inherits(design, surveycore::survey_collection))
) {
  cli::cli_abort(...)
}

# export_crosstab() rejects a collection first, with its own error class
if (S7::S7_inherits(design, surveycore::survey_collection)) {
  cli::cli_abort(
    c(
      "x" = "{.arg design} must be a single survey design, not a collection.",
      "i" = "Got class {.cls {class(design)}}.",
      "v" = "Use {.fn export_topline} for wave-comparison (trend) output."
    ),
    class = "surveyreports_error_collection_not_supported_for_crosstab"
  )
}
```

Check the design class BEFORE resolving any tidy-select argument.

---

## 3. Error & Warning Conventions

### `cli_abort()` structure

```r
cli::cli_abort(
  c(
    "x" = "What went wrong (declarative).",   # always present
    "i" = "Context or diagnosis.",              # usually present
    "v" = "How to fix it (imperative)."        # when fixable
  ),
  class = "surveyreports_error_{condition}"    # ALWAYS required
)
```

- `"x"` — what is wrong; subject is the object/argument, not the user
- `"i"` — why, or what was found; use `{.val}` / `{.field}` / `{.cls}` for actual values
- `"v"` — the fix; imperative; only include when actionable

`cli_warn()` uses the same structure with `"!"` instead of `"x"`, and also requires `class=`.

### Error and warning classes

`class=` is required on every `cli_abort()` and `cli_warn()` — no exceptions.

The canonical list is in `plans/error-messages.md`. When adding a new error/warning:
1. Add a row to `plans/error-messages.md` first
2. Use the class name from that table
3. Add a corresponding `expect_error(class = ...)` test

Naming:
- Errors: `"surveyreports_error_{snake_case_condition}"`
- Warnings: `"surveyreports_warning_{snake_case_condition}"`

### cli inline markup

| What you're showing | Markup | Renders as |
|---------------------|--------|------------|
| Function argument | `{.arg vars}` | `vars` |
| Column / variable name | `{.field {var}}` | `var` |
| Function name | `{.fn export_topline}` | `export_topline()` |
| Code snippet | `{.code show_n = FALSE}` | `show_n = FALSE` |
| A value | `{.val "BH"}` | `"BH"` |
| A class name | `{.cls survey_taylor}` | `<survey_taylor>` |

### Message language register

- `"x"` bullets — declarative, object as subject: `"Variable {.field {var}} is not in the design."`
- `"i"` bullets — declarative, system as subject: `"Got class {.cls {class(design)}}."`
- `"v"` bullets — imperative: `"Use {.fn surveycore::as_survey} to create a design."`
- Never `"You must..."` or `"You provided..."` — never address the user directly

---

## 4. Function Design

### NSE and tidy-eval

Prefer `{{ }}` (the embrace operator) when forwarding user-supplied NSE arguments into tidy-eval–aware functions:

```r
# Correct — forwarding an NSE argument
.compute_subgroup <- function(design, var) {
  surveycore::get_freqs(design, {{ var }})
}

# Fall back to !!sym() only when var is already a character string
.compute_subgroup_chr <- function(design, var_chr) {
  surveycore::get_freqs(design, !!sym(var_chr))
}
```

`!!sym()` is appropriate when working with already-resolved character vectors (e.g., after `tidyselect::eval_select()`). Try `{{ }}` first; if it fails, use `!!sym()`.

### Return value visibility

| Function type | Return |
|---------------|--------|
| `export_*()` functions | `invisible(file_name)` — the path supplied by the caller |
| Functions that compute a result (`pool_pvals()`) | Visible — the result tibble |
| Print methods | `invisible(x)` |
| Internal validators (`.validate_*()`) | `invisible(TRUE)` on success; errors on failure |
| Internal render helpers (`.render_*()`, `.write_*()`) | `list(wb = , next_row = )` |

An `export_*()` function writes a spreadsheet. Its return value is the path, not
the data, so the caller can pipe it onward. Never return the workbook object.

### Argument order

1. `design` — first and required for any function that takes one
2. Required NSE/tidy-select arguments (`vars`, `banner`)
3. Required scalar arguments (`file_name`)
4. Optional NSE/tidy-select arguments (`interactions = NULL`)
5. Optional scalar control arguments (`conf_level = 0.95`, `decimals = 1L`)
6. `...`
7. Named-only control args (after `...`)

A function that takes no design starts with its own primary argument instead.
`pool_pvals(results, method = "BH", …)` takes a list of tibbles, so `results`
is first.

```r
export_crosstab(design, vars, banner, file_name, layout, interactions, ...)
pool_pvals(results, method, p_col, new_col, id_col, strip_within_adj)
```

### Internal helper placement

| Helper used in... | Lives in... |
|-------------------|-------------|
| Exactly 1 source file | Same file, below the exported function(s) that call it |
| 2 or more source files | `R/export-utils.R` |

All internal helpers are not exported and prefixed with `.`. When a single-use
helper grows a second call site, promote it to `R/export-utils.R` in the same
PR.

Helper name families in use — match the nearest one rather than coining a new
verb:

| Prefix | Does |
|--------|------|
| `.validate_*` | Checks an argument; errors or returns `invisible(TRUE)` |
| `.compute_*` | Returns survey estimates for one variable or cell |
| `.build_*` | Assembles a data frame or a workbook object |
| `.render_*` | Writes one question block to a sheet; returns the next row |
| `.write_*` | Writes one element (a title, a footnote, a header row) |
| `.extract_*` | Pulls metadata out of a design |
| `.emit_*` | Raises a warning |

---

## 5. Writing Workbooks With openxlsx2

Both export functions build one workbook, write question blocks into it in
order, then save once. Two rules keep that orderly.

**A render helper takes a start row and returns the next row.** It never
tracks position in a shared variable:

```r
.render_topline_single <- function(wb, sheet, frame, start_row, ...) {
  # ... write rows ...
  list(wb = wb, next_row = start_row + n_written + 1L)
}
```

The caller threads the cursor through each block:

```r
res <- .render_topline_single(wb, sheet, frame, row)
wb <- res$wb
row <- res$next_row
```

**Save once, at the end, in the exported function.** A render helper never
calls `openxlsx2::wb_save()`. The exported function saves and returns
`invisible(file_name)`.

Build the workbook with `.build_workbook()` rather than calling
`openxlsx2::wb_workbook()` directly, so shared defaults stay in one place.
