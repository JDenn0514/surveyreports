# Nationscape Wave 1: July 18, 2019

The first weekly wave of the Democracy Fund + UCLA Nationscape survey,
fielded July 18–24, 2019. Approximately 6,250 completed online
interviews drawn from the Lucid respondent exchange platform using a
non-probability quota design, with raking weights calibrated to ACS
demographic targets and 2016 presidential vote choice.

## Usage

``` r
ns_wave1
```

## Format

A data frame with approximately 6,250 rows and 171 columns (170 survey
variables plus `wave_id` added by the prepare script). Run
`names(ns_wave1)` for the complete column list. Key columns:

- `response_id` — Unique respondent ID (integer)

- `start_date` — Interview date (character, `"YYYY-MM-DD"` format)

- `wave_id` — Wave identifier: `"ns20190718"` for all rows in this
  dataset

- `weight` — Raking weight calibrated to ACS demographic targets and
  2016 presidential vote choice; use for all population-level estimates

- `right_track` — Country direction: `1` = Right direction, `2` = Wrong
  track, `3` = Not sure

- `economy_better` — Economy outlook: `1` = Better, `2` = Worse, `3` =
  Same, `4` = Not sure

- `interest` — Political interest (4-pt): `1` = Very interested, `4` =
  Not at all interested

- `registration` — Voter registration: `1` = Registered, `2` = Not
  registered, `3` = Not eligible

- `pres_approval` — Trump presidential approval: `1` = Strongly approve,
  `2` = Somewhat approve, `3` = Somewhat disapprove, `4` = Strongly
  disapprove

- `vote_intention` — 2020 vote intention: `1` = Trump, `2` = Democratic
  candidate, `3` = Other, `4` = Don't plan to vote, `5` = Not sure

- `vote_2016` — 2016 presidential vote (see labels)

- `pid3` — 3-category party ID: `1` = Democrat, `2` = Republican, `3` =
  Independent, `4` = Something else

- `pid7_legacy` — 7-point party ID (legacy coding; see labels)

- `ideo5` — 5-point ideological self-placement: `1` = Very liberal, `5`
  = Very conservative

- `age` — Respondent age in years

- `gender` — Gender: `1` = Male, `2` = Female, `3` = Other

- `census_region` — Census region: `1` = Northeast, `2` = Midwest, `3` =
  South, `4` = West

- `hispanic` — Hispanic or Latino origin: `1` = Yes, `2` = No

- `race_ethnicity` — Race/ethnicity (6 categories; see labels)

- `household_income` — Household income (7 brackets; see labels)

- `education` — Educational attainment (6 categories; see labels)

- `state` — U.S. state of residence (2-letter abbreviation)

## Source

Democracy Fund Voter Study Group / UCLA. Nationscape Data Set, version
December 2021. <https://www.voterstudygroup.org/data/nationscape> (free
download; academic research use). Prepared by
`data-raw/prepare-nationscape-phase1.R`.

For full methodology, see the Nationscape User Guide and the
Representative Assessment report in
`data-raw/nationscape/phase_1_v20210301/ns20190718/`.

## Details

This dataset is the first of 77 weekly waves collected from July 2019
through January 2021. The full survey ran in three phases:

|         |       |                             |           |
|---------|-------|-----------------------------|-----------|
| Phase   | Weeks | Dates                       | Approx. N |
| Phase 1 | 1–24  | Jul 18, 2019 – Dec 26, 2019 | 150,000   |
| Phase 2 | 25–50 | Jan 2, 2020 – Jun 25, 2020  | 162,500   |
| Phase 3 | 51–77 | Jul 2, 2020 – Jan 12, 2021  | 168,750   |

Only Wave 1 is bundled in the package because 77 waves × ~6,250 rows
would be prohibitively large. To obtain the full dataset by phase, use
the prepare scripts in `data-raw/` (see the Source section).

**Survey design:** The Nationscape is a calibrated non-probability
sample (quota design with raking weights). Use
[`surveycore::as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.html)
— it is designed specifically for this use case:

    svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)

**Metadata:** All substantive columns carry variable labels (`"label"`
attribute) set during data preparation. Battery items additionally carry
a `"question_preface"` attribute with the shared question stem. Value
labels (`"labels"` attribute) are present for all coded response items.

**Battery structure:** Most multi-item question groups follow a
`{battery}_{item}` naming convention. All items within a battery share
an identical `"question_preface"` attribute:

|                        |                                        |         |
|------------------------|----------------------------------------|---------|
| Battery prefix         | Preface summary                        | N items |
| `news_sources_*`       | News sources used in past week         | 13      |
| `group_favorability_*` | Favorability toward named groups       | 13      |
| `cand_favorability_*`  | Favorability toward named candidates   | 9       |
| `trump_*`              | Trump head-to-head matchups            | 10      |
| `pence_*`              | Pence head-to-head matchups            | 5       |
| `cand_truth_*`         | Whether each candidate tells the truth | 6       |
| `cand_facts_*`         | Whether each candidate relies on facts | 6       |
| `racial_attitudes_*`   | Agree/disagree racial attitude items   | 4       |
| `gender_attitudes_*`   | Agree/disagree gender attitude items   | 4       |
| `discrimination_*`     | Perceived discrimination by group      | 6       |

## References

Tausanovitch, Chris and Lynn Vavreck. 2021. Democracy Fund + UCLA
Nationscape, October 10–17, 2019 (version 20210301). Retrieved from
voterstudygroup.org/data/nationscape.

## Examples

``` r
# Design variables
head(ns_wave1[, c("response_id", "weight", "age", "gender")])
#> # A tibble: 6 × 4
#>   response_id weight   age gender
#>   <chr>        <dbl> <dbl>  <dbl>
#> 1 00100002    1.75      37      1
#> 2 00100003    0.144     45      2
#> 3 00100004    0.213     24      1
#> 4 00100005    0.0506    26      1
#> 5 00100007    0.137     60      1
#> 6 00100008    0.0653    55      2

# Inspect a battery item's metadata
attr(ns_wave1$group_favorability_blacks, "label")
#> [1] "Blacks"
attr(ns_wave1$group_favorability_blacks, "question_preface")
#> [1] "Here are the names of some groups that are in the news from time to time. How favorable is your impression of each?"
attr(ns_wave1$news_sources_cnn, "labels")
#> Yes  No 
#>   1   2 

# Create a calibrated survey design
svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)

# Party identification distribution
table(ns_wave1$pid3)
#> 
#>    1    2    3    4 
#> 2291 1819 1868  437 
```
