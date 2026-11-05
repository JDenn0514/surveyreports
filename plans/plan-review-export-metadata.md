# Plan review — export-metadata

Adversarial review of `plans/impl-export-metadata.md`. Each pass appends a
section. Never overwrite a prior pass.

---

## Plan Review: export-metadata — Pass 1 (2026-09-22)

Plan under review: `plans/impl-export-metadata.md` v3.0.0 — 19 PRs, 598 tasks,
218 acceptance criteria, a strict chain where PR n depends on PR n−1.

All five lenses ran. Lenses 1, 2 and 5 ran on sonnet; lenses 3 and 4 ran on
opus, because each compares two large documents. Twenty-seven raw findings
deduplicate to twenty-one, because four defects were found by two lenses each.

### What the plan gets right

State this first, so the findings below are read in proportion.

- **Spec coverage is complete.** 18 of 18 new helpers, all 9 changed or deleted
  helpers, all 20 subsections of spec III, all 6 error classes and all 6 warning
  classes, 14 of 15 gate VIII lines, 10.5 of 11 invariants in 8.1, and 7 of 8
  breaking changes in 5.1 each reach a PR. Section 1.6's `survey_nonprob`
  fixture is delivered.
- **The chain is sound.** The `Depends on:` line is strict and gapless from 1 to
  19. No circular dependency. No missing link.
- **Spec IX's forced ordering holds.** In `feature/crosstab-label-cols-and-sizes`,
  tasks 4 to 9 add `label_cols` and the battery adoption before task 21 extracts
  `.render_block_preamble()`.
- **All four cross-PR references resolve.** Each names a branch rather than a
  number, and each points the right way along the chain.
- **Helper dependency order is right.** `.unanimous_across()` precedes the two
  resolvers, which precede `.apply_role_guard()`.
- **Citation hygiene is sound.** Every scenario id cited in a criterion exists in
  the test-spec. Every `spec N.N` reference resolves to a real heading. No
  dangling pointer.
- **Every owned scenario reaches a criterion.** For all 14 PRs that own
  scenarios, the ids in "Scenarios owned" equal the ids cited in that PR's
  criteria. No scenario is assigned and then dropped.
- **`plans/error-messages.md` is handled correctly.** The plan measured the
  committed file, found all ten classes present, and made PR 1's task a check
  with a close-the-gap rule.

The defects below are specific omissions. The shape of the plan is not in
question.

---

### New issues

#### Section: the write-surface rule for generated files

**Issue 1: the documentation deferral makes `devtools::check(): 0 warnings` unreachable on PRs 11 to 18**
Severity: BLOCKING
Violates the standard criterion "`devtools::check()` clean, 0 errors, 0
warnings", and the rule that a criterion must be reachable inside its own PR's
write surface. Raised by lens 3 and lens 5 independently.

The plan confines `man/`, `NAMESPACE` and `_pkgdown.yml` to PR 19 and says so:
"No code PR above touches `man/`, `NAMESPACE` or `_pkgdown.yml`." Five PRs then
change the formal arguments of the exported, documented `export_crosstab()`:

| PR | Task | Change |
|---|---|---|
| `feature/crosstab-min-eff-n` | 4 | removes `pub_type`, adds `min_eff_n` |
| `feature/crosstab-withheld-notices` | 22 | adds `withheld_note` |
| `feature/crosstab-label-cols-and-sizes` | 12 | removes `show_n`, adds `sample_size_display` and `show_ess` |
| `feature/crosstab-variance-strings` | 4 | adds `variance_display` |
| `feature/crosstab-total-and-missing` | 4, 21 | adds `show_total`, `total_label`, `na.rm`, `na_label` |

Measured 2026-09-22. `man/export_crosstab.Rd` carries the old signature: the
`\usage{}` block reads `pub_type = c("none", "external", "internal")` and
`show_n = TRUE`, and `\arguments{}` holds `\item{pub_type}` and `\item{show_n}`.
CI runs `r-lib/actions/check-r-package@v2`, which checks a built tarball and
does not re-run roxygen, so the committed `.Rd` is what `R CMD check` reads.

From `feature/crosstab-min-eff-n` onward, `R CMD check` reports **Codoc
mismatches** and **Undocumented arguments in documentation object
'export_crosstab'**. Both are WARNINGs, not notes. Eight consecutive PRs carry a
merge gate that none of them can pass.

Two more criteria fail from the same cause, and both are mechanical:

- `feature/crosstab-min-eff-n`: "`grep -rn "pub_type" R/` returns nothing."
  `R/export-crosstab.R:29` is `#' @param pub_type One of ...`. The roxygen
  comment is inside `R/`, so the grep returns line 29.
- `feature/crosstab-label-cols-and-sizes`: "`grep -rn "show_n" R/export-crosstab.R`
  returns nothing." `R/export-crosstab.R:38` is `#' @param show_n Logical. ...`.

The plan also contradicts itself on who deletes those two roxygen lines.
`docs/export-metadata` task 6 says "Remove the `@param pub_type` and
`@param show_n` entries", which assumes they survive to PR 19, while the two
greps above assert they are already gone.

Options:
- **A** Each PR that changes a signature edits its own roxygen, runs
  `devtools::document()`, and adds `man/export_crosstab.Rd` and `NAMESPACE` to
  its write surface. `docs/export-metadata` then carries only the prose of spec
  7.2 — `@details`, `@section Workbook Layout`, `@returns`, `@seealso` —
  Effort: medium, Risk: low, Impact: `check()` stays green across the chain, the
  two grep criteria become true where they are written, and the strict chain
  means no two PRs contend for `man/`.
- **B** Keep the deferral and downgrade the criterion on PRs 11 to 18 to "0
  errors; the only warnings are the codoc and undocumented-argument warnings
  named here" — Effort: low, Risk: medium, Impact: eight PRs merge with a
  known-warning `check()`, so the gate stops discriminating and a real warning
  hides among the expected ones.
- **C** Do nothing — every PR from 11 to 18 fails its own merge gate, and the
  builder either invents option A mid-chain or forces the merge.

**Recommendation: A** — the chain is strict, so nothing is contended, and it is
the only option that keeps "0 warnings" meaning what it says. This reverses the
docs-last decision for formal arguments only; the prose deferral of spec 7.3
still holds, because stale prose is not what the Rd checks catch.

---

#### Section: PRs that remove an argument

**Issue 2: four PRs remove arguments that committed tests still pass, and no task deletes those tests**
Severity: BLOCKING
Violates "does the first PR leave `develop` in a state where CI passes", applied
at every link of the chain. Raised by lens 2 and lens 3.

Measured 2026-09-22 in `tests/testthat/test-export-crosstab.R`:

- Section 10, "pub_type suppression", holds five `test_that()` blocks at lines
  589, 632, 667, 700 and 740. They pass `pub_type` at lines 615, 654, 693, 733
  and 772 — 14 occurrences of the string in the file. They assert
  `class = "surveyreports_warning_subgroup_suppressed"`.
- Section 9, "show_n and show_eff_n", holds three blocks at lines 517 to 583,
  passing `show_n` and `show_eff_n` — 9 occurrences in the file.

`export_crosstab()` takes no `...`. Measured: zero `...` in its formals. So the
moment `feature/crosstab-min-eff-n` task 4 removes `pub_type`, all five blocks
raise `unused argument (pub_type)`. That is a hard error, not a test failure.
`devtools::test()` and `devtools::check()` both go red, and that PR's own gate
is unreachable. `feature/crosstab-label-cols-and-sizes` does the same to the
three `show_n` blocks.

Swapping the argument would not save them either. No PR before
`feature/crosstab-withheld-notices` raises any withholding warning, so the
`subgroup_suppressed` assertions would still fail.

The plan contains **no task anywhere that deletes an existing test section**.
Searched: no match for a delete instruction against section 9 or section 10.
The nearest task, `feature/crosstab-min-eff-n` task 10, reads "Add
`min_eff_n = 0` to any other block that now asserts on a withheld table" — which
does not describe these blocks, because they fail on the signature and not on a
withheld table. Both PRs' grep gates are scoped to `R/`, so neither catches the
survival of a test.

The test-spec already marks template section 10 N/A, with the reason. The
decision exists. It is not carried into the PR that executes it.

Options:
- **A** Add to `feature/crosstab-min-eff-n` a task "Delete section 10 of
  `tests/testthat/test-export-crosstab.R`, five blocks; the test-spec marks the
  template section N/A" and a criterion "`grep -n "pub_type"
  tests/testthat/test-export-crosstab.R` returns nothing". Add the matching pair
  for section 9 to `feature/crosstab-label-cols-and-sizes` — Effort: low, Risk:
  low, Impact: the deletion becomes a recorded decision, and the reviewer sees
  coverage move rather than vanish.
- **B** Leave it to the "run `devtools::test()`, confirm green" step and trust
  the builder to notice — Effort: none, Risk: medium, Impact: the builder may
  patch symptoms, for example keeping a dead `subgroup_suppressed` assertion and
  reintroducing the retired class, which muddies the rename.
- **C** Do nothing — the task list followed literally does not produce a green
  PR, and the coverage drop is attributed to the wrong cause.

**Recommendation: A** — one task and one criterion per PR closes a confirmed
break at a hard chain gate.

---

**Issue 3: `show_eff_n` is never removed from `export_crosstab()`**
Severity: BLOCKING
Spec 5.1 breaking-change row 3, and spec 3.2, reach no task, no criterion and no
gate. Raised by lens 4; lens 2 reached the same ambiguity from the test side.

Spec 5.1 lists "`show_eff_n` renamed `show_ess`, default `FALSE` to `TRUE`" as a
breaking change. Spec 3.2 says `show_ess` "Replaces `show_eff_n`, which was a
no-op". `feature/crosstab-label-cols-and-sizes` task 12 reads: "Remove `show_n`
from the `export_crosstab()` signature, and add `sample_size_display` and
`show_ess = TRUE`." It says nothing about `show_eff_n`.

Measured: `show_eff_n` appears 12 times in `R/export-crosstab.R`, including the
exported signature at `:82` and the `@param` block at `:40`. Every mention of
`show_eff_n` in the plan concerns `export_topline()` — the join block deleted in
`feature/effective-n-rewiring`, and scenario `TC-08`. `show_ess` appears 3 times
in the whole plan.

`feature/effective-n-rewiring` deletes the `show_eff_n` join block in
`R/export-utils.R`, which makes the crosstab argument fully inert from that PR
onward. `feature/crosstab-label-cols-and-sizes` then adds `show_ess` beside it.
`docs/export-metadata` task 6 removes the `@param pub_type` and `@param show_n`
entries and not `@param show_eff_n`. Scenario `XE-07` asserts the unused-argument
error for `pub_type` and `show_n` only. Gate VIII greps for `pub_type` and
`show_n`, never for `show_eff_n`.

As planned, the release ships an `export_crosstab()` carrying both a documented,
inert `show_eff_n` and a working `show_ess`.

Options:
- **A** Add to `feature/crosstab-label-cols-and-sizes` a task "Remove
  `show_eff_n` from the `export_crosstab()` signature and from its ten internal
  call sites", a criterion "`grep -rn "show_eff_n" R/export-crosstab.R` returns
  nothing", and extend `XE-07`'s criterion to name `show_eff_n` as a third
  unused argument. Add `@param show_eff_n` to `docs/export-metadata` task 6 —
  Effort: low, Risk: low, Impact: closes the breaking change and matches spec
  3.2.
- **B** Leave it as a deprecated no-op and state that in spec V — Effort: low,
  Risk: medium, Impact: contradicts spec 5.1, which calls the rename breaking.
- **C** Do nothing — the release ships two sample-size arguments, one dead and
  documented, and the spec 5.1 row is unimplemented.

**Recommendation: A** — the removal belongs in the PR that introduces its
replacement, and that PR's write surface already allows it.

---

**Issue 4: no PR pins the final argument order of spec 3.1**
Severity: BLOCKING
Spec 3.1 fixes the order exactly and states "No shipped argument moves". Raised
by lens 4.

Nine new or changed arguments arrive across five PRs. Every task says only "add"
or "replace", and none states a position:

- `feature/crosstab-min-eff-n` task 4 — `min_eff_n`
- `feature/crosstab-withheld-notices` task 22 — `withheld_note`
- `feature/crosstab-label-cols-and-sizes` task 12 — `sample_size_display`, `show_ess`
- `feature/crosstab-variance-strings` task 4 — `variance_display`
- `feature/crosstab-total-and-missing` task 4 — `show_total`, `total_label`, and task 21 — `na.rm`, `na_label`

Spec 3.1's order is `design, vars, banner, file_name, layout, interactions,
min_eff_n, variance, variance_display, conf_level, sample_size_display,
show_ess, decimals, show_total, total_label, na.rm, na_label, withheld_note,
base_notes`.

A builder appending each argument as it arrives produces `min_eff_n,
withheld_note, sample_size_display, show_ess, variance_display, show_total,
total_label, na.rm, na_label`. The two differ. `show_total` already ships in the
current signature, so the appended order also moves a shipped argument — the one
thing spec 3.1 forbids, and the thing its two defending paragraphs are about.

No criterion in any PR compares the signature against spec 3.1. The test-spec
has no scenario and no profile gate on argument order.

Options:
- **A** Add to `feature/crosstab-total-and-missing`, the last PR that touches the
  signature, the criterion "`names(formals(export_crosstab))` is identical to the
  order of spec 3.1", and add the target position to each of the five insertion
  tasks — Effort: low, Risk: low, Impact: the order becomes a checked contract in
  one place, and each PR knows where its argument goes.
- **B** Add the identical-order criterion to all five PRs, each against the
  partial order at that point — Effort: medium, Risk: low, Impact: catches drift
  earlier, at the cost of five partial orders to maintain.
- **C** Do nothing — the order is whatever insertion produced, a shipped argument
  moves, and spec 3.1's reasoning is discarded silently.

**Recommendation: A**.

---

#### Section: PRs 2 to 5, the helper PRs

**Issue 5: fifteen helpers are defined 5 to 11 PRs before their first caller**
Severity: REQUIRED
Raised by lens 1. See the note below on the rule it collides with.

`feature/metadata-readers`, `feature/metadata-unanimity`,
`feature/metadata-guards` and `feature/format-helpers` add 15 internal functions
and own 0 of 178 scenarios between them. The gap from definition to first call
site:

| Helper | Defined in | First called in | Gap |
|---|---|---|---|
| `.resolve_eff_n()` | `feature/metadata-readers` | `feature/effective-n-rewiring` | 5 PRs |
| `.resolve_roles()`, `.resolve_base_notes()` | `feature/metadata-unanimity` | `feature/base-notes-adoption` | 5 PRs |
| `.apply_role_guard()`, `.reject_design_vars()` | `feature/metadata-guards` | `feature/topline-guards` | 5 PRs |
| `.fmt_pct()` | `feature/format-helpers` | `feature/crosstab-percent-cells` | 11 PRs |

For up to 11 PRs each helper is verified only by a direct unit test written
against the spec's description of its signature, with no confirmation against a
real call site. If the call site later needs a different return shape, the fix
lands far downstream and the defining PR's tests become dead weight.

**This finding collides with two things the lens was not given.** First,
`.claude/skills/implementation-workflow/references/stage-1-draft.md` states that
shared infrastructure "ships in its own PR before the functions that depend on
it" — the opposite of the lens's own recommendation. Second, the user chose this
split deliberately, twice, to cut PR size. Folding the helpers into their callers
would re-inflate PRs 6 to 17, which is the problem the splits solved.

What survives both objections is narrower: the risk is a return shape chosen
without its consumer. That is mitigated by a criterion, not by restructuring.

Options:
- **A** Keep the four helper PRs and pin each helper's return shape in its
  defining PR's criteria, naming the consuming call site — Effort: low, Risk:
  low, Impact: keeps the approved structure and the drafting rule, and closes
  the real risk.
- **B** Dissolve PRs 2 to 5 and fold each helper into the PR that first calls it
  — Effort: high, Risk: medium, Impact: every helper is then tested through its
  caller, but this contradicts `stage-1-draft.md` and reverses a user decision.
- **C** Do nothing — four review cycles approve code with no observable behavior
  change, on unit tests written against spec text alone.

**Recommendation: A**.

---

**Issue 6: eight helper behaviors are tested by a task but pinned by no criterion**
Severity: REQUIRED
These four PRs own no scenario, so their criteria are the only contract.
Raised by lens 3.

- `.unanimous_across()` — tasks test three behaviors. The only criterion is that
  `R/export-utils.R` "defines" it. No behavioral criterion at all, on the helper
  that carries the unanimity rule for the whole feature.
- `.banner_levels_labelled()` — the criterion covers factor in, factor out with
  level order intact. Missing: non-factor returns character, `NA` preserved.
- `.resolve_roles()` — the task names five payload shapes, the criterion names
  three. The two happy-path shapes have no criterion.
- `.resolve_base_notes()` — "both empty returns `NULL`" is tested and uncriteried.
- `.apply_role_guard()` — "returns the survivors in input order" has no
  criterion. Input order is load-bearing: `XM-15` asserts the sheet name follows
  the first survivor.
- `.fmt_variance()` — the empty-string case has no criterion.
- `.write_sample_size_rows()` — the zero-row case has a criterion; the happy path
  does not.

Options:
- **A** Add one criterion per uncovered behavior, each citing the spec 2.2
  contract line it comes from — Effort: low, Risk: low, Impact: all eleven
  helpers get a checkable target, not five.
- **B** One line per helper: "satisfies every bullet of its spec 2.2 contract" —
  Effort: low, Risk: medium, Impact: shorter, but the tester cannot read the spec
  at all.
- **C** Do nothing — nothing blocks a merge that skips the tests.

**Recommendation: A**.

---

**Issue 7: no numerical tolerance appears anywhere in the plan, and PRs 2 to 5 have no source for one**
Severity: REQUIRED
Raised by lens 3.

The string "toleran" appears zero times in `plans/impl-export-metadata.md` and
zero times in `plans/spec-export-metadata.md`.

For the PRs that own numerical scenarios this is harmless: every numerical
criterion names a scenario, and the test-spec carries a per-row tolerance column
and a Tolerances table, so the tester is served.

`feature/metadata-readers` is not served. Its task asks for a direct test that
`.resolve_eff_n()`'s `n` and `n_eff` match `surveycore::get_effective_n()`, and
the criterion repeats the oracle comparison. The builder reads only the spec,
which has no tolerance table. The fallback, `.claude/rules/testing.md`, gives
1e-10, 1e-8 and 1e-6 — and has **no row for effective N**. The test-spec does,
and calls it a deliberate classification: "Effective N | `1e-8` — an SE-class
quantity, not a point estimate." The builder never sees that line, so it either
treats `n_eff` as a point estimate at 1e-10 or falls back to `expect_equal()`'s
default. Neither is the decision the test-spec made.

Options:
- **A** State the tolerance on the `.resolve_eff_n()` criterion — `n` exact as
  integers, `n_eff` at 1e-8 — and add the effective-N row to the spec's contract
  for that helper — Effort: low, Risk: low, Impact: builder and tester agree on
  one number.
- **B** Copy the whole tolerance table into the spec — Effort: low, Risk: medium,
  Impact: two copies that drift; the pipeline split exists to avoid that.
- **C** Do nothing — the helper test ships with a tolerance nobody chose.

**Recommendation: A**.

---

#### Section: standard gates

**Issue 8: PR 1 carries no `air format --check .` criterion and no coverage criterion**
Severity: REQUIRED
Raised by lens 3.

Every PR from 2 to 18 carries both lines and an `air format .` task.
`chore/export-metadata-infra` carries neither, and its write surface holds three
R files: `tests/testthat/helper-test-data.R` and both test files. It adds a
`nonprob` design to the generator and edits both cross-design loops, so it writes
new R code.

If it lands unformatted, the next PR's criterion "`air format --check .` passes"
fails on files it never touched, and its builder must reformat outside its write
surface or waive the gate.

Options:
- **A** Add the task and both criteria to `chore/export-metadata-infra` —
  Effort: low, Risk: low, Impact: brings PR 1 in line and stops the leak.
- **B** Add the air criterion only — Effort: low, Risk: low, Impact: fixes the
  leak, leaves the coverage line inconsistent.
- **C** Do nothing — PR 2 inherits a formatting failure it did not cause.

**Recommendation: A**. `docs/export-metadata` may stay as it is, because `air`
does not reformat roxygen comments.

---

**Issue 9: the coverage criterion is stricter than the gate the tester runs**
Severity: REQUIRED
Raised by lens 3.

Thirteen PRs carry "Coverage at or above 98 percent; no uncovered new line." The
test-spec's profile gate, which is what the tester runs, reads
"`covr::package_coverage()` — 95% floor, 98% target, no uncovered new lines".
A PR at 96 percent passes the tester and fails the plan. The shipper gates on the
tester's verdict, so the 98 line never blocks anything.
`.claude/rules/testing.md` matches the test-spec, so the plan is the outlier.

"No uncovered new line" also carries no command. Identifying new lines needs
`covr::zero_coverage()` filtered to the changed files.

Options:
- **A** Restate the criterion as the gate states it, and give "no uncovered new
  line" the `covr::zero_coverage()` command — Effort: low, Risk: low, Impact:
  criterion and gate become the same test.
- **B** Raise the test-spec gate to a hard 98 percent — Effort: low, Risk:
  medium, Impact: contradicts `.claude/rules/testing.md`.
- **C** Do nothing — thirteen criteria read as a gate and act as a wish.

**Recommendation: A**.

---

**Issue 10: two PRs run `snapshot_review()` but list no snapshot file**
Severity: REQUIRED
Raised by lens 5.

`feature/cover-sheet` task 22 and `feature/base-notes-adoption` task 19 both
review moved snapshots. Neither write surface lists `_snaps/export-topline.md`
or `_snaps/export-crosstab.md`. Every other PR with that task does list the
matching file, and the master write-surface table also excludes these two.

So either the master table is right and both tasks are dead boilerplate, or the
table is wrong and both PRs are missing a declared file.

Options:
- **A** Delete the snapshot-review task from both PRs. Neither changes a
  condition message: `feature/cover-sheet` adds the About sheet and routes
  worksheet names, `feature/base-notes-adoption` changes base-note text —
  Effort: low, Risk: low, Impact: the task matches the declared surface.
- **B** Add both snapshot files to both write surfaces defensively — Effort: low,
  Risk: low, Impact: contradicts the master table, which then also needs editing.
- **C** Do nothing — a reviewer checking declared surface against actual gets a
  false alarm or a silent violation.

**Recommendation: A**.

---

#### Section: spec behaviors with no criterion

**Issue 11: PR 18's `na.rm` criterion names a call site outside its write surface**
Severity: REQUIRED
Raised by lens 3 as BLOCKING and by lens 4 as SUGGESTION. Recorded here as
REQUIRED: the criterion is unreachable as written, but spec 4.1 makes the right
answer unambiguous, so it does not stop implementation.

`feature/crosstab-total-and-missing` carries "`na.rm` reaches all five call sites
of spec 3.13 with the same value". Its tasks reach four. Spec 3.13's fifth row is
the collection path of `export_topline()`, and `R/export-topline.R` is not in
that PR's write surface. No PR gives `export_topline()` an `na.rm` argument, so
no caller can set a value on that path and the criterion cannot be observed.

Options:
- **A** Reword to the four reachable sites, and record the fifth as out of scope
  because `export_topline()` takes no `na.rm` and spec 4.1 bounds its change —
  Effort: low, Risk: low, Impact: the criterion becomes checkable and the spec's
  fifth row is answered rather than ignored.
- **B** Add `na.rm` to `export_topline()` — Effort: high, Risk: high, Impact:
  breaks the "no topline snapshot moved" criterion in the same PR and exceeds
  spec 4.1.
- **C** Do nothing — the builder skips the site or reaches outside the surface,
  and the shipper's surface check fails.

**Recommendation: A**.

---

**Issue 12: the About sheet's column widths and its "no merged cells" rule reach no PR**
Severity: REQUIRED
Spec 3.14's Styling row is absent from the plan. Raised by lens 4.

Spec 3.14 states: "Styling | bold, the block structure, and the column widths of
section 3.16. No merged cells". `feature/cover-sheet` writes the three blocks,
the domain row and the collection branch, and sets no width and no alignment.
Its criteria name presence, position, keys, domain row, collisions and glossary
— none names a width or a merged cell. `feature/crosstab-sheet-properties` sets
widths, but its criterion `XB-01` is about the question-block shape, not a
`Key`/`Value` sheet. No `XA` scenario covers either fact; the closest, `XA-12`,
covers bold alone.

Options:
- **A** Add to `feature/cover-sheet` a task that sets the `Key` and `Value`
  widths, and a criterion "the About sheet holds no merged cell, and both columns
  carry a stored width" — Effort: low, Risk: low, Impact: the sheet is legible on
  first open.
- **B** Move the cover-sheet widths into `feature/crosstab-sheet-properties` —
  Effort: low, Risk: medium, Impact: the sheet ships unstyled for nine PRs, and
  that PR's write surface excludes the cover-sheet writer.
- **C** Do nothing — the sheet renders at default width and a long universe value
  is cut off.

**Recommendation: A**.

---

**Issue 13: PR 15's `100%` criterion is wider than the spec and contradicts section 4.2**
Severity: REQUIRED
Raised by lens 4.

`feature/crosstab-sheet-properties` carries "No cell in any sheet holds the
string `100%` (test-spec XH-10; spec 3.9, spec 3.16)." Scenario `XH-10` reads "no
cell in **the sheet**" and sits in the crosstab table. Spec 4.2 says of
`export_topline()`: "The `100%` row | still written ... both stay."

That PR's task 4 is "Delete the `Total` row of `100%` cells from the single
route", and both files hold a single route — `.render_crosstab_single()` and
`.render_topline_single()`. Only the write surface keeps the deletion out of the
topline file, and the surface does include `tests/testthat/test-export-topline.R`.
No `TP` scenario asserts the topline row survives.

Options:
- **A** Narrow the criterion to an `export_crosstab()` sheet, and add "the
  topline still writes its `Total` row of `100%` cells (spec 4.2)" — Effort: low,
  Risk: low, Impact: the scope line becomes a checked assertion rather than a
  write-surface accident.
- **B** Narrow the criterion only — Effort: low, Risk: medium, Impact: a later PR
  can delete the row with no test failing.
- **C** Do nothing — a builder reading the criterion literally deletes the
  topline row, breaking spec 4.2 and the snapshot rule of spec 5.2.

**Recommendation: A**.

---

**Issue 14: spec 3.19's "unused factor level on the tabulated variable" reaches no criterion**
Severity: REQUIRED
Raised by lens 4.

Spec 3.19 holds two adjacent rows: unused factor level on the banner, and unused
factor level on the tabulated variable, the second reading "no response row; the
sample-size rows are unchanged". `feature/crosstab-withheld-notices` cites
`XX-06` and `XX-07`, and both are banner cases — the test-spec names them so.
Nothing asserts the tabulated-variable half, which is the half that interacts
with the sample-size rows.

Options:
- **A** Add the criterion to `feature/crosstab-sheet-properties`, which already
  owns the edge-case block and by which point the sample-size rows exist —
  Effort: low, Risk: low, Impact: closes the last uncovered row of spec 3.19.
- **B** Fold it into `feature/crosstab-withheld-notices` — Effort: low, Risk:
  low, Impact: that PR predates the sample-size rows, so the second half cannot
  be asserted there.
- **C** Do nothing — the case ships untested.

**Recommendation: A**.

---

**Issue 15: gate VIII's helper-inventory line reaches no criterion**
Severity: REQUIRED
Raised by lens 4.

Gate VIII: "`R/export-utils.R` holds the 15 shared helpers of section 2.1, and
`R/export-crosstab.R` holds the 3 helpers section 2.1 assigns to it ... below the
exported function. No `R/utils.R` was created."

Every other gate VIII line maps to a criterion. This one does not.
`feature/format-helpers` asserts `.unique_sheet_name()`'s placement alone.
`feature/crosstab-label-cols-and-sizes` creates the preamble and footer and
asserts only what they do, never where they live. No PR asserts the count of 15,
and none asserts that no `R/utils.R` appeared.

Options:
- **A** Add the whole gate line to `feature/crosstab-total-and-missing`, the last
  PR touching either file — Effort: low, Risk: low, Impact: counted once, when
  all 18 helpers exist.
- **B** Assert the three crosstab helpers' placement on
  `feature/crosstab-label-cols-and-sizes` and the count of 15 on the last PR —
  Effort: low, Risk: low, Impact: catches a misplaced preamble four PRs earlier.
- **C** Do nothing — a misplaced helper ships and only a reviewer reading
  `code-style.md` catches it.

**Recommendation: B**.

---

**Issue 16: the `variance = "se"` glossary entry reaches no PR, because the spec contradicts itself**
Severity: REQUIRED — and a HOLD. This one needs a decision from the spec owner.
Raised by lens 4.

Spec 3.15 ends: "When `variance` is set to `"se"`, an entry names the statistic
in the brackets in the same words as the legend row of section 3.12." The same
section also carries "**Decision (2026-09-16, issue 66): the glossary stays at
five terms.**" `.write_cover_sheet()`'s seven arguments drive three conditions,
not four.

The plan silently takes the five-term reading: `feature/cover-sheet` writes five
terms and three conditions, and `XA-05` and `XA-05a` assert four terms and a
two-entry flip. Under `variance = "se"` the workbook then holds a bracketed
standard error with a legend row and no glossary entry — the one case the closing
sentence was written for.

Options:
- **A** Record in `feature/cover-sheet` that the five-term table governs and the
  `"se"` sentence is superseded by the issue-66 decision, and raise a one-line
  spec correction — Effort: low, Risk: low, Impact: the contradiction is resolved
  in writing and the counts two scenarios assert stay put.
- **B** Add a sixth conditional entry, an eighth argument, and a scenario —
  Effort: medium, Risk: medium, Impact: contradicts the issue-66 decision and
  moves two asserted counts.
- **C** Do nothing — the builder meets two rules in one section and picks one
  with no record.

**Recommendation: A**, subject to the spec owner confirming that issue 66
governs.

---

### Suggestions

Recorded in brief. Each is a quality improvement, none blocks implementation.

**Issue 17: the Part A / Part B boundary is off by one between the Overview and the ordering table.** The Overview puts `feature/crosstab-guards` in Part B, matching spec X's file-based split and that PR's own write surface of `R/export-crosstab.R` alone. The ordering table says "PRs 7 to 10 precede PRs 11 to 18", putting it in Part A. Fix the table row. Raised by lens 2. **Recommendation: fix the table.**

**Issue 18: the standard gate criteria cite no source.** `docs/export-metadata` cites three gate lines as "(test-spec profile gates)". The other PRs carry identical gates uncited. Since the tester reads only the test-spec, the citation is what tells it the line is its job. The `changelog/{branch}.md exists` line comes from the PR checklist in `github-strategy.md` and has no source in either document. Raised by lens 3. **Recommendation: append the source to each.**

**Issue 19: "No exported function changes behavior" is not verifiable as written.** Carried by all four helper PRs. A negative claim over all inputs with no command. The check intended is a clean `git diff` over `_snaps/` plus a green suite. Raised by lens 3. **Recommendation: restate as the two commands.**

**Issue 20: four criteria point at a source instead of stating the outcome.** `feature/crosstab-sheet-properties` ("behave as spec 3.19 states"), `feature/crosstab-guards` ("their existing class", three classes, none named), `feature/crosstab-withheld-notices` ("both warnings"), `feature/crosstab-total-and-missing` ("two warnings and no third"). Each names a scenario, so the tester can resolve it; a reviewer reading the plan alone cannot. Raised by lens 3. **Recommendation: name the class or outcome inline.**

**Issue 21: five grep-checkable invariants are stated without the grep.** The plan sets this standard elsewhere — `grep -n "phase1"`, `grep -rn "compute_eff_n"`, `grep -rn "\* 100"` with an expected line count. Five siblings state the same kind of source-tree invariant in prose. Raised by lens 3. **Recommendation: give each a command.**

Two further suggestions are directed at documents other than the plan, and need
no plan edit:

- **Spec 2.1's file table is not exhaustive.** It omits `DESCRIPTION`,
  `.claude/rules/testing.md`, both snapshot files, `NAMESPACE`, `_pkgdown.yml`
  and the changelog, all of which the plan correctly claims. The table should
  state its scope. Raised by lens 5.
- **No PR states which `testing.md` template sections it closes.** The test-spec
  carries the mapping; the plan does not. Several sections split across PRs, so a
  reviewer of one PR cannot tell whether a section is still open. Raised by lens
  3. A single table beside the existing scenario-coverage table would carry most
  of the value.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 12 |
| SUGGESTION | 5 |

**Total issues:** 21, from 27 raw findings across five lenses.

**Verdict: BLOCK.**

**Overall assessment:** The plan's structure is sound and its spec coverage is
complete — the chain is strict and gapless, every new helper and every subsection
of the crosstab contract reaches a PR, and every owned scenario reaches a
criterion. Three of the four blocking issues share one root cause: the plan was
written as though the tree held no existing `export_crosstab()` signature, no
existing `man/` entry for it, and no existing tests for the arguments it removes.
The fourth, the unpinned argument order, is the same blind spot seen from the
other side. All four are cheap to fix and none requires a boundary to move.

---

## Plan Review: export-metadata — Pass 2, delta (2026-09-22)

Plan under review: `plans/impl-export-metadata.md` v4.0.0 — 19 PRs, 620 tasks.
This is a delta pass. It checks the 21 resolutions and the sections the
resolver touched. It does not re-review the rest of the document.

### Prior issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | The documentation deferral makes `check(): 0 warnings` unreachable | RESOLVED |
| 2 | Four PRs remove arguments that committed tests still pass | RESOLVED |
| 3 | `show_eff_n` is never removed from `export_crosstab()` | PARTIAL |
| 4 | No PR pins the final argument order of spec 3.1 | RESOLVED |
| 5 | Fifteen helpers are defined 5 to 11 PRs before their first caller | RESOLVED |
| 6 | Eight helper behaviors are tested by a task but pinned by no criterion | RESOLVED |
| 7 | No numerical tolerance appears anywhere in the plan | PARTIAL |
| 8 | PR 1 carries no `air` criterion and no coverage criterion | RESOLVED |
| 9 | The coverage criterion is stricter than the gate the tester runs | RESOLVED |
| 10 | Two PRs run `snapshot_review()` but list no snapshot file | RESOLVED |
| 11 | PR 18's `na.rm` criterion names a call site outside its write surface | RESOLVED |
| 12 | The About sheet's column widths and merged-cell rule reach no PR | RESOLVED |
| 13 | PR 15's `100%` criterion is wider than the spec | RESOLVED |
| 14 | Spec 3.19's unused factor level on the tabulated variable | RESOLVED |
| 15 | Gate VIII's helper-inventory line reaches no criterion | RESOLVED (option B) |
| 16 | The `variance = "se"` glossary entry reaches no PR | RESOLVED |
| 17 | The Part A / Part B boundary is off by one | PARTIAL |
| 18 | The standard gate criteria cite no source | RESOLVED |
| 19 | "No exported function changes behavior" is not verifiable | RESOLVED |
| 20 | Four criteria point at a source instead of stating the outcome | PARTIAL |
| 21 | Five grep-checkable invariants are stated without the grep | RESOLVED |

### What is missing on the four PARTIAL rows

- **Issue 3.** The code side landed in full: `feature/crosstab-label-cols-and-sizes`
  task 13 removes `show_eff_n` from its ten internal call sites, task 15 removes
  the `@param` entry, and the criterion `grep -rn "show_eff_n"
  R/export-crosstab.R` returns nothing. The second half of option A did not
  land. Option A said to extend `XE-07` to name `show_eff_n` as a third unused
  argument. The plan's criterion names three arguments; the test-spec row
  `XE-07` still reads `pub_type = "external"`, then `show_n = FALSE`, and
  "Both arguments are gone". Issue 23 below carries this.
- **Issue 7.** The plan half landed. `feature/metadata-readers` task 10 and its
  criterion both state `n` exact as integers and `n_eff` at `1e-8`, with the
  reason. The spec half did not: `grep -n "1e-8" plans/spec-export-metadata.md`
  returns nothing, so the spec's contract for `.resolve_eff_n()` still carries
  no tolerance. The builder works from the plan as well as the spec, so the
  number now reaches it. No further change is needed unless the spec is meant
  to stand alone.
- **Issue 17.** The ordering table was fixed and now reads "PRs 6 to 9 precede
  PRs 10 to 18", which matches the Overview's 5 + 4 + 9 + 1 split.
  `feature/crosstab-guards`'s own preamble still reads "This PR closes
  Part A." The same off-by-one now sits one section lower. No execution
  consequence: the chain is strict and the dependency is stated as a number.
- **Issue 20.** Three of the four criteria now name the class or the outcome
  inline. The fourth does not. `feature/crosstab-withheld-notices` reads "The
  three withholding warnings fire with the dual pattern" and names no class.
  Its tasks 11, 15 and 16 name all three, so a reader of the PR section can
  resolve it.

### Job 1, the checks asked for by name

**Issue 1, the five roxygen PRs.** All five carry the full set. Each has the
`@param` task, the `devtools::document()` task, the criterion
"`devtools::document()` run; `NAMESPACE` and `man/` in sync", and both
`man/export_crosstab.Rd` and `NAMESPACE` in its write surface: PR 11 tasks 6,
7, 8; PR 13 tasks 23, 24; PR 14 tasks 15, 16, 17; PR 17 tasks 5, 6; PR 18 tasks
22, 23. The sentence "No code PR above touches `man/`, `NAMESPACE` or
`_pkgdown.yml`" is gone, and the master write-surface table lists PRs 11, 13,
14, 17, 18 and 19 against both files. The two grep criteria were widened to
`grep -rn "pub_type" R/ man/` and `grep -rn "show_n" R/export-crosstab.R
man/export_crosstab.Rd`, so both are now true where they are written.

**The `export_topline()` consequence: measured, and there is none.** The
committed signature is `design, vars, file_name, conf_level, decimals,
variance, show_n, show_eff_n, base_notes`, and `man/export_topline.Rd`'s
`\usage{}` block holds the same nine names in the same order. No PR changes any
of them. PR 7 adds a wave-name join inside the function body, PR 8 changes a
call to `.base_note_for()`, and PR 9 adds two guard calls and swaps a bare
vector for `tidyselect::all_of()`. PR 6 changes the `.build_workbook()` call,
which is an internal helper and carries no `.Rd`. So `man/export_topline.Rd`
raises no codoc mismatch and no undocumented argument at any link of the chain,
and confining it to `docs/export-metadata` is correct. The `@param` prose that
PR 19 edits — `design`, `vars`, `base_notes` in both files — belongs to
arguments whose formals do not move, and `\arguments{}` item text is not what
codoc reads.

**Issue 2, task placement.** Correct in both PRs. `feature/crosstab-min-eff-n`
task 4 removes `pub_type`, task 5 deletes section 10, and no task runs the
suite between them. `feature/crosstab-label-cols-and-sizes` task 12 removes
`show_n` and `show_eff_n`, task 13 strips the ten internal call sites, task 14
deletes section 9. Task 13 is part of the same removal and runs no test, so the
tree is red only across the one removal group. The first suite run after it is
task 22.

**Issue 4, the argument order.** Walked literally, from the committed
14-argument signature, applying the five insertion tasks in chain order:

| Step | Task | Anchor the task names | Result |
|---|---|---|---|
| PR 11 | 4 | replace `pub_type` in place, after `interactions` | `… interactions, min_eff_n, variance, conf_level, show_n, show_eff_n, decimals, show_total, base_notes` |
| PR 13 | 22 | after `show_total`, before `base_notes` | `… show_total, withheld_note, base_notes` |
| PR 14 | 12 | drop `show_n` and `show_eff_n`; add `sample_size_display` then `show_ess` after `conf_level`, before `decimals` | `… conf_level, sample_size_display, show_ess, decimals, show_total, withheld_note, base_notes` |
| PR 17 | 4 | after `variance`, before `conf_level` | `… variance, variance_display, conf_level, …` |
| PR 18 | 4, 21 | `total_label` after `show_total`; `na.rm` then `na_label` after `total_label`, before `withheld_note` | `… show_total, total_label, na.rm, na_label, withheld_note, base_notes` |

The result is `design, vars, banner, file_name, layout, interactions,
min_eff_n, variance, variance_display, conf_level, sample_size_display,
show_ess, decimals, show_total, total_label, na.rm, na_label, withheld_note,
base_notes` — 19 names, identical to spec 3.1 element by element. `show_total`
never moves. The criterion on `feature/crosstab-total-and-missing` and task 45
pin it.

**Issue 5, the two extensions the resolver made.** Both are right.

- The `@param` tasks kept in `docs/export-metadata` cover `layout`, `banner`,
  `vars`, `base_notes` and `design`. None of those formals changes, and spec
  7.2 carries a row for each. `base_notes` moves from position 14 to 19, but
  `\usage{}` is regenerated by the five earlier PRs, and codoc reads `\usage{}`
  and not the `\item{}` order. So deferring them raises no warning. Task 10's
  list of eight already-written `@param` entries matches the eight arguments
  the five PRs add, exactly.
- The `covr` task in PR 1 is task 18, with the matching criterion. It breaks
  nothing. It is close to a no-op: `covr::zero_coverage()` reports lines in
  `R/`, and PR 1's write surface holds no file in `R/`. The 95 percent floor
  still bites, because the fourth design changes which lines the suite reaches.

**Issue 6, the invariants.** Nothing broken by a change. The chain is strict 1
to 19, the scenario table still totals 178 with `XX-05` excluded, spec IX's
forced ordering is stated in the `feature/crosstab-label-cols-and-sizes`
preamble and in the ordering table, and tasks 4 to 9 precede task 25. No branch
was renamed.

---

### New issues

#### Section: PR 1's write surface and the `air` gate

**Issue 22: `air format --check .` is already false on `develop`, and six of the seven files sit outside every PR's write surface**
Severity: BLOCKING
Violates the rule that a criterion must be reachable inside its own PR's write
surface. Raised by the resolution of issue 8.

Pass 1 recommended adding an `air format .` task and an `air format --check .`
criterion to `chore/export-metadata-infra`. Both landed, at task 19 and in the
criteria. The resolver did not measure the tree first.

Measured 2026-09-22 on `develop`, commit `8db9799`, with
`air 0.x` from `~/.local/bin/air`:

```
Would reformat: data-raw\parse-nationscape-codebooks.R
Would reformat: data-raw\prepare-anes-2024.R
Would reformat: data-raw\prepare-gss-2024.R
Would reformat: data-raw\prepare-nationscape-helpers.R
Would reformat: data-raw\prepare-nationscape-phase1.R
Would reformat: tests\testthat\helper-test-data.R
Would reformat: tests\testthat\test-pool-pvals.R
```

Seven files. Only `tests/testthat/helper-test-data.R` is in PR 1's write
surface. The five `data-raw/` files and `tests/testthat/test-pool-pvals.R` are
in no PR's write surface anywhere in the chain. There is no `air.toml`, so
`air` scans `data-raw/` even though `.Rbuildignore` excludes it from the build.

`air format --check .` is a test-spec profile gate — "every R file already
formatted" — and the tester runs every profile gate. The shipper gates on the
tester's verdict. So PR 1 has two exits and both are closed. Running `air
format .` as task 19 writes six files outside the declared surface, and the
shipper's surface check fails. Running `air` on the declared files alone leaves
the gate false, and it stays false for PRs 2 to 18, each of which carries the
same criterion. No GitHub Actions workflow runs `air`, so CI will not catch it;
the pipeline stalls at PR 1's tester run.

Options:
- **A** Add `data-raw/parse-nationscape-codebooks.R`,
  `data-raw/prepare-anes-2024.R`, `data-raw/prepare-gss-2024.R`,
  `data-raw/prepare-nationscape-helpers.R`,
  `data-raw/prepare-nationscape-phase1.R` and
  `tests/testthat/test-pool-pvals.R` to `chore/export-metadata-infra`'s write
  surface, and say in task 19 that the repo-wide `air format .` reformats six
  files the feature does not otherwise touch, in the formatting commit of its
  own — Effort: low, Risk: low, Impact: the gate becomes true at PR 1 and stays
  true for the chain, and the surface declares what the command writes.
- **B** Add an `air.toml` that excludes `data-raw/`, and add
  `tests/testthat/test-pool-pvals.R` alone to the surface — Effort: low, Risk:
  medium, Impact: fewer files move, but it adds a repo-wide formatter config
  that no spec asks for, and it hides five unformatted files rather than fixing
  them.
- **C** Do nothing — PR 1 either exceeds its surface without saying so, or
  eighteen PRs carry a formatting gate that was false before the work started.

**Recommendation: A** — one formatting commit, declared, at the head of the
chain. It is the same shape as the fix Pass 1 chose, applied to what the tree
actually holds.

---

#### Section: the `XE-07` citation

**Issue 23: the plan's `XE-07` criterion names three removed arguments; the test-spec scenario names two**
Severity: REQUIRED
Breaks citation hygiene, which Pass 1 measured as clean. Follows from the
partial resolution of issue 3.

`feature/crosstab-label-cols-and-sizes` carries "A call passing `pub_type`,
`show_n` or `show_eff_n` gets an unused-argument error (test-spec XE-07; spec
5.1)."

Measured 2026-09-22 in `plans/test-spec-export-metadata.md` line 479:

```
| XE-07 | an unused-argument error | `pub_type = "external"`, then
  `show_n = FALSE` | `expect_error()`. Both arguments are gone, and a call
  passing either must not silently succeed |
```

Two arguments, and the word "Both". The tester reads only the test-spec, so it
writes and checks a two-argument block. The criterion cites a scenario that
does not carry its third claim.

The removal itself is not at risk: the same PR carries `grep -rn "show_eff_n"
R/export-crosstab.R` returns nothing. What is at risk is the assertion that a
caller still passing `show_eff_n` gets an error rather than silence, which is
the observable half of spec 5.1's breaking-change row.

Options:
- **A** Add `show_eff_n = TRUE` as a third input to the `XE-07` row of the
  test-spec, and change "Both arguments" to "All three arguments" — Effort:
  low, Risk: low, Impact: the citation resolves, and the tester checks what the
  plan claims. This is the half of Pass 1 option A that did not land.
- **B** Drop `show_eff_n` from the plan's criterion and rely on the grep —
  Effort: low, Risk: medium, Impact: the citation resolves, and no test asserts
  the error for the third argument.
- **C** Do nothing — the plan and the test-spec disagree on one row, and a
  reviewer comparing them finds a claim with no scenario behind it.

**Recommendation: A**.

---

### Suggestions

**Issue 24: the three criteria that carry a spec section and no scenario id are acceptable, and two of the three could still gain a row.** The prompt asked for a judgment on each. The answer per criterion:

- *The topline `100%` row, in `feature/crosstab-sheet-properties`.* **Acceptable.** Measured: no committed test and no snapshot holds the string `100%` for `export_topline()`, so the criterion is the only assertion. But `R/export-topline.R` is not in PR 15's write surface, nor in PR 16's, PR 17's or PR 18's. The builder of PR 15 cannot delete the topline row, and neither can any later PR of the chain. The write surface is the guard, and the criterion plus task 6 add a second one. A `TP` row in the test-spec would let the tester see it too; it is worth adding if the test-spec is opened for issue 23 anyway.
- *The unused factor level on the tabulated variable, in the same PR.* **Acceptable.** It sits inside that PR's own subject, beside `XX-01`, `XX-03` and `XX-04`, which the tester does check. Its twin `XX-06` covers the banner half. A new `XX` row beside `XX-06` would close spec 3.19's second half for the tester; `XX-05` is retired and must not be reused.
- *The About sheet's width and merged-cell rule, in `feature/cover-sheet`.* **Acceptable as is.** It is presentation on a sheet that PR alone writes, and `XA-12` already gives the tester the pattern for reading a resolved cell property. No row needed.

**Recommendation: leave all three; add a `TP` row and an `XX` row if the test-spec is edited for issue 23.**

**Issue 25: `feature/cover-sheet` and `feature/base-notes-adoption` lost the snapshot-review task and gained no replacement guard.** Issue 10 option A landed exactly: neither PR runs `snapshot_review()` now, and neither declares a snapshot file. `feature/metadata-readers` through `feature/format-helpers` each carry "`git diff --exit-code tests/testthat/_snaps/` is clean" as the positive statement of the same fact. These two do not. Both change what a workbook holds, not what a condition prints, so the risk is small. **Recommendation: add the same one-line criterion to both.**

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 1 |
| SUGGESTION | 2 |

**Prior issues:** 17 RESOLVED, 4 PARTIAL, 0 REGRESSED, 0 NOT DONE.

**Verdict: BLOCK.**

**Overall assessment:** Every one of the 21 resolutions landed in substance,
the argument-order arithmetic produces spec 3.1 exactly, and the codoc problem
issue 1 fixed for the crosstab does not exist for `export_topline()`, because
no PR moves any of its nine formals; what blocks the pass is one measurement
the resolver did not take — `air format --check .` is already false on
`develop` over seven files, six of which no PR declares.

---

## Plan Review: export-metadata — Pass 3, delta (2026-11-04)

Plan under review: `plans/impl-export-metadata.md` v4.2.0, with
`plans/test-spec-export-metadata.md` v0.16.0. Both are uncommitted edits on
`develop` at `6b83e5f`. This is a delta pass. It checks issues 22 and 23, the
lines the edit touched, and the four PARTIAL rows. It does not re-review the
rest of the document.

### Prior issues (Pass 1 and Pass 2)

| # | Title | Status |
|---|---|---|
| 1 | The documentation deferral makes `check(): 0 warnings` unreachable | RESOLVED |
| 2 | Four PRs remove arguments that committed tests still pass | RESOLVED |
| 3 | `show_eff_n` is never removed from `export_crosstab()` | RESOLVED — the `XE-07` half landed with issue 23 |
| 4 | No PR pins the final argument order of spec 3.1 | RESOLVED |
| 5 | Fifteen helpers are defined 5 to 11 PRs before their first caller | RESOLVED |
| 6 | Eight helper behaviors are tested by a task but pinned by no criterion | RESOLVED |
| 7 | No numerical tolerance appears anywhere in the plan | PARTIAL — unchanged since Pass 2 |
| 8 | PR 1 carries no `air` criterion and no coverage criterion | RESOLVED |
| 9 | The coverage criterion is stricter than the gate the tester runs | RESOLVED |
| 10 | Two PRs run `snapshot_review()` but list no snapshot file | RESOLVED |
| 11 | PR 18's `na.rm` criterion names a call site outside its write surface | RESOLVED |
| 12 | The About sheet's column widths and merged-cell rule reach no PR | RESOLVED |
| 13 | PR 15's `100%` criterion is wider than the spec | RESOLVED |
| 14 | Spec 3.19's unused factor level on the tabulated variable | RESOLVED |
| 15 | Gate VIII's helper-inventory line reaches no criterion | RESOLVED (option B) |
| 16 | The `variance = "se"` glossary entry reaches no PR | RESOLVED |
| 17 | The Part A / Part B boundary is off by one | PARTIAL — unchanged since Pass 2 |
| 18 | The standard gate criteria cite no source | RESOLVED |
| 19 | "No exported function changes behavior" is not verifiable | RESOLVED |
| 20 | Four criteria point at a source instead of stating the outcome | PARTIAL — unchanged since Pass 2 |
| 21 | Five grep-checkable invariants are stated without the grep | RESOLVED |
| 22 | `air format --check .` is already false on `develop`, six files outside every write surface | RESOLVED |
| 23 | The plan's `XE-07` criterion names three arguments; the test-spec names two | RESOLVED |
| 24 | Three criteria carry a spec section and no scenario id (suggestion) | OPEN — optional; no `TP` or `XX` row added |
| 25 | `feature/cover-sheet` and `feature/base-notes-adoption` lack the snapshot guard (suggestion) | OPEN — optional; criterion not added |

### What is still missing on the three PARTIAL rows

None of the three changed. Each was measured again at `6b83e5f` with the
working-tree edits applied.

- **Issue 7.** `grep -n "1e-8" plans/spec-export-metadata.md` still returns
  nothing. The plan carries the tolerance at
  `plans/impl-export-metadata.md` lines 316 and 363, so the builder has the
  number. As Pass 2 said, no change is needed unless the spec must stand alone.
- **Issue 17.** `plans/impl-export-metadata.md` lines 1114-1115, in
  `feature/crosstab-guards`, still read "This PR closes Part A." Line 2504
  reads "PRs 6 to 9 precede PRs 10 to 18", so PR 10 is Part B. No execution
  consequence.
- **Issue 20.** `plans/impl-export-metadata.md` line 1567, in
  `feature/crosstab-withheld-notices`, still reads "The three withholding
  warnings fire with the dual pattern" and names no class. The scenario ids
  `XV-03` to `XV-05` on line 1569 and the PR's tasks name the classes.

### Job 1, issues 22 and 23 measured

**Issue 22: resolved.** Measured 2026-11-04 at `6b83e5f` with `air 0.11.0`
from `~/.local/bin/air`. `air format --check .` exits 1 and lists the same
seven files as Pass 2:

```
Would reformat: data-raw\parse-nationscape-codebooks.R
Would reformat: data-raw\prepare-anes-2024.R
Would reformat: data-raw\prepare-gss-2024.R
Would reformat: data-raw\prepare-nationscape-helpers.R
Would reformat: data-raw\prepare-nationscape-phase1.R
Would reformat: tests\testthat\helper-test-data.R
Would reformat: tests\testthat\test-pool-pvals.R
```

All seven are now in PR 1's write surface, at
`plans/impl-export-metadata.md` lines 255 and 259-267. Task 19, lines 214-219,
names the seven by count, names `helper-test-data.R`, and names the six others
by group. The file-by-file table at lines 2424-2427 lists all of them against
PR 1 alone. No later PR claims any of the six. There is still no `air.toml`.

The fix was also run, on a scratch copy of `git archive HEAD` outside the
repo:

- `air format .` changes the seven files and no others (615 insertions, 453
  deletions).
- `air format --check .` then exits 0. So one run makes the gate true, as
  task 19 claims.
- `testthat::test_file("tests/testthat/test-pool-pvals.R")` on the formatted
  copy gives 110 passed, 0 failed, 11 skipped. The file holds 13
  `expect_snapshot()` calls. `tests/testthat/_snaps/pool-pvals.md` shows no
  content diff (`git diff --stat` is empty; the file differs in line endings
  only). So "no other change" holds for `test-pool-pvals.R`.
- Limit: the full suite was not run on the formatted copy, so
  `helper-test-data.R` was checked by `air format --check .` only. `data-raw/`
  is in `.Rbuildignore` (`^data-raw$`, line 8), so its reformat cannot reach
  `R CMD check`.

**Issue 23: resolved.** The test-spec and the plan now agree on all three
arguments:

- `plans/test-spec-export-metadata.md` line 480: the `XE-07` row reads
  "`pub_type = "external"`, then `show_n = FALSE`, then `show_eff_n = TRUE`"
  and "All three arguments are gone".
- Test-spec lines 43-45 name all three, and the template row 9 at line 68
  names `show_n` or `show_eff_n`.
- Test-spec line 69 (template row 10) and line 315 (`XS-08`) still cite
  `XE-07` for one argument each. Both are true under the three-argument row.
- `plans/impl-export-metadata.md` task 23 (line 1692), the criterion at lines
  1765-1766, the owned list at line 1787 and the coverage table at line 2469
  all cite `XE-07` for `feature/crosstab-label-cols-and-sizes`, and the two
  prose lines name all three arguments.
- `plans/spec-export-metadata.md` does not cite `XE-07`.

**Version citations.** The test-spec header (line 4) reads 0.16.0, dated
2026-11-04. The plan cites v0.16.0 at line 8 and line 2451, and nowhere cites
v0.15.0. The spec does not cite a test-spec version. The decisions entry at
`plans/decisions-export-metadata.md` lines 1063-1067 matches the diff.

### Job 2, what the edit could have broken

- **Scenario count.** No row was added or removed. The test-spec still holds
  178 ids, and the plan's coverage table and family check at lines 2454-2480
  are unchanged and still total 178.
- **"Six PRs own no scenario"** (line 2482). Still true. Reformatting adds no
  behavior a scenario describes. The sentence "PR 1 changes a fixture and a
  manifest" does not list the formatting commit, but it does not claim to be
  exhaustive.
- **PR 1's other criteria.** The coverage criterion at lines 241-242 reads
  `covr::zero_coverage()`, which reports files in `R/`. PR 1 touches no file in
  `R/`, so the six new files do not change it.
- **Line-number citations.** No file in `plans/` cites a line number in any of
  the seven reformatted files, so the reformat moves no citation.

---

### New issues

#### Section: Overview

**Issue 26: the Overview cites spec v0.20.0; the header cites v0.21.0**
Severity: SUGGESTION
Breaks citation hygiene. Not introduced by this edit: commit `6b83e5f` (#15)
raised the header to v0.21.0 and left the Overview line.

`plans/impl-export-metadata.md` line 7 reads "**Source spec:**
`plans/spec-export-metadata.md` v0.21.0". Line 17 reads "This plan turns spec
v0.20.0 into nineteen pull requests." The spec header
(`plans/spec-export-metadata.md` line 4) reads 0.21.0. Line 17 is now the only
stale version string in the plan.

Options:
- **A** Change line 17 to "spec v0.21.0" — Effort: low, Risk: low, Impact: the
  plan cites one spec version.
- **B** Drop the version from line 17, and leave the header as the one
  citation — Effort: low, Risk: low, Impact: the next spec bump cannot make
  line 17 stale.
- **C** Do nothing — a reader sees two spec versions and has to check which one
  the plan follows.

**Recommendation: B** — one version string in the header is one place to keep
current.

---

#### Section: PR 1 — task 19

**Issue 27: task 19 counts seven reformatted files, then says the formatting commit holds "those six files"**
Severity: SUGGESTION
Clarity of a task the builder follows literally.

`plans/impl-export-metadata.md` lines 214-218 read: "this reformats seven
files: `tests/testthat/helper-test-data.R`, which this PR already changes, and
six files that this feature does not otherwise touch … The formatting commit
holds those six files and nothing else of substance."

`air format .` also rewrites `helper-test-data.R` (74 lines changed on the
scratch copy). So the formatting commit holds seven files, unless the builder
formats `helper-test-data.R` in an earlier commit. A builder who reads "those
six files" literally may try to keep `helper-test-data.R` out of the commit,
which `air format .` does not allow. "Nothing else of substance" probably
means to allow it, but the task does not say so.

Options:
- **A** Change the sentence to "The formatting commit holds the seven files and
  no change other than formatting." — Effort: low, Risk: low, Impact: the task
  says what the command writes.
- **B** Do nothing — the result is the same either way, and a careful builder
  reads "of substance" as the allowance.

**Recommendation: A** — one sentence, and the count then agrees with itself.

---

#### Section: PR 1 — write surface and criteria

No new issues found.

#### Section: PR 14 — `feature/crosstab-label-cols-and-sizes` (`XE-07`)

No new issues found.

#### Section: Write surface, file by file

No new issues found.

#### Section: Scenario coverage

No new issues found.

#### Section: test-spec v0.16.0

No new issues found.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 2 |

**Total issues:** 2 (issues 26 and 27).

**Prior issues:** 20 RESOLVED, 3 PARTIAL (7, 17, 20, none with an execution
consequence), 2 OPEN suggestions (24, 25), 0 REGRESSED.

**Verdict: PASS.**

**Overall assessment:** Both fixes measure true — the seven files `air` lists
at `6b83e5f` are all in PR 1's surface, one `air format .` run makes the gate
pass with the `test-pool-pvals.R` tests and snapshots unchanged, and `XE-07`
now carries all three removed arguments in both documents — and what remains is
two wording suggestions and three PARTIAL rows that change no PR.

---

## Plan Review: export-metadata — Pass 4, delta (2026-11-05)

Plan under review: `plans/impl-export-metadata.md` v4.4.0, with
`plans/spec-export-metadata.md` v0.22.0 and
`plans/test-spec-export-metadata.md` v0.17.0. All three are uncommitted edits
on `docs/export-metadata-plan-pass-3` at `2728b60`. This is a delta pass. It
checks the three variance rules of spec 3.16, the rows `XB-05` to `XB-10`, the
PR 17 changes and the counts. It does not re-review the rest of the documents.

Measurements are at `2728b60`, with R 4.6.1 and openxlsx2 1.28, from a scratch
script outside the repo.

### Prior issues (Passes 1 to 3)

| # | Title | Status |
|---|---|---|
| 1 | The documentation deferral makes `check(): 0 warnings` unreachable | RESOLVED |
| 2 | Four PRs remove arguments that committed tests still pass | RESOLVED |
| 3 | `show_eff_n` is never removed from `export_crosstab()` | RESOLVED |
| 4 | No PR pins the final argument order of spec 3.1 | RESOLVED |
| 5 | Fifteen helpers are defined 5 to 11 PRs before their first caller | RESOLVED |
| 6 | Eight helper behaviors are tested by a task but pinned by no criterion | RESOLVED |
| 7 | No numerical tolerance appears anywhere in the plan | PARTIAL — not changed by this delta |
| 8 | PR 1 carries no `air` criterion and no coverage criterion | RESOLVED |
| 9 | The coverage criterion is stricter than the gate the tester runs | RESOLVED |
| 10 | Two PRs run `snapshot_review()` but list no snapshot file | RESOLVED |
| 11 | PR 18's `na.rm` criterion names a call site outside its write surface | RESOLVED |
| 12 | The About sheet's column widths and merged-cell rule reach no PR | RESOLVED |
| 13 | PR 15's `100%` criterion is wider than the spec | RESOLVED |
| 14 | Spec 3.19's unused factor level on the tabulated variable | RESOLVED |
| 15 | Gate VIII's helper-inventory line reaches no criterion | RESOLVED (option B) |
| 16 | The `variance = "se"` glossary entry reaches no PR | RESOLVED |
| 17 | The Part A / Part B boundary is off by one | PARTIAL — not changed by this delta |
| 18 | The standard gate criteria cite no source | RESOLVED |
| 19 | "No exported function changes behavior" is not verifiable | RESOLVED |
| 20 | Four criteria point at a source instead of stating the outcome | PARTIAL — not changed by this delta |
| 21 | Five grep-checkable invariants are stated without the grep | RESOLVED |
| 22 | `air format --check .` is already false on `develop` | RESOLVED |
| 23 | The plan's `XE-07` criterion names three arguments; the test-spec names two | RESOLVED |
| 24 | Three criteria carry a spec section and no scenario id (suggestion) | OPEN — not changed by this delta |
| 25 | `feature/cover-sheet` and `feature/base-notes-adoption` lack the snapshot guard (suggestion) | OPEN — not changed by this delta |
| 26 | The Overview cites spec v0.20.0; the header cites v0.21.0 (suggestion) | RESOLVED — applied |
| 27 | Task 19 counts seven files, then says "those six files" (suggestion) | RESOLVED — applied |

### What the delta did to the open rows

- **Issue 7.** `grep -n "1e-8" plans/spec-export-metadata.md` still returns
  nothing. The plan carries the tolerance at lines 321 and 368. The delta adds
  no tolerance.
- **Issue 17.** Plan lines 1118-1120 still read "This PR closes Part A." Line
  2552 still reads "PRs 6 to 9 precede PRs 10 to 18". The line numbers moved,
  and the text did not change.
- **Issue 20.** Plan line 1572 still reads "The three withholding warnings
  fire with the dual pattern" and names no class.
- **Issue 24.** The four new PR 17 criteria, plan lines 2140-2151, each cite a
  scenario id. The delta adds no criterion of the kind issue 24 names.
- **Issue 25.** No snapshot guard was added to either PR.
- **Issues 26 and 27.** Still applied. Plan line 20 cites no spec version.
  Line 222 says the formatting commit holds "the seven files".

### The delta, check by check

**1. The width formula.** The formula holds for `decimals` 0, 1 and 2 inside
the range spec line 1764 states. Measured with `nchar()`:

| String | Characters |
|---|---|
| `(-10.5% – 100.4%)` | 17 |
| `(-10.53% – 100.47%)` | 19 |
| `(-10% – 100%)` | 13 |
| `(-100% – 1000%)` | 15 |

- The floor and ceiling strings of spec 3.3, line 795-796, are 3 and 4
  characters at `decimals = 0`, 5 and 6 at 1, and 6 and 7 at 2. None is longer
  than the `5 + decimals` bound of spec line 1756. So a floor or ceiling string
  inside an interval cannot push it past the width.
- At `decimals = 0`, `round(-99.6)` is `-100` and `round(999.6)` is `1000`.
  Both values are inside the stated range, and both print 5 characters. The
  worst string is then `(-100% – 1000%)`, 15 characters. It fits with 0
  characters spare, not 2. Issue 31.
- No string the formatter writes under `"ci"` exceeds the width inside the
  stated range. Outside it (a lower bound at or below `-100%`, an upper bound
  at or above `1000%`) a string can. Spec line 1764 states that limit.
- Limit: this counts characters, not Excel width units. No workbook was opened
  in Excel.

**2. The six test-spec rows.** Lines 410-415 have the 8 cells of their
neighbours. The 184 ids hold no duplicate. Each input is reachable when PR 17
runs: `min_eff_n` lands in PR 11, `variance_display` at PR 17 task 4, and
`XH-16` already runs `variance = "ci"` on all four designs. Each oracle states
an exact value. The readback is feasible on openxlsx2 1.28, measured after
`wb_save()` and `wb_load()`:

- openxlsx2 exports no width getter. The width is in
  `wb$worksheets[[i]]$cols_attr`, as `width="17.711"` for a width set to 17.
- A row height is in `wb$worksheets[[i]]$sheet_data$row_attr`: `ht` is `"30"`
  and `customHeight` is `"1"` for a set row, and `ht` is `""` for a row with no
  height of its own. So "carries no height of its own" is testable.
- `wb_get_cell_style()` returns the style id, and
  `wb$styles_mgr$styles$cellXfs` holds `<alignment wrapText="1"/>` for it.

The width oracle has one defect, which `XB-01` shares. Issue 28.

**3. PR placement.** PR 17 is the right owner, though one reason it gives is
wrong (issue 30). At `2728b60`, `R/export-crosstab.R` holds no `se`, `ci_low`
or `ci_high`. `variance` reaches only the `get_freqs()` call at line 187. So
before PR 17 a `"ci"` call writes no interval, and the width of 12 between PR 15
and PR 17 hides nothing. No PR 15 or PR 16 criterion is false at its own merge.
`XB-03` (test-spec line 408) runs at `variance = NULL`, so its "an estimate
cell … resolves to a non-wrapping one" stays true after PR 17.

TDD granularity holds. Each new row gets a write, run, implement and run step.
`XB-07` and `XB-10` are guards that pass on first run, and tasks 35 and 42 say
so. No cross-reference is stale. The only "task N" citations outside a PR,
plan lines 2557 and 2562, name PR 10 task 34 and PR 18 task 45. Neither PR was
renumbered.

**4. Write surface.** The author's flag is a real gap. Issue 29.

**5. Counts and citations.** All true:

- The test-spec holds 184 ids: XB 10, XC 11, XS 10, XW 13, XH 24, XD 1, XR 2,
  XA 14, XM 17, XE 15, XV 13, XX 12, XN 10, TP 14, TC 8, TE 4, TW 2, TN 4.
- The coverage table, plan lines 2503-2523, sums to 184. A scripted diff of
  its ids against the test-spec ids is empty.
- PR 17 owns 15 at plan line 2168 and at line 2520.
- Spec line 4 reads 0.22.0. Test-spec line 4 reads 0.17.0. Plan line 4 reads
  4.4.0, lines 7-8 cite 0.22.0 and 0.17.0, and line 2499 cites v0.17.0.
- `grep` for `0.21.0`, `0.16.0`, `4.3.0` and `178` finds nothing in the three
  documents. The `184.98` hits at spec lines 155-158 and 1142 and test-spec
  line 723 are effective-N values.

**6. Other notes, not issues.**

- Spec line 1471 is 89 characters, the one prose line in the delta past 80.
- `plans/decisions-export-metadata.md` line 1122 says 3.16 "changes the Column
  widths and Wrapping rows, adds an Estimate row height row". The diff also
  adds a sentence to the Heading row height row (spec line 1749). The decisions
  file is history, so this review does not ask for an edit.

---

### New issues

#### Section: test-spec v0.17.0 — sheet properties

**Issue 28: "rounded to the nearest whole number" turns a correct width of 17 into 18**
Severity: REQUIRED
A stated oracle fails on correct code. The defect predates the delta in
`XB-01`, and the delta copies it into three rows.

`plans/test-spec-export-metadata.md` lines 410-412 (`XB-05`, `XB-06`,
`XB-07`) give the tolerance "rounded to the nearest whole number", as `XB-01`
does at line 406. The plan repeats it: task 8 (line 1832, "rounds to 44") and
task 30 (line 2094, "rounds to `15 + 2 * decimals`").

Measured on openxlsx2 1.28: `wb_set_col_widths()` with widths 44, 15 and 17
writes `width="44.711"`, `"15.711"` and `"17.711"`, and `wb_load()` reads the
same back. `round()` gives 45, 16 and 18. So a tester who follows the rows
reads 18 for a correct 17 and blocks the PR. `XB-01` fails the same way in PR
15 (45 for 44, 13 for 12). `XB-02` compares two workbooks, so it is not
affected.

Options:
- **A** Change the tolerance on `XB-01`, `XB-05`, `XB-06` and `XB-07` to "the
  integer part, `floor()`, of the stored width", and say that openxlsx2 1.28
  stores the set width plus 0.711. Change plan tasks 8 and 30 from "rounds to"
  to "has the integer part". — Effort: low, Risk: low, Impact: the oracle
  passes correct code and still tells 15, 17 and 19 apart.
- **B** State the stored value: "the stored width is the set width plus
  `0.711`, compared at `1e-6`". — Effort: low, Risk: medium, Impact: exact, but
  a future openxlsx2 that changes the padding breaks every row.
- **C** Do nothing — the tester blocks PR 15 on `XB-01` and PR 17 on `XB-05`
  to `XB-07`, or improvises a rule the test-spec does not state.

**Recommendation: A** — `floor()` holds whether or not openxlsx2 keeps its
0.711 padding, and the rows stay 2 characters apart.

---

#### Section: PR 15 and PR 17 — write surface

**Issue 29: no PR names the file that holds the width code, and PR 15's surface points the wrong way**
Severity: REQUIRED
Lens 5, file completeness. A builder must guess a file, and one guess stops
PR 17 at the shipper's write-surface check.

- PR 17 task 32 (plan lines 2097-2099) edits the width "at the site where PR
  15 sets the fixed widths". PR 17's surface (lines 2171-2178) lists
  `R/export-crosstab.R` and not `R/export-utils.R`.
- PR 15 task 10 (lines 1835-1836), task 16 (line 1845), task 17 (line 1846)
  and task 21 (line 1852) name no file or function.
- PR 15's surface lists `R/export-utils.R` (line 1928), and the file table
  lists PR 15 against it (line 2476). No PR 15 task names a change in that
  file. Tasks 23 to 36 only write tests and confirm they pass. So the only PR 15
  code that could go in `R/export-utils.R` is the sheet-property code.
- If PR 15 puts the widths or the freeze pane there, for example inside
  `.write_sample_size_rows()`, which knows the last sample-size row, then PR
  17 task 32 is outside PR 17's surface.

The likely site is `R/export-crosstab.R`. The question sheets are added there
(lines 209, 231, 253, 274), and the three routes that write the estimate cells
are there. Spec 2.1 lists every new helper and names no width helper, so the
code goes into an existing function. But the plan does not say so.

Options:
- **A** Name the site in PR 15 task 10, task 16, task 17 and task 21, for
  example "in `R/export-crosstab.R`, after each sheet is added in
  `export_crosstab()`". Name the same file in PR 17 task 32. Then drop
  `R/export-utils.R` from PR 15's surface and from PR 15 on line 2476, or
  state the change that needs it. — Effort: low, Risk: low, Impact: both
  surfaces agree with the tasks.
- **B** Add `R/export-utils.R` to PR 17's surface and the file table. —
  Effort: low, Risk: low, Impact: the gate cannot stop PR 17, but the site
  stays unnamed and PR 17's surface is wider than its tasks.
- **C** Do nothing — the result depends on where the PR 15 builder puts the
  code.

**Recommendation: A** — one named site removes the guess in both PRs and the
unexplained `R/export-utils.R` entry in PR 15.

---

#### Section: PR 17 — the boundary note

**Issue 30: the PR 17 note says the `"ci"` width depends on `variance_display`; it does not**
Severity: SUGGESTION
A stated reason does not match the spec.

Plan lines 2048-2050 read: "All three depend on `variance_display`, which this
PR adds, so none can land in PR 15." Spec line 1747 says the width rule
"holds under both `variance_display` values", and `XB-05` (test-spec line 410)
tests that. The width depends on `variance` and `decimals`, and both exist at
`2728b60` (`R/export-crosstab.R` line 79). The placement is still right, for a
different reason: PR 17 is the first PR that writes an interval.

PR 15's criterion at plan line 1889 reads "The column widths are fixed at 44
and 12". After PR 17 that is true only away from `"ci"`. PR 16 carries a lag
note for a similar case (line 1946).

Options:
- **A** Change lines 2048-2050 to say that the wrap and the row height depend
  on `variance_display`, and that the width lands here because this PR first
  writes the interval it makes room for. Add "at `variance = NULL`" to the PR
  15 criterion at line 1889. — Effort: low, Risk: low, Impact: the reason is
  true and the PR 15 criterion matches spec 3.16.
- **B** Do nothing — the placement is right, and a reader who checks the
  reason against spec 3.16 finds it false.

**Recommendation: A** — two short edits, and both texts then match spec 3.16.

---

#### Section: spec v0.22.0 — section 3.16

**Issue 31: the derivation says 2 characters are spare at `decimals = 0`, and the `"se"` claim is checked at one `decimals` value**
Severity: SUGGESTION
A worked bound in the spec is not exact. No string exceeds the width.

- Spec lines 1760-1762 say a bound at `decimals = 0` "prints at most 4
  characters", and that the formula "leaves 2 characters spare". Inside the
  range line 1764 states, `round(-99.6)` prints `-100%` and `round(999.6)`
  prints `1000%`, 5 characters each. The worst string,
  `(-100% – 1000%)`, is 15 characters, so 0 are spare. The formula still
  holds.
- Spec lines 1766-1768 justify the width of 12 under `"se"` at
  `decimals = 1` only. `(100.00%)` at `decimals = 2` is 9 characters, so the
  rule holds there too, but the text does not say so. It holds up to
  `decimals = 5` (`(100.00000%)`, 12 characters).

Options:
- **A** Change "at most 4 characters" to "at most 5, as in `-100%`", and
  "2 characters spare" to "the worst string, `(-100% – 1000%)`, fills it
  exactly". Add "and `(100.00%)`, 9 characters, at `decimals = 2`" to the
  `"se"` paragraph. — Effort: low, Risk: low, Impact: the derivation is exact.
- **B** Do nothing — the width rule is correct, and only its explanation is
  off at an edge no real interval reaches.

**Recommendation: A** — the derivation exists to be checked, so it should
check.

---

#### Section: PR 17 — tasks 38 and 39

**Issue 32: the wrap and the row height are written three times, one copy per route**
Severity: SUGGESTION
`CLAUDE.md` engineering principle 1 (DRY) asks for repetition to be raised in
review.

Task 38 (plan lines 2108-2110) sets the wrap "in all three render routes".
Task 39 (lines 2111-2112) sets the row height "under the same condition" and
names no site. So the condition `!is.null(variance) && variance_display ==
"cell"` and two openxlsx2 calls go into three functions. The same PR splits
the `.fmt_variance()` calls into one task per route (tasks 7 to 9). Spec 2.1
closes the helper list, so a new helper is not an option without a spec edit.

Options:
- **A** Keep the three copies, and split tasks 38 and 39 into one task per
  route, as tasks 7 to 9 do. — Effort: low, Risk: low, Impact: each edit is one
  2-5 minute step, and the repetition is a stated choice.
- **B** Set both properties once per block, where the estimate row range is
  known after the route returns, and say where in task 38. — Effort: medium,
  Risk: low, Impact: one copy of the condition, but the route must return the
  range.
- **C** Do nothing — three copies of the condition, and one task that covers
  three edits.

**Recommendation: A** — it matches tasks 7 to 9 and needs no spec change.

---

#### Section: PR 17 — acceptance criteria and owned scenarios

No new issues found.

#### Section: Scenario coverage

No new issues found.

#### Section: Write surface, file by file

No new issue beyond issue 29.

---

## Summary (Pass 4)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 3 |

**Total issues:** 5 (issues 28 to 32).

**Prior issues:** 22 RESOLVED, 3 PARTIAL (7, 17, 20), 2 OPEN suggestions (24,
25), 0 REGRESSED. The delta changed none of the open rows.

**Verdict: BLOCK.**

**Overall assessment:** The width formula, the counts and the PR 17 placement
are correct, but the width oracle fails correct code on openxlsx2 1.28
(`round(17.711)` is 18) and no PR names the file that holds the width code, so
both REQUIRED issues need a short edit before the plan returns to
`PLAN_READY`.
