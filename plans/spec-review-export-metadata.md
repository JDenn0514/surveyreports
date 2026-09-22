# Spec Review: export-metadata

Adversarial review of `plans/spec-export-metadata.md` and
`plans/test-spec-export-metadata.md`. Stage 3 of the spec workflow.

---

## Spec Review: export-metadata — Pass 1 (2026-09-10)

Artifacts read in full:

- `plans/spec-export-metadata.md` v0.4.0
- `plans/test-spec-export-metadata.md` v0.1.0

Supporting files read: `.claude/standards/function-documentation.md`,
`.claude/rules/testing.md`, `.claude/rules/code-style.md`,
`.claude/rules/package-conventions.md`, `plans/error-messages.md`,
`plans/decisions-export-metadata.md`,
`plans/spec-methodology-export-metadata.md`.

Repository claims were spot-checked against `R/export-utils.R`,
`R/export-crosstab.R`, `R/export-topline.R`,
`tests/testthat/helper-test-data.R`, `tests/testthat/_snaps/`, and the
installed `surveycore` NAMESPACE. The verified and the failed claims are named
inside the issues below.

### New Issues

#### Section: Cross-artifact check

**Issue 1: Three test-spec rows are undefined, and the spec closes none of them**
Severity: BLOCKING
Violates the Stage 3 cross-artifact rule — every function contract needs at
least one usable scenario.

`TX-08`, `XX-08` and `XX-09` each read
**"UNDEFINED — spec reviewer to resolve."** The test-spec instructs the tester
not to write an assertion. The spec does not define any of the three, so the
tester has no target and the builder has no contract.

The three cases are:

- `TX-08` and `XX-09` — an empty domain together with a role-dropped column.
  Which condition is reported first?
- `XX-08` — an unused factor level on a banner column. Does it give a column
  group with a raw N of `0`, or no column group?

Measurement settles the first pair. `.validate_export_inputs()` runs the
empty-domain check at `R/export-utils.R:67-77`, and both export functions call
it before they resolve `banner` or run any role guard —
`R/export-crosstab.R:121` and `R/export-topline.R:95`. Section 5.7 places the
role guard after the not-found checks, so `surveyreports_error_empty_domain`
always fires first. The order is already fixed by the code; the spec only has
to state it.

`XX-08` needs a measurement against surveycore. Section 3.5 defines the
unobserved **labelled code** case ("no row — surveycore drops it"). A factor
level is a different path and is not defined.

Options:
- **[A]** Add a row to section 3.5's contract table for the unused factor
  level, and one sentence to section 5.7 fixing the domain-before-role order.
  Then rewrite the three test rows as real assertions — Effort: low, Risk: low,
  Impact: the tester can write all three, Maintenance: none.
- **[B]** Delete the three rows from the test-spec and record them as parked,
  the way sections 1.3.1 and 1.3.2 park other cases — Effort: low, Risk:
  medium, Impact: three real paths stay untested.
- **[C] Do nothing** — the test-spec ships with three rows the tester is told
  not to write, and a reader cannot tell a gap from a pass.

**Recommendation: A** — the domain order costs one sentence, and the factor
level costs one measurement of the same kind the spec already ran 20 times.

---

**Issue 2: The spec carries the test gates, the test fixture, and the expected numbers**
Severity: BLOCKING
Violates the Stage 3 cross-artifact rule — `spec-{id}.md` carries no tolerance,
dataset, or oracle call.

The spec's section IX is a gate list, and it duplicates the test-spec:

| Spec, section IX | Test-spec |
|---|---|
| `devtools::test()` — 0 failures | Profile gate 2, `RG-01` |
| warnings drop to 8 or fewer | `RG-02` |
| `devtools::check()` | Profile gate 5 |
| `covr::package_coverage()` at or above 98% | `RG-04`, Profile gate 7 |
| No committed snapshot changed | `RG-01` |
| no `# nocov` cover for a missing test | `RG-05` |
| `air format .` | Profile gate 8 |

Two of the spec's gates go further and carry test data:

- "The twophase Total header reports an effective N at or below the design's
  in-scope row count — **119, not 185**." That is an expected value taken from
  one fixture.
- Sections 1.2.1 and 3.3 name `make_all_designs(seed = 42)` and
  `helper-test-data.R` directly.

The leak runs the other way too. The test-spec's "Open items for the spec
reviewer" opens with "The behavioral contract's design support matrix omits
`survey_nonprob`" — a reference to the other artifact, addressed to a role that
is not the tester.

The two gate lists already disagree in one place. The spec says coverage "at or
above 98%". The test-spec says the same in `RG-04` but "95% floor, 98% target"
in Profile gate 7.

Options:
- **[A]** Cut section IX down to the items that are not test gates — the
  `plans/error-messages.md` edit, the `grep -rn "compute_eff_n" R/` check, and
  the `DESCRIPTION` pin — and move the rest to the test-spec. Move the
  "119, not 185" figure into `TN-03`, which already states it. Drop the
  fixture names from 1.2.1 and 3.3, keeping the measured ratios. Delete the
  test-spec's "Open items" section once issues 1 and 3 are resolved — Effort:
  low, Risk: low, Impact: the two artifacts become independently sufficient,
  Maintenance: one gate list instead of two.
- **[B]** Keep both lists and add a line to each saying the other is
  authoritative — Effort: low, Risk: medium, Impact: the drift stays and gains
  a pointer.
- **[C] Do nothing** — the builder reads the tester's acceptance numbers, and
  the two gate lists drift further apart.

**Recommendation: A** — one gate list, in the document whose job it is.

---

#### Section: I. Scope

**Issue 3: The design support matrix omits `survey_nonprob`, and no workstream closes the generator gap**
Severity: BLOCKING
Violates `.claude/rules/testing.md`, Cross-design testing — the canonical
subclass table names four subclasses.

Section 1.4's matrix has four rows: `survey_taylor`, `survey_replicate`,
`survey_twophase`, `survey_collection`. `survey_nonprob` is absent. It is not
marked "no"; it is not there. Lens 3 requires a yes or a no in every row.

The gap is real, not a wording slip. `tests/testthat/helper-test-data.R`
returns a three-element list — `taylor`, `replicate`, `twophase`. It builds no
nonprob design. `.claude/rules/testing.md` records the same gap and says the
generator "must gain one".

The test-spec then writes **every** cross-design row against all four
subclasses and states that until the generator returns a nonprob design "the
loops cover three of the four subclasses, and the shortfall is a gap, not a
pass".

So the tester is told to expect four designs, the builder is told about three,
and neither document assigns the work of adding the fourth. Section 2.1's file
table does not list `tests/testthat/helper-test-data.R`.

Options:
- **[A]** Add a `survey_nonprob` row to section 1.4, add
  `tests/testthat/helper-test-data.R` to section 2.1's file table, and make
  "`make_all_designs()` returns a `survey_nonprob` design" an explicit
  deliverable of this spec — Effort: medium, Risk: medium, Impact: the
  cross-design loops become real for both export functions; every metadata read
  gains a fourth design, Maintenance: one more design in every loop.
- **[B]** Add a `survey_nonprob` row to section 1.4 that reads "out of scope —
  the generator gap is a separate change", and remove nonprob from every
  cross-design row in the test-spec — Effort: low, Risk: medium, Impact: the
  spec and the test-spec agree, but a whole subclass stays untested against
  five new behaviors, Maintenance: the debt moves to a follow-up.
- **[C] Do nothing** — the two documents keep contradicting each other, and the
  tester reports a permanent shortfall on every row.

**Recommendation: A** — the generator gap is one constructor call, and this
spec adds five behaviors that every subclass must survive. Option B parks a gap
that grows with every row this spec adds.

---

#### Section: II. Architecture

**Issue 4: The warn-and-drop policy has no shared helper**
Severity: REQUIRED
Violates `.claude/rules/code-style.md`, Internal helper placement — a helper
used in 2 or more source files lives in `R/export-utils.R`.

Section 2.2 specifies `.resolve_roles(design, cols)` as a **lookup**: it
"returns a named character vector, one entry per element of `cols`". It does
not classify, it does not warn, and it does not drop.

The policy that surrounds the lookup is four steps:

1. Split the resolved roles into the drop set and the keep set of section 5.4.
2. Raise `surveyreports_warning_role_dropped` once, listing every dropped
   column.
3. Raise `surveyreports_warning_unknown_role` once, per the section 5.3 table.
4. Abort when the surviving set is empty.

Section 2.1 assigns "role guard" to `R/export-crosstab.R` **and** to
`R/export-topline.R`. So all four steps get written twice, in two files, for
`vars`. Step 4 differs by argument — `vars` uses the existing error class,
`banner` uses the new one — but steps 1 to 3 are identical.

DRY is engineering principle 1 in `CLAUDE.md`, and Lens 1 is the highest
priority lens.

Options:
- **[A]** Add `.apply_role_guard(design, cols, arg, empty_class)` to section 2.2
  and to `R/export-utils.R`. It calls `.resolve_roles()`, raises both warnings,
  and returns the surviving column names. Each export function calls it once
  for `vars`; `export_crosstab()` calls it a second time for `banner` —
  Effort: low, Risk: low, Impact: one implementation, one set of tests,
  Maintenance: one place to change the drop set.
- **[B]** Widen `.resolve_roles()` so it warns and returns the surviving
  columns — Effort: low, Risk: low, Impact: the same, but the helper's name no
  longer describes what it does, and section 5.6's collection branch gets
  harder to read.
- **[C] Do nothing** — the drop set, the two warning texts, and the classifier
  live in two files and drift.

**Recommendation: A** — a named guard reads correctly at both call sites and
keeps `.resolve_roles()` a lookup, which is what sections 5.3 and 5.6 specify.

---

**Issue 5: `R/export-crosstab.R` has four `wb_add_worksheet()` call sites, not three**
Severity: REQUIRED
A measured claim in the spec does not hold.

Section 2.1 says "route all three `wb_add_worksheet()` calls through
`.unique_sheet_name()`". Section 6.2.1 names them: `:209`, `:231`, `:253`.

Measured — `grep -n "wb_add_worksheet" R/export-crosstab.R` returns four lines:

```
209:        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
231:        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
253:        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
274:    wb <- openxlsx2::wb_add_worksheet(wb, "Crosstab")
```

Line 274 writes the stacked-layout sheet. Its name is the literal `"Crosstab"`,
so it cannot collide with `"About"` today. It can collide with a data sheet if
`layout` ever writes both, and a reader who follows "all three" will not know
whether 274 was measured and excluded or simply missed.

Options:
- **[A]** Correct the count to four, name `:274`, and state that it is routed
  for consistency although its literal name cannot collide today — Effort: low,
  Risk: low, Impact: the file table matches the file, Maintenance: none.
- **[B]** Correct the count to four and state that `:274` is deliberately not
  routed, with the reason — Effort: low, Risk: low, Impact: the same clarity,
  one fewer line changed.
- **[C] Do nothing** — the spec's measured claim is wrong, which weakens every
  other measured claim in it.

**Recommendation: B** — say what was measured and why the fourth site is
excluded. Routing a literal name through a uniqueness helper adds no behavior.

---

**Issue 6: `.unique_sheet_name()` is placed against the rule the spec cites**
Severity: SUGGESTION
Violates `.claude/rules/code-style.md`, Internal helper placement.

Section 2.1 puts all seven new helpers in `R/export-utils.R` and justifies it:
"`code-style.md` directs a helper used in 2 or more source files there — line
21 and line 239 both name `R/export-utils.R`."

Both lines were verified and both say exactly that. The same table's first row
says a helper used in exactly 1 source file lives in that file, below the
exported function.

`.unique_sheet_name()` has call sites in `R/export-crosstab.R` only —
section 6.2.1 says so itself: "`export_topline()` is unaffected. Measured — it
writes one sheet, `"Topline"` ... The sheet-name collision is therefore a
crosstab-only case."

The other six helpers are placed correctly. `.resolve_base_notes()` and
`.resolve_roles()` are called from both export files. `.resolve_eff_n()`,
`.banner_levels_labelled()`, `.unanimous_across()` and `.write_cover_sheet()`
are called from within `R/export-utils.R`.

Options:
- **[A]** Move `.unique_sheet_name()` to `R/export-crosstab.R`, below the
  exported function — Effort: low, Risk: low, Impact: the placement matches the
  rule, Maintenance: it moves to `R/export-utils.R` if `export_topline()` ever
  gains a second sheet.
- **[B]** Keep it in `R/export-utils.R` and add one sentence saying the
  placement anticipates a second caller — Effort: low, Risk: low, Impact: an
  abstraction with one real call site, which principle 3 in `CLAUDE.md` calls
  over-engineering.
- **[C] Do nothing** — the spec cites a rule and then breaks it in the same
  paragraph.

**Recommendation: A** — one file, one helper, per the rule the spec quotes.

---

#### Section: III. Workstream 1

**Issue 7: Two or more unlabelled codes on one banner column are unspecified**
Severity: REQUIRED
Section 3.5's contract table contradicts itself on this input.

Two rows of the table apply at once when a banner column carries codes 1, 2, 3
and 4, and only 1 and 2 carry labels:

- "labelled banner | one row per **observed** code"
- "a banner where some codes carry a label and some do not | one row per
  observed code. Labelled codes give the label; an unlabelled code gives
  `level = NA_character_`."

Read literally, `.resolve_eff_n()` returns two rows whose `level` is
`NA_character_`. Section 3.8 then joins the `show_eff_n` block on
`as.character(subgroup_value)`. A duplicated join key multiplies rows.
The suppression path is worse: `sup_vals` would hold `NA` once, and
`r$subgroup_value %in% sup_vals` matches a missing value to a missing value —
the spec says so in section 3.4, consequence 3 — so **both** unlabelled codes
lose their rows even when only one falls below the threshold.

The alternative reading is that surveycore's `.apply_group_labels()` collapses
every unlabelled code into one factor `NA` level, giving one row that covers
codes 3 and 4 together. Then the join is clean, but the contract's "one row per
observed code" is false and the suppression footnote reports one subgroup where
the design has two.

Both readings are plausible. The spec measured the single-unlabelled-code case
(section 3.5, closed question 17) and did not measure this one. The test-spec's
`XP-08` uses one unlabelled code, so no scenario would catch either failure.

Options:
- **[A]** Measure `get_effective_n()` and `get_freqs()` on a banner with two
  unlabelled codes. Record the row count in the section 3.5 table, and add a
  test-spec row asserting it — Effort: low, Risk: low, Impact: the join key and
  the suppression filter both become defined, Maintenance: none.
- **[B]** Abort during validation when a banner column carries more than one
  unlabelled observed code, next to the section 3.6 duplicate-label check —
  Effort: low, Risk: medium, Impact: it removes a real subgroup shape from
  service to avoid measuring it.
- **[C] Do nothing** — the implementer builds a join whose key may be
  duplicated, and suppression may remove a subgroup that is above the
  threshold.

**Recommendation: A** — the spec already measured 20 upstream facts of exactly
this kind. This is the twenty-first.

---

**Issue 8: The line references to the deleted helper drift, and two `# nocov` markers go unmentioned**
Severity: SUGGESTION
Measured claims in sections 3.8 and IX do not hold.

Read against `R/export-utils.R`:

| Spec says | Measured |
|---|---|
| `.compute_eff_n()` body at `:134-158` | `:134-159` |
| its `# nocov` block at `:148-153` | `:150-156` |
| one `# nocov` block in the helper | three markers — `:138`, `:141`, and the `:150-156` block |

The one correct and load-bearing reference holds: `:145` is
`data <- data[data[[col]] == level, , drop = FALSE]`, which is the defect
section 3.1 describes.

The three other checked references in the same workstream also hold: `:490` is
the `sup_vals` filter, `:238-242` is the `interaction()` call, and `:381-396`
is the collection branch of `.build_freq_frame()`.

The count matters more than the offsets. Section IX's gate reads
"`grep -rn "compute_eff_n" R/` returns nothing — the helper and its
`# nocov` block are gone", singular. Deleting the helper removes three markers.
`RG-05` in the test-spec asserts that no **new** marker is added, so the
removals are not otherwise counted.

Options:
- **[A]** Correct the two line ranges and say "three `# nocov` markers" —
  Effort: low, Risk: low, Impact: the gate counts what is actually removed,
  Maintenance: none.
- **[B]** Drop the line numbers and name the helper only — Effort: low, Risk:
  low, Impact: the references stop decaying with every edit above them,
  Maintenance: less.
- **[C] Do nothing** — a reader who checks `:148-153` finds `wi <- data[[wt_col]]`
  and doubts the rest of the spec.

**Recommendation: B** — the helper is deleted whole, so a line range adds
nothing that its name does not.

---

**Issue 9: The suppression footnote changes more than section 3.4 states**
Severity: SUGGESTION
An accuracy problem in section 3.4, consequence 3.

The spec says `.write_suppression_footnote()` "prints the label with no change,
because it reads `row$subgroup_value`", then names the label change as the only
change.

Measured — `R/export-utils.R:604-612`:

```r
text <- sprintf(
  "* %s: %s suppressed (n=%d, threshold=%d)",
  row$subgroup_var,
  row$subgroup_value,
  row$raw_n,
  row$threshold
)
```

The footnote also prints `raw_n`. Section 3.8 changes where `raw_n` comes from:
today `sum(col_vals == level, na.rm = TRUE)` over `@data`, after the change
`n` from `.resolve_eff_n()`. For a twophase design that count drops from the
phase-1 rows to the phase-2 rows; for a domain-restricted design it drops to
the in-domain rows. So the footnote's `n=` value changes on two design types,
for the same reason the effective N does.

This does not break gate IX. Checked — neither `_snaps/export-crosstab.md` nor
`_snaps/export-topline.md` records a suppression warning or a footnote, so no
committed snapshot moves.

Options:
- **[A]** Replace "with no change" with the two changes: the label, and the
  `n=` count on a twophase or domain-restricted design. Add a test-spec row
  asserting the footnote's `n=` against the oracle on a twophase design —
  Effort: low, Risk: low, Impact: the workstream's user-visible effect is
  stated completely, Maintenance: none.
- **[B]** Correct the sentence only, with no new test row — Effort: low, Risk:
  low, Impact: the text is right, the count stays unasserted.
- **[C] Do nothing** — the spec understates the change, and the corrected `n=`
  count is never asserted anywhere.

**Recommendation: A** — the corrected `n=` on a twophase design is the exact
defect this workstream exists to fix, and `XN-04` asserts it only in aggregate.

---

#### Section: IV. Workstream 2

No new issues found. The two-source split in section 4.2, the ordering
constraint in 4.3, the collection branch in 4.4, and the unanimity rule and its
two shapes in 4.5 are each specified to the level a builder can implement.
Their scenarios are `TP-01` to `TP-06`, `TC-01`, `TC-02`, and `XP-09` to
`XP-14`. One seam with workstream 3 is raised as issue 11.

---

#### Section: V. Workstream 3

**Issue 10: `interactions` is not reconciled with a role-dropped banner column**
Severity: BLOCKING
An unspecified degenerate case that section 5.5's sibling case does specify.

Section 5.5 defines what happens when the role guard empties `vars` and when it
empties `banner`. It does not define what happens when the guard drops a banner
column that `interactions` names.

The sequence is fixed by the existing code and by section 5.7:

1. `R/export-crosstab.R:155-171` validates `interactions` against
   `banner_resolved` and aborts with
   `surveyreports_error_interaction_not_in_banner` when a named variable is not
   in the banner.
2. Section 5.7 places the role guard **after** the not-found checks.
3. So `interactions = list(c("gen", "reg"))` passes validation, then the guard
   drops `gen` for `role = "paradata"`, and `interactions` now names a variable
   the banner no longer holds.

What follows is undefined. `.compute_interaction_freq()` would build its
grouping column from a dropped column, or `.build_col_groups()` would find no
levels. There are at least three defensible answers — drop the interaction and
warn, abort, or keep the interaction and its dropped parent — and the spec
picks none.

The case is not exotic. `interactions` exists to cross demographic banner
columns, and `demographic` is one of the roles section 5.4 keeps, so a
mixed banner is the normal input.

Options:
- **[A]** Add a row to section 5.5: an `interactions` element that names a
  dropped column is itself dropped, reported by the existing
  `surveyreports_warning_role_dropped`. An element that keeps two or more
  surviving columns is kept and crossed over the survivors — Effort: medium,
  Risk: low, Impact: the case is defined and testable, Maintenance: one more
  branch in the interaction loop.
- **[B]** Re-run the `interactions` validation after the role guard, so a
  dropped column raises the existing
  `surveyreports_error_interaction_not_in_banner` — Effort: low, Risk: low,
  Impact: the case aborts with an existing class and an accurate message; the
  caller fixes the call, Maintenance: one moved check.
- **[C] Do nothing** — the implementer guesses, and one guess writes a
  crosstab whose spanners come from a column the workbook says was dropped.

**Recommendation: B** — it reuses an existing class, matches section 5.5's
"abort rather than deliver a different shape silently" reasoning, and costs one
line. Option A is the friendlier behavior but adds a branch the spec has no
other need for.

---

**Issue 11: Dropping one member of a battery or a SATA group is unspecified**
Severity: REQUIRED
Section 5.7 names the risk and does not resolve it.

Section 5.7 states the ordering and the reason:

> The role guard runs **after** tidyselect resolution and **after** the existing
> not-found checks, and **before** `classify_question_type()`. A dropped column
> must not reach classification, or it will form its own question group and
> change the group numbering of everything after it.

That reasoning covers a dropped **single** variable. It does not cover a
dropped **member of a group**. `vars = c(bat_1, bat_2, bat_3)` with
`role = "paradata"` on `bat_2` reaches `classify_question_type()` as
`c("bat_1", "bat_3")`, and three consequences follow that no section states:

1. Does the surviving pair still classify as a battery, or as two singles?
   `surveycore::classify_question_type()` decides, and the spec does not say
   which answer it gives.
2. Section 4.5's unanimity rule then runs over the survivors only. A battery
   whose three members disagree but whose two survivors agree now prints a
   universe it would not have printed. That is a defensible outcome, but it is
   the opposite of "never state a universe that is false for a member of the
   block" if the reader thinks of the block as the original three.
3. `R/export-crosstab.R:226` and `:248` take the sheet name from
   `group_vars[[1L]]`. Dropping `bat_1` renames the sheet.

The same applies to a SATA group, whose members carry `set_sata()` metadata in
`make_all_designs()`.

No test-spec row covers it. `TP-03` to `TP-06` and `XP-11` to `XP-14` all vary
the universe text and never drop a member. `TP-07` to `TP-10` and `XP-15` to
`XP-19` all drop a single-response variable.

Options:
- **[A]** Add a row to section 5.4 or 5.7 defining group-member drops: state
  whether the survivors reclassify, that unanimity applies to the survivors,
  and what the sheet name becomes. Add a scenario for a battery and one for a
  SATA group — Effort: medium, Risk: low, Impact: the interaction between
  workstreams 2 and 3 becomes defined, Maintenance: two more scenarios.
- **[B]** Exempt group members from the guard: a column that
  `classify_question_type()` would place in a SATA or battery group is never
  dropped for its role. This needs classification to run before the guard,
  which section 5.7 forbids — Effort: high, Risk: high, Impact: it inverts a
  stated ordering constraint.
- **[C] Do nothing** — the seam between the two workstreams is untested, and
  the behavior falls out of whatever `classify_question_type()` happens to
  return.

**Recommendation: A** — the guard and the unanimity rule are the two headline
behaviors of this spec, and this is the one input where they meet.

---

**Issue 12: `surveyreports_error_vars_empty_selection` is reused with a message that is wrong for the new trigger**
Severity: REQUIRED
The spec, the test-spec and gate IX cannot all hold at once.

Section 5.5 routes the all-dropped `vars` case to the **existing**
`surveyreports_error_vars_empty_selection`. Measured — that class is raised at
`R/export-utils.R:43-51` with this message:

```r
"x" = "{.arg vars} did not select any columns.",
"i" = "The tidyselect expression resolved to an empty set.",
"v" = "Use bare column names or a tidyselect helper that matches existing columns."
```

The `"i"` bullet is false for the new trigger. Tidyselect resolved fine; the
role guard emptied the set afterwards. The `"v"` bullet sends the caller to fix
a tidyselect expression that is correct.

The test-spec then asks for more than the class. `TE-01` says: "Assert that the
abort fires, and that the message names the dropped columns." The current
message names no column, and the spec specifies no message change.

Gate IX closes the loop: "No committed snapshot changed." Changing the shared
message changes the existing snapshot for the existing trigger.

So one of three things must give, and the spec chooses none of them.

Options:
- **[A]** Add a new class, `surveyreports_error_vars_all_dropped`, with its own
  message naming the dropped columns and their roles. Add it to section VIII
  and to `plans/error-messages.md` — Effort: low, Risk: low, Impact: `TE-01`
  becomes writable, no existing snapshot moves, the caller gets an accurate
  fix, Maintenance: one more class in the table.
- **[B]** Keep the shared class and branch its message on the cause. The
  existing trigger keeps today's text; the role trigger gets its own bullets —
  Effort: low, Risk: medium, Impact: `TE-01` becomes writable, one class covers
  two causes, and a caller who filters on the class cannot tell them apart.
- **[C] Do nothing** — the tester writes `TE-01`, it fails on the message
  assertion, and the fix arrives at implementation time as an unplanned class.

**Recommendation: A** — `plans/error-messages.md` already gives each condition
its own class, and section 5.5 created a new condition, not a new path to an old
one. The same reasoning already gave `banner` its own
`surveyreports_error_banner_empty_selection`; `vars` should not be treated
differently.

---

#### Section: VI. Workstream 4

**Issue 13: Routing only the `wb_add_worksheet()` call leaves the render helper writing to the colliding name**
Severity: REQUIRED
The specified change does not produce the specified behavior.

Section 2.1 says: "**route all three `wb_add_worksheet()` calls through
`.unique_sheet_name()`**". Section 6.2.1 repeats it: "`R/export-crosstab.R`
routes all three `wb_add_worksheet()` calls — `:209`, `:231`, `:253` — through
it."

Measured — each call site computes `sheet_name` first, and then uses it twice:

```r
207:        sheet_name <- substr(var, 1L, 31L)
209:        wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)
210:        result <- .render_crosstab_single(
211:          wb,
212:          sheet_name,
```

The SATA and battery sites have the same shape at `:226`/`:231`/`:233` and
`:248`/`:253`/`:255`.

A literal reading of the instruction gives
`wb <- wb_add_worksheet(wb, .unique_sheet_name(wb, sheet_name))`. The workbook
then holds `About_2`, and the render helper writes its question block into
`About` — the cover sheet — because `sheet_name` never changed. The cover sheet
is overwritten and the data sheet stays empty.

`XP-22` asserts sheet **names** only ("the workbook holds `About` and
`About_2`; the cover sheet keeps the name `About`"), so it passes while the
cover sheet's contents are destroyed.

The correct change is an assignment: `sheet_name <- .unique_sheet_name(wb,
sheet_name)`, placed after the `substr()` and before both uses.

Options:
- **[A]** Restate section 6.2.1's owner row as an assignment to `sheet_name`
  before the add and the render, and name the three `substr()` lines — `:207`,
  `:226`, `:248` — as the insertion points. Add a content assertion to `XP-22`:
  the `About` sheet still holds `Key` in `A1` — Effort: low, Risk: low,
  Impact: the change produces the specified behavior and the test catches the
  failure mode, Maintenance: none.
- **[B]** Rename the **cover** sheet instead when a data sheet would collide —
  Effort: medium, Risk: medium, Impact: it reverses the decision logged on
  2026-09-10 that the data sheet is suffixed because the user cannot rename the
  cover sheet.
- **[C] Do nothing** — a builder follows the instruction literally and ships a
  crosstab that silently overwrites its own cover sheet.

**Recommendation: A** — the decision is right and only the mechanism is
under-specified. Option B re-opens a logged decision for no gain.

---

**Issue 14: "the active sheet" is asserted, not measured**
Severity: REQUIRED
A claim both documents assert, which the spec's stated reasoning does not
support.

Section 6.2.1 says:

> `openxlsx2::wb_workbook()` creates no sheets, so `"About"` becomes sheet 1
> and the active sheet. A workbook with dataset metadata **opens on the cover
> sheet**. This is intended.

The premise establishes the **position** only. Being sheet 1 and being the
active sheet are two different properties of an `.xlsx` file: position is sheet
order, and the active sheet is the `activeTab` entry in the workbook's
`bookViews`.

Every other upstream fact in this spec carries a measurement and a date.
This one does not, and it is the only claim in section VI about openxlsx2's own
behavior rather than surveycore's.

After the cover sheet is written, `wb_add_worksheet()` runs again — once in
`export_topline()` at `R/export-topline.R:129`, and up to four times in
`export_crosstab()`. If `openxlsx2::wb_add_worksheet()` sets the sheet it adds
as the active one, the last data sheet is active and the claim is false.

Both documents depend on it. `TP-11` asserts "it is the first sheet and the
active sheet". `XP-20` asserts "it is first and active". The test-spec's Result
structure sections assert it again for both functions.

I could not settle this without running R, which is outside this review's scope.

Options:
- **[A]** Measure it. If `wb_add_worksheet()` moves the active sheet, add
  `openxlsx2::wb_set_active_sheet(wb, "About")` as the last step of the export
  function, after every data sheet is written, and say so in section 6.2.1 —
  Effort: low, Risk: low, Impact: the workbook opens where both documents say
  it opens, Maintenance: one call at the end of two functions.
- **[B]** Drop the active-sheet claim from both documents and assert position
  only — Effort: low, Risk: low, Impact: the cover sheet is sheet 1 and the
  workbook opens wherever openxlsx2 leaves it, which may differ between the two
  functions and between layouts.
- **[C] Do nothing** — four test assertions rest on an unmeasured claim, and
  they fail at implementation time rather than at review time.

**Recommendation: A** — every other upstream fact in this spec was measured
before it was written. This one deserves the same treatment, and the fix if it
fails is one call.

---

**Issue 15: Four of the six cover-sheet keys, and the bold column A, have no scenario**
Severity: SUGGESTION
Lens 2 — a contract item with no scenario.

Section 6.2 defines six key-to-label mappings:

| Key | Display label |
|---|---|
| `survey_name` | Survey |
| `data_name` | Dataset |
| `vendor` | Vendor |
| `field_start` | Field start |
| `field_end` | Field end |
| `field_period` | Field period |

`TP-11` and `XP-20` set `survey_name` and `vendor` only, and assert the two
rows they produce. `data_name`, `field_start`, `field_end` and `field_period`
are never written, so four of the six display labels and the "surveycore's
canonical key order" rule are unasserted. A transposed label or a wrong order
ships.

Section 6.2 also says "Column A is bold", and section 6.3.1 says the wave
heading is bold. No scenario reads a cell's style.

Options:
- **[A]** Extend `TP-11` to set all six keys and assert the six display labels
  in canonical order. Add one style assertion for column A — Effort: low, Risk:
  low, Impact: the label map and the order are covered, Maintenance: one
  scenario grows.
- **[B]** Extend `TP-11` to all six keys and drop the bold rule from section
  6.2, since it is presentation and no scenario needs to guard it — Effort:
  low, Risk: low, Impact: the contract shrinks to what is asserted.
- **[C] Do nothing** — four labels and the key order are written once and never
  checked.

**Recommendation: A** — six keys cost one more `set_dataset_metadata()` call in
a scenario that already exists.

---

#### Section: VII. Workstream 5

**Issue 16: The `all_of()` before-and-after snippet does not match `R/export-topline.R`**
Severity: REQUIRED
A code snippet in the spec is correct for one of its two call sites.

Section 7.1 gives one "before" for both files:

```r
classify_out <- surveycore::classify_question_type(design, vars_resolved)
```

That is `R/export-crosstab.R:179`, exactly. It is **not**
`R/export-topline.R:112-115`. Measured:

```r
105:  design_for_classify <- if (
106:    S7::S7_inherits(design, surveycore::survey_collection)
107:  ) {
108:    design@surveys[[1L]]
109:  } else {
110:    design
111:  }
112:  classify_out <- surveycore::classify_question_type(
113:    design_for_classify,
114:    vars_resolved
115:  )
```

The topline call passes `design_for_classify`, because
`classify_question_type()` needs a single design and `export_topline()` accepts
a collection. Section 7.2's "after" snippet keeps `design`. A builder who
applies it literally to `R/export-topline.R` replaces `design_for_classify`
with `design` and breaks every trend workbook — the same failure mode section
4.4 warns about for `extract_universe()`.

Options:
- **[A]** Give section 7.2 two snippets, one per file, with the topline one
  keeping `design_for_classify` — Effort: low, Risk: low, Impact: the builder
  cannot regress the collection path, Maintenance: none.
- **[B]** Replace both snippets with a one-line instruction: wrap the resolved
  vector in `tidyselect::all_of()` at both call sites, and change nothing else
  — Effort: low, Risk: low, Impact: the same protection with less text.
- **[C] Do nothing** — the workstream the spec calls "Cleanup" is the one that
  can silently break the collection path.

**Recommendation: B** — the change is one wrapper, and a snippet that shows the
surrounding call invites a copy that is wrong for one of the two files.

---

#### Section: VIII. Error and warning classes

**Issue 17: `surveyreports_warning_duplicate_value_label` was never in `plans/error-messages.md`**
Severity: SUGGESTION
A measured claim in section VIII and gate IX does not hold.

Section VIII says the class "from the previous draft is **removed**". Gate IX
asks a checker to confirm that `plans/error-messages.md` "no longer lists
`surveyreports_warning_duplicate_value_label`".

Measured — `plans/error-messages.md` holds five warning classes:
`surveyreports_warning_example`,
`surveyreports_warning_pool_pvals_input_pre_adjusted`,
`surveyreports_warning_pool_pvals_no_pvalues_available`,
`surveyreports_warning_subgroup_suppressed`, and
`surveyreports_warning_missing_variable_label`. The duplicate-label class is
not among them. It existed only in an earlier draft of this spec, which never
reached the table.

The gate is therefore satisfied before any work starts, and a reader is told to
undo an edit that was never made.

Every other class the spec references was checked and does exist:
`surveyreports_error_vars_empty_selection`,
`surveyreports_error_empty_domain`,
`surveyreports_error_collection_not_supported_for_crosstab`,
`surveyreports_error_not_survey_object`, and
`surveyreports_warning_subgroup_suppressed`.

Options:
- **[A]** Change section VIII to say the class was proposed in an earlier draft
  and never added, and delete the second half of the gate IX line — Effort:
  low, Risk: low, Impact: the gate checks four additions and nothing else,
  Maintenance: none.
- **[B]** Delete the sentence and the gate clause with no replacement —
  Effort: low, Risk: low, Impact: the same, with no record of the reversal.
  The reversal itself is already recorded in
  `plans/decisions-export-metadata.md`, issue 6.
- **[C] Do nothing** — a gate reads as a real check and passes vacuously.

**Recommendation: B** — the decisions log already carries the history, and
section 3.6 already states the abort.

---

#### Section: IX–XI. Quality gates, dependency sequencing, open questions

**Issue 18: Renumbering left a dangling reference and a missing separator**
Severity: SUGGESTION
Seams from the removal of the spec's Testing section.

Two artefacts remain from the cut:

- Line 1179, in the "Closed by decision, pass 2" table, gives issue 15's
  sections as "1.2.1, 3.5, **9.2**, X". There is no section 9.2. Section IX has
  no subsections; it is a flat checklist. The content that was section 9.2 is
  now the test-spec's per-function tables.
- Section IX has no `---` rule and no blank line before it. Every other
  top-level section in the document has one.

The rest of the renumbering held. Section 1.3.1's reference to "the
no-snapshot-change gate of section IX" is correct, and sections I to XI are
present and in order with no gap.

The content that was cut appears not to have been lost. Each test row the
decisions log cites by number has a successor in the test-spec: row 26 is
`XP-08`, row 27 is `XP-04` and `XP-07`, row 28 is `TW-05` and `XW-05`, row 29
is `TC-08`, row 30 is `TP-02` and `TP-06`.

Options:
- **[A]** Change "9.2" to a test-spec-free reference — the sections that
  actually carry the decision are 1.2.1, 3.5 and X. Add the missing separator
  — Effort: low, Risk: low, Impact: no dangling reference, Maintenance: none.
- **[B]** Fix the separator only and leave "9.2" — Effort: low, Risk: low,
  Impact: a reader hunts for a section that does not exist.
- **[C] Do nothing.**

**Recommendation: A** — both are one-character edits.

---

#### Section: Documentation (whole spec)

**Issue 19: No documentation tier is assigned, and no roxygen content is specified**
Severity: REQUIRED
Violates `.claude/standards/function-documentation.md` and Lens 3.

The spec never assigns a documentation tier to `export_topline()` or
`export_crosstab()`, and it specifies no roxygen change for either. Section 2.1's
file table lists six files and no `man/` entry. Gate IX asks only that
`devtools::document()` was run.

`function-documentation.md` names both functions in its illustrative examples,
under **Tier 2 — Standard** and again under **Tier 4 — Dispatcher**. Whichever
tier applies, both require an Output Columns or Workbook Layout section and a
Design Types section, and Tier 4 also requires `@details` and `@seealso`.

Four user-visible behaviors change on arguments that already have `@param`
entries:

1. `base_notes` — a note now appears from `universe` metadata when the caller
   supplies none, subject to the unanimity rule of section 4.5.
2. `vars` — a column is dropped for its `role`, and an all-dropped selection
   aborts.
3. `banner` — the same, with its own error class.
4. The workbook shape — a new `"About"` sheet becomes sheet 1 when the design
   carries dataset metadata.

None of these is documented anywhere the user can see. `devtools::document()`
regenerates `man/` from unchanged roxygen, so gate IX passes with the help
pages describing behavior the package no longer has. `R CMD check` raises
nothing, so no other gate catches it either.

Section 1.3 says "No change to the signature ... No new user-facing argument",
which is true and is not the same as no change to the documented behavior.

Options:
- **[A]** Add a documentation section to the spec: assign the tier, and name
  the `@param` entries and the named sections each workstream changes —
  `base_notes`, `vars`, `banner`, and a Workbook Layout note for the cover
  sheet. Add `man/` to section 2.1's file table — Effort: medium, Risk: low,
  Impact: the builder has a documentation target and the reviewer can check the
  tier, Maintenance: the docs track the behavior.
- **[B]** Add one gate to section IX: the four changed behaviors each appear in
  the rendered help page — Effort: low, Risk: medium, Impact: the gate catches
  an omission but the builder still guesses the wording and the section
  placement.
- **[C] Do nothing** — two exported functions ship with help pages that
  describe the old behavior, and the omission passes every gate.

**Recommendation: A** — the standard exists to stop exactly this, and the tier
decides which sections are required.

---

#### Section: Test-spec — completeness

**Issue 20: SATA dispatch, variance options, and the missing-label warning are neither covered nor marked N/A**
Severity: REQUIRED
Violates `.claude/rules/testing.md` — the section templates, and Lens 2's rule
that a category which does not apply is marked N/A with a reason.

`testing.md` gives a numbered section template for each test file. Checked
against the test-spec:

| Template section | Test-spec |
|---|---|
| var_type dispatch — SATA and battery blocks | battery covered by `TP-03`–`TP-06`, `XP-11`–`XP-14`. **SATA: no row** |
| Variance options — `variance = NULL`, `"se"`, `"ci"` | **no row, no N/A** |
| Missing metadata warning — one warning listing every affected variable | **no row, no N/A** |
| Layout — `per_question` and `stacked` | `per_question` in `XP-22`, `XP-23`. `stacked` in the Result structure section only |
| Self-banner — a variable used as its own banner | **no row, no N/A** |

SATA is the one that matters. `make_all_designs()` applies
`surveycore::set_sata()` to `sata_a`, `sata_b` and `sata_c`, so a SATA group is
a standard fixture, and issue 11 above shows the role guard can drop one of its
members. Neither the universe fallback nor the role guard is exercised against
a SATA block anywhere in the document.

Variance and the missing-label warning are plausibly N/A — this spec changes
neither — but `testing.md` and Lens 2 both make N/A a stated decision rather
than an omission. A reader cannot currently tell a considered N/A from a
forgotten row.

Options:
- **[A]** Add a SATA row to the universe table and one to the role table for
  each function. Add an "N/A for this change" note for variance options, the
  missing-label warning, and the self-banner path, each with its reason —
  Effort: low, Risk: low, Impact: every template section is answered, and the
  SATA seam gets coverage, Maintenance: four more scenarios.
- **[B]** Add the N/A notes only, and rely on the battery rows to cover the
  group path — Effort: low, Risk: medium, Impact: SATA and battery take
  different render helpers (`.render_crosstab_sata()` against
  `.render_crosstab_battery()`), so one does not stand in for the other.
- **[C] Do nothing** — the tester cannot tell which omissions were decided.

**Recommendation: A** — the SATA rows are the same shape as the battery rows
that are already written, and the N/A notes cost three sentences.

---

**Issue 21: `layout = "stacked"` with a cover sheet, and the self-banner path with a role drop, have no scenario**
Severity: SUGGESTION
Lens 2 and Lens 6 — two realistic combinations with no row.

`XP-20` to `XP-23` all describe the cover sheet against `per_question`. The
stacked layout takes a different code path: `R/export-crosstab.R:274` adds one
sheet with the literal name `"Crosstab"`, outside the loop that `:209`, `:231`
and `:253` sit in. No scenario writes a cover sheet under `layout = "stacked"`,
so the "About is sheet 1 and active" claim of issue 14 is asserted for one
layout only.

The self-banner path is the second gap. `R/export-utils.R:475-477` skips a
banner column that equals the variable being tabulated. A variable can now be
kept in `vars` and dropped from `banner`, or the reverse, because the role guard
runs on the two arguments separately. No scenario crosses the two.

Options:
- **[A]** Add one scenario for a cover sheet under `layout = "stacked"`, and
  one for a variable that appears in both `vars` and `banner` with a
  non-substantive role — Effort: low, Risk: low, Impact: both layouts and the
  self-banner path are covered, Maintenance: two more scenarios.
- **[B]** Add the stacked-layout row only, and mark the self-banner path N/A
  because the guard treats the two arguments independently by design —
  Effort: low, Risk: low, Impact: the layout gap closes; the self-banner
  interaction stays unasserted.
- **[C] Do nothing** — the cover sheet is proven on one of two layouts.

**Recommendation: A** — a stacked-layout cover sheet is one line of setup in a
scenario that already exists.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 10 |
| SUGGESTION | 7 |

**Total issues:** 21

**Overall assessment:** The methodology is sound and unusually well measured —
the delegation to `get_effective_n()`, the three collection branches, and the
unanimity rule are each specified to a level a builder can implement — but the
spec is not yet implementable, because it defines no behavior for four seams
between its own workstreams (`interactions` against a dropped banner column, a
dropped group member, an unlabelled-code count above one, and the reused
`vars_empty_selection` message), omits a whole design subclass that
`testing.md` requires, and specifies no documentation change for two exported
functions whose user-visible behavior it changes.

### What could not be verified

- Whether `openxlsx2::wb_add_worksheet()` moves the active sheet. This decides
  issue 14 and four test assertions. It needs an R session, which is outside
  this review's scope.
- Whether `surveycore::get_effective_n()` returns one row or two for a banner
  column with two unlabelled observed codes. This decides issue 7.
- Whether `surveycore::classify_question_type()` still returns a battery for the
  two surviving members of a three-member group. This decides issue 11.

All three are single measurements of the kind section 1.2 already ran.

---

## Measurements taken after Pass 1 (2026-09-10)

Pass 1 listed three questions it could not answer without an R session. All
three ran against R 4.6.1, surveycore `1.1.0.9000` and openxlsx2 `1.28`, in
this repository. The results below are facts, not options.

### M1 — two unlabelled codes on one banner column (decides issue 7)

A banner with three observed codes, where only code 1 carries a label:

```
> get_effective_n(d, group = gen)
   gen   n     n_eff deff_kish
1 Male 150 140.07773  1.070834
2 <NA>  80  74.52510  1.073464
3 <NA>  70  64.44617  1.086178
```

**Three rows. Two of them key as `NA`.** `get_freqs(d, q1, group = gen)` agrees
— it returns six rows for the two unlabelled codes, all headed `<NA>`, and
`unique()` collapses them to one value.

The consequence is worse than Pass 1 supposed. The spec's rule "an unlabelled
code gives `level = NA_character_`" is not a one-row case. Two unlabelled codes
produce two distinct subgroups with different counts that share one key. So:

- A join on the level string matches one key to two rows.
- A suppression footnote prints `gen=NA` twice, and a reader cannot tell which
  subgroup each line names.
- An `%in%` filter on a missing value removes **both** subgroups when only one
  falls below the threshold.
- A crosstab renders two column groups with the same `NA` heading and
  different numbers.

Issue 7 is confirmed, and its severity rises. This is not an unspecified edge
case; it is a silent wrong answer on data that surveycore accepts.

### M2 — the active sheet (decides issue 14)

```
active after 1/2/3 sheets:   /   /       (numeric(0) each time)
after save+load active: 1
after save+load names: About,Q1,Q2
```

`get_active_sheet()` returns `numeric(0)` on a workbook held in memory. No
active sheet is set while the workbook is built. After a save and a reload it
reads `1`, the first sheet.

So the spec's claim holds for the written file: a workbook whose first sheet is
`About` opens on `About`. Adding later sheets does **not** move it. But the
claim is only observable after a reload, and a test that asserts it on a
workbook still in memory compares against `numeric(0)`.

### M3 — a partially dropped battery (decides issue 11)

A three-member battery, classified with three, two, then one member selected:

| Members selected | `type` | `group` |
|---|---|---|
| `bat_1`, `bat_2`, `bat_3` | `battery` | 1 |
| `bat_1`, `bat_2` | `battery` | 1 |
| `bat_1` | **`single`** | 1 |

Dropping one member of a three-member battery is safe: the remaining two still
classify as a battery, with the group id unchanged. Dropping two members is
not: the last survivor silently reclassifies as a single-response question and
renders as its own block, with no preface.

So the role guard changes a question's rendered shape when it leaves exactly
one member of a group. Issue 11 needs a rule for that case only.

---

## Spec Review: export-metadata — Pass 2 (2026-09-10)

Delta pass. Artifacts read in full:

- `plans/spec-export-metadata.md` v0.5.0
- `plans/test-spec-export-metadata.md` (124 ids: 118 scenarios plus 6 regression
  rows)
- `plans/decisions-export-metadata.md`, the Stage 3 resolve entry

Supporting files read: `.claude/standards/function-documentation.md` (Tier 4),
`.claude/rules/testing.md`, `plans/error-messages.md`.

Repository claims were re-measured against `R/export-utils.R`,
`R/export-crosstab.R`, `R/export-topline.R`,
`tests/testthat/helper-test-data.R` and `plans/error-messages.md`. Every claim
Pass 1 found wrong is now correct. The claims added during resolution were spot
checked, and all held except the two named in issues 23 and 25.

### Prior Issues (Pass 1)

| # | Severity | Status | Note |
|---|---|---|---|
| 1 | BLOCKING | RESOLVED | `TX-08`, `XX-08` and `XX-09` carry real assertions. Section 3.5 gains the unused-factor-level row; section 5.7 fixes the domain-before-guard order. |
| 2 | BLOCKING | RESOLVED | Section IX is source-tree checks only. The `119` figure sits in `TN-03`. The two coverage floors now agree. Residual duplication: issue 30. |
| 3 | BLOCKING | RESOLVED | Section 1.4 gains the `survey_nonprob` row, section 1.5 makes the fixture a deliverable, section 2.1 lists `helper-test-data.R`, `RG-06` asserts the count of 4. |
| 4 | REQUIRED | RESOLVED | `.apply_role_guard(design, cols, arg, empty_class)` is in sections 2.1 and 2.2, with its four steps in order. |
| 5 | REQUIRED | RESOLVED | Section 6.2.1 states four call sites and excludes `:274` with the reason. Measured — `R/export-crosstab.R` holds four. |
| 6 | SUGGESTION | RESOLVED | `.unique_sheet_name()` moves to `R/export-crosstab.R` in sections 2.1, 2.2 and 6.2.1. Two stale statements remain elsewhere: issue 23. |
| 7 | REQUIRED | RESOLVED | Section 3.6.1 aborts, per the measurement. The class is in section VIII, and `XE-04` uses the dual pattern. Section 3.5's table marks the case unreachable. |
| 8 | SUGGESTION | RESOLVED | The decayed ranges are gone. Section 3.8 and gate IX both say three `# nocov` markers. Measured — three. |
| 9 | SUGGESTION | REGRESSED | Section 3.4 now states both changes. The two new scenarios `TN-05b` and `TN-05c` sit in the `export_topline()` table, where no suppression footnote can exist. Issue 22. |
| 10 | BLOCKING | RESOLVED | Section 5.5.2 re-validates `interactions` after the guard. Section 5.5 carries the row. `XE-05`, `XE-06` and `XE-07` cover it. |
| 11 | REQUIRED | PARTIAL | Section 5.6.1 defines all three cases, and `TP-09b`–`TP-09g` and `XP-18b`–`XP-18e` cover them. The sheet-name rule is asserted on the wrong function: issue 24. |
| 12 | REQUIRED | RESOLVED | Section 5.5.1 adds `surveyreports_error_vars_all_dropped`. The class is in section VIII. `TE-01` and `TE-01b` separate it from the tidyselect class. |
| 13 | REQUIRED | RESOLVED | Section 6.2.1's Mechanism row assigns to `sheet_name` before both uses, and names `:207`, `:226`, `:248`. `XP-22` asserts the cover sheet's cells. |
| 14 | REQUIRED | PARTIAL | Section 6.2.1 records the measurement, and `TP-11c` and `XP-20b` save and reload. Both Result structure lists still say "the active sheet is `About`" with no reload, and they apply "in every block". |
| 15 | SUGGESTION | RESOLVED | `TP-11` sets all six keys, asserts an ordered label vector, and asserts column A bold. `XP-20` sets six keys and asserts the order. |
| 16 | REQUIRED | RESOLVED | Section 7.2 gives no snippet. It names the two first arguments and the failure mode a copied snippet would cause. |
| 17 | SUGGESTION | RESOLVED | The sentence and the gate clause are gone. Measured — `surveyreports_warning_duplicate_value_label` was never in `plans/error-messages.md`. |
| 18 | SUGGESTION | RESOLVED | The `9.2` reference now reads `IX`. Sections I to XI are present and in order. A new malformed rule appears before VIII-A: issue 29. |
| 19 | REQUIRED | RESOLVED | Section VIII-A exists and assigns Tier 4. Its content carries two gaps: issues 25 and 26. |
| 20 | REQUIRED | RESOLVED | SATA rows `TP-09d`, `TP-09g`, `XP-18d`, `XP-18e`. The "Template sections marked N/A" table records five template sections with a reason each. |
| 21 | SUGGESTION | RESOLVED | `XP-22b` covers the stacked layout. `XP-18f` covers the self-banner path. |

**Counts:** RESOLVED 18, PARTIAL 2, NOT RESOLVED 0, REGRESSED 1.

### New Issues

#### Section: Test-spec — `export_topline()` numerical accuracy

**Issue 22: `TN-05b` and `TN-05c` cannot run against `export_topline()`**
Severity: BLOCKING
The two scenarios that close Pass 1 issue 9 are written against a function that
raises no suppression footnote.

Both rows assert the `n=` count inside the suppression footnote, and both sit
in the `export_topline()` numerical accuracy table.

Measured:

- `export_topline()` has no `pub_type` argument. `R/export-topline.R:54-64`
  gives its nine formals, and the test-spec's own "Functions under test" table
  repeats them.
- `R/export-topline.R:118` calls `.build_freq_frame()` with no `pub_type` and
  no `banner_resolved`.
- `R/export-utils.R:415` guards the suppression loop with
  `pub_type != "none" && !is.null(banner_resolved)`.
- `plans/error-messages.md` lists `surveyreports_warning_subgroup_suppressed`
  under `export_crosstab()` only.

So `suppressed` is always empty for a topline workbook, and the footnote is
never written. The test-spec contradicts itself two pages apart: its
"Functions under test" section states "No banner scenario and no suppression
scenario is written against it."

The consequence is the one Pass 1 issue 9 set out to prevent. The footnote's
label change is asserted by `XP-02`. The footnote's corrected `n=` count is
asserted nowhere a tester can reach it.

Options:
- **[A]** Move `TN-05b` and `TN-05c` to the `export_crosstab()` numerical
  accuracy table as `XN-08` and `XN-09`. Keep the text unchanged — Effort: low,
  Risk: low, Impact: the corrected count gains an assertion on the function
  that produces it, Maintenance: none.
- **[B]** Delete both rows and record the footnote count as unasserted —
  Effort: low, Risk: medium, Impact: the twophase correction reaches the user
  through a string that no test reads.
- **[C] Do nothing** — the tester writes two rows against a function with no
  `pub_type` argument, and both fail at the call.

**Recommendation: A** — the rows are correct; only their table is wrong.

---

#### Section: IX. Quality gates, and XI. Open questions

**Issue 23: Gate IX and section XI both contradict section 2.1 on `.unique_sheet_name()`**
Severity: REQUIRED
The fix for Pass 1 issue 6 landed in three sections and not in two others.

Section 2.1 places `.unique_sheet_name()` in `R/export-crosstab.R`, below the
exported function. Section 2.2 repeats it in the helper's comment block.
Section 6.2.1's Owner row repeats it again.

Two other places still carry the superseded placement:

| Location | Text |
|---|---|
| Gate IX, bullet 3 | "`R/export-utils.R` holds all **8** new helpers" |
| Section XI, Stage 2 pass 2 table, issue 22 | "A shared `.unique_sheet_name()` in `R/export-utils.R`, over all **three** `wb_add_worksheet()` call sites" |

The section XI row also contradicts the fix for Pass 1 issue 5, which counted
four call sites.

The count is wrong as well. Section 2.2 declares 8 helpers, but sections 4.4
and 5.6 use two more that no section declares — `.design_universe()` at line
768 and `.roles_of()` at line 1055. Measured — neither exists in `R/`. So the
gate asks a reviewer to confirm 8 helpers in one file, when 7 belong in that
file, 1 belongs in another, and 2 more are unlisted.

A reviewer who runs gate IX literally would move `.unique_sheet_name()` back
and undo the issue 6 fix.

Options:
- **[A]** Change gate IX to "`R/export-utils.R` holds the 7 shared helpers of
  section 2.1, and `R/export-crosstab.R` holds `.unique_sheet_name()`". Add
  `.design_universe()` and `.roles_of()` to sections 2.1 and 2.2. Update the
  section XI issue 22 row to name `R/export-crosstab.R` and four call sites —
  Effort: low, Risk: low, Impact: one placement statement across five sections,
  Maintenance: none.
- **[B]** Fix gate IX and the section XI row only, and leave the two helpers
  undeclared — Effort: low, Risk: medium, Impact: the contradiction closes; the
  builder still meets two helper names for the first time inside pseudocode.
- **[C] Do nothing** — a gate instructs a reviewer to reverse a logged
  decision.

**Recommendation: A** — the two undeclared helpers are the reason the count is
wrong, so fixing the count without declaring them leaves the next reader with
the same arithmetic.

---

#### Section: Test-spec — group-member drops

**Issue 24: The sheet-name rule of section 5.6.1 is asserted on the function that has no per-question sheets**
Severity: REQUIRED
`TP-09f` is unwritable as titled, and the crosstab has no equivalent row.

Section 5.6.1 states: "The sheet name follows the first survivor.
`R/export-crosstab.R:226` and `:248` take the sheet name from
`group_vars[[1L]]`, so dropping `bat_1` renames the sheet to `bat_2`." The rule
cites two crosstab lines and applies to `export_crosstab()`.

`TP-09f` carries it, under `export_topline`: "the sheet name follows the first
survivor ... the block is named for `bat_2`".

Measured — `export_topline()` writes one sheet. `R/export-topline.R:129` is
`wb_add_worksheet(wb, "Topline")`, and it is the only such call in the file.
Section 6.2.1 states the same fact. So a topline sheet name never follows a
variable, and the row's expected result cannot be read from a topline workbook.

`XP-18b` to `XP-18f` cover the battery type, the last-survivor case, the SATA
group, the SATA universe and the self-banner path. None of them asserts the
sheet name. So the one rule in section 5.6.1 that names a file and a line has
no scenario on the function it applies to.

Options:
- **[A]** Move the row to the `export_crosstab()` table as `XP-18g`, asserting
  that the sheet is named `bat_2` when `bat_1` is dropped under
  `layout = "per_question"` — Effort: low, Risk: low, Impact: the rule is
  asserted where it holds, Maintenance: none.
- **[B]** Rewrite `TP-09f` to assert the block heading rather than the sheet
  name, and add a separate crosstab row for the sheet name — Effort: low, Risk:
  low, Impact: both functions covered; the topline row asserts a rule section
  5.6.1 does not state.
- **[C] Do nothing** — the tester writes an assertion against a sheet name that
  is always `"Topline"`.

**Recommendation: A** — the rule is crosstab-only, and section 5.6.1 says so.

---

#### Section: VIII-A. Documentation

**Issue 25: Section VIII-A assigns Tier 4 and assumes two roxygen blocks that neither function has**
Severity: REQUIRED
A measured claim in a new section does not hold.

Section 8a.1 says both functions are Tier 4 and that "Neither function changes
tier." Section 8a.3 then asks the builder to **add** one item to
`@section Workbook Layout` and one sentence to `@details`.

Measured — `grep -n "@details|@section|@seealso" R/export-topline.R
R/export-crosstab.R` returns two lines, both `@seealso`:

```
R/export-topline.R:52:  #' @seealso [surveycore::get_freqs()] ...
R/export-crosstab.R:68: #' @seealso [export_topline()] ...
```

Neither function has an `@details` block. Neither has a
`@section Workbook Layout`. `function-documentation.md` requires both of a Tier
4 function, and requires `@seealso` to "Link to every function it routes to" —
`export_topline()` links to `surveycore::get_freqs()` only, not to
`export_crosstab()`.

So section VIII-A declares a tier the two functions do not currently meet, and
then specifies edits to blocks that must first be written whole. Section 8a.3
also states that `@seealso` is unchanged, which keeps the existing shortfall.

Gate IX checks only "the four changed behaviors of section 8a.2 each appear in
the rendered help page". A two-line `@details` naming the role guard passes
that gate while the Tier 4 requirement stays unmet.

Options:
- **[A]** State in 8a.1 that neither block exists today, and make writing a
  full `@details` route overview and a full `@section Workbook Layout` a
  deliverable for both functions. Add `export_crosstab()` to
  `export_topline()`'s `@seealso`. Add a gate IX line for the three Tier 4
  requirements — Effort: medium, Risk: low, Impact: the tier the spec assigns
  is the tier the package ships, Maintenance: two documentation blocks to keep
  current.
- **[B]** Keep the four behavior edits and record the missing Tier 4 blocks as
  a parked follow-up, the way sections 1.3.1 and 1.3.2 park other work —
  Effort: low, Risk: medium, Impact: the spec assigns a tier it does not
  deliver, and says so.
- **[C] Do nothing** — the builder is told to add a sentence to a block that
  does not exist, and guesses whether to create it.

**Recommendation: A** — Pass 1 issue 19 exists because no gate catches a
documentation omission. Assigning the tier without checking conformance
reproduces the gap one level up.

---

**Issue 26: The two new banner aborts are absent from section VIII-A**
Severity: REQUIRED
Lens 3 — a contract item with no documentation target.

Section 8a.2 lists four changed behaviors. Section VIII adds six classes. Two
of them reach the user on ordinary data and appear in neither 8a.2 nor 8a.3:

| Class | Trigger |
|---|---|
| `surveyreports_error_duplicate_value_label` | a surviving `banner` column carries one label on 2 or more codes |
| `surveyreports_error_multiple_unlabelled_codes` | a surviving `banner` column carries 2 or more observed unlabelled codes |

Both are new aborts on `banner`, and both are reachable from a labelled banner
that surveycore itself accepts — section 3.6.1 measured exactly that input.
Section 8a.3's `@param banner` row names the role rule and the `interactions`
abort, and stops there.

Gate IX asks only for the four behaviors of 8a.2, so the omission passes every
gate, which is the failure mode section 8a.2 was written to close.

Options:
- **[A]** Add both aborts to 8a.2's table and to 8a.3's `@param banner` row —
  Effort: low, Risk: low, Impact: a caller reads why the call stopped before
  they read the error, Maintenance: none.
- **[B]** Add them to 8a.3 only, and leave 8a.2's table at four — Effort: low,
  Risk: medium, Impact: the roxygen is right; gate IX still counts four.
- **[C] Do nothing** — two new aborts ship undocumented.

**Recommendation: A** — the gate reads 8a.2's table, so a change that is not in
the table is not gated.

---

#### Section: Test-spec — collection cover sheet

**Issue 27: `TC-05` does not assert the key order or the bold heading that section 6.3.1 specifies**
Severity: SUGGESTION
Lens 2 — the gap Pass 1 issue 15 closed for the single-design sheet is open for
the per-wave sheet.

Section 6.3.1 sets four rules for a wave block: the wave name in column A,
**bold**; the wave's set keys in **surveycore's canonical key order**; one blank
row between blocks; none after the last.

`TC-05` asserts the block structure and the blank rows. It does not assert the
key order, and no scenario asserts that the wave heading is bold. `TC-06`
asserts a heading with no rows under it and does not assert its style either.

`TP-11` was extended in this resolution to assert the six labels "as an ordered
character vector, so a transposed pair fails". The per-wave sheet uses the same
canonical order and did not get the same treatment.

Options:
- **[A]** Extend `TC-05` to set three or more keys per wave and assert the
  labels as an ordered character vector, and add one style assertion for the
  wave heading — Effort: low, Risk: low, Impact: both cover-sheet shapes are
  covered to the same depth, Maintenance: one scenario grows.
- **[B]** Extend `TC-05` for the order only, and drop the bold rule for the
  wave heading from section 6.3.1 — Effort: low, Risk: low, Impact: the
  contract shrinks to what is asserted.
- **[C] Do nothing** — the wave key order is written once and never checked.

**Recommendation: A** — it is the same edit `TP-11` already took.

---

#### Section: Test-spec — header

**Issue 28: The test-spec header still reads v0.1.0 and "DRAFT — not spec-reviewed"**
Severity: SUGGESTION
The document went through the Stage 3 review and gained 27 scenarios. Its
header records neither.

The spec moved to v0.5.0 and to "Spec-reviewed and resolved". The test-spec
header is unchanged: `**Version:** 0.1.0`, `**Status:** DRAFT — not
spec-reviewed`. A reader who checks the status before running the scenarios is
told the document has not been reviewed.

Options:
- **[A]** Bump the version and set the status to match the spec's — Effort:
  low, Risk: low, Impact: the two artifacts state the same stage,
  Maintenance: none.
- **[B] Do nothing** — the tester reads "DRAFT" on the artifact they are meant
  to work from.

**Recommendation: A.**

---

#### Section: Structural integrity

**Issue 29: Three seams from the insertions**
Severity: SUGGESTION
None changes meaning; all three cost one edit.

- **A malformed rule before VIII-A.** Line 1338 ends section VIII's last
  paragraph, and line 1339 is `---`, with no blank line between them. In
  CommonMark a `---` directly under a paragraph is a level-2 setext heading
  underline, so "Message structure follows `code-style.md` ..." renders as a
  heading and the rule disappears. This is the defect Pass 1 issue 18 fixed at
  section IX, reintroduced at the new section.
- **Mixed heading levels.** The new sections 3.6.1 and 5.6.1 use `###`, the
  level their parents use. The other sub-subsections — 1.2.1, 1.3.1, 1.3.2,
  5.5.1, 5.5.2, 6.3.1 — use `####`. Section 6.2.1 uses `###` and predates this
  pass.
- **`TP-09b` to `TP-09g` are listed before `TP-09`.** The six new rows sit
  above the row they extend. `XP-18b` to `XP-18f` are placed correctly, after
  `XP-18`.

No duplicate id, no skipped id, and no dangling section reference was found.
124 ids across 12 prefixes, all unique.

Options:
- **[A]** Fix all three — Effort: low, Risk: low, Impact: the document renders
  as written and reads in order, Maintenance: none.
- **[B]** Fix the rule only — Effort: low, Risk: low, Impact: the rendering bug
  goes; the two ordering slips stay.
- **[C] Do nothing.**

**Recommendation: A.**

---

#### Section: Cross-artifact check

**Issue 30: Two gates still stand in both lists**
Severity: SUGGESTION
Residue from the issue 2 fix. The two lists agree, so nothing drifts yet.

| Gate | Spec IX | Test-spec |
|---|---|---|
| `make_all_designs()` returns 4 designs | bullet 4 | `RG-06` |
| `devtools::document()`; `man/` and `NAMESPACE` current | bullet 5 | Profile gate 1 |

The spec's fourth bullet also checks that `testing.md`'s "Gap to close" note is
removed, which is a source-tree check and belongs where it is. The count of
four is the runtime half.

Section IX also opens with "They belong to the validation artifact", which
points at the other document without naming it. The rest of the cross-artifact
check is clean: neither file names the other, the spec carries no tolerance, no
dataset call and no oracle call, and the test-spec carries no `R/` path and no
internal helper name.

Options:
- **[A]** Cut the runtime half of the two spec bullets, keeping the
  `testing.md` note removal and the `man/` file check — Effort: low, Risk: low,
  Impact: one gate list per gate, Maintenance: none.
- **[B] Do nothing** — the two lists agree today and may not after the next
  edit.

**Recommendation: A.**

---

### New-section review

Applied Lens 3, Lens 4 and Lens 5 to the six new sections and to VIII-A.

| Section | Verdict |
|---|---|
| 1.5 `survey_nonprob` fixture | Complete. States the deliverable, the constructor, the two consequences, and that no workstream branches on the subclass. Right-sized. |
| 3.6.1 Two or more unlabelled codes | Complete. Carries the measurement, four named consequences, a two-row contract table, and the observed-codes qualifier. `XE-04` matches, and pairs the abort with a passing case. |
| 5.5.1 `vars` gets its own class | Complete. Quotes the old message, names both false bullets, and states that the existing class keeps its trigger so no snapshot moves. `TE-01b` guards the separation. |
| 5.5.2 `interactions` re-validated | Complete. States the three-step sequence, reuses an existing class, and gives the reason for rejecting the friendlier branch. `XE-05` asserts the order against the role warning. |
| 5.6.1 Group-member drops | Complete on the contract; one rule is asserted on the wrong function — issue 24. The last-survivor boundary, the unanimity consequence and the sheet-name consequence are each stated. |
| 6.3.1 Per-wave layout | Complete on the contract. Two assertion gaps — issue 27. |
| VIII-A Documentation | Two gaps — issues 25 and 26. The tier assignment itself is correct against `function-documentation.md`: Tier 4 requires `@details`, a Workbook Layout section and `@seealso`, and forbids `@section Algorithm`; 8a.1 states all four. |

### Ordering constraints

The three constraints added in three sections compose into one sequence with no
contradiction. Verified against the call order in `R/export-crosstab.R`:

1. tidyselect resolves `vars` (`:115`) and `banner` (`:131`)
2. `.validate_export_inputs()` (`:121`) — not-found, then empty domain
   (`R/export-utils.R:67-77`)
3. `interactions` validated the first time (`:157-171`)
4. `.validate_base_notes()` (`:175`) — section 4.3, on the caller's vector
5. the role guard on `vars` and on `banner` — section 5.7
6. `interactions` validated again, on the survivors — section 5.5.2
7. the duplicate-label and unlabelled-code checks, on the surviving `banner`
   columns — sections 3.6, 3.6.1 and 5.7
8. `classify_question_type()` (`:179`) — section 5.7

`.validate_export_inputs()` runs at `:121` and `banner_resolved` is built at
`:131`, so section 5.7's "before they resolve `banner`" holds. Scenarios
`TX-08`, `XX-09`, `XE-05` and `XP-25` each assert one link in the chain, and
none contradicts another. Steps 6 and 7 are not ordered against each other, and
nothing depends on that order.

### Measured claims re-checked

| Claim | Section | Result |
|---|---|---|
| `R/export-crosstab.R` holds four `wb_add_worksheet()` calls; `:274` is the literal `"Crosstab"` | 6.2.1 | holds |
| `sheet_name <- substr(...)` at `:207`, `:226`, `:248` | 6.2.1 | holds |
| `.compute_eff_n()` holds three `# nocov` markers | 3.8, IX | holds — `:138`, `:141`, and the block at `:150-156` |
| `R/export-utils.R:145` is the level comparison | 3.1 | holds |
| the empty-domain check at `R/export-utils.R:67-77` | 5.7 | holds |
| `.validate_export_inputs()` called at `R/export-crosstab.R:121` and `R/export-topline.R:95` | 5.7 | holds |
| `interactions` validated at `R/export-crosstab.R:155-171` | 5.5.2 | holds |
| sheet name from `group_vars[[1L]]` at `:226` and `:248` | 5.6.1 | holds |
| `export_topline()` writes one sheet, `R/export-topline.R:129` | 6.2.1 | holds |
| `export_topline()` signature at `R/export-topline.R:54-64` | VIII | holds |
| `surveyreports_warning_duplicate_value_label` absent from `plans/error-messages.md` | VIII, IX | holds — the class is not in the table |
| `make_all_designs()` returns 3 designs; `testing.md` carries the "Gap to close" note | 1.5 | holds |
| both functions are Tier 4, and neither changes tier | 8a.1 | **fails** — neither has `@details` or a Workbook Layout section; issue 25 |
| `R/export-utils.R` holds all 8 new helpers | IX | **fails** — 7 belong there, 1 in `R/export-crosstab.R`, and 2 more are undeclared; issue 23 |

## Summary (Pass 2)

| Prior issue status | Count |
|---|---|
| RESOLVED | 18 |
| PARTIAL | 2 |
| NOT RESOLVED | 0 |
| REGRESSED | 1 |

| New severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 4 |

**Total new issues:** 9

**Overall assessment:** The resolution work is thorough, and the four blocking
issues of Pass 1 are closed, but three new scenarios were filed against
`export_topline()`, which has no `pub_type` argument and writes one sheet, so
the two behaviors Pass 1 issues 9 and 11 set out to assert are still unasserted
on the function that produces them.

VERDICT: BLOCK

---

## Spec Review: export-metadata — Pass 3 (2026-09-10)

Final delta pass. Artifacts read:

- `plans/spec-export-metadata.md` v0.6.0
- `plans/test-spec-export-metadata.md` v0.2.0
- `plans/decisions-export-metadata.md`, the Stage 3 resolve pass 2 entry

The nine Pass 2 findings and the three carried-over statuses are the checklist.
Pass 1's 21 issues were not re-verified; Pass 2 did that.

Repository claims added or changed in this round were re-measured against
`R/export-topline.R` and `R/export-crosstab.R`, and against
`.claude/standards/function-documentation.md`, Tier 4.

### Prior Issues (Pass 2)

| # | Severity | Status | Note |
|---|---|---|---|
| 22 | BLOCKING | RESOLVED | The two footnote rows are now `XN-08` and `XN-09` in the `export_crosstab()` numerical table. The topline numerical table holds `TN-01` to `TN-06` and no footnote row. |
| 23 | REQUIRED | RESOLVED | Gate IX reads "the 9 shared helpers of section 2.1", and names `R/export-crosstab.R` for `.unique_sheet_name()`. Section XI's issue 22 row names the same file and four call sites. `.design_universe()` and `.roles_of()` are declared in 2.1 and 2.2. |
| 24 | REQUIRED | RESOLVED | The sheet-name rule is `XP-18g`, in the `export_crosstab()` happy-path table. No topline row asserts a sheet name. |
| 25 | REQUIRED | RESOLVED | Section 8a.1 carries a measured conformance table. Verified — neither file holds `@details` or a `@section`; `export_topline()` links `surveycore::get_freqs()` only. Section 8a.3 makes both blocks a deliverable for both functions, and gate IX checks the three Tier 4 items. |
| 26 | REQUIRED | RESOLVED | Section 8a.2's table holds six rows, including both banner aborts. The 8a.3 `@param banner` row names both. Gate IX reads "six changed behaviors". |
| 27 | SUGGESTION | RESOLVED | `TC-05` sets four or more keys per wave, asserts an ordered label vector, asserts the bold wave heading, and asserts that column B is empty on that row. `TC-06` asserts the bold heading. |
| 28 | SUGGESTION | RESOLVED | The test-spec header reads v0.2.0 and "Spec-reviewed and resolved". |
| 29 | SUGGESTION | RESOLVED | A blank line separates section VIII from the rule before VIII-A. Sections 3.6.1, 5.6.1 and 6.2.1 all use `####`. `TP-09` precedes its extensions. One new ordering slip: issue 32. |
| 30 | SUGGESTION | RESOLVED | Section IX holds eight bullets, all source-tree checks. The design count and `devtools::document()` are gone from it. |
| 9 (Pass 1) | SUGGESTION | RESOLVED | The corrected `n=` count is asserted by `XN-08` and `XN-09`, on the function that writes the footnote. |
| 11 (Pass 1) | REQUIRED | RESOLVED | The section 5.6.1 sheet-name rule is asserted by `XP-18g` on `export_crosstab()`. |
| 14 (Pass 1) | REQUIRED | RESOLVED | Both Result structure lists say the active sheet is asserted only in the two scenarios that save the file and load it back. `TP-11c` and `XP-20b` carry it. |

**Counts:** RESOLVED 12, PARTIAL 0, NOT RESOLVED 0, REGRESSED 0.

### Checks run on the round's edits

| Check | Result |
|---|---|
| Ids skipped or duplicated after the moves | none. 124 ids over 12 prefixes, all unique, no gap in any sequence |
| Design coverage lost in a move | none lost. `XN-09` keeps all four subclasses; `XN-08` keeps the single design it arrived with — see issue 33 |
| Prose around a moved table | one stale reference — issue 31 |
| Helper count | consistent. Section 2.2 declares 10; section 2.1 says "nine of the ten" and lists 9; gate IX says 9. Every helper the pseudocode calls is declared |
| Cross-artifact | clean. Neither file names the other. The spec carries no tolerance, no oracle call and no test id. The test-spec carries no `R/` path and no internal helper name |
| Gate lists | no overlap and no disagreement. The spec keeps the file checks; the test-spec keeps the run gates |
| Section VIII-A against the source | the conformance table holds. Measured — `R/export-topline.R:52` and `R/export-crosstab.R:68` are the only `@seealso` tags, and neither file holds `@details` or `@section` |
| Section VIII-A against Tier 4 | the four checked items match the standard. The `@description` rule is already met: each file names what it routes to, and `export_crosstab()` names `layout` |

### New Issues

#### Section: Test-spec — template sections marked N/A

**Issue 31: The N/A table cites `TP-09g`, an id the rename removed**
Severity: SUGGESTION
A dangling reference created by this round's move.

The var_type dispatch row reads "See `TP-09d`, `TP-09g`, `XP-18d`, `XP-18e`".
The old `TP-09f` moved to the crosstab table as `XP-18g`, and the old `TP-09g`
took its place as `TP-09f`. So `TP-09g` no longer exists, and the SATA universe
row it points at is now `TP-09f`.

The fix is one character: change `TP-09g` to `TP-09f`.

---

**Issue 32: `XP-18g` is listed above `XP-18f`**
Severity: SUGGESTION
The same ordering slip issue 29 fixed for `TP-09`.

The crosstab happy-path table runs `XP-18b`, `XP-18c`, `XP-18d`, `XP-18e`,
`XP-18g`, `XP-18f`. The new row landed above the row it follows. Move `XP-18g`
below `XP-18f`.

---

#### Section: Test-spec — `export_crosstab()` numerical accuracy

**Issue 33: `XN-08` names one design type, and the cross-design rule two sections above calls that a gap**
Severity: SUGGESTION
A conflict the move exposed rather than created.

`XN-08` reads "Designs: twophase". The crosstab Cross-design section says
"Every row in the ... Numerical accuracy tables runs against every design type",
and "A row that names one design type only is a gap".

`XN-08` is right to be twophase-only: the phase-2 correction exists on no other
subclass. `TN-03` handles the same fact by naming all four designs and telling
the tester to compute the expected count from the design. `XN-08` is the only
row in the document that names a single subclass, so a tester meets a rule and
an exception with nothing joining them.

One clause on the row — "twophase only; the phase-2 subset exists on no other
subclass" — closes it.

---

#### Section: 2.2 New helper signatures

**Issue 34: `.roles_of()`'s declaration does not cover the four foreign payload shapes**
Severity: SUGGESTION
Lens 3, on text this round added.

`.roles_of(extra)` is declared as returning "a named character vector; a
variable with no role key is omitted". Section 5.3 measured four payload shapes
that surveycore accepts and a character vector cannot hold: a length-2
character, a non-character of any length, a length-0 value, and an absent key.

Section 5.6's collection branch sends every member payload through
`.roles_of()` before the section 5.3 coercion rule runs, so a foreign payload in
one wave reaches a helper whose contract does not describe it. The
non-collection branch passes the raw payload instead, so the two branches hand
the same coercion rule two different shapes.

Both readings end at the same behavior — keep the column, and warn
`surveyreports_warning_unknown_role` — so a builder converges either way. One
line on the declaration, saying that `.roles_of()` applies the section 5.3
coercion rule per variable, removes the fork.

---

#### Section: VIII-A. Documentation

**Issue 35: `@param design` is not in 8a.3, and section 1.5 adds a subclass to the supported set**
Severity: SUGGESTION
Lens 3, on the documentation contract.

Section 1.4 lists `survey_nonprob` as supported on every workstream, and section
1.5 makes the fixture a deliverable, so every cross-design loop gains a fourth
design. Measured — both `@param design` entries name three constructors:
`as_survey()`, `as_survey_replicate()` and `as_survey_twophase()`.
`package-conventions.md` says the entry "names every accepted subclass and links
each one to its constructor", and takes the list from `testing.md`, Cross-design
testing, which holds four.

The omission predates this spec. It becomes visible now, because section VIII-A
is the documentation contract and section 1.5 puts the fourth subclass under
test. Adding `[surveycore::as_survey_nonprob()]` to a `@param design` row in
8a.3 costs one line in each file.

---

## Summary (Pass 3)

| Prior issue status | Count |
|---|---|
| RESOLVED | 12 |
| PARTIAL | 0 |
| NOT RESOLVED | 0 |
| REGRESSED | 0 |

| New severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 5 |

**Total new issues:** 5

**Overall assessment:** Every Pass 2 finding is closed, and so are the three
carried-over statuses. The three scenarios Pass 2 found on the wrong function
now sit on the function that produces the behavior, and each one asserts what
the spec states. Section VIII-A's conformance table was checked against both
source files and holds. The helper count is consistent in all three places it
appears, and every helper the pseudocode calls is declared. The five new
findings are one stale id, one row out of order, one missing clause on a design
column, and two contract lines. None changes a behavior, and none stops a
builder or a tester.

VERDICT: PASS

---

## Spec Review: export-metadata — Pass 4 (2026-09-14)

Full pass, not a delta. The spec was rewritten between v0.7.0 and v0.8.0 and
locked at v0.9.0, so every Pass 1–3 resolution was re-checked against the
current text rather than carried forward.

Artifacts read in full:

- `plans/spec-export-metadata.md` v0.9.0
- `plans/test-spec-export-metadata.md` v0.5.0
- `plans/spec-review-export-metadata.md`, Passes 1–3

Supporting files read: `.claude/standards/function-documentation.md`,
`.claude/rules/code-style.md`, `.claude/rules/testing.md`,
`.claude/rules/package-conventions.md`, `CLAUDE.md`.

Repository claims were re-measured against `R/export-utils.R`,
`R/export-crosstab.R` and `R/export-topline.R`. Three claims in section 2.1 do
not hold against the source; see issues 44 and 48.

Lens 1 carries extra weight on this pass, at the user's request, and its
findings are reported first.

### Cross-artifact check

| Check | Result |
|---|---|
| Every function contract has at least one scenario | pass |
| Every output element in the spec's workbook contract has a structural assertion | **fail** — the sheet properties of section 3.16 (column widths, wrapping, freeze pane) and the cover sheet's bold header and block headings have no assertion. Issue 52 |
| Neither file references the other | pass |
| The spec carries no tolerance, dataset or oracle call | pass. No `1e-` value, no `expect_` call, no test id. It names `make_all_designs()` only where the fixture is a deliverable, which Pass 1 issue 3 settled |
| The test-spec carries no `R/` path and no internal helper name | pass |
| The two artifacts do not restate each other | **fail** — the snapshot-review obligation and the topline snapshot-scope rule stand in both, near-verbatim. Issue 46 |
| The two artifacts do not contradict each other | **fail** — three contradictions. Issues 49, 50 and 51 |

### Prior Issues (Passes 1–3)

Every prior issue was re-opened against the rewritten text. "Resolved" below
means the current section that carries the resolution is named.

| # | Title | Status |
|---|---|---|
| 1 | Three test-spec rows are undefined | ✅ Resolved — 3.19 carries both unused-factor rows; 3.11 puts the domain check before the guard; `XX-06`, `XX-07`, `XX-10` |
| 2 | The spec carries the test gates, fixture and numbers | ✅ Resolved — section VIII is source-tree checks only; no tolerance in the spec |
| 3 | `survey_nonprob` omitted | ✅ Resolved — 1.5 matrix row, 1.6 deliverable, 2.1 file list, profile gate asserts four designs |
| 4 | The warn-and-drop policy has no shared helper | ✅ Resolved — `.apply_role_guard()` in 2.1 and 2.2 |
| 5 | Four `wb_add_worksheet()` call sites, not three | ✅ Resolved — 3.14 names three routed and one literal `"Crosstab"` |
| 6 | `.unique_sheet_name()` placed against the cited rule | ✅ Resolved — 2.1 puts it in `R/export-crosstab.R` |
| 7 | Two unlabelled codes unspecified | ✅ Resolved — 3.7 aborts |
| 8 | Line references to a deleted helper drift | ⚠️ **Regressed** — the rewrite introduced a new one, `R/export-utils.R:733-739` at 3.3. Issue 65 |
| 9 | The suppression footnote changes more than stated | ✅ Superseded — B2 and B4 replace the footnote entirely |
| 10 | `interactions` not reconciled with a dropped banner column | ✅ Resolved — 3.10, 3.11 step 10, `XE-06` |
| 11 | Dropping one group member unspecified | ✅ Resolved — 3.10 table; `XM-12`–`XM-15` |
| 12 | `vars_empty_selection` reused with a wrong message | ✅ Resolved — 3.10 and 3.17 add `vars_all_dropped`; `XE-02` separates them |
| 13 | Routing only the `wb_add_worksheet()` argument | ✅ Resolved — 3.14, "Assign the result back to the sheet-name variable" |
| 14 | "The active sheet" asserted, not measured | ✅ Resolved — 3.14 Active sheet row; `XA-08` saves and reloads |
| 15 | Cover-sheet keys and bold column A have no scenario | ⚠️ **Regressed** — `XA-03` keeps the ordered key assertion; the bold assertion is gone, and 3.14 still requires it. Issue 52 |
| 16 | The `all_of()` snippet does not match the source | ✅ Resolved — no snippet; 3.11 step 12 states the rule |
| 17 | `warning_duplicate_value_label` was never in the error table | ✅ Resolved — 3.17 uses an error class |
| 18 | Dangling reference and missing separator | ✅ Resolved — sections I–XI present and in order |
| 19 | No documentation tier, no roxygen content | ✅ Resolved — section VII |
| 20 | SATA dispatch, variance, missing-label neither covered nor marked N/A | ⚠️ **Regressed** — the scenarios survive; the "Template sections marked N/A" table does not. Issue 54 |
| 21 | Stacked layout and self-banner have no scenario | ✅ Resolved — `XX-11`, `XX-09` |
| 22 | `TN-05b`/`TN-05c` cannot run against `export_topline()` | ✅ Obsolete — the ids are gone; the numerical tables are split by function |
| 23 | Gate and section XI contradict 2.1 on `.unique_sheet_name()` | ⚠️ **Regressed** — the old contradiction is gone; a new count contradiction replaces it. Gate VIII checks "the 12 shared helpers", 2.1 says "twelve of the thirteen", and a fourteenth shared writer is named in prose and never declared. Issue 38 |
| 24 | The sheet-name rule asserted on the wrong function | ✅ Resolved — `XM-15`, on `export_crosstab()` |
| 25 | Tier 4 assumed two roxygen blocks that do not exist | ✅ Resolved — 7.1 carries the measured conformance table |
| 26 | The two banner aborts absent from the documentation section | ✅ Resolved — 7.2 `@param banner` row |
| 27 | `TC-05` does not assert key order or the bold heading | ✅ Resolved — `TC-05` asserts an ordered vector; `TC-06` asserts the bold heading |
| 28 | Test-spec header stale | ✅ Resolved — v0.5.0, dated with the spec |
| 29 | Three structural seams | ✅ Resolved — no malformed heading found |
| 30 | Two gates stand in both lists | ⚠️ **Regressed** — the gate lists are clean; the snapshot obligation and the topline snapshot-scope rule are now duplicated instead. Issue 46 |
| 31 | The N/A table cites a removed id | ✅ Obsolete — the table and the ids are both gone. Its cause returns as issue 54 |
| 32 | `XP-18g` listed above `XP-18f` | ✅ Obsolete — ids renumbered |
| 33 | `XN-08` names one design type | ✅ Resolved — `XN-08` reads "all four" |
| 34 | `.roles_of()` does not cover the foreign payloads | ✅ Resolved — 2.2 says it applies the 3.10 coercion rule per variable |
| 35 | `@param design` omits `survey_nonprob` | ✅ Resolved — 7.2 carries the row |

**Counts:** Resolved 28, Obsolete/Superseded 2, **Regressed 5**.

The five regressions are issues 8, 15, 20, 23 and 30. None is the same defect
the prior pass found; each is the same *class* of defect, reintroduced by the
rewrite at a new location.

---

### New Issues

#### Section: Lens 1 — DRY (sections II, 3.3, 3.4, 3.5, 3.12, 3.16)

**Issue 36: The proportion-to-percentage conversion is a rule in two sections and arithmetic at every call site**
Severity: REQUIRED
Violates `CLAUDE.md` principle 1 — repeated logic in 2+ places extracts to a
shared helper.

Section 3.3 states: "The caller multiplies by 100 before calling `.fmt_pct()`,
so `.fmt_pct()` receives `35.6`." Section 2.2 repeats it in the signature
comment: "get_freqs() returns a proportion, so THE CALLER MULTIPLIES BY 100
before calling." Section 3.12 states it a third time: "The render multiplies by
100, as section 3.3 does."

Count the call sites the spec implies. Each of the three render routes formats
an estimate (`pct`), and under `variance` also `se`, or `ci_low` and `ci_high`.
That is 3 to 12 occurrences of `x * 100` scattered through the render code, each
one a place a builder can forget. Section 3.12 says what happens when one is
forgotten: "every standard error in the workbook prints as `0.0`." The spec
describes a defect it has already predicted and then chooses a design that
invites it.

The conversion belongs inside the formatter. Every call site holds a surveycore
proportion; no call site holds percentage points already.

Options:
- **[A]** `.fmt_pct(p, decimals, has_rows)` takes the **proportion** and
  multiplies internally — Effort: low, Risk: low, Impact: removes every inline
  `* 100`, deletes the "caller multiplies" paragraph from 3.3, the signature
  comment in 2.2 and the restatement in 3.12; `decimals` keeps its current
  meaning, decimal places on a percentage. Maintenance: one place to change if
  surveycore ever returns percentages.
- **[B]** Keep the current contract and add a second helper,
  `.as_pp(x) <- x * 100` — Effort: low, Risk: low, Impact: names the conversion
  but still leaves it at every call site. A helper that is one multiplication is
  the over-abstraction principle 3 warns about.
- **[C] Do nothing** — three statements of one rule, and up to twelve chances
  to miss it.

**Recommendation: A** — this is the user's own `make_pct()` case: one named
function owns the scale, the rounding and the suffix, and no call site does
arithmetic.

---

**Issue 37: One block row order is specified once and implemented three times**
Severity: REQUIRED
Violates `CLAUDE.md` principle 1, and `code-style.md`'s helper-placement rule.

Section 3.16 gives one row order for a question block: title, base note,
variance legend, spanner row, heading row, the two sample-size rows, the data
rows, then the bottom sample-size rows and the withheld lines. Section 3.1 says
three render helpers exist. Measured — they are
`.render_crosstab_single()` (`R/export-crosstab.R:492`),
`.render_crosstab_sata()` (`:647`) and `.render_crosstab_battery()` (`:767`).

The three differ in two things only: the number of label columns (1, 1, 2) and
the data rows between. Rows 1 to 7 and the closing rows are the same sequence.

Part of this is already shared — `.write_question_title()`,
`.write_crosstab_headers()` and `.write_base_note()` exist and all three routes
call them. What is not shared is the **sequence**: the order, the presence
conditions, and the row cursor. This spec adds two new rows to that sequence
(the variance legend and the two sample-size rows) and one new branch
(`sample_size_display`), so the un-shared part grows from three copies of five
steps to three copies of eight.

The `sample_size_display` branch is the user's second candidate and it is the
same finding: "top" versus "bottom" is one decision that lands in three
functions.

Options:
- **[A]** Two helpers own the sequence:
  `.render_block_preamble(wb, sheet, start_row, title, base_note, legend, col_groups, label_cols, counts, sample_size_display, show_ess)` and
  `.render_block_footer(wb, sheet, start_row, label_cols, counts, sample_size_display, show_ess, withheld_lines)`, each returning
  `list(wb = , next_row = )` per `code-style.md`. The `sample_size_display`
  branch then exists twice — once in each — instead of six times. Three real
  call sites each, in this spec. Placement: `R/export-utils.R`, on the same
  reasoning section 2.1 already gives for `.fmt_pct()` — the topline pass adopts
  the same block shape. Effort: medium, Risk: low, Impact: the row order becomes
  one implementation, and a later row added to 3.16 is one edit.
- **[B]** One `.render_block(wb, sheet, block, data_writer)` that takes the data
  rows as a callback — Effort: medium, Risk: medium. Rejected: a function-valued
  argument to hide three lines of difference is over-engineering.
- **[C] Do nothing** — three copies of an eight-step sequence, and a battery
  block that silently drifts from a SATA block on the next change.

**Recommendation: A** — two named helpers, three call sites each, both clearing
principle 3's bar inside this spec alone.

---

**Issue 38: The withheld list has three renderings and no declared owner**
Severity: REQUIRED
Violates `CLAUDE.md` principle 1, and leaves a helper named in prose but absent
from the architecture.

The same list is written three times, in three formats:

| Where | Section | Content stated |
|---|---|---|
| the cover sheet block | 3.14 | "one row per withheld subgroup naming its label, its banner variable and its effective N", plus `None` when nothing was withheld |
| under each table | 3.16, row k+2 | "withheld-subgroup lines" — content not stated |
| the console warning | 3.18 | "naming each subgroup and its effective N" |

Three descriptions, two of them incomplete, and nothing says they produce the
same text. `XW-07` and `XW-08` assert the cover-sheet form; `XW-10` asserts the
per-table form only as "the same lines", which is an assertion the test cannot
make precise while the spec does not.

The writer itself is undeclared. Section 2.1's prose names "the withheld-note
writer" as one of three helpers going to `R/export-utils.R`, and gate VIII names
it again, but it appears in neither 2.1's helper list nor 2.2's signatures. The
counts then disagree: 2.1 says "Twelve of the thirteen new helpers live in
`R/export-utils.R`" (twelve listed, plus `.unique_sheet_name()`), gate VIII
checks for "the 12 shared helpers", and the withheld-note writer is a
fourteenth that neither count includes.

Section 2.1's stated reason for its placement is also false. It says the three
helpers "are called only from `R/export-crosstab.R` in this spec". Measured —
its predecessor `.write_suppression_footnote()` is called from
`R/export-topline.R` at lines 461, 591 and 671, as well as from three sites in
`R/export-crosstab.R`. It already has two call-site files.

Options:
- **[A]** Declare two helpers: `.build_withheld(counts, min_eff_n, banner_var)`
  returning the withheld frame, and `.format_withheld_lines(withheld,
  min_eff_n)` returning a character vector. The cover sheet, the per-table
  block and the warning all read from the second one. Add both to 2.1's list and
  2.2's signatures, fix the count to fourteen, and correct the placement reason
  to "two call-site files today" — Effort: low, Risk: low, Impact: one text, one
  producer, three consumers; `XW-10` gains something exact to assert.
- **[B]** Declare the writer only, and let each consumer build its own text —
  Effort: low, Risk: medium. The cover sheet and the per-table block drift.
- **[C] Do nothing** — a helper the gate checks for and the architecture never
  declares, and three descriptions of one list.

**Recommendation: A**.

---

**Issue 39: The variance cell string is assembled inline in three render routes**
Severity: SUGGESTION
`CLAUDE.md` principle 1.

Section 3.12 confirms the user's third candidate the good way: the variance path
**does** reuse `.fmt_pct()` — "The formatter is `.fmt_pct()`, called on the
converted value." That part is not duplicated, and the shared rounding mode,
floor and ceiling follow from it. Dismissed.

What is not shared is the wrapper around it. Two forms exist — `(2.9%)` for
`se`, and `(30.0% – 41.3%)` for `ci`, with an en-dash and one `%` per number —
and each of the three render routes assembles them, under two `variance_display`
values. The en-dash in particular is a character an implementer can get wrong in
one route and right in the others, and no invariant in 8.1 covers it.

Options:
- **[A]** `.fmt_variance(rows, variance, decimals, has_rows)` returning
  `character(1)`, empty when `variance` is `NULL` or the cell has no rows —
  Effort: low, Risk: low, Impact: the two forms, the parentheses and the en-dash
  live once; `XH-20`'s "reads `-` alone" becomes a property of one function.
- **[B] Do nothing** — three copies of a two-branch string build.

**Recommendation: A** — it is three call sites and it pairs with issue 36.

---

**Issue 40: The below-floor test is described as four applications with no single owner**
Severity: SUGGESTION
`CLAUDE.md` principle 1, and Lens 5 under-engineering.

Section 3.5's reach table lists three subgroup kinds that face the floor — a
banner level, an interaction cell, a missing-value banner level — and the
degenerate table adds the full sample. The spec then says only "the rows for a
withheld subgroup are filtered out of the frequency frame".

Three of the four are actually one test, because section 2.2 already routes all
three through one frame: `.resolve_eff_n(design, group_var)` returns
`level, n, n_eff` whether `group_var` is a banner column, the synthetic
interaction column, or a column holding a missing-value level. So one filter
over that frame covers all three. The fourth, the full sample, is a different
operation — it warns and removes nothing.

The spec does not say this, so an implementer can reasonably write the test at
the banner loop, again at the interaction loop, and again where the
missing-value level is built. Three copies of `n_eff < min_eff_n` is three
places for a `<=` to appear.

Options:
- **[A]** State that one filter over the `.resolve_eff_n()` frame serves all
  three subgroup kinds, and give it a name —
  `.apply_eff_n_floor(counts, min_eff_n)` returning
  `list(keep = , withheld = )`, feeding issue 38's formatter. Say that the
  full-sample test is separate and warns — Effort: low, Risk: low.
- **[B] Do nothing** — the reach table reads as four features rather than one
  test applied to one frame.

**Recommendation: A**.

---

**Issue 41: The opening sequence is ordered for `export_crosstab()` only**
Severity: REQUIRED
Violates `CLAUDE.md` principle 1 and `code-style.md`'s ordering contract.

Section 3.11 calls its order "a contract, not an implementation note", and gives
thirteen steps for `export_crosstab()`. `export_topline()` runs six of the same
steps — the design class check, `vars` tidy-select resolution,
`.validate_export_inputs()` including the empty-domain check,
`.validate_base_notes()`, the role guard on `vars`, and
`classify_question_type()` with `all_of()` — and the spec states their order
nowhere.

Two consequences. First, `export_topline()` can run the role guard before the
empty-domain check and raise a role warning where section 3.11 says the domain
error must win; `XX-10` asserts that order for `export_crosstab()` and the
test-spec has no topline equivalent. Second, six steps are described once and
implemented twice with no shared owner, which is the DRY case at the level of a
whole sequence rather than a line.

Not blocking: the applicable subset is derivable by deleting the banner steps
and the `min_eff_n` step. But the derivation is the implementer's, and it is
exactly the kind of guess a contract section exists to prevent.

Options:
- **[A]** Add one sentence to 3.11 naming the steps that apply to
  `export_topline()` and in what order, and add a topline scenario mirroring
  `XX-10` — Effort: low, Risk: low, Impact: closes the guess; the two functions
  stay separate implementations.
- **[B]** Extract `.prepare_export_inputs(design, vars_quo, file_name,
  conf_level, decimals, base_notes)` returning the resolved and guarded `vars`,
  called by both — Effort: medium, Risk: medium, Impact: one implementation of
  six steps. Two real call sites, so it clears principle 3. The risk is that the
  two functions' validation sets are not identical (`min_eff_n` and the banner
  steps are crosstab-only), so the helper needs either optional arguments or a
  narrower scope than the whole sequence.
- **[C] Do nothing** — topline's order is undefined and its domain-before-guard
  behavior is untested.

**Recommendation: A**, with B deferred — the shared set is six steps out of
thirteen, and a helper covering only the six leaves the caller ordering the rest
anyway.

---

**Issue 42: The collection branch — two copies, not three, and a combinator is not warranted**
Severity: SUGGESTION
`CLAUDE.md` principle 3, judged both ways.

The user's sixth candidate asks whether `.design_universe()`, `.resolve_roles()`
and `.resolve_eff_n()` carry three copies of one shape. They do not.

`.resolve_eff_n()` is not the same shape. Section 2.2 says its collection result
is "ONE ROW PER MEMBER, level taken from the `.survey` column" — it keys the
members, it does not reduce them. `.design_universe()` and `.resolve_roles()`
both reduce: read each member, then collapse by unanimity. Folding
`.resolve_eff_n()` into a shared combinator would force a keyed frame and a
reduced vector through one signature, and that is the over-abstraction principle
3 warns about. Dismissed, with the reason.

The remaining two do share a shape, and half of it is already factored out:
`.unanimous_across()` owns the reduce, with three call sites (wave unanimity on
universe, wave unanimity on roles, battery unanimity on universe). What is left
duplicated is the branch itself — roughly "if this is a collection, `lapply()`
over `@surveys`, else read once" — which is three lines in two helpers.

One asymmetry is worth fixing regardless. Section 2.2's `.resolve_roles()`
comment spells out that it branches and applies the unanimity rule;
`.design_universe()`'s comment says only "with the collection branch applied"
and never names unanimity. A builder reading the two can reasonably put the wave
reduction for universes in `.base_note_for()` instead, which then also sees the
battery reduction and applies them in the wrong order — section 3.6 says
explicitly that "the two rules never run in the other order".

Options:
- **[A]** Add the unanimity clause to `.design_universe()`'s declaration, and do
  not extract a combinator — Effort: low, Risk: low, Impact: closes the
  asymmetry; six duplicated lines stay.
- **[B]** Add `.map_members(design, f)` and use it in both — Effort: low, Risk:
  low, Impact: removes six lines. Two real call sites, so it clears the bar, but
  barely.
- **[C] Do nothing** — the asymmetry stands and the reduction can land in the
  wrong helper.

**Recommendation: A** — the combinator is defensible and not worth the
indirection at two call sites of three lines.

---

**Issue 43: Three declared helpers have one call site and no independent contract**
Severity: SUGGESTION
`CLAUDE.md` principle 3, the over-engineering side.

| Helper | Only caller | Assessment |
|---|---|---|
| `.roles_of(extra)` | `.resolve_roles()` | A private helper of a private helper. Its contract — the 3.10 coercion rule per variable — could live in `.resolve_roles()`. The collection branch calls it once per member, which is one call site in a loop, not two call sites |
| `.design_universe(design)` | `.resolve_base_notes()` | The same shape. One caller, one line of contract beyond the branch |
| `.banner_heading(design, col)` | the banner loop in `export_crosstab()` | Two statements: read `extract_var_label()`, fall back to the column name. Its `fell_back` return is real, but so is `.emit_missing_label_warning()`, which already exists at `R/export-utils.R:566` |

None of these is harmful. The point is that the spec adds twelve shared helpers
and three of them exist to name two lines, while four behaviors that really are
repeated (issues 36–39) get no helper at all. The balance is the wrong way
round.

Options:
- **[A]** Fold `.roles_of()` into `.resolve_roles()` and `.design_universe()`
  into `.resolve_base_notes()`; keep `.banner_heading()` for its `fell_back`
  contract. Helper count goes from twelve to ten, and issues 36–39 add back four
  that carry real duplication — Effort: low, Risk: low.
- **[B] Do nothing** — two extra names to hold in mind, each with one caller.

**Recommendation: A**, but this is the lowest-value item in Lens 1 and the last
to spend review time on.

---

**Issue 44: Section 2.1's change list omits three existing helpers that Part B obsoletes**
Severity: REQUIRED
Lens 5, under-engineering. Measured against `R/export-utils.R`.

Section 2.1 lists what changes in `R/export-utils.R`. Three helpers that Part B
breaks are not in it:

| Helper | Line | Why this spec touches it |
|---|---|---|
| `.empty_suppressed()` | `:543` | Its tibble carries `pub_type` and `threshold` columns. B3 removes `pub_type`, and gate VIII greps `R/` for that string |
| `.write_suppression_footnote()` | `:596` | It is the predecessor of the withheld-note writer, and it has call sites in both export files — issue 38 |
| `.sata_pct_cell()` / `.cell_rows()` | `:742`, `:716` | They hold the never-asked-versus-chosen-by-nobody distinction that 3.3 removes |

Gate VIII catches `pub_type` by accident, because it greps for the string. It
catches nothing else. An implementer working from 2.1 alone can leave
`.write_suppression_footnote()` in place beside a new writer, and the file keeps
two implementations of the same block.

Options:
- **[A]** Add the three rows to 2.1's `R/export-utils.R` cell, each naming the
  change — Effort: low, Risk: low.
- **[B] Do nothing** — the change list understates the blast radius and the gate
  finds one of three.

**Recommendation: A**.

---

**Issue 45: The sample-size row labels are literals in two sections that must agree**
Severity: SUGGESTION
`CLAUDE.md` principle 1.

`Unweighted sample size` and `Effective sample size` appear as row labels in
3.4 and again as glossary terms in 3.15. The glossary only works if the term
matches the label the reader saw. Nothing binds them, and `XS-01` and `XA-05`
assert them separately.

A one-line fix: state that the glossary term and the row label come from the
same constant.

**Recommendation: A** — name the constant in 2.2, or state the rule in 3.15.

---

**Issue 46: The snapshot obligation stands in both artifacts, near-verbatim**
Severity: SUGGESTION
Cross-artifact duplication. This is the regression of Pass 2 issue 30.

Spec section 5.2 and the test-spec's "Assertion conventions" both carry the
snapshot-review obligation, and both carry the topline snapshot-scope rule, in
close to the same words. The spec adds it to gate VIII a third time. The two
artifacts are meant to be independently sufficient, not identical; a rule in
both is a rule that can be edited in one.

The same shape appears with the measured `119` for the twophase subset, which
sits in spec 1.4.1 and in test-spec `XN-04`. That one is defensible — the spec
records it as an upstream measurement and the test-spec as an expected value —
but it is the same maintenance trap.

Options:
- **[A]** The obligation is a test-run gate, so it belongs in the test-spec.
  The spec keeps the statement that snapshots move (5.1) and drops the
  procedure from 5.2 and gate VIII — Effort: low, Risk: low.
- **[B] Do nothing** — three copies of one obligation.

**Recommendation: A**.

---
#### Section: II. Architecture — ordering and shared state

**Issue 47: `.build_workbook()` takes the withheld list, but it runs before withholding is decided**
Severity: BLOCKING
Lens 5 and Lens 3. Three sections contradict each other on when the workbook is
built.

- Section 2.3: `.build_workbook(design, withheld = NULL, min_eff_n = NULL, has_banner, string_cells, variance)`.
- Section 3.14: the cover sheet is "Named `"About"`, written first, by
  `.build_workbook()`", and its withheld block lists every withheld subgroup.
- Section 3.11, step 13: "estimation, then withholding, then rendering."

The withheld list does not exist until step 13. A `.build_workbook()` that runs
before estimation cannot receive it. A `.build_workbook()` that runs after
estimation is no longer "first" in the call sequence, and the spec never places
the workbook build in its ordering contract at all — step 13 lumps estimation,
withholding and rendering into one line and never mentions the workbook.

`has_banner`, `string_cells` and `variance` are all known up front, so the
signature reads as though it is called early. `withheld` is the only argument
that forces the opposite. An implementer has to pick one, and the two choices
produce different code shapes for every render path.

Options:
- **[A]** Estimate and withhold first, then call `.build_workbook()`, then
  render. `"About"` stays sheet 1 because it is still the first sheet added.
  Add the workbook build to 3.11 as an explicit step between withholding and
  rendering — Effort: low, Risk: low, Impact: one reading, and the signature
  becomes honest.
- **[B]** Build the workbook first with an empty `"About"`, render, then fill
  the cover sheet at the end — Effort: medium, Risk: medium. The sheet is
  written twice and the "written first" property becomes about position, not
  order.
- **[C] Do nothing** — the implementer guesses, and the invariant "the
  workbook's first sheet is `About`" is the only thing either choice preserves.

**Recommendation: A**.

---

**Issue 48: `.total_col_group()` is shared with `export_topline()`, and section 3.9 changes it**
Severity: BLOCKING
Lens 5, and a direct threat to the scope line of section 4.2. Measured.

`R/export-utils.R:701` defines a constructor holding `spanner = "Total"` and
`levels = "Total"`. It is called from `R/export-crosstab.R` at lines 518, 670
and 790, and from `R/export-topline.R` at line 557.

Section 3.9 changes both of the strings this helper holds: the heading becomes
`total_label`, and the spanner becomes empty. Section 4.2 says
`export_topline()` keeps `Total` and gets no presentation change. Section 5.2
makes a moved topline snapshot outside the `show_eff_n` set "a defect in Part
A's scope line".

So the implementer faces a choice the spec does not name: parameterize
`.total_col_group()` and break topline's snapshots, or fork it and leave two
near-identical constructors in a shared file. Section 2.1 lists neither, and
`.total_col_group()` appears nowhere in the spec.

The same trap is smaller but real for the `100%` row: B6 removes it, and
`R/export-topline.R:432` and `:441` write their own, so that one does not leak.
`.total_col_group()` does.

Options:
- **[A]** `.total_col_group(total_label = "Total", spanner = "Total")`, with
  `export_crosstab()` passing `total_label` and `spanner = ""` and
  `export_topline()` calling it with no arguments — Effort: low, Risk: low,
  Impact: one constructor, topline byte-identical, and the scope line holds.
  Add the row to 2.1.
- **[B]** Fork it into `.total_col_group_crosstab()` — Effort: low, Risk: low,
  Maintenance: two constructors in a shared file until the topline pass merges
  them back.
- **[C] Do nothing** — whichever the implementer picks, section 2.1 does not
  predict it, and option B picked silently breaks section 5.2's gate.

**Recommendation: A**.

---

#### Section: Test-spec (Lens 2)

**Issue 49: The effective-N cell is rounded to one decimal and asserted at 1e-8**
Severity: REQUIRED
A contradiction between the artifacts. Two rows cannot pass.

Spec section 3.4 writes the effective sample size cell "at one decimal".
Test-spec `XS-03` asserts "the effective cell equals `n_eff` at one decimal",
tolerance `1e-8`. `XN-02` asserts the full-sample cell "equals
`get_effective_n(d)$n_eff`", tolerance `1e-8`.

Section 1.4.1's own measured value is `184.98`; the unrounded oracle is
`184.9760…`. A cell rounded to one decimal differs from the oracle by up to
`0.05`, which is seven orders of magnitude above the stated tolerance. Both
rows fail on a correct implementation.

Options:
- **[A]** Assert the cell against `round(n_eff, 1)` at tolerance `1e-8` —
  Effort: low, Risk: low, Impact: the tolerance keeps its meaning and the
  rounding is asserted rather than tolerated.
- **[B]** Widen the tolerance to `0.05` — Effort: low, Risk: medium. It hides a
  real error of `0.049` and violates `testing.md`'s tolerance table.
- **[C] Do nothing** — two rows fail against correct code, and a tester
  "fixes" them by loosening the tolerance.

**Recommendation: A**.

---

**Issue 50: `XX-05` tests zero-weight rows that section 3.19 says cannot exist**
Severity: REQUIRED
A contradiction between the artifacts. The scenario cannot be built.

Test-spec `XX-05` reads: "zero-weight rows | 40 rows given a weight of `0` | the
call succeeds; both counts match the oracle".

Spec section 3.19 reads: "zero-weight rows — **cannot reach an export
function.** `as_survey()` aborts at construction on a non-positive weight —
section 1.4. No design holding one can be built." Section 1.4 records the
measurement.

The spec is right and the test-spec row is unrunnable. The row exists because
`testing.md` lists zero-weight rows as a required edge case; the spec already
writes the exemption, and the test-spec needs the matching one.

Options:
- **[A]** Replace `XX-05` with a row asserting that `as_survey()` aborts on a
  zero weight, and record the case as covered upstream — Effort: low, Risk: low,
  Impact: `testing.md`'s required case is answered and the row runs.
- **[B]** Delete `XX-05` and state the exemption in prose, mirroring spec
  3.19 — Effort: low, Risk: low.
- **[C] Do nothing** — the tester writes a test whose fixture aborts at setup
  and reports a blocked run.

**Recommendation: B** — the spec already carries the reasoning; the test-spec
needs the statement, not a test of surveycore's constructor.

---

**Issue 51: `XA-05` asserts four glossary terms against a five-term conditional glossary**
Severity: REQUIRED
A contradiction between the artifacts, and a lost conditionality.

`XA-05` reads: "the glossary is always present | any call | the glossary block
holds **the four terms** of the contract, each with its text".

Spec section 3.15 defines **five** terms, and three of them are conditional:
`Why a column is missing` needs `min_eff_n > 0` and a rendered banner;
`Percentages` needs string cells; `Confidence intervals` needs
`variance = "ci"`. Section 3.15 is emphatic about this — "Two entries are false
in an `export_topline()` workbook, which is why they are conditional" — and
`.write_cover_sheet()`'s signature takes three arguments for no other purpose.

`XA-05` therefore asserts the wrong count and asserts an unconditional set.
`XA-07` comes close to the conditional case — "at `min_eff_n = 0` … the glossary
block is still present" — but does not assert that the `Why a column is missing`
entry is absent, which is the behavior the argument exists for. `TP-06` has the
same gap for the topline workbook, where two entries must be absent.

Options:
- **[A]** Rewrite `XA-05` as a matrix: five terms against their presence
  conditions, asserted under at least three argument combinations
  (`min_eff_n = 0`; `variance = "ci"`; the topline default) — Effort: low,
  Risk: low, Impact: the three `.write_cover_sheet()` arguments get the only
  test that justifies them.
- **[B]** Fix the count to five and leave the conditions untested — Effort:
  low, Impact: an unconditional glossary passes.
- **[C] Do nothing** — the spec's conditional glossary has no scenario, and
  `XA-05` fails on a correct implementation.

**Recommendation: A**.

---

**Issue 52: B9 and the cover-sheet styling have no scenario**
Severity: REQUIRED
Violates `testing.md` — every behavior in the contract gets a test. This carries
the regression of Pass 1 issue 15.

Section 1.2 lists B9 — "Column widths, text wrapping, and a freeze pane" — as an
in-scope change. Section 3.16 specifies all three precisely: 44 characters for
the label column, 12 for each data column, not auto-fit, wrapping on the label
column and the heading row, a taller heading row, and a freeze pane below the
last heading or sample-size row, absent when `sample_size_display == "bottom"`.

The test-spec contains no row for any of it. A search for "freeze", "width" and
"wrap" over the test-spec returns nothing.

Section 3.14 also requires bold on the cover sheet's header row and on each
block heading. Pass 1 issue 15 closed that gap with a bold assertion; the
rewrite dropped it. `XA-03` now asserts the key order and not the styling.
`XS-02` shows the pattern to follow: "Read the style, not the value".

Options:
- **[A]** Add four rows: the two column widths, the wrap and heading height, the
  freeze pane under `"top"` and its absence under `"bottom"`, and the cover
  sheet's bold header and block headings — Effort: medium, Risk: low, Impact:
  the only in-scope workstream with zero coverage gets some.
- **[B]** Cover the freeze pane and the bold only, and mark widths and wrapping
  N/A with a reason — Effort: low, Risk: medium. Section 3.16's own argument
  against auto-fit is that widths must be stable across snapshots, which is a
  testable claim.
- **[C] Do nothing** — B9 ships untested and the styling rules of 3.14 and 3.16
  are unverified.

**Recommendation: A**.

---

**Issue 53: Two new warning classes have no snapshot, and "dual pattern" is undefined for a warning**
Severity: REQUIRED
Violates `testing.md` — every error class gets a test, and the test-spec's own
conventions must define the patterns it cites.

The test-spec's "Assertion conventions" defines the dual pattern for **errors**
only: "Errors: the dual pattern — `expect_error(class = )` **and**
`expect_snapshot(error = TRUE)`". "Warnings: `expect_warning(result <- ...,
class = ...)`".

But five warning rows then say "Dual pattern" — `XV-01`, `XV-03`, `XV-07`,
`TW-01`, `TW-02` — and three do not: `XV-04`
(`surveyreports_warning_banner_all_withheld`), `XV-05`
(`surveyreports_warning_full_sample_below_min`) and `XV-06`
(`surveyreports_warning_missing_variable_label`, whose trigger this spec
extends).

Two of the three unsnapshotted classes are **new** in section 3.18. Their
messages are user-facing and nothing pins their text.

Options:
- **[A]** Define the dual pattern for warnings in the conventions section
  (`expect_warning(class = )` plus `expect_snapshot()` once per class), and
  apply it to every new or changed class — that is `banner_all_withheld`,
  `full_sample_below_min` and the extended `missing_variable_label` — Effort:
  low, Risk: low.
- **[B]** State that warnings are class-only and remove "dual pattern" from the
  five warning rows — Effort: low, Risk: medium. Two new user-facing messages
  ship with no text assertion.
- **[C] Do nothing** — the document uses a term it defines for a different
  condition type, inconsistently.

**Recommendation: A**.

---

**Issue 54: The "template sections marked N/A" table is gone**
Severity: REQUIRED
Regression of Pass 1 issue 20's resolution. Violates `testing.md` — "If a
category doesn't apply to a specific function, mark it **N/A** and state why —
N/A is a deliberate decision."

Pass 2 recorded the resolution: "The 'Template sections marked N/A' table
records five template sections with a reason each." The v0.5.0 rewrite dropped
it. A search for "template" over the test-spec returns nothing.

What the table used to make explicit, and what a reader must now infer:

- `export_topline()` has no banner section — stated in prose under "Functions
  under test", so this one survives.
- `export_topline()` has no withholding section — same.
- `export_crosstab()` has no collection section — same.
- `export_crosstab()`'s **var_type dispatch** section: the `testing.md` template
  for `test-export-crosstab.R` lists "var_type dispatch — SATA and battery
  blocks" as section 7. The test-spec has `XS-10` (a battery's blank label
  column), `XC-07a` (a SATA cell) and `XM-12`–`XM-15` (group survival), but no
  row asserting that a SATA block and a battery block each render in their own
  shape. Whether that is covered or N/A is now a judgment the tester makes.
- `export_topline()`'s variance options: the topline table has no `variance` row
  at all, and `variance` is in its signature.

Options:
- **[A]** Restore the table, one row per template section per function, each
  marked covered-by-id or N/A-with-reason — Effort: low, Risk: low, Impact: the
  tester can check the template off without re-deriving it.
- **[B]** Add the two missing rows (a var_type dispatch row, a topline variance
  row) and leave the rest implicit — Effort: low, Risk: medium.
- **[C] Do nothing** — `testing.md`'s deliberate-N/A rule is unmet, and the
  gap Pass 1 found returns.

**Recommendation: A**.

---

**Issue 55: `show_total = FALSE` has no scenario**
Severity: SUGGESTION
Lens 2 — an argument in the signature with no row.

`show_total` is in section 3.1's signature and 3.2's table. `XH-08` and `XH-09`
both run with the default `TRUE`. No row sets it to `FALSE`, so nothing asserts
that the Total column group disappears, that the `counts` frame of section 3.4
loses its `total_label` row, or that the spanner and heading rows shrink by one.

**Recommendation: A** — one row, `show_total = FALSE`, asserting the column
count drops by one and no heading reads `Full Sample`.

---

**Issue 56: `min_eff_n = Inf` is specified and untested**
Severity: SUGGESTION
Lens 2.

Section 3.17 says `surveyreports_error_invalid_min_eff_n` fires when `min_eff_n`
is "not a length-1, non-missing, **finite**, non-negative numeric". `XE-11`
tests `-5`, `NA`, `c(50, 100)` and `"100"`. It does not test `Inf`, which is the
only one of the five conditions with no input behind it — and the one an
implementer is most likely to omit, because `Inf >= 0` is `TRUE`.

**Recommendation: A** — add `Inf` to `XE-11`'s input list.

---

**Issue 57: The block row order of section 3.16 is not asserted as an order**
Severity: SUGGESTION
Lens 2.

Individual rows are asserted — `XS-01` places the sample-size rows "directly
under the heading row", `XH-18` asserts the legend exists, `XM-01` the base
note. Nothing asserts the full sequence of section 3.16 in one place, and the
legend row's position relative to the base note and the spanner is asserted
nowhere.

If issue 37 is taken and one helper owns the sequence, one scenario covers it:
render a block with every optional row present and compare column A against an
expected character vector.

**Recommendation: A** — one row, with every optional element switched on.

---
#### Section: VII. Documentation (Lens 3)

**Issue 58: `@returns` is unchanged in both functions, and both workbooks change shape**
Severity: REQUIRED
Violates `package-conventions.md` — "`@returns` … the written file for an
`export_*()` function", with the sheet described.

Measured — `R/export-topline.R:37` and `R/export-crosstab.R:54` both read only
"`invisible(file_name)` — the path supplied in `file_name`." Neither describes
the workbook. `package-conventions.md` gives the required form, which names the
sheet and the block contents.

This spec gives both functions a new first sheet named `"About"`, and gives
`export_crosstab()` string cells, two sample-size rows, no `N` column and no
`100%` row. Section 7.2's table has rows for `@param`, `@details`,
`@section Workbook Layout` and `@seealso`, and **no row for `@returns`**.
Section 7.1's conformance table does not check it either.

So the one block that already exists in both files, and that a rule file
requires to describe the written sheets, is the one the documentation contract
does not mention.

Options:
- **[A]** Add a `@returns` row to 7.2 for both functions, and a `@returns` line
  to 7.1's conformance table — Effort: low, Risk: low.
- **[B] Do nothing** — the help page says the function returns a path and never
  says what is in the file, and section 7.3's own argument applies: nothing
  catches it.

**Recommendation: A**.

---

**Issue 59: `export_topline()`'s two new roxygen blocks are promised, not specified**
Severity: REQUIRED
Lens 3 — contract completeness.

Section 7.2's last row reads, for `export_topline()`: "`@details`,
`@section Workbook Layout`, `@seealso` — **Write the first two; add
`export_crosstab()` to the third.**"

For `export_crosstab()` the same table says what each block must contain: the
three render routes and what selects them for `@details`; the cover sheet, the
Total column, the banner groups, the two layouts, the sample-size rows and the
row order of 3.16 for Workbook Layout.

For `export_topline()` it says nothing. Its routes differ (no banner, plus the
collection wave path), and its layout differs on every row of section 4.2's
table — an `N` column, the effective N in the Total header, the `100%` row it
keeps, and now the `"About"` sheet. An implementer writing that block from
scratch has no list to write from, and section 7.1 has already established that
the block does not exist to copy.

Section 7.1's warning applies to the function it was not written about: "section
7.2 cannot be read as 'edit these blocks'. Two of them do not exist, and writing
them whole is a deliverable."

Options:
- **[A]** Give `export_topline()` its own content list, mirroring the
  `export_crosstab()` rows: the routes for `@details` (single, SATA, battery,
  plus the collection trend path), and for Workbook Layout the one sheet, the
  `N` column, the Total header, the `100%` row, the base notes and the new
  cover sheet — Effort: low, Risk: low.
- **[B]** State that `export_topline()`'s blocks describe its current layout and
  leave the list to the implementer — Effort: low, Risk: medium. Gate VIII then
  checks only that a `@section` exists, not that it is right.
- **[C] Do nothing** — one of the two Tier 4 deliverables has no content spec.

**Recommendation: A**.

---

**Issue 60: Section 7.1's conformance table omits two Tier 4 rules**
Severity: SUGGESTION
Lens 3, against `.claude/standards/function-documentation.md`, Tier 4.

The standard lists seven requirements for Tier 4. Section 7.1's table checks
four. Missing:

- **`@description`** — "end with a sentence naming what it routes to and which
  argument controls the routing". Pass 3 measured this as already met and said
  so in the review; the rewritten 7.1 drops the row, so the fact that it is met
  is no longer recorded anywhere.
- **Output Columns / Workbook Layout** is present, but `@returns` is not — issue
  58.

`@references` is correctly handled: 7.2 says it stays absent because no
published method is implemented, which matches the standard's "required when
the routes implement published methods".

**Recommendation: A** — add the `@description` row marked satisfied, so a
reader of 7.1 alone sees the whole tier.

---

**Issue 61: The argument order claim in 3.1 does not match `code-style.md`**
Severity: SUGGESTION
Lens 3 — argument order.

Section 3.1 states: "Argument order follows `code-style.md`: `design`, required
NSE, required scalar, optional NSE, then optional scalar control arguments."

The signature places `layout` (an optional scalar) before `interactions`.
`code-style.md`'s own ordering list names `interactions = NULL` as its example
of "4. Optional NSE/tidy-select arguments", which puts it ahead of every
optional scalar. So the signature is in the order the current function already
has, and the conformance claim is false.

This is defensible — keeping `layout` where callers already pass it avoids a
silent positional change — but this release is already breaking, so the
deviation is a choice rather than a constraint.

Options:
- **[A]** Move `interactions` ahead of `layout` — Effort: low, Risk: low,
  Impact: conforms; adds one more breaking change to a list of seven.
- **[B]** Keep the order and replace the claim with the reason: positional
  compatibility with the existing signature — Effort: low, Risk: low.
- **[C] Do nothing** — a stated conformance that a reviewer checking
  `code-style.md` will reject.

**Recommendation: B**.

---

#### Section: 3.19 Edge cases and engineering level (Lenses 4 and 5)

**Issue 62: `show_total = FALSE` with every banner level withheld is undefined**
Severity: REQUIRED
Lens 4 — a boundary with no stated behavior.

Section 3.5's degenerate table covers "every level of every banner column is
withheld": "The tables render with the Total column alone — a topline under a
crosstab file name." That assumes `show_total = TRUE`.

With `show_total = FALSE` and the same input, the block has **zero** data
columns. Nothing in the spec says what is written: a spanner row and a heading
row with only the label column, then response rows with no cells; or no block;
or an abort. The sample-size rows would take a `counts` frame with zero rows,
which section 3.4's contract ("one row per rendered data column") permits and
`.write_sample_size_rows()` has no stated behavior for.

`XX-02` reaches the neighbouring case — a single-row design at the default floor
— but with the default `show_total = TRUE`.

Options:
- **[A]** Add a row to 3.19: with no rendered data column, the block writes its
  title, base note and label column and no data columns, and the existing
  `banner_all_withheld` warning covers it. Add the matching scenario — Effort:
  low, Risk: low.
- **[B]** Abort with a new class when no data column would be rendered —
  Effort: medium, Risk: medium, and it contradicts 3.5's "Do not abort".
- **[C] Do nothing** — the implementer guesses, and an empty `counts` frame
  reaches a writer with no contract for it.

**Recommendation: A**.

---

**Issue 63: A design variable with no `role` still renders as a question**
Severity: SUGGESTION
Lens 4 — "Variables that are design variables (weight, strata, PSU) — should
this error?"

`package-conventions.md`'s model `@param vars` says "Cannot include design
variables (weights, strata, PSU)." Measured — `.validate_export_inputs()`
(`R/export-utils.R:7`) checks the design class, the resolved length and the
names; it does not exclude `design@variables$weights`.

This spec introduces `role = "weight"` as a drop reason, which makes the case
look handled. It is handled only when someone has set the role. On the 39
existing `adldata` datasets, which section 1.3 says are not being cleaned, no
role is set, so `vars = c(q1, wt)` renders a table of weight values.

The defect predates this spec. It becomes easy to close here, because the guard
already exists and the design object already names its own weight column.

Options:
- **[A]** Have `.apply_role_guard()` treat `design@variables$weights`, `strata`
  and `ids` as `role = "weight"` whatever the metadata says — Effort: low,
  Risk: low, Impact: the documented contract becomes true; it is a drop, not an
  error, so it fits the existing warning.
- **[B] Do nothing** — scope discipline. The role mechanism covers it for any
  cleaned dataset, and section 1.3 already parks the uncleaned ones.

**Recommendation: B** for this spec, with A recorded in section 1.3's parked
list — the spec should say the case is known and parked, since 3.10's role table
implies otherwise.

---

**Issue 64: `.write_cover_sheet()` cannot see `withheld_note`**
Severity: SUGGESTION
Lens 3 — contract completeness on a declared signature.

`.write_cover_sheet(wb, design, withheld, min_eff_n, has_banner, string_cells,
variance)` takes no `withheld_note`. Section 3.14 makes the withheld block
conditional on `withheld_note == "once"` and `min_eff_n > 0`, so the helper
cannot evaluate its own presence condition.

The resolution is obvious — the caller passes `withheld = NULL` unless
`withheld_note == "once"` — but the spec does not state it, and a builder can
just as reasonably add the argument.

**Recommendation: A** — one line on the signature comment in 2.2.

---

**Issue 65: A new decaying line reference**
Severity: SUGGESTION
Regression of Pass 1 issue 8, at a new location.

Section 3.3 reads: "`R/export-utils.R:733-739` makes the distinction today,
printing a blank for never-asked and `0` for chosen-by-nobody."

Pass 1 issue 8 found the same pattern and its resolution removed every line
range from the spec. The rewrite put one back. Measured — the behavior is in
`.sata_pct_cell()` at `R/export-utils.R:742` and `.cell_rows()` at `:716`, so
the quoted range is already off by nine lines.

**Recommendation: A** — cite the helper name, not the line range:
"`.sata_pct_cell()` makes the distinction today". Issue 44 needs the same helper
named anyway.

---

#### Section: Lens 6 — API coherence and the realistic workflow

**The traced workflow.** An analyst crosstabs 40 questions against a 3-variable
banner on a 1,200-row weighted survey, at the default `min_eff_n = 100`. Take
the banner as gender (2 levels), age (4) and region (4), and a design effect
around 1.1, so the full sample's effective N is near 1,090.

What they get:

| Step | Result |
|---|---|
| Sheets | 41 — `About`, then one per question, named for the variable. Two questions whose names share 31 characters no longer abort; the second is suffixed |
| Columns per table | Total plus up to 10 banner levels. Gender and age levels clear the floor comfortably; a region level holding 8 percent of the sample lands near `n_eff = 87` and its column is gone |
| Feedback on the loss | one console warning naming every withheld subgroup with its effective N, and one cover-sheet block saying the same |
| Cells | every percentage is a string. No Excel number format, no sort, no chart, no formula |
| Sample sizes | two italic rows per table, at the top, under a freeze pane |
| Cover sheet | dataset metadata, the withheld list, and a five-entry glossary, of which four apply here |

Nothing in that is wrong, and most of it is an improvement on the current
output. Three things would surprise the analyst, and two of them are worth
raising.

---

**Issue 66: "Full Sample" labels a domain-restricted subset**
Severity: REQUIRED
Lens 6 — "methodologically correct but confusing".

Section 3.9 sets the Total column's default heading to `"Full Sample"`, and
argues: "`"Full Sample"` is right for a general-population study and wrong for
one fielded on a panel of donors, which is why it is an argument."

The domain case is stronger than the panel case, and the spec does not mention
it. Section 3.20 says that on a domain-restricted design "both counts follow the
in-domain rows" — so on a design restricted to, say, registered voters, the
column headed `Full Sample` holds estimates for registered voters only, and its
sample-size rows hold the in-domain counts. The package knows the design is
restricted; it prints a heading that says it is not.

An analyst who filters a design, exports, and sends the workbook onward has
published a column labelled `Full Sample` over a subset. Nothing in the workbook
contradicts it: the cover sheet carries no domain line, and the glossary does
not mention domains.

Options:
- **[A]** When the design carries `..surveycore_domain..` and the caller did not
  set `total_label`, use `"Total"` instead of `"Full Sample"` — Effort: low,
  Risk: low, Impact: removes the false claim without inventing a label the
  package cannot know.
- **[B]** Add a cover-sheet row naming the domain restriction and the in-domain
  row count whenever the domain column is present — Effort: medium, Risk: low,
  Impact: the reader can see the base; the heading still says `Full Sample`.
- **[C] Do nothing** — a default heading that is wrong on every
  domain-restricted export, in a spec whose other half is about making the base
  visible.

**Recommendation: A**, with B as a follow-on. A costs one condition.

---

**Issue 67: Item nonresponse loses its last in-table signal**
Severity: REQUIRED
Lens 6 — a plausible workflow that yields a silently misread result.

Three decisions in this spec compose, and the spec states each one separately
and the composition nowhere:

1. The sample-size rows "ignore the tabulated variable" (3.4, 1.4.1). They are
   design-level or subgroup-level row counts.
2. The floor is tested on the subgroup, not on the question's base (3.5). "A
   subgroup at `n_eff = 105` on a question that 40 percent of it skipped carries
   an effective base near 63 for that question, and the floor publishes it."
3. The per-response `N` column is removed (B2), and section VI records that the
   count is "**not** recoverable from the workbook when a variable has item
   nonresponse".

Take the traced workflow, and one of the 40 questions with 40 percent item
nonresponse. A region column reports `Unweighted sample size 96`, and its
percentages are computed on 58 people. The workbook contains no number from
which the reader can recover 58. The current output does, in the `N` column
this spec deletes.

The glossary does tell the reader the rule — "a question that many people
skipped can still be shown for a subgroup that clears the minimum" — which is
why this is not BLOCKING under the protocol's bar. It states the rule on a
separate sheet, in general terms, with no per-question number.

Options:
- **[A]** Add a third optional sample-size row, the question's own base, present
  under a new argument or under `show_ess`'s sibling — Effort: medium, Risk:
  low, Impact: closes the gap where it is read. Cost: a third row on every
  block, and section 3.4's "Two rows, always two" goes.
- **[B]** Write the question's base into the block only when it differs from the
  subgroup count by more than some margin — Effort: medium, Risk: medium. A
  conditional row is worse than no row: its absence means two different things.
- **[C]** Keep the design and record the composition explicitly — one row in
  section VI naming all three decisions together, and one sentence in the
  `Percentages` glossary entry saying the percentages are based on those who
  answered, which can be fewer than the sample size shown — Effort: low, Risk:
  low.
- **[D] Do nothing** — three separately-reasonable decisions compose into a
  workbook where the base of a published percentage is unrecoverable.

**Recommendation: C** for this spec, A for the topline pass when both functions
are rebuilt together. C is one row and one sentence and it puts the warning
where the number is read.

---

**Issue 68: Two smaller surprises in the traced workflow**
Severity: SUGGESTION
Lens 6.

**A 41-sheet workbook has no index.** The `About` sheet carries dataset
metadata, the withheld list and the glossary. It does not list the 40 question
sheets or say which variable each one holds, and the tabs carry variable names,
not labels — section 3.8 explains why, and the reason is sound. A fourth block
on the cover sheet, one row per sheet with its variable label, would cost one
loop. Not required; worth recording as a deliberate omission if it stays out.

**Section 4.2 omits the `100%` row.** The table lists five aspects that stay
inconsistent between the two functions after this spec. Measured — the `100%`
row is written at `R/export-topline.R:432` and `:441`, and B6 removes it from
`export_crosstab()` only. So a reader building both workbooks from one script
sees a sixth inconsistency that the table promises to enumerate. One row.

**Recommendation: A** for the 4.2 row; the sheet index is a judgment call and
either answer is defensible.

---

## Summary (Pass 4)

| Prior issue status | Count |
|---|---|
| Resolved | 28 |
| Obsolete / superseded | 2 |
| **Regressed** | **5** |

Regressed: 8 (a new decaying line reference), 15 (the cover sheet's bold
assertion), 20 (the N/A template table), 23 (a new helper-count contradiction),
30 (a rule duplicated across both artifacts).

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 16 |
| SUGGESTION | 15 |

**Total new issues:** 33 (issues 36–68)

**Lens 1 findings, ranked by how much duplication each removes:**

| Rank | Issue | Removes |
|---|---|---|
| 1 | 36 — the `× 100` conversion | 3 to 12 inline conversions, and one rule stated in three sections |
| 2 | 37 — the block preamble and footer | 3 copies of an 8-step sequence, and 6 copies of the `sample_size_display` branch |
| 3 | 38 — the withheld list | 3 renderings of one list, and it declares a helper the gate already checks for |
| 4 | 41 — the opening sequence | 6 ordering steps duplicated across two functions, one of them untested |
| 5 | 39 — the variance cell string | 2 forms × 2 displays × 3 routes |
| 6 | 40 — the below-floor test | 3 applications collapsing to 1 filter over 1 frame |
| 7 | 42 — the collection branch | 6 lines. Dismissed: `.resolve_eff_n()` is a different shape, and extracting it with the other two is the over-abstraction principle 3 warns against |
| 8 | 43 — three single-call-site helpers | 2 names that add nothing (`.roles_of()`, `.design_universe()`) |

**Overall assessment:** The spec is thorough, unusually well measured, and not
yet implementable: two architectural contradictions force a guess
(`.build_workbook()` receives a list that does not exist when it runs, and
`.total_col_group()` is shared with the function this spec promises not to
change), the DRY layer is inverted — three helpers exist to name two lines while
four genuinely repeated behaviors get none — and the test-spec contradicts the
spec in three places, one of which cannot be built at all.

VERDICT: BLOCK — resolve issues 47 and 48 before the implementation plan, and
take issues 36 to 41 in the same round, because each one changes a helper
signature the plan will carry.

---

## Spec Review: export-metadata — Pass 5, delta (2026-09-16)

Delta pass. Verifies the 33 resolutions of Stage 3r landed. Not a fresh review.

Artifacts read:

- `plans/spec-export-metadata.md` v0.18.0
- `plans/test-spec-export-metadata.md` v0.13.0
- `plans/error-messages.md`
- `plans/decisions-export-metadata.md`, the 2026-09-16 entry
- `plans/spec-review-export-metadata.md`, Pass 4, issues 36 to 68

Repository claims were re-measured against `R/export-utils.R`,
`R/export-crosstab.R`, `R/export-topline.R` and
`tests/testthat/helper-test-data.R`.

### Resolution audit

| # | Decided | Verdict | Note |
|---|---|---|---|
| 36 | A — `.fmt_pct()` takes the proportion and multiplies by 100 itself | LANDED | 2.2: "The helper multiplies by 100 itself, so 0.356 reaches it as 0.356 and no call site does arithmetic." 3.3 and 3.12 state the same rule and the "caller multiplies" text is gone. Section VI records the two implementations |
| 37 | B — both helpers in `R/export-crosstab.R`, not the shared file | LANDED | 2.1: "Three helpers stay in `R/export-crosstab.R`, below the exported function." 2.2 declares both; 3.16 says "Two helpers own the sequence" |
| 38 | A — `.build_withheld()` and `.format_withheld_lines()` declared | LANDED | Both sit in 2.1's list and 2.2's signatures. 3.14: "One wording, three places." The placement reason now reads two call-site files, and the predecessor's six sites measure 3 plus 3 in the tree |
| 39 | A — `.fmt_variance()` owns the variance string | LANDED | 2.2 and 3.12 give both forms, the parentheses, one `%` per number and the en-dash. Invariant 8.1 carries the U+2013 and U+002D rule |
| 40 | B — no new helper; `.build_withheld()` sole owner; wording plus a boundary scenario | LANDED | 2.2: "THE SOLE OWNER OF THE FLOOR TEST." 3.5 states one test over one frame, the kept levels as a set difference, and the full-sample test as separate. `XW-13` is the boundary row |
| 41 | A — name the topline steps and add the mirror scenario | LANDED | 3.11 carries a ten-step topline list and the seven steps that do not apply. `TE-03` is the topline companion to `XX-10` |
| 42, 43 | B — fold both helpers away, move the clause to the survivor | LANDED | `.resolve_roles()` owns the coercion rule; `.resolve_base_notes()` owns the wave unanimity rule; `.banner_heading()` stays for `fell_back`. Section XI records the reversal. Neither folded name appears in 2.1 or 2.2 |
| 44 | `.empty_suppressed()` row added; the `.cell_rows()` claim rejected; `.sata_pct_cell()` stays | LANDED | 2.1 carries the `.empty_suppressed()` paragraph and the `threshold` reason. 2.3 keeps `.write_suppression_footnote()` and VI carries its cost. 2.1 states that `.cell_rows()` dispatches on `type` and reads neither field |
| 45 | State the label-and-term rule in 3.15 | LANDED | 3.15: "`Unweighted sample size` is byte-identical to the label in section 3.4", with the `(ESS)` departure named and the no-constant decision stated |
| 46 | B — delete the obligation from both artifacts | LANDED | Spec 5.2: "The review procedure itself is not restated here." The test-spec keeps only the fact that crosstab snapshots move. Gate VIII holds no snapshot line |
| 47 | A — estimate, withhold, build, render | LANDED | 3.11 steps 14 to 17, with "Steps 15 and 16 are in this order because `.build_workbook()` receives the withheld frame". 2.2 and 3.14 forbid a `withheld_note` argument on `.write_cover_sheet()`, which closes issue 64 in the same edit |
| 48 | A — parameterize `.total_col_group()` | LANDED | 2.3 gives the before and the after; 2.1 records six call sites in three files, which the tree confirms; 3.9 names the helper as the holder of both strings |
| 49 | A, on all seven rows | LANDED | `XS-03`, `XS-04`, `XN-02`, `XN-03` and `TN-04` round the oracle; `TN-01` and `TN-03` compare header text exactly. The Tolerances section states the rule once and adds "A tolerance is never widened to absorb the rounding" |
| 50 | Row deleted, id retired with a gap, 3.19's `testing.md` claim corrected | LANDED | `XX-05` appears only in the retirement paragraph and no row takes the number. 3.19 now lists `testing.md`'s five required edge cases, which matches that file |
| 51 | Three rows plus two spec fixes | LANDED | `XA-05` asserts four of five terms with one absence, `XA-05a` flips the two conditional entries, `TP-06a` covers the topline interval entry. 3.15 names the seven arguments and which four decide entries. See new issue 70 on `XA-05`'s fixture |
| 52 | A — four sheet-property rows, plus `XA-12` and a heading height | LANDED | `XB-01` to `XB-04` and `XA-12`. 3.16 fixes the heading row at 30 points, which `XB-03` asserts |
| 53 | A — define the warning dual pattern in the test-spec | LANDED | Assertion conventions give the warning form, record that no warning snapshot exists in the tree, and flag the repo rule. `XV-04`, `XV-05` and `XV-06` are marked dual pattern |
| 54 | Table restored, plus two entries converted to scenarios | LANDED | "Template section coverage" holds both files' sections. The totals — 22 sections, 19 covered, 3 N/A — add up. `XD-01` and `TP-13` are the two conversions |
| 55 | Spec line in 3.9 and one row; the all-withheld case deferred to 62 | LANDED | 3.9: "`show_total = FALSE` removes the group", with the base-note and sample-size paragraph. `XH-09a` is the row |
| 56 | `Inf` added to `XE-11` and to 3.19 | LANDED | `XE-11` runs five inputs including `Inf`, with the `Inf >= 0` reason. 3.19's last row names `Inf` |
| 57 | Two order rows | LANDED | `XR-01` and `XR-02` compare column A as an ordered character vector and differ in `sample_size_display` alone |
| 58 | 7.2 row, 7.1 line, gate VIII grep | LANDED | 7.1's last row reads "present, names no sheet" for both functions; 7.2 has a `@returns` row for both; gate VIII extracts each `\value{}` block and greps it |
| 59 | Measured content list, plus 4.2 and `TN-01` | LANDED | 7.2 gives `export_topline()`'s `@details` and Workbook Layout content, every fact with a grep target. 4.2 carries the `%` plus `(Eff N=1,234)` header form; `TN-01` asserts it as exact text |
| 60 | `@description` and `@param` rows | LANDED | 7.1's first two rows, measured 2026-09-16, with `@param` reading "partly" for `export_crosstab()` |
| 61 | B — keep the signature, replace the claim | LANDED | 3.1 names the one deviation, measures `layout` as the fifth argument, and records that `code-style.md` contradicts itself |
| 62 | 3.5 statement, 3.9 marker, the writer contract, 3.19 row, `XX-13` | LANDED | 3.5 has the degenerate row and the row-by-row paragraph; 3.9 has "One combination needs both sections"; 2.2 and 3.4 make a zero-row `counts` frame valid; 3.19 carries the row. See new issue 69 on `XX-13`'s warning claim |
| 63 | C — user override: a design variable errors | LANDED | `surveyreports_error_design_variable_selected` in 3.17, 3.10, 3.19, 4.1, 5.1 and `error-messages.md`; `.reject_design_vars()` in 2.1 and 2.2 with the per-subclass slot reader; step 9 of 3.11; scenarios `XE-12` to `XE-15` and `TE-04` |
| 64 | One line on the signature | LANDED | Resolved inside 47. 2.2: "THIS HELPER TAKES NO withheld_note ARGUMENT AND READS NONE" |
| 65 | Citations converted, load-bearing ones kept, policy stated | LANDED | The document-purpose section states the policy. The `733-739` range is gone and 3.3 names `.sata_pct_cell()`. Every remaining line number marks an expression the builder edits or deletes, and all of them re-measure correctly in the tree |
| 66 | A and B — the `NULL` default and the domain row | LANDED | 3.2 and 3.9 give the default; 3.14 gives the `Restricted to` row; `.has_domain()` is in 2.2; 3.15 keeps five terms with the reason; 5.1 records no new breaking change. Scenarios `XH-08a`, `XH-08b` and `XA-13` |
| 67 | One glossary sentence | LANDED | The `Percentages` entry opens "Each percentage is based on the people who answered that question, which can be fewer than the sample size shown above the table." `XA-05` asserts it and says a run asserting the four rounding forms alone fails |
| 68 | 4.2's `100%` row; the sheet index parked in VI | LANDED | 4.2 carries the `100%` row with the reason the first row does not cover it. VI parks the index and names the three costs of adding it |

No resolution is PARTIAL and none is ABSENT.

### Cross-artifact check

| Check | Result |
|---|---|
| Every function contract has at least one scenario | pass. All 18 new helpers and all 4 changed ones reach a scenario. `.render_block_preamble()` and `.render_block_footer()` reach `XR-01` and `XR-02`, `.has_domain()` reaches `XH-08a` and `XA-13`, `.reject_design_vars()` reaches `XE-12` to `XE-15` and `TE-04` |
| Neither file references the other | pass. No hit for `test-spec` in the spec, and none for `spec-export-metadata` in the test-spec |
| The spec carries no tolerance, dataset call, oracle call or test id | pass. No `1e-` value, no `tolerance`, no `expect_`, no scenario id. `make_all_designs()` appears only where the fixture is a deliverable, which Pass 1 issue 3 settled |
| The test-spec carries no `R/` path and no dot-prefixed helper name | pass. No `R/` hit, and a search for all 22 helper names returns nothing. Topline section 10's title is rewritten to avoid the frame builder's name |

### Number consistency

| Number | Places checked | Result |
|---|---|---|
| 18 new helpers, 15 plus 3 | 2.1 prose, 2.1 file table, 2.2 declarations, gate VIII | agree. The file table names 15 for `R/export-utils.R` and 3 for `R/export-crosstab.R`; 2.2 declares exactly 18 new signatures; the placement split is 3 by exception, 4 by the two-file rule and 8 shared by both functions |
| 6 error classes, 4 new warnings, 1 rename, 1 extension | 2.1, gate VIII, 3.17, 3.18, `plans/error-messages.md` | agree. 3.17 lists 6. 3.18 lists 6 rows, of which 4 are new, 1 renamed and 1 extended. `error-messages.md` holds all 6 errors and all 6 warnings, and no longer holds `surveyreports_warning_subgroup_suppressed` |
| Part A's write surface in `R/export-topline.R` — five items | 2.1, 2.3, 3.11, 4.1 | agree. All four name the same five: the `all_of()` fix, the design-variable check, the role guard, the threaded base notes and the deleted effective-N branch |
| 3.11 — 17 crosstab steps, 10 topline steps | every "step N" reference in the spec | agree. 17 less the 7 named exclusions is 10, and the topline list holds those 10 in order. Every reference resolves: step 8 is the `min_eff_n` check, step 9 the design-variable check, step 15 withholding, step 16 the workbook build, step 17 rendering, and topline step 5 the design-variable check |
| 5 glossary terms | 3.15, 4.1, 4.2, `XA-05`, `XA-05a`, `TP-06`, `TP-06a` | agree. Five defined, four true of the `XA-05` workbook, two or three of a topline workbook |
| 5 inline `* 100` sites, 2 retire, 3 stay | 2.3, 4.1, VI, 8.1, gate VIII | agree, and measured: the tree holds exactly 5, at the 5 cited lines |

### Scenario id integrity

178 ids are defined, each exactly once. No collision. The only id referenced and
never defined is `XX-05`, which the retirement paragraph names and no row takes.

Every id added this round resolves to exactly one definition row: `XW-13`,
`TE-03`, `XA-05a`, `TP-06a`, `XB-01`, `XB-02`, `XB-03`, `XB-04`, `XD-01`,
`XA-12`, `XH-09a`, `TP-13`, `XR-01`, `XR-02`, `XE-12`, `XE-13`, `XE-14`,
`XE-15`, `TE-04`, `XX-13`, `XH-08a`, `XH-08b` and `XA-13`.

### Gate VIII passability

Fifteen lines. Every one is a file check or a `grep`, and none needs the suite.
Each was tested against the current tree for the text that would make it fail,
or make it pass while proving nothing:

| Line | Result |
|---|---|
| `compute_eff_n` returns nothing | passes. No other name in `R/` holds the string |
| `pub_type` over `R/ man/` returns nothing | passes. Three files hold it today — `R/export-crosstab.R`, `R/export-utils.R` and `man/export_crosstab.Rd` — and all three are in scope. `export_topline()` never reads it |
| `show_n` over `R/export-crosstab.R` returns nothing | passes. Every hit today is the argument or a pass-through, and `show_ess` does not hold the string |
| `subgroup_suppressed` over `R/ man/ tests/` returns nothing | passes. Two files hold it, `R/export-utils.R:459` and `tests/testthat/test-export-crosstab.R`. `man/` and `_snaps/` hold none. The `plans/` exclusion is stated |
| `error-messages.md` holds the classes | passes. Verified row by row |
| The 15 and the 3 helper names | passes. It reads from 2.1's table, whose counts agree |
| The PR description states the placement exception | passes, but it is neither a file check nor a `grep`, which the section's opening sentence claims of every line. A reviewer verifies it from the PR body, so it does not need the suite. Recorded, not raised |
| `* 100` returns three lines across two files | passes. The tree holds exactly 5 lines at the 5 cited sites, and the 2 named ones retire |
| `design_variable_selected` in `R/export-utils.R` only | passes. Roxygen in this package names a condition class once, in `R/pool-pvals.R`, so the convention does not put class names in the two export files' comments |
| `phase1` inside `.reject_design_vars()` | passes. The one hit today is `R/export-utils.R:138`, inside `.compute_eff_n()` at lines 134 to 163, which this spec deletes. After the change the helper's own line is the only one |
| `testing.md`'s "Gap to close" note removed | passes |
| `man/` regenerated and tracked | passes |
| Both functions meet Tier 4 | passes. Four greppable facts |
| The `\value{}` block names its sheets | passes. `sed` then `grep`, one file at a time |
| `DESCRIPTION` pins `@develop` | passes |

No line of the already-fixed kind remains. No `grep` is scoped so that the
spec's own text satisfies it.

### New issues found

**Issue 69: `XX-13` asserts one warning where the contract raises two**
Severity: REQUIRED. Introduced by the issue 62 resolution.

`XX-13` reads: "`banner_all_withheld` is the **only** warning raised: assert it
fires, and assert no second warning arrives for the empty block". Spec 3.5
carries the same words at the block: "The existing warning still covers it, and
no second warning fires."

Section 3.18 gives `surveyreports_warning_subgroup_withheld` the trigger "one or
more subgroups fall below `min_eff_n`. Once per call", and `XV-03` records that
it fires even at `withheld_note = "none"`. `XX-13` puts `min_eff_n` above every
subgroup's effective N, so that warning fires too. Section 3.11's emission order
lists both classes and `XV-11` runs a call that raises several, so two warnings
in one call is the ordinary case.

The intent in 3.5 is "no new class for the empty block", and its next two
sentences say exactly that. The literal sentence, and the `XX-13` assertion built
on it, fail against correct code.

Fix, one line in each artifact: 3.5 reads "no warning class is added for the
empty block", and `XX-13` asserts that `banner_all_withheld` fires, that
`subgroup_withheld` fires, and that no third class arrives.

**Issue 70: `XA-05`'s fixture renders no banner, and the entry it asserts is
conditional on one**
Severity: REQUIRED. Introduced by the issue 51 rewrite, which gave the row its
inputs.

`XA-05` runs `banner = group` at `min_eff_n = 100` and asserts that
`Why a column is missing` is present. Section 3.15 makes that entry conditional
on "`min_eff_n > 0` **and a banner was rendered**".

Measured on `make_survey_data()`: `group` holds three levels over 200 rows, so
each level carries about 67 rows and an effective N near 62. At `min_eff_n = 100`
every level is withheld, `banner_all_withheld` fires, and the workbook holds the
Total column alone. Under the plain reading of "a banner was rendered" the entry
is absent and the row fails. Under the reading that `has_banner` reports only
that the call resolved a banner, it passes. Both readings are available in 3.15,
and `.write_cover_sheet()` runs at step 16, after withholding, so either is
implementable.

Fix: state in 3.15 which fact `has_banner` carries, and give `XA-05` a floor that
leaves a banner column standing. The labelled `gen` fixture at `min_eff_n = 50`
renders `Male` and withholds `Female`, so the entry is true of the workbook under
test.

### Summary

All 33 resolutions landed. None is partial and none is absent. The four
cross-artifact checks pass. The six numbers that moved most agree in every place
the spec states them, and three of them re-measure correctly against the tree.
All 178 scenario ids are unique, every id added this round resolves, and `XX-05`
is retired with nothing reusing it. All fifteen gate VIII lines pass without the
suite.

Two new issues, both one-line edits. Each is a row that asserts a warning or an
entry against a condition the spec states elsewhere. Neither re-opens a
resolution.

One provenance gap, recorded and not raised: the decisions log's 2026-09-16
outcome closes at spec v0.17.0, and the spec header reads v0.18.0. Section XI
records no v0.18.0 change.

VERDICT: PASS — with issues 69 and 70 to close before the implementation plan.

---

## Pass 5 resolve (2026-09-16)

Both new issues are closed. Neither needed a user decision.

**Issue 69 — the second warning.** Section 3.5's headline read "no second
warning fires", while its body said the narrower and correct thing: this spec
adds no warning class for the empty block.
`surveyreports_warning_subgroup_withheld` does fire there, because subgroups
fell below the floor. The headline now matches the body, and it names both
classes. `XX-13` asserts both, and asserts that no third warning arrives.

**Issue 70 — `has_banner`.** Section 3.15 now states what the argument carries:
`has_banner` records that the caller supplied a `banner`, not that a column
survived the floor. So `Why a column is missing` still appears when every
banner level is withheld, which is the case that most needs the entry.
`XA-05`'s floor moved from `100` to `50`, below every `group` level's effective
N, so every banner column survives and the row is about the glossary alone.
`XA-05a` stays at `0`, so the pair still differs in `min_eff_n` and `variance`
alone.

**The provenance gap** Pass 5 recorded is closed too. The decisions log has an
addendum covering v0.18.0 and v0.19.0.

Spec v0.19.0. Test-spec v0.14.0. Leak checks clean on both. Table integrity
clean on both.

VERDICT: PASS — Stage 3 is complete.
