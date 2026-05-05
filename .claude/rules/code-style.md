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
| Class membership test | `S7::S7_inherits(x, survey_taylor)` — class object, never a string |
| NSE forwarding | `{{ var }}` first; `!!sym(var_chr)` for resolved strings |
| Setter return values | `invisible(x)` |
| Getter/report return values | Visible (no `invisible()`) |
| Argument order | `design` → required NSE → required scalar → optional NSE → optional scalar → `...` → named-only |
| Internal helper placement | Same file (below exports) if used in 1 file; `R/utils.R` if used in 2+ files |
| Error structure | `"x"` + `"i"` + optional `"v"` bullets; `class=` on every `cli_abort()` |
| Warning classes | `class=` on every `cli_warn()` too |
| Message language | Declarative for `"x"`/`"i"` bullets; imperative for `"v"` bullet |

---

## 1. General R Style

**Indentation:** 2 spaces per level. No tabs.

**Line length:** 80 characters. Break long function signatures after `(`:

```r
report_freqs <- function(
  design,
  vars,
  group = NULL,
  ci = TRUE,
  ci_level = 0.95,
  ...
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
| Function name | `{.fn report_freqs}` | `report_freqs()` |
| Code snippet | `{.code ci = FALSE}` | `ci = FALSE` |
| A value | `{.val "mean"}` | `"mean"` |
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
| `report_*()` functions | Visible — the result tibble |
| Setters, print/summary methods | `invisible(x)` |
| Internal validators (`.validate_*()`) | `invisible(TRUE)` on success; errors on failure |

### Argument order

1. `design` — always first, always required
2. Required NSE/tidy-select arguments
3. Required scalar arguments
4. Optional NSE/tidy-select arguments (`group = NULL`)
5. Optional scalar control arguments (`ci = TRUE`, `ci_level = 0.95`)
6. `...`
7. Named-only control args (after `...`)

### Internal helper placement

| Helper used in... | Lives in... |
|-------------------|-------------|
| Exactly 1 source file | Same file, below the exported function(s) that call it |
| 2 or more source files | `R/utils.R` |

All internal helpers are not exported and prefixed with `.`. When a single-use
helper grows a second call site, promote it to `R/utils.R` in the same PR.
