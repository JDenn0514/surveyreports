# Tickets: export-metadata, remaining work

These tickets replace PRs 16 to 20 of `plans/impl-export-metadata.md`. They
also carry three user decisions of 2026-11-19 that change merged code (gaps
14, 15 and 19). The old plan copied the spec into step-by-step tasks, so
every spec decision needed an edit in two places. A ticket instead names the
spec sections and the test-spec scenario ids it must satisfy, and keeps only
the notes that neither document states. The source of truth is
`plans/spec-export-metadata.md` v0.29.0 and
`plans/test-spec-export-metadata.md` v0.24.0. Where a ticket and the spec
disagree, the spec wins.

| # | Title | Blocked by | Scenario ids |
|---|---|---|---|
| 01 | [About sheet glossary text](01-about-glossary-text.md) | None | 4 own (XA-05b, XW-10, XW-11, TP-06a); 5 re-check (XW-07, XW-08, XA-03, XA-04, XA-06) |
| 02 | [Crossed columns on a value-labelled banner follow code order](02-labelled-banner-crossed-order.md) | None | 1 (XH-05a) |
| 03 | [A crosstab percentage cell becomes a string](03-crosstab-percent-cells.md) | branch `fix/sata-chosen-code-1` | 12 (XC-01 to XC-08, with XC-05a, XC-05b, XC-06a, XC-07a) |
| 04 | [Variance strings, the legend row and the room a variance needs](04-crosstab-variance-strings.md) | 03 | 16 (XH-15 to XH-20, XN-09, XN-10, XB-05 to XB-10, XB-14) |
| 05 | [The Total column, missing data and the block row order](05-crosstab-total-and-missing.md) | 04, 01 | 18 (XH-08, XH-08a, XH-08b, XH-09, XH-09a, XH-11 to XH-14, XX-13, XX-17, XA-05, XA-05a, XR-01, XR-02, XN-06 to XN-08) |
| 06 | [House style B1 on the crosstab sheets and the About sheet](06-house-style-crosstab-and-about.md) | 05 | 25 (XY-01 to XY-24, TY-10); rewrites XB-03, XB-10 to XB-13 |
| 07 | [House style B1 on the topline sheet](07-house-style-topline.md) | 06 | 10 (TY-01 to TY-09, TY-11) |
| 08 | [Documentation prose for both export functions](08-documentation-prose.md) | 01 to 07 | 0 |

## How to pick the next ticket

Work the frontier. Any ticket whose blockers are all merged to `develop` can
start. Today 01 and 02 can start at once, and 03 can start when
`fix/sata-chosen-code-1` merges. Tickets on the frontier at the same time
can run in parallel, each on its own branch cut from `develop`.

## Rules every ticket follows

- One ticket is one branch and one PR into `develop`
  (`.claude/rules/github-strategy.md`).
- A scenario that says "all four" runs on every design from
  `make_all_designs(seed = 42)`, labelled with the design name.
- The gate runner `bash .claude/scripts/run-gates.sh <log-dir>` passes
  before the PR opens.
- Each PR adds `changelog/{branch-name}.md`, with the slash of the branch
  name written as a hyphen.
- A moved `export_topline()` snapshot is a defect, except where a ticket
  says otherwise. No ticket here says otherwise.
