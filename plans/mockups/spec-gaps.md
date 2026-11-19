# Spec gaps found while building the mockups

**Date:** 2026-11-19
**Spec read:** `plans/spec-export-metadata.md` v0.27.0, with
`plans/test-spec-export-metadata.md` and `plans/decisions-export-metadata.md`
**Script:** `plans/mockups/build-mockups.R`

The mockups show the output after PR 19. They use `ns_wave1` as a
`survey_nonprob` design, with real labels and real estimates from
`surveycore::get_freqs()` and `surveycore::get_effective_n()`.

| File | Call it stands for |
|---|---|
| `mockup-crosstab.xlsx` | `layout = "per_question"`, `banner = c(gender, pid3)`, `interactions = list(c("gender", "pid3"))`, `variance = "ci"`, defaults otherwise (`variance_display = "cell"`, `withheld_note = "once"`, `min_eff_n = 100`) |
| `mockup-crosstab-stacked.xlsx` | the same call with `layout = "stacked"`, `variance = NULL` and `withheld_note = "every"` |
| `mockup-topline.xlsx` | `export_topline()` at its defaults (`show_n = TRUE`, `show_eff_n = FALSE`, `variance = NULL`) |

Each workbook holds a single-response question (`pres_approval`), a
select-all-that-apply block (six `news_sources_*` items, marked SATA with
`set_sata()`), and a battery (four `group_favorability_*` items). The script
sets the six dataset keys and a universe on `pres_approval` and on the battery
items. Two crossed cells fall below the floor of 100: `Female × Something else`
(effective N 94.5) and `Male × Something else` (68.9).

Where the spec is silent, the mockup adds no styling of its own. That is the
rule behind most choices below.

---

## Part 1: the gaps

The entries that change the look most come first.

### 1. Alignment of the percentage cells

- **Decision:** how a percentage cell is aligned.
- **Section:** 3.3 makes the cell a string. No section gives an alignment.
- **Choice:** none set. Excel aligns text to the left, so every percentage
  sits on the left of its column. The sample-size cells are numbers, so they
  sit on the right. The two kinds of cell in one column do not line up.
- **Other choice:** right-align, or center, every data cell of the block:
  the estimate cells, the variance rows and the sample-size cells.

### 2. The width of column B on the About sheet

- **Decision:** how wide the value column of the cover sheet is, and whether
  its text wraps.
- **Section:** 3.14, Styling row: "the column widths of section 3.16". That
  section gives 44 for the label column and 12 for a data column.
- **Choice:** column A is 44 and column B is 12, with no wrap. Each glossary
  text is one line of 200 to 400 characters that runs far to the right of
  column B. The reader must scroll sideways to read one entry.
- **Other choice:** column B at about 80 to 100 characters with wrap on, so
  each entry reads as a short paragraph.

### 3. The spanner row: wrap, height, bold and alignment

- **Decision:** how a spanner cell is styled.
- **Section:** 3.16 says "one merged cell per column group". 3.8 says the
  spanner reads the variable label. Nothing says how it looks.
- **Choice:** plain text, aligned left, no wrap, default height. In
  `ns_wave1` the `gender` label is `What is your gender? Provided by LUCID.`,
  39 characters over two columns of 17. Excel cuts it at the edge of the
  merged cell. Real variable labels are often this long.
- **Other choice:** bold and centered, with wrap on and the row at 30
  points, as the heading row is.

### 4. Bold, borders and fill anywhere in the table

- **Decision:** whether the heading row, the label headings (`Response`,
  `Item`) or any part of the table has bold, a border or a fill.
- **Section:** 3.16 names bold for the title row only. 3.4 says the
  sample-size rows have "no fill, no border". No section names a border for
  any other row.
- **Choice:** none. The only bold in a table is the title. The table has no
  rules between the headings and the data.
- **Other choice:** bold headings and a bottom border under the heading row,
  or under the last sample-size row.

### 5. The second line of a variance cell

- **Decision:** the size and colour of the interval line.
- **Section:** 3.12 says "a smaller size and a lighter colour".
- **Choice:** 9 points (the body text is 11) and mid grey, `#808080`.
- **Other choice:** 10 points, one step down as the sample-size rows are,
  and a darker grey such as `#595959`.

### 6. The item label in a battery block

- **Decision:** where the item label goes when an item takes several rows.
- **Section:** 3.16 says a battery has one row per response value within
  each item, and two label columns. It does not say how often the item label
  is written.
- **Choice:** once, on the first row of the item. The rows below it leave
  column A blank. No blank row or border separates two items.
- **Other choice:** the label on every row, or one merged cell down the
  item's rows, or a blank row between items.

### 7. How the sample-size numbers are shown

- **Decision:** the number format of the two sample-size rows.
- **Section:** 3.4 says the effective sample size is "at one decimal". It does
  not say whether the cell is a number or text, or whether a thousands
  separator is used.
- **Choice:** both are numbers. The unweighted row uses General (`6422`). The
  effective row uses the format `0.0` (`963.0`), so the decimal shows even
  when it is zero. No thousands separator.
- **Other choice:** `#,##0` and `#,##0.0`, which the topline already uses in
  its `Eff N` header (`1,234`). Or General for both, so `963.0` shows as
  `963`.

### 8. The wording of a withheld line

- **Decision:** the exact sentence of one withheld line.
- **Section:** 3.14 says the line names the subgroup, its banner variable and
  its effective N, and no raw N. 2.2 says "Section 3.14 fixes the wording",
  but 3.14 gives no sentence.
- **Choice:** `Male × Something else (gender × pid3): effective sample size
  68.9`. The banner variable is the column name, as the withheld frame holds
  it. The effective N is at one decimal, as in the sample-size row.
- **Other choice:** name the banner by its variable label, as the spanner
  does, and state the floor: `"Male × Something else" (gender × pid3)
  withheld: effective sample size 68.9, below the minimum of 100.`

### 9. The layout of the About sheet blocks

- **Decision:** three things the spec does not fix.
  - the text in the key column for a dataset key
  - whether the survey block has its own heading row
  - where the minimum and the withheld lines go in the withheld block
- **Section:** 3.14. XA-03 says "display labels" but no section defines them.
- **Choice:**
  - The key column shows the key in sentence case: `survey_name` becomes
    `Survey name`, `field_start` becomes `Field start`.
  - The survey block has no heading. The `Key` / `Value` row heads it.
  - The withheld block is the bold heading `Subgroups not shown`, then
    `Minimum effective sample size` in A with `100` in B, then one line per
    withheld subgroup in column A alone.
- **Other choice:** the raw key (`survey_name`) or a shorter label
  (`Survey`); a bold `Survey metadata` heading under the header row; each
  withheld line in column B beside a `Not shown` key.

### 10. The base-note and legend rows

- **Decision:** whether the base note and the variance legend are merged
  across the block, and whether they wrap.
- **Section:** 3.16 says the title is "merged across the block". For rows 2
  and 3 it says "italic" only.
- **Choice:** both rows are merged across the block, as the title is, with
  no wrap. The topline already merges its base note.
- **Other choice:** unmerged, in column A. The text then runs into the empty
  cells to the right.

### 11. Which rows of column A wrap

- **Decision:** the label column wraps (3.16). Does that include the title,
  base-note, legend and withheld-line rows?
- **Section:** 3.16, Wrapping row: "on for the label column".
- **Choice:** wrap is on in column A from the heading row to the last
  sample-size row only. The title, notes and withheld lines do not wrap. A
  withheld line is longer than 44 characters, and with wrap on at the default
  height of 15 points only its first line would show.
- **Other choice:** wrap on every cell of column A, with a fixed height on
  the rows whose text is longer than the column.

### 12. Space between blocks on the stacked sheet

- **Decision:** how many blank rows separate two blocks on the `"Crosstab"`
  sheet.
- **Section:** none. `package-conventions.md` shows
  `current_row <- result$next_row + 1L`.
- **Choice:** one blank row.
- **Other choice:** two blank rows, or none with a border.

### 13. The style of a withheld line under a table

- **Decision:** how the lines look when `withheld_note = "every"`.
- **Section:** 3.16 gives the row, not a style.
- **Choice:** plain text in column A, directly under the last row of the
  table, with no blank row before it.
- **Other choice:** italic, as the base note is, with a blank row before
  the first line.

### 14. "Listed above" when the cover sheet lists no minimum

- **Decision:** what the `Why a column is missing` entry says when
  `withheld_note` is `"every"` or `"none"`.
- **Section:** 3.15 writes the entry when `min_eff_n > 0` and a banner was
  rendered. Its text says "The minimum for this workbook is listed above".
  3.14 writes the withheld block, which lists the minimum, only under
  `"once"`. The two contradict each other under `"every"` and `"none"`.
- **Choice:** the stacked mockup (`"every"`) keeps the entry verbatim. The
  sheet lists no minimum above it, so the sentence is false there.
- **Other choice:** write the minimum on the cover sheet whatever
  `withheld_note` is, or name the number inside the entry text.

### 15. The order of crossed levels on a value-labelled banner

- **Decision:** the order of the crossed headings when a banner column holds
  value-labelled numeric codes, not a factor.
- **Section:** 3.8 keeps the level order for a factor only. A labelled
  numeric column comes back as character, and `interaction()` then sorts it
  alphabetically: `Democrat`, `Independent`, `Republican`. The `pid3`
  spanner itself keeps code order: `Democrat`, `Republican`, `Independent`.
- **Choice:** code order in both places, so the crossed group follows the
  `pid3` group.
- **Other choice:** alphabetical crossed levels, as the spec's rule
  produces for this input.

### 16. Which value counts as "chosen" in a SATA item

- **Decision:** which response value a SATA cell reports.
- **Section:** 3.3 speaks of an item "chosen" or "chosen by nobody". It does
  not name the value. The current code reads the value `"1"`.
- **Choice:** the `Yes` level, code 1 in `news_sources_*`. With labelled
  values, `get_freqs()` returns `Yes`, not `"1"`, so a reader of `"1"` finds
  no row and every SATA cell would read `-`.
- **Other choice:** the first value label, or the code `1` read before the
  labels are applied.

### 17. A dash or 0% for a category nobody in a column chose

- **Decision:** what a single-response cell shows when the column has
  answers but nobody in it chose this category.
- **Section:** 3.3 says `has_rows` is computed over "the `get_freqs()` rows
  for this cell". The Percentages entry of 3.15 says "A dash means the answer
  was not chosen in that column". XC-06 expects `0%` for a category with an
  estimate of exactly 0 in a column whose rows carry `n > 0`. The two readings
  disagree.
- **Choice:** per cell. A category row with `n = 0` reads `-`. The mockup data
  has no such cell, so the choice is not visible.
- **Other choice:** per column. Any row with `n > 0` in the column makes a
  zero category read `0%`.

### 18. The glossary entry for `variance = "se"`

- **Decision:** whether a standard-error glossary entry exists.
- **Section:** 3.15, last paragraph before the topline note: "When `variance`
  is set to `"se"`, an entry names the statistic". The same section records
  decision 66, "the glossary stays at five terms", and its table has no such
  entry.
- **Choice:** no entry. Neither mockup uses `"se"`.
- **Other choice:** a sixth entry, `Standard error`, worded as the legend
  row is.

### 19. The topline interval entry with no intervals in the cells

- **Decision:** whether a topline workbook at `variance = "ci"` carries the
  `Confidence intervals` entry.
- **Section:** 3.15 and 4.1 say it does. 4.1 also holds the topline look
  fixed, and the topline render writes no standard error or interval into
  any cell. The entry then explains numbers the workbook does not show.
- **Choice:** the topline mockup runs at `variance = NULL`, so the entry is
  absent and the question does not arise.
- **Other choice:** omit the entry from every topline workbook until the
  topline pass writes intervals.

### 20. The base font

- **Decision:** the font and size of "the body text".
- **Section:** 3.4 says the sample-size rows are one point smaller than the
  body text. No section names the body font.
- **Choice:** the openxlsx2 1.28 default, Aptos Narrow 11. The sample-size
  rows are Aptos Narrow 10, italic.
- **Other choice:** Calibri 11, the older Excel default.

### 21. The glossary text: Markdown marks

- **Decision:** whether the backticks in the 3.15 Percentages text are part
  of the text.
- **Section:** 3.15 says "written verbatim", and the text holds `` `<0.1%` ``.
- **Choice:** the backticks are Markdown and are left out: `reads <0.1%.`
- **Other choice:** quotation marks around each form: `reads "<0.1%".`

### 22. A long title on the topline sheet

- **Decision:** none for this spec. The spec keeps the topline look (1.3,
  4.1). Recorded because the reviewer will see it.
- **Section:** 4.1.
- **Choice:** as today. The topline sets no column widths, so the title is
  merged across three columns of about 8 characters, and a long question
  text is cut at the edge.
- **Other choice:** for the topline pass: give the topline the 44 / 12
  widths of the crosstab.

---

## Part 2: what the spec settles

Each element below is built as the spec states it.

| Element | Section |
|---|---|
| `About` is sheet 1 and the file opens on it | 3.14 |
| `Key` / `Value` header in A1:B1, bold | 3.14 |
| Six dataset keys, in surveycore's canonical order | 3.14, XA-03 |
| Block headings bold in column A; one blank row between blocks, none after the last | 3.14 |
| Withheld block: the minimum, then one line per subgroup, under `"once"` only | 3.14 |
| Glossary terms and texts, and which entries appear (five, four, two) | 3.15, XA-05, TP-06 |
| No merged cells on the About sheet | 3.14 |
| Per-question sheet names: the variable, or the first member of a group | 3.8, 3.10 |
| One `"Crosstab"` sheet on the stacked layout | 3.2 |
| Block row order: title, base note, legend, spanner, headings, two sample-size rows, data | 3.16, XR-01 |
| Title bold and merged across the block | 3.16 |
| Base note and legend italic; base note is the universe text, verbatim | 3.6, 3.16 |
| Legend text `Percentages; 95% confidence interval in parentheses.` | 3.12 |
| Total column first, heading `Full Sample`, empty spanner cell | 3.9 |
| Spanners read variable labels; crossed spanner joins them with ` × ` | 3.8 |
| Crossed headings read value labels, first variable varying fastest | 3.8, XH-04, XH-05 |
| A withheld subgroup has no column, no heading and no share of the spanner | 3.5 |
| Floor test `n_eff < 100` on banner levels and crossed cells | 3.5 |
| Label headings `Response`, `Item`, and `Item` + `Response` | 3.16 |
| Sample-size labels `Unweighted sample size` and `Effective sample size`, italic, one point smaller | 3.4 |
| Sample-size counts ignore the tabulated variable | 3.4, 1.4.1 |
| Percentage string rule, half to even, ragged decimals (`20%` beside `16.7%`) | 3.3 |
| Interval string `(16.7% – 20%)`, en-dash with spaces, one `%` per bound | 3.12 |
| Interval on a second line in the cell, as rich text | 3.12 |
| Column widths: A 44, battery B 20, data 12, or 17 under `"ci"`; stacked B the larger of 20 and the data width | 3.16, XB-01, XB-05, XB-13 |
| Heading row wraps and is 30 points | 3.16 |
| Under `"ci"` and `"cell"`, every estimate cell wraps and every estimate row is 30 points | 3.16, XB-08, XB-09 |
| Battery `Response` cells wrap | 3.16 |
| Freeze pane at the first data row of the first block, rows only | 3.16, XB-11 |
| No `100%` row and no `N` column in the crosstab | 3.9, 3.16, XS-08 |
| Withheld lines under each block under `"every"`, none on the cover sheet | 3.5, 3.16, XW-10 |
| Topline: numeric percentages, an `N` column, a `Total` row of `100%`, one table per battery item | 4.1, 4.2, TP-09, TP-10 |

### Not in the mockups

The mockups do not show these cases. The spec covers each one, and a
reviewer may want to see some of them:

- the `None` row of the withheld block, and the domain row `Restricted to`
- a collection cover sheet, with one block per wave
- `variance_display = "row"`, `variance = "se"`, and
  `sample_size_display = "bottom"` or `"none"`
- `na.rm = FALSE`, with its `No answer` row and column
- the special cell forms `-`, `0%`, `<0.1%` and `>99.9%`, and a negative
  interval bound. No cell in this data produces one.
