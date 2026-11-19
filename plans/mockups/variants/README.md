# Style variants of the mockup workbooks

Written by `plans/mockups/build-mockups.R`. Do not edit by hand:
change the style lists in section 6 of the script and run it again.

Each variant is three files: `X-crosstab.xlsx` (per-question layout,
intervals in the cell, withheld lines once on the About sheet),
`X-crosstab-stacked.xlsx` (one Crosstab sheet, no intervals, withheld
lines under each block) and `X-topline.xlsx`. The content of the files
is the same in every variant. Only the styling changes.

B1, B2 and B3 revise B with four shared changes: the navy band moves to the title row; the zebra stripes stay; the interval sits on its own line in the estimate cell; the panes freeze the heading rows and the label columns. They differ only in how the column groups are set apart.

## What every variant shares

- One font family across the workbook. Colours are hex RGB.
- Every data cell (percentages, intervals, sample sizes) is right-
  aligned or centered, as the variant's table says.
- Title, base-note, legend and withheld rows are merged across the
  block, wrap on, with the row height fitted to the text.
- Each spanner is merged over its group's columns, centered, wrap on,
  and its row is at least two lines high.
- The heading row and the label columns wrap.
- The interval line is a second rich-text run, smaller and lighter
  than the estimate.
- The freeze pane is below the last sample-size row of the first
  block. B1 to B3 also freeze the label columns. The topline has no
  freeze pane.
- The About sheet has no merged cells (spec 3.14). Each section is a
  small two-column table in the variant's heading and body styles.
- Gridlines are hidden on every sheet.

Row heights: Excel does not fit merged cells, so the script sets every
table row. A row is the largest of its cells, where a cell needs
`lines x 1.35 x font size + pad` points. `lines` comes from a word wrap
at `(column width - 1) x 11 / font size` characters per line, 10 per
cent fewer for bold text. Spanner and heading rows take at least two
lines. `pad` is set per variant.

A border is written `style #colour`, with an Excel border style
(hair, thin, medium). A dash means the element takes the value of the
cell it sits in.

## A. Clean rules

No fills. Black text, bold headings, and horizontal rules only: a medium rule above the table, under the heading row and under the last row, hairlines between rows. Rows carry 6 pt of extra height.

**Good for:** Reports that are printed or pasted into a document, where the table should read like a journal table.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells right; data headings right.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 9 pt, #595959.
- Gap 6 (battery item label): no; written on the item's first row only.
- Gap 7 (sample-size numbers): `#,##0` and `#,##0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Aptos | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Aptos | 12 | bold | #000000 | none | none | left, center | on | across the block | fit to text |
| Base-note and legend rows | Aptos | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Aptos | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Aptos | 11 | bold | #000000 | none | bottom thin #000000 | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | - | none | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Aptos | 11 | bold | #000000 | none | bottom medium #000000 | left, bottom | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Aptos | 11 | bold | #000000 | none | bottom medium #000000 | right, bottom | on | no | same row |
| Sample-size label cells | Aptos | 10 | italic | #404040 | none | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `#,##0`, effective `#,##0.0`) | Aptos | 10 | italic | #404040 | none | none | right, center | off | no | same row |
| Label cells (response or item) | Aptos | 11 | regular | #000000 | none | none | left, center | on | no | fit to text |
| Battery item label (column A) | Aptos | 11 | bold | #000000 | none | none | left, top | on | no; written on the item's first row only | fit to text |
| Estimate cell (percentage string) | Aptos | 11 | regular | #000000 | none | none | right, center | on | no | 1 line; with an interval 1.35 x (11 + 9) + 6 pt |
| Interval line (second rich-text run of the estimate cell) | Aptos | 9 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Topline battery item heading | Aptos | 11 | bold | #000000 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Aptos | 11 | bold | #000000 | none | top thin #000000 | label left; numbers as estimate cells | on | no | fit to text |
| Rule: table top | - | - | - | - | - | medium #000000 on top of the spanner row (topline: heading row) | - | - | - | - |
| Rule: between body rows | - | - | - | - | - | hair #A6A6A6 bottom of every response row and sample-size row except the last | - | - | - | - |
| Rule: between battery items | - | - | - | - | - | thin #7F7F7F bottom of the last row of each item except the last item | - | - | - | - |
| Rule: under the sample-size rows | - | - | - | - | - | thin #7F7F7F bottom of the last sample-size row | - | - | - | - |
| Rule: table bottom | - | - | - | - | - | medium #000000 bottom of the last table row | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block; no columns; topline none |
| About: Key / Value row and section headings | Aptos | 11 | bold | #000000 | none | bottom medium #000000 | left, bottom | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Aptos | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Aptos | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 6 pt |

## B. Banded header

A solid navy band with white bold text across the spanner and heading rows, light blue zebra stripes on the response rows, and a thin grey box around each block from its title to its last row.

**Good for:** Workbooks read on screen, where a reader scrolls many blocks and needs each header and each row to stand out.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells right; data headings center.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 9 pt, #595959.
- Gap 6 (battery item label): no; written on the item's first row only.
- Gap 7 (sample-size numbers): `#,##0` and `#,##0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Calibri | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Calibri | 12 | bold | #1F3864 | none | none | left, center | on | across the block | fit to text |
| Base-note and legend rows | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Calibri | 11 | bold | #FFFFFF | #1F3864 | none | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | #FFFFFF | #1F3864 | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Calibri | 11 | bold | #FFFFFF | #1F3864 | none | left, center | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Calibri | 11 | bold | #FFFFFF | #1F3864 | none | center, center | on | no | same row |
| Sample-size label cells | Calibri | 10 | italic | #404040 | none | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `#,##0`, effective `#,##0.0`) | Calibri | 10 | italic | #404040 | none | none | right, center | off | no | same row |
| Label cells (response or item) | Calibri | 11 | regular | #000000 | none | none | left, center | on | no | fit to text |
| Battery item label (column A) | Calibri | 11 | bold | #000000 | none | none | left, top | on | no; written on the item's first row only | fit to text |
| Estimate cell (percentage string) | Calibri | 11 | regular | #000000 | none | none | right, center | on | no | 1 line; with an interval 1.35 x (11 + 9) + 4 pt |
| Interval line (second rich-text run of the estimate cell) | Calibri | 9 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Zebra stripe: all cells of every second response row (in a battery, of every second item); topline and About body rows by row | - | - | - | - | #E8EEF7 | - | - | - | - | - |
| Topline battery item heading | Calibri | 11 | bold | #1F3864 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Calibri | 11 | bold | #000000 | none | top thin #1F3864 | label left; numbers as estimate cells | on | no | fit to text |
| Rule: under the sample-size rows | - | - | - | - | - | thin #1F3864 bottom of the last sample-size row | - | - | - | - |
| Rule: band separators | - | - | - | - | - | thin #FFFFFF left side of the first column of each group (Total included) in the spanner and heading rows, and bottom of each labelled spanner; About: left side of B in the heading row | - | - | - | - |
| Rule: block box | - | - | - | - | - | thin #7F7F7F outline from the title row to the last table row | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block; no columns; topline none |
| About: Key / Value row and section headings | Calibri | 11 | bold | #FFFFFF | #1F3864 | none | left, center | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 4 pt |

## C. Full grid

A thin grey border on every cell of the table, a dark outline around the table and around each spanner, grey fills on the spanner, heading and label column, and a light blue Total column. Battery item labels are merged down their rows.

**Good for:** Analysts who copy cells out of the workbook or check numbers cell by cell, where the grid keeps the eye on the right row and column.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells center; data headings center.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 10 pt, #595959.
- Gap 6 (battery item label): column A merged down the item's rows.
- Gap 7 (sample-size numbers): `0` and `0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Calibri | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Calibri | 11 | bold | #000000 | none | none | left, center | on | across the block | fit to text |
| Base-note and legend rows | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Calibri | 11 | bold | #000000 | #D9D9D9 | box thin #404040 | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | - | #D9D9D9 | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Calibri | 11 | bold | #000000 | #D9D9D9 | bottom thin #404040 | left, center | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Calibri | 11 | bold | #000000 | #D9D9D9 | bottom thin #404040 | center, center | on | no | same row |
| Heading cell, Total column | Calibri | 11 | bold | #000000 | #BDD7EE | bottom thin #404040 | center, center | on | no | same row |
| Sample-size label cells | Calibri | 10 | italic | #404040 | #F2F2F2 | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `0`, effective `0.0`) | Calibri | 10 | italic | #404040 | none | none | center, center | off | no | same row |
| Label cells (response or item) | Calibri | 11 | regular | #000000 | #F2F2F2 | none | left, center | on | no | fit to text |
| Battery item label (column A) | Calibri | 11 | bold | #000000 | #F2F2F2 | none | left, center | on | column A merged down the item's rows | fit to text |
| Estimate cell (percentage string) | Calibri | 11 | regular | #000000 | none | none | center, center | on | no | 1 line; with an interval 1.35 x (11 + 10) + 2 pt |
| Interval line (second rich-text run of the estimate cell) | Calibri | 10 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Total column, body and sample-size cells | - | - | - | - | #DDEBF7 | - | - | - | - | - |
| Topline battery item heading | Calibri | 11 | bold | #000000 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Calibri | 11 | bold | #000000 | #F2F2F2 | none | label left; numbers as estimate cells | on | no | fit to text |
| Rule: grid | - | - | - | - | - | thin #A6A6A6 all four sides of every cell from the spanner row to the last table row | - | - | - | - |
| Rule: block box | - | - | - | - | - | thin #404040 outline from the spanner row to the last table row | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block; no columns; topline none |
| About: Key / Value row and section headings | Calibri | 11 | bold | #000000 | #D9D9D9 | bottom thin #404040 | left, center | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Calibri | 11 | regular | #000000 | #F2F2F2 | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 2 pt |

## D. Report accent

A dark blue title bar with white text across each block, spanners and headings shaded in alternating light blue and light orange per banner group, a blue vertical rule at the start of each column group, and the sample-size rows in a muted grey fill.

**Good for:** Client-facing deliverables, where the banner groups must read apart at a glance and the workbook carries a house look.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells center; data headings center.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 9 pt, #595959.
- Gap 6 (battery item label): no; written on the item's first row only.
- Gap 7 (sample-size numbers): `#,##0` and `#,##0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Aptos | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Aptos | 12 | bold | #FFFFFF | #1F4E79 | none | left, center, indent 1 | on | across the block | fit to text |
| Base-note and legend rows | Aptos | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Aptos | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Aptos | 11 | bold | #000000 | alternates by labelled group: #DEEBF7, #FCE4D6 | none | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | - | none | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Aptos | 11 | bold | #000000 | #F2F2F2 | bottom medium #1F4E79 | left, center | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Aptos | 11 | bold | #000000 | the group's spanner tint; #F2F2F2 over Total, on the topline and on the About sheet | bottom medium #1F4E79 | center, center | on | no | same row |
| Sample-size label cells | Aptos | 10 | italic | #404040 | #EDEDED | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `#,##0`, effective `#,##0.0`) | Aptos | 10 | italic | #404040 | #EDEDED | none | center, center | off | no | same row |
| Label cells (response or item) | Aptos | 11 | regular | #000000 | none | none | left, center | on | no | fit to text |
| Battery item label (column A) | Aptos | 11 | bold | #1F4E79 | none | none | left, top | on | no; written on the item's first row only | fit to text |
| Estimate cell (percentage string) | Aptos | 11 | regular | #000000 | none | none | center, center | on | no | 1 line; with an interval 1.35 x (11 + 9) + 4 pt |
| Interval line (second rich-text run of the estimate cell) | Aptos | 9 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Topline battery item heading | Aptos | 11 | bold | #1F4E79 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Aptos | 11 | bold | #000000 | #EDEDED | top thin #1F4E79 | label left; numbers as estimate cells | on | no | fit to text |
| Rule: between body rows | - | - | - | - | - | thin #D9D9D9 bottom of every response row and sample-size row except the last | - | - | - | - |
| Rule: between battery items | - | - | - | - | - | thin #7F7F7F bottom of the last row of each item except the last item | - | - | - | - |
| Rule: table bottom | - | - | - | - | - | medium #1F4E79 bottom of the last table row | - | - | - | - |
| Rule: column groups | - | - | - | - | - | thin #1F4E79 left side of the first column of each group (Total included), spanner row to last table row; About: left side of column B | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block; no columns; topline none |
| About: Key / Value row and section headings | Aptos | 11 | bold | #000000 | #F2F2F2 | bottom medium #1F4E79 | left, center | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Aptos | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Aptos | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 4 pt |

## B1. Banded title, group rules

B with the navy band on the title row only, a blue-grey spanner and heading with a navy rule under the heading, and a medium navy vertical rule at the left edge of each column group.

**Good for:** Wide banners, where a plain rule is enough to tell one banner variable from the next.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells right; data headings center.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 9 pt, #595959.
- Gap 6 (battery item label): no; written on the item's first row only.
- Gap 7 (sample-size numbers): `#,##0` and `#,##0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Calibri | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Calibri | 12 | bold | #FFFFFF | #1F3864 | none | left, center, indent 1 | on | across the block | fit to text |
| Base-note and legend rows | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Calibri | 11 | bold | #1F3864 | #C8D4E6 | none | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | - | none | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | left, center | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | center, center | on | no | same row |
| Sample-size label cells | Calibri | 10 | italic | #404040 | none | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `#,##0`, effective `#,##0.0`) | Calibri | 10 | italic | #404040 | none | none | right, center | off | no | same row |
| Label cells (response or item) | Calibri | 11 | regular | #000000 | none | none | left, center | on | no | fit to text |
| Battery item label (column A) | Calibri | 11 | bold | #000000 | none | none | left, top | on | no; written on the item's first row only | fit to text |
| Estimate cell (percentage string) | Calibri | 11 | regular | #000000 | none | none | right, center | on | no | 1 line; with an interval 1.35 x (11 + 9) + 4 pt |
| Interval line (second rich-text run of the estimate cell) | Calibri | 9 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Zebra stripe: all cells of every second response row (in a battery, of every second item); topline and About body rows by row | - | - | - | - | #EDF1F8 | - | - | - | - | - |
| Topline battery item heading | Calibri | 11 | bold | #1F3864 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Calibri | 11 | bold | #000000 | none | top thin #1F3864 | label left; numbers as estimate cells | on | no | fit to text |
| Rule: under the sample-size rows | - | - | - | - | - | thin #1F3864 bottom of the last sample-size row | - | - | - | - |
| Rule: block box | - | - | - | - | - | thin #7F7F7F outline from the title row to the last table row | - | - | - | - |
| Rule: column-group edge | - | - | - | - | - | medium #1F3864 left side of the first column of each group (Total included), spanner row to last table row; drawn after the block box; topline: left side of B; not on the About sheet | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block, and the label columns: A on single-response and SATA sheets, A:B on battery sheets; stacked sheet A:B (the battery block uses B as a label column); topline none |
| About: Key / Value row and section headings | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | left, center | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 4 pt |

## B2. Banded title, tinted groups

B1, plus spanner cells that alternate light blue and light grey by column group, so each group reads as one unit.

**Good for:** Banners with many groups of similar size, where the eye needs colour as well as a rule to find the group edges.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells right; data headings center.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 9 pt, #595959.
- Gap 6 (battery item label): no; written on the item's first row only.
- Gap 7 (sample-size numbers): `#,##0` and `#,##0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Calibri | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Calibri | 12 | bold | #FFFFFF | #1F3864 | none | left, center, indent 1 | on | across the block | fit to text |
| Base-note and legend rows | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Calibri | 11 | bold | #1F3864 | alternates by labelled group: #D0E2F5, #E3E3E3 | none | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | - | none | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | left, center | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | center, center | on | no | same row |
| Sample-size label cells | Calibri | 10 | italic | #404040 | none | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `#,##0`, effective `#,##0.0`) | Calibri | 10 | italic | #404040 | none | none | right, center | off | no | same row |
| Label cells (response or item) | Calibri | 11 | regular | #000000 | none | none | left, center | on | no | fit to text |
| Battery item label (column A) | Calibri | 11 | bold | #000000 | none | none | left, top | on | no; written on the item's first row only | fit to text |
| Estimate cell (percentage string) | Calibri | 11 | regular | #000000 | none | none | right, center | on | no | 1 line; with an interval 1.35 x (11 + 9) + 4 pt |
| Interval line (second rich-text run of the estimate cell) | Calibri | 9 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Zebra stripe: all cells of every second response row (in a battery, of every second item); topline and About body rows by row | - | - | - | - | #EDF1F8 | - | - | - | - | - |
| Topline battery item heading | Calibri | 11 | bold | #1F3864 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Calibri | 11 | bold | #000000 | none | top thin #1F3864 | label left; numbers as estimate cells | on | no | fit to text |
| Rule: under the sample-size rows | - | - | - | - | - | thin #1F3864 bottom of the last sample-size row | - | - | - | - |
| Rule: block box | - | - | - | - | - | thin #7F7F7F outline from the title row to the last table row | - | - | - | - |
| Rule: column-group edge | - | - | - | - | - | medium #1F3864 left side of the first column of each group (Total included), spanner row to last table row; drawn after the block box; topline: left side of B; not on the About sheet | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block, and the label columns: A on single-response and SATA sheets, A:B on battery sheets; stacked sheet A:B (the battery block uses B as a label column); topline none |
| About: Key / Value row and section headings | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | left, center | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 4 pt |

## B3. Banded title, boxed groups

B with the navy band on the title row only, a thin navy box around each column group from the spanner row to the last row, and a medium navy box around the Total column.

**Good for:** Readers who compare a subgroup with the full sample, since the Total column stands apart and each group is closed on both sides.

How it settles the styling gaps (spec-gaps.md, 1 to 7):

- Gap 1 (alignment): data cells right; data headings center.
- Gap 2 (About column B): width 90, wrap on, top-aligned.
- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.
- Gap 4 (bold, borders, fill): as the summary above and the table say.
- Gap 5 (interval line): 9 pt, #595959.
- Gap 6 (battery item label): no; written on the item's first row only.
- Gap 7 (sample-size numbers): `#,##0` and `#,##0.0`.

| Element | Font | Size | Bold/italic | Colour | Fill | Border | Alignment (h, v) | Wrap | Merge | Height or width |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Workbook base font | Calibri | 11 | regular | #000000 | none | none; gridlines hidden on every sheet | - | - | - | - |
| Title row (question text or group preface) | Calibri | 12 | bold | #FFFFFF | #1F3864 | none | left, center, indent 1 | on | across the block | fit to text |
| Base-note and legend rows | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Withheld line under a block (stacked file) | Calibri | 10 | italic | #404040 | none | none | left, center | on | across the block | fit to text |
| Spanner cell with a label | Calibri | 11 | bold | #1F3864 | #C8D4E6 | none | center, center | on | across the group's columns | fit to text, at least 2 lines |
| Spanner cell, empty (over the label columns and Total) | - | - | - | - | none | none | - | - | no | - |
| Heading cell, label columns (Response, Item) | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | left, center | on | no | fit to text, at least 2 lines |
| Heading cell, data columns | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | center, center | on | no | same row |
| Sample-size label cells | Calibri | 10 | italic | #404040 | none | none | left, center | off | no | fit to text |
| Sample-size numbers (unweighted `#,##0`, effective `#,##0.0`) | Calibri | 10 | italic | #404040 | none | none | right, center | off | no | same row |
| Label cells (response or item) | Calibri | 11 | regular | #000000 | none | none | left, center | on | no | fit to text |
| Battery item label (column A) | Calibri | 11 | bold | #000000 | none | none | left, top | on | no; written on the item's first row only | fit to text |
| Estimate cell (percentage string) | Calibri | 11 | regular | #000000 | none | none | right, center | on | no | 1 line; with an interval 1.35 x (11 + 9) + 4 pt |
| Interval line (second rich-text run of the estimate cell) | Calibri | 9 | regular | #595959 | - | - | second line of the cell | on | - | - |
| Zebra stripe: all cells of every second response row (in a battery, of every second item); topline and About body rows by row | - | - | - | - | #EDF1F8 | - | - | - | - | - |
| Topline battery item heading | Calibri | 11 | bold | #1F3864 | none | none | left, center | on | across the 3 columns | fit to text |
| Topline Total row | Calibri | 11 | bold | #000000 | none | top thin #1F3864 | label left; numbers as estimate cells | on | no | fit to text |
| Rule: under the sample-size rows | - | - | - | - | - | thin #1F3864 bottom of the last sample-size row | - | - | - | - |
| Rule: block box | - | - | - | - | - | thin #7F7F7F outline from the title row to the last table row | - | - | - | - |
| Rule: column-group box | - | - | - | - | - | thin #1F3864 outline of each group except Total, spanner row to last table row; drawn after the block box; topline: outline of B:C; not on the About sheet | - | - | - | - |
| Rule: Total column box | - | - | - | - | - | medium #1F3864 outline of the Total column, spanner row to last table row; drawn last | - | - | - | - |
| Freeze pane | - | - | - | - | - | - | - | - | - | rows above the first data row of the first block, and the label columns: A on single-response and SATA sheets, A:B on battery sheets; stacked sheet A:B (the battery block uses B as a label column); topline none |
| About: Key / Value row and section headings | Calibri | 11 | bold | #1F3864 | #DDE5F0 | bottom medium #1F3864 | left, center | on | no (spec 3.14) | fit to text |
| About: column A (keys; glossary terms bold) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| About: column B (values, glossary paragraphs) | Calibri | 11 | regular | #000000 | none | none | left, top | on | no | fit to text |
| Column widths | - | - | - | - | - | - | - | - | - | crosstab A 44, battery B 20, data 12 (17 under variance = ci); topline A 44, B and C 10; About A 44, B 90 |
| Row heights | - | - | - | - | - | - | - | - | - | every table row set: lines x 1.35 x font size + 4 pt |

