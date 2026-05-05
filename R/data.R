#' ANES 2024: American National Election Studies Time Series
#'
#' A 19-variable extract from the 2024 American National Election Studies
#' (ANES) Time Series Study, a landmark biennial pre- and post-election survey
#' of the American electorate. Fielded via face-to-face interview and web
#' (n = 5,521). This extract uses the FTF + Web combined design variables
#' (`v240103a`–`v240103d`), the recommended set for most analyses.
#'
#' @format A data frame with 5,521 rows and 19 variables:
#' \describe{
#'   \item{v240103a}{Pre-election weight (FTF+Web combined). Use for
#'     variables asked before November 5, 2024.}
#'   \item{v240103b}{Post-election weight (FTF+Web combined). Use for
#'     variables asked after November 5, 2024.}
#'   \item{v240103c}{PSU (FTF+Web combined). Use as the cluster ID for
#'     variance estimation.}
#'   \item{v240103d}{Stratum (FTF+Web combined). Use as the stratification
#'     variable.}
#'   \item{v240001}{2024 Time Series Case ID. Unique respondent identifier.}
#'   \item{v240003}{Sample type: `1` = Panel, `2` = Fresh Web, `3` = Fresh
#'     FTF, `4` = GSS.}
#'   \item{v240002c}{Pre/Post interview completion: `1` = Pre-election only,
#'     `2` = Pre- and post-election.}
#'   \item{v243002}{State FIPS code.}
#'   \item{v243007}{Census region: `1` = Northeast, `2` = Midwest,
#'     `3` = South, `4` = West.}
#'   \item{v241458x}{Age on Election Day (summary). Top-coded at 80.
#'     `-2` = missing.}
#'   \item{v241550}{Sex: `1` = male, `2` = female.}
#'   \item{v241501x}{Race/ethnicity (5-category summary): White non-Hispanic,
#'     Black non-Hispanic, Hispanic, Asian/NHPI non-Hispanic,
#'     Other/Multiracial non-Hispanic.}
#'   \item{v241465x}{Education (5-category summary): `1` = less than HS,
#'     `2` = HS diploma, `3` = some college, `4` = bachelor's degree,
#'     `5` = graduate degree.}
#'   \item{v241566x}{Household income (28 categories from < $5,000 to
#'     $250,000+).}
#'   \item{v241177}{Liberal-conservative self-placement (7-point scale):
#'     `1` = extremely liberal, `7` = extremely conservative.
#'     `99` = haven't thought about this.}
#'   \item{v241222}{Party identification strength: `1` = strong,
#'     `2` = not very strong.}
#'   \item{v241223}{Party identification lean (Independents): `1` = closer to
#'     Republican, `2` = neither, `3` = closer to Democrat.}
#'   \item{v242066}{Did respondent vote for President (POST): `1` = yes,
#'     `2` = no.}
#'   \item{v242067}{Presidential vote choice (POST): `1` = Harris,
#'     `2` = Trump, `3` = RFK Jr., `4` = West, `5` = Stein, `6` = Other.}
#' }
#'
#' @details
#' **Survey design:** Stratified cluster — use Taylor series linearization.
#' Two weights are available depending on whether the analysis uses pre- or
#' post-election variables:
#'
#' ```r
#' # Pre-election analysis (party ID, ideology, candidate preference)
#' svy_pre <- surveycore::as_survey(anes_2024,
#'   ids     = v240103c,
#'   strata  = v240103d,
#'   weights = v240103a,
#'   nest    = TRUE
#' )
#'
#' # Post-election analysis (validated vote choice)
#' svy_post <- surveycore::as_survey(anes_2024,
#'   ids     = v240103c,
#'   strata  = v240103d,
#'   weights = v240103b,
#'   nest    = TRUE
#' )
#' ```
#'
#' **Missing value codes:** The ANES uses negative integer codes for missing
#' data throughout: `-9` = Refused, `-8` = Don't know, `-4` = Technical error,
#' `-1` = Inapplicable, and others. These must be recoded to `NA` before
#' analysis. Check `attr(anes_2024$v241177, "labels")` for the full set of
#' codes for a given variable.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original Stata file, automatically extracted into surveycore's metadata
#' system when you call `surveycore::as_survey()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column. Example: `attr(anes_2024$v241550, "label")` returns
#'   `"PRE: What is your sex?"` (or similar ANES phrasing).
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning, including all missing-value codes. Example:
#'   `attr(anes_2024$v241550, "labels")` returns a vector with entries for
#'   `Male`, `Female`, and the applicable negative missing codes.
#'
#' @source
#' American National Election Studies. 2024 Time Series Study.
#' Available at electionstudies.org (free account required to download raw
#' data; the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-anes-2024.R`.
#'
#' @examples
#' # Variables in the dataset
#' names(anes_2024)
#'
#' # Create pre-election design
#' svy <- surveycore::as_survey(
#'   anes_2024,
#'   ids = v240103c,
#'   strata = v240103d,
#'   weights = v240103a,
#'   nest = TRUE
#' )
#'
#' # Inspect variable label (ANES uses opaque V-codes; labels give context)
#' attr(anes_2024$v241177, "label")
#'
#' # Inspect value labels, including missing-value codes
#' attr(anes_2024$v241177, "labels")
"anes_2024"


#' GSS 2024: General Social Survey
#'
#' A 27-variable extract from the 2024 General Social Survey (GSS), one of
#' the longest-running sociological surveys in the United States (fielded
#' annually or biennially since 1972). All 3,309 respondents from the 2024
#' cross-section are included.
#'
#' @format A data frame with 3,309 rows and 27 variables:
#' \describe{
#'   \item{vpsu}{Variance primary sampling unit. Use as the cluster ID for
#'     variance estimation.}
#'   \item{vstrat}{Variance stratum. Use as the stratification variable.}
#'   \item{wtssps}{Person post-stratification weight. Standard analysis
#'     weight.}
#'   \item{wtssnrps}{Person post-stratification weight adjusted for
#'     differential non-response. Preferred when non-response bias is a
#'     concern.}
#'   \item{id}{Respondent ID. Unique case identifier.}
#'   \item{year}{Survey year (all `2024` in this extract).}
#'   \item{ballot}{Ballot form (`A`, `B`, `C`, or `D`). The GSS uses a
#'     split-ballot design; not all questions appear on every ballot.
#'     Inapplicable items are coded `-100`.}
#'   \item{age}{Age in years (`89` = 89 or older).}
#'   \item{sex}{Sex: `1` = male, `2` = female.}
#'   \item{race}{Race: `1` = white, `2` = black, `3` = other.}
#'   \item{hispanic}{Hispanic origin: `1` = not Hispanic; `2`–`50` = specific
#'     Hispanic origin.}
#'   \item{educ}{Highest year of school completed (0–20 years).}
#'   \item{degree}{Highest degree: `0` = less than HS, `1` = high school,
#'     `2` = associate, `3` = bachelor's, `4` = graduate.}
#'   \item{income16}{Total family income (26 categories from < $1,000 to
#'     $170,000+).}
#'   \item{marital}{Marital status: `1` = married, `2` = widowed,
#'     `3` = divorced, `4` = separated, `5` = never married.}
#'   \item{wrkstat}{Labor force status: `1` = full time, `2` = part time,
#'     `3` = temporarily not working, `4` = unemployed, `5` = retired,
#'     `6` = in school, `7` = keeping house, `8` = other.}
#'   \item{hrs1}{Hours worked last week (for employed respondents only).}
#'   \item{adults}{Number of adults in household (`8` = 8 or more).}
#'   \item{partyid}{Party identification: `0` = strong Democrat,
#'     `3` = Independent, `6` = strong Republican, `7` = other party.}
#'   \item{polviews}{Political views: `1` = extremely liberal,
#'     `7` = extremely conservative.}
#'   \item{happy}{General happiness: `1` = very happy, `2` = pretty happy,
#'     `3` = not too happy.}
#'   \item{health}{Self-rated health: `1` = excellent, `2` = good,
#'     `3` = fair, `4` = poor.}
#'   \item{trust}{Social trust: `1` = most people can be trusted,
#'     `2` = can't be too careful, `3` = depends.}
#'   \item{natfare}{Government spending on welfare: `1` = too little,
#'     `2` = about right, `3` = too much.}
#'   \item{abany}{Abortion for any reason: `1` = yes, `2` = no.}
#'   \item{attend}{Religious service attendance: `0` = never,
#'     `8` = several times a week.}
#'   \item{relig}{Religious preference: `1` = Protestant, `2` = Catholic,
#'     `3` = Jewish, `4` = none, and others.}
#' }
#'
#' @details
#' **Survey design:** Stratified multi-stage cluster — use Taylor series
#' linearization:
#'
#' ```r
#' svy <- surveycore::as_survey(gss_2024,
#'   ids     = vpsu,
#'   strata  = vstrat,
#'   weights = wtssps,      # or wtssnrps for non-response-adjusted weight
#'   nest    = TRUE
#' )
#' ```
#'
#' **Missing value codes:** The GSS uses a consistent system of negative
#' integer codes for missing data across all variables:
#'
#' | Code | Meaning |
#' |------|---------|
#' | `-100` | Inapplicable (question not asked of this respondent) |
#' | `-99` | No answer |
#' | `-98` | Don't know |
#' | `-97` | Skipped on web |
#' | `-90` | Refused |
#'
#' These codes are stored as value labels on every column (check
#' `attr(gss_2024$happy, "labels")`). Recode them to `NA` before analysis.
#'
#' **Split-ballot design:** The `ballot` variable indicates which question
#' module a respondent received. Variables asked only on some ballots will
#' have `-100` (Inapplicable) for respondents on other ballots.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original SPSS file, automatically extracted into surveycore's metadata
#' system when you call `surveycore::as_survey()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column. Example: `attr(gss_2024$happy, "label")` returns
#'   `"GENERAL HAPPINESS"`.
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning, including all missing-value codes. Example:
#'   `attr(gss_2024$happy, "labels")` returns entries for `Very happy`,
#'   `Pretty happy`, `Not too happy`, and the negative missing codes.
#'
#' @source
#' NORC at the University of Chicago. General Social Survey 2024.
#' \url{https://gss.norc.org} (free account required to download raw data;
#' the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-gss-2024.R`.
#'
#' @examples
#' # Variables in the dataset
#' names(gss_2024)
#'
#' # Create survey design
#' svy <- surveycore::as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   strata = vstrat,
#'   weights = wtssps,
#'   nest = TRUE
#' )
#'
#' # Inspect variable label
#' attr(gss_2024$happy, "label")
#'
#' # Inspect value labels (includes GSS missing-value codes)
#' attr(gss_2024$happy, "labels")
#'
#' # Split-ballot: how many respondents per ballot form?
#' table(gss_2024$ballot)
"gss_2024"


#' Pew Jewish Americans 2020
#'
#' The extended survey dataset from Pew Research Center's 2019-2020 Survey
#' of U.S. Jews, fielded November 19, 2019 – June 3, 2020 (n = 5,881).
#' Respondents were drawn from a national, stratified random sample of
#' residential mailing addresses with oversampling of households likely to
#' contain Jewish respondents. The dataset carries 100 jackknife replicate
#' weights alongside the main weight.
#'
#' @format A data frame with 5,881 rows and 130 variables. Variables
#' `extweight1`–`extweight100` are jackknife replicate weights; the remaining
#' 30 variables are:
#' \describe{
#'   \item{extweight}{Full-sample base weight. Use for all estimates.}
#'   \item{extweight1}{Jackknife replicate weight 1 of 100.}
#'   \item{extweight2}{Jackknife replicate weight 2 of 100.}
#'   \item{extweight3}{Jackknife replicate weight 3 of 100.}
#'   \item{extweight4}{Jackknife replicate weight 4 of 100.}
#'   \item{extweight5}{Jackknife replicate weight 5 of 100.}
#'   \item{extweight6}{Jackknife replicate weight 6 of 100.}
#'   \item{extweight7}{Jackknife replicate weight 7 of 100.}
#'   \item{extweight8}{Jackknife replicate weight 8 of 100.}
#'   \item{extweight9}{Jackknife replicate weight 9 of 100.}
#'   \item{extweight10}{Jackknife replicate weight 10 of 100.}
#'   \item{extweight11}{Jackknife replicate weight 11 of 100.}
#'   \item{extweight12}{Jackknife replicate weight 12 of 100.}
#'   \item{extweight13}{Jackknife replicate weight 13 of 100.}
#'   \item{extweight14}{Jackknife replicate weight 14 of 100.}
#'   \item{extweight15}{Jackknife replicate weight 15 of 100.}
#'   \item{extweight16}{Jackknife replicate weight 16 of 100.}
#'   \item{extweight17}{Jackknife replicate weight 17 of 100.}
#'   \item{extweight18}{Jackknife replicate weight 18 of 100.}
#'   \item{extweight19}{Jackknife replicate weight 19 of 100.}
#'   \item{extweight20}{Jackknife replicate weight 20 of 100.}
#'   \item{extweight21}{Jackknife replicate weight 21 of 100.}
#'   \item{extweight22}{Jackknife replicate weight 22 of 100.}
#'   \item{extweight23}{Jackknife replicate weight 23 of 100.}
#'   \item{extweight24}{Jackknife replicate weight 24 of 100.}
#'   \item{extweight25}{Jackknife replicate weight 25 of 100.}
#'   \item{extweight26}{Jackknife replicate weight 26 of 100.}
#'   \item{extweight27}{Jackknife replicate weight 27 of 100.}
#'   \item{extweight28}{Jackknife replicate weight 28 of 100.}
#'   \item{extweight29}{Jackknife replicate weight 29 of 100.}
#'   \item{extweight30}{Jackknife replicate weight 30 of 100.}
#'   \item{extweight31}{Jackknife replicate weight 31 of 100.}
#'   \item{extweight32}{Jackknife replicate weight 32 of 100.}
#'   \item{extweight33}{Jackknife replicate weight 33 of 100.}
#'   \item{extweight34}{Jackknife replicate weight 34 of 100.}
#'   \item{extweight35}{Jackknife replicate weight 35 of 100.}
#'   \item{extweight36}{Jackknife replicate weight 36 of 100.}
#'   \item{extweight37}{Jackknife replicate weight 37 of 100.}
#'   \item{extweight38}{Jackknife replicate weight 38 of 100.}
#'   \item{extweight39}{Jackknife replicate weight 39 of 100.}
#'   \item{extweight40}{Jackknife replicate weight 40 of 100.}
#'   \item{extweight41}{Jackknife replicate weight 41 of 100.}
#'   \item{extweight42}{Jackknife replicate weight 42 of 100.}
#'   \item{extweight43}{Jackknife replicate weight 43 of 100.}
#'   \item{extweight44}{Jackknife replicate weight 44 of 100.}
#'   \item{extweight45}{Jackknife replicate weight 45 of 100.}
#'   \item{extweight46}{Jackknife replicate weight 46 of 100.}
#'   \item{extweight47}{Jackknife replicate weight 47 of 100.}
#'   \item{extweight48}{Jackknife replicate weight 48 of 100.}
#'   \item{extweight49}{Jackknife replicate weight 49 of 100.}
#'   \item{extweight50}{Jackknife replicate weight 50 of 100.}
#'   \item{extweight51}{Jackknife replicate weight 51 of 100.}
#'   \item{extweight52}{Jackknife replicate weight 52 of 100.}
#'   \item{extweight53}{Jackknife replicate weight 53 of 100.}
#'   \item{extweight54}{Jackknife replicate weight 54 of 100.}
#'   \item{extweight55}{Jackknife replicate weight 55 of 100.}
#'   \item{extweight56}{Jackknife replicate weight 56 of 100.}
#'   \item{extweight57}{Jackknife replicate weight 57 of 100.}
#'   \item{extweight58}{Jackknife replicate weight 58 of 100.}
#'   \item{extweight59}{Jackknife replicate weight 59 of 100.}
#'   \item{extweight60}{Jackknife replicate weight 60 of 100.}
#'   \item{extweight61}{Jackknife replicate weight 61 of 100.}
#'   \item{extweight62}{Jackknife replicate weight 62 of 100.}
#'   \item{extweight63}{Jackknife replicate weight 63 of 100.}
#'   \item{extweight64}{Jackknife replicate weight 64 of 100.}
#'   \item{extweight65}{Jackknife replicate weight 65 of 100.}
#'   \item{extweight66}{Jackknife replicate weight 66 of 100.}
#'   \item{extweight67}{Jackknife replicate weight 67 of 100.}
#'   \item{extweight68}{Jackknife replicate weight 68 of 100.}
#'   \item{extweight69}{Jackknife replicate weight 69 of 100.}
#'   \item{extweight70}{Jackknife replicate weight 70 of 100.}
#'   \item{extweight71}{Jackknife replicate weight 71 of 100.}
#'   \item{extweight72}{Jackknife replicate weight 72 of 100.}
#'   \item{extweight73}{Jackknife replicate weight 73 of 100.}
#'   \item{extweight74}{Jackknife replicate weight 74 of 100.}
#'   \item{extweight75}{Jackknife replicate weight 75 of 100.}
#'   \item{extweight76}{Jackknife replicate weight 76 of 100.}
#'   \item{extweight77}{Jackknife replicate weight 77 of 100.}
#'   \item{extweight78}{Jackknife replicate weight 78 of 100.}
#'   \item{extweight79}{Jackknife replicate weight 79 of 100.}
#'   \item{extweight80}{Jackknife replicate weight 80 of 100.}
#'   \item{extweight81}{Jackknife replicate weight 81 of 100.}
#'   \item{extweight82}{Jackknife replicate weight 82 of 100.}
#'   \item{extweight83}{Jackknife replicate weight 83 of 100.}
#'   \item{extweight84}{Jackknife replicate weight 84 of 100.}
#'   \item{extweight85}{Jackknife replicate weight 85 of 100.}
#'   \item{extweight86}{Jackknife replicate weight 86 of 100.}
#'   \item{extweight87}{Jackknife replicate weight 87 of 100.}
#'   \item{extweight88}{Jackknife replicate weight 88 of 100.}
#'   \item{extweight89}{Jackknife replicate weight 89 of 100.}
#'   \item{extweight90}{Jackknife replicate weight 90 of 100.}
#'   \item{extweight91}{Jackknife replicate weight 91 of 100.}
#'   \item{extweight92}{Jackknife replicate weight 92 of 100.}
#'   \item{extweight93}{Jackknife replicate weight 93 of 100.}
#'   \item{extweight94}{Jackknife replicate weight 94 of 100.}
#'   \item{extweight95}{Jackknife replicate weight 95 of 100.}
#'   \item{extweight96}{Jackknife replicate weight 96 of 100.}
#'   \item{extweight97}{Jackknife replicate weight 97 of 100.}
#'   \item{extweight98}{Jackknife replicate weight 98 of 100.}
#'   \item{extweight99}{Jackknife replicate weight 99 of 100.}
#'   \item{extweight100}{Jackknife replicate weight 100 of 100.}
#'   \item{qkey}{Unique respondent identifier.}
#'   \item{jewishcat}{Jewish identity category: `1` = Jews By Religion,
#'     `2` = Jews Of No Religion, `3` = Jewish Background,
#'     `4` = Jewish Affinity, `5` = Respondent Not Jewish In Any Way.}
#'   \item{finalmode}{Collection mode: `1` = Screener And Extended Survey
#'     Via Cawi, `2` = Screener And Extended Survey Via Teleform,
#'     `3` = Screener Via Cawi, Extended Survey Via Teleform.}
#'   \item{region}{Census region: `1` = Northeast, `2` = Midwest,
#'     `3` = South, `4` = West.}
#'   \item{sexask}{Sex: `1` = Male, `2` = Female, `99` = Not Answered.}
#'   \item{age4cat}{Age: `1` = 18-29, `2` = 30-49, `3` = 50-64, `4` = 65+;
#'     `999` = No Answer.}
#'   \item{educ4cat}{Education: `1` = High School Or Less,
#'     `2` = Some College, `3` = College Graduate, `4` = Postgrad Degree;
#'     `99` = No Answer.}
#'   \item{religmod}{Current religion (24 categories including Jewish
#'     subgroups and combinations).}
#'   \item{hisp}{Hispanic origin: `1` = Yes, `2` = No, `99` = Not Answered.}
#'   \item{racecmb}{Race (5 categories).}
#'   \item{racethn}{Race-ethnicity (4 categories).}
#'   \item{presapp}{Presidential approval (Trump): `1` = Strongly Approve,
#'     `2` = Somewhat Approve, `3` = Somewhat Disapprove,
#'     `4` = Strongly Disapprove, `99` = Not Answered.}
#'   \item{track}{Right track/wrong track:
#'     `1` = Generally Headed In The Right Direction,
#'     `2` = Off On The Wrong Track, `99` = Not Answered.}
#'   \item{satisfpersmod}{Personal life satisfaction: `1` = Excellent,
#'     `2` = Good, `3` = Only Fair, `4` = Poor, `99` = Not Answered.}
#'   \item{localrating}{Community as a place to live: `1` = Excellent,
#'     `2` = Good, `3` = Only Fair, `4` = Poor, `99` = Not Answered.}
#'   \item{relconsider_a}{Jewish. Battery 1: religious identity
#'     (select-all-that-apply). See Details for question text.}
#'   \item{relconsider_b}{Catholic. Battery 1: religious identity.}
#'   \item{relconsider_c}{Mormon. Battery 1: religious identity.}
#'   \item{relconsider_d}{Muslim. Battery 1: religious identity.}
#'   \item{relraised_a}{Jewish. Battery 2: religious background
#'     (select-all-that-apply). See Details for question text.}
#'   \item{relraised_b}{Catholic. Battery 2: religious background.}
#'   \item{relraised_c}{Mormon. Battery 2: religious background.}
#'   \item{relraised_d}{Muslim. Battery 2: religious background.}
#'   \item{discrim_a}{Evangelical Christians. Battery 3: discrimination
#'     perceptions (rating scale). See Details for question text.}
#'   \item{discrim_b}{Muslims. Battery 3: discrimination perceptions.}
#'   \item{discrim_c}{Jews. Battery 3: discrimination perceptions.}
#'   \item{discrim_d}{Blacks. Battery 3: discrimination perceptions.}
#'   \item{discrim_e}{Hispanics. Battery 3: discrimination perceptions.}
#'   \item{discrim_f}{Gays and lesbians. Battery 3: discrimination
#'     perceptions.}
#' }
#'
#' @details
#' **Survey design:** Jackknife replication — use `surveycore::as_survey_replicate()`
#' with all 100 replicate weights:
#'
#' ```r
#' svy <- surveycore::as_survey_replicate(
#'   pew_jewish_2020,
#'   weights    = extweight,
#'   repweights = extweight1:extweight100,
#'   type       = "JK1"
#' )
#' ```
#'
#' **Jewish identity classification:** The `jewishcat` variable classifies
#' respondents into five mutually exclusive categories used in the published
#' Pew report. Use `jewishcat` rather than constructing your own
#' classification from the raw religion variables.
#'
#' **Battery question stems:**
#'
#' - **Battery 1** (`relconsider_a`–`relconsider_d`): `"ASIDE from religion,
#'   do you consider yourself to be any of the following in any way (for
#'   example ethnically, culturally or because of your family's background)?"`
#'   Values: `1` = Yes, Consider Myself This, `2` = No, Do Not Consider
#'   Myself This, `99` = Refused.
#' - **Battery 2** (`relraised_a`–`relraised_d`): `"Please indicate whether
#'   you were raised in any of the following traditions or had a parent from
#'   any of the following backgrounds."` Values: `1` = Yes, Was Raised In
#'   This Tradition Or Had A Parent From This Background, `2` = No, Was Not
#'   Raised In This Tradition And Did Not Have A Parent From This Background,
#'   `99` = Refused.
#' - **Battery 3** (`discrim_a`–`discrim_f`): `"Please tell us how much
#'   discrimination there is against each of these groups in our society
#'   today."` Values: `1` = A Lot, `2` = Some, `3` = Not Much,
#'   `4` = None At All, `99` = Not Answered.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original Stata file. The three battery variable groups additionally carry a
#' `"question_preface"` attribute with the shared question stem. All three
#' attribute types are automatically extracted into surveycore's metadata
#' system when you call `surveycore::as_survey_replicate()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column — for battery items this is the unique item text (e.g.,
#'   `"Jewish"`). Example: `attr(pew_jewish_2020$relconsider_a, "label")`
#'   returns `"Jewish"`.
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning. Example:
#'   `attr(pew_jewish_2020$relconsider_a, "labels")` returns
#'   `c("Yes, Consider Myself This" = 1, "No, Do Not Consider Myself This" = 2,
#'   Refused = 99)`.
#' - **Question preface** (`"question_preface"` attribute): The shared question
#'   stem for each battery group. Example:
#'   `attr(pew_jewish_2020$discrim_a, "question_preface")` returns
#'   `"Please tell us how much discrimination there is against each of these
#'   groups in our society today."`.
#'
#' @source
#' Pew Research Center. Jewish Americans in 2020 (Extended Dataset).
#' \url{https://www.pewresearch.org/datasets/} (free account required to
#' download raw data; the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-pew-jewish-2020.R`.
#'
#' @examples
#' # Design variables
#' head(pew_jewish_2020[, c("qkey", "extweight", "jewishcat")])
#'
#' # Confirm 100 replicate weights are present
#' sum(grepl("^extweight[0-9]", names(pew_jewish_2020)))
#'
#' # Inspect variable label (unique item text for battery variable)
#' attr(pew_jewish_2020$discrim_a, "label")
#'
#' # Inspect value labels
#' attr(pew_jewish_2020$discrim_a, "labels")
#'
#' # Inspect question preface (shared stem across the battery)
#' attr(pew_jewish_2020$discrim_a, "question_preface")
#'
#' # Jewish identity distribution (use jewishcat, not raw religion vars)
#' table(pew_jewish_2020$jewishcat)
"pew_jewish_2020"


#' Nationscape Wave 1: July 18, 2019
#'
#' The first weekly wave of the Democracy Fund + UCLA Nationscape survey,
#' fielded July 18–24, 2019. Approximately 6,250 completed online interviews
#' drawn from the Lucid respondent exchange platform using a non-probability
#' quota design, with raking weights calibrated to ACS demographic targets
#' and 2016 presidential vote choice.
#'
#' @details
#' This dataset is the first of 77 weekly waves collected from July 2019
#' through January 2021. The full survey ran in three phases:
#'
#' | Phase | Weeks | Dates | Approx. N |
#' |-------|-------|-------|-----------|
#' | Phase 1 | 1–24 | Jul 18, 2019 – Dec 26, 2019 | 150,000 |
#' | Phase 2 | 25–50 | Jan 2, 2020 – Jun 25, 2020 | 162,500 |
#' | Phase 3 | 51–77 | Jul 2, 2020 – Jan 12, 2021 | 168,750 |
#'
#' Only Wave 1 is bundled in the package because 77 waves × ~6,250 rows
#' would be prohibitively large. To obtain the full dataset by phase, use the
#' prepare scripts in `data-raw/` (see the Source section).
#'
#' **Survey design:**
#' The Nationscape is a calibrated non-probability sample (quota design with
#' raking weights). Use [surveycore::as_survey_nonprob()] — it is designed
#' specifically for this use case:
#'
#' ```r
#' svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#' ```
#'
#' **Metadata:**
#' All substantive columns carry variable labels (`"label"` attribute) set
#' during data preparation. Battery items additionally carry a
#' `"question_preface"` attribute with the shared question stem. Value
#' labels (`"labels"` attribute) are present for all coded response items.
#'
#' **Battery structure:**
#' Most multi-item question groups follow a `{battery}_{item}` naming
#' convention. All items within a battery share an identical
#' `"question_preface"` attribute:
#'
#' | Battery prefix | Preface summary | N items |
#' |----------------|-----------------|---------|
#' | `news_sources_*` | News sources used in past week | 13 |
#' | `group_favorability_*` | Favorability toward named groups | 13 |
#' | `cand_favorability_*` | Favorability toward named candidates | 9 |
#' | `trump_*` | Trump head-to-head matchups | 10 |
#' | `pence_*` | Pence head-to-head matchups | 5 |
#' | `cand_truth_*` | Whether each candidate tells the truth | 6 |
#' | `cand_facts_*` | Whether each candidate relies on facts | 6 |
#' | `racial_attitudes_*` | Agree/disagree racial attitude items | 4 |
#' | `gender_attitudes_*` | Agree/disagree gender attitude items | 4 |
#' | `discrimination_*` | Perceived discrimination by group | 6 |
#'
#' @format A data frame with approximately 6,250 rows and 171 columns
#' (170 survey variables plus `wave_id` added by the prepare script).
#' Run `names(ns_wave1)` for the complete column list. Key columns:
#'
#' - `response_id` — Unique respondent ID (integer)
#' - `start_date` — Interview date (character, `"YYYY-MM-DD"` format)
#' - `wave_id` — Wave identifier: `"ns20190718"` for all rows in this dataset
#' - `weight` — Raking weight calibrated to ACS demographic targets and
#'   2016 presidential vote choice; use for all population-level estimates
#' - `right_track` — Country direction: `1` = Right direction,
#'   `2` = Wrong track, `3` = Not sure
#' - `economy_better` — Economy outlook: `1` = Better, `2` = Worse,
#'   `3` = Same, `4` = Not sure
#' - `interest` — Political interest (4-pt): `1` = Very interested,
#'   `4` = Not at all interested
#' - `registration` — Voter registration: `1` = Registered,
#'   `2` = Not registered, `3` = Not eligible
#' - `pres_approval` — Trump presidential approval: `1` = Strongly approve,
#'   `2` = Somewhat approve, `3` = Somewhat disapprove,
#'   `4` = Strongly disapprove
#' - `vote_intention` — 2020 vote intention: `1` = Trump,
#'   `2` = Democratic candidate, `3` = Other, `4` = Don't plan to vote,
#'   `5` = Not sure
#' - `vote_2016` — 2016 presidential vote (see labels)
#' - `pid3` — 3-category party ID: `1` = Democrat, `2` = Republican,
#'   `3` = Independent, `4` = Something else
#' - `pid7_legacy` — 7-point party ID (legacy coding; see labels)
#' - `ideo5` — 5-point ideological self-placement: `1` = Very liberal,
#'   `5` = Very conservative
#' - `age` — Respondent age in years
#' - `gender` — Gender: `1` = Male, `2` = Female, `3` = Other
#' - `census_region` — Census region: `1` = Northeast, `2` = Midwest,
#'   `3` = South, `4` = West
#' - `hispanic` — Hispanic or Latino origin: `1` = Yes, `2` = No
#' - `race_ethnicity` — Race/ethnicity (6 categories; see labels)
#' - `household_income` — Household income (7 brackets; see labels)
#' - `education` — Educational attainment (6 categories; see labels)
#' - `state` — U.S. state of residence (2-letter abbreviation)
#'
#' @source
#' Democracy Fund Voter Study Group / UCLA. Nationscape Data Set, version
#' December 2021. \url{https://www.voterstudygroup.org/data/nationscape}
#' (free download; academic research use). Prepared by
#' `data-raw/prepare-nationscape-phase1.R`.
#'
#' For full methodology, see the Nationscape User Guide and the
#' Representative Assessment report in
#' `data-raw/nationscape/phase_1_v20210301/ns20190718/`.
#'
#' @references
#' Tausanovitch, Chris and Lynn Vavreck. 2021. Democracy Fund + UCLA
#' Nationscape, October 10–17, 2019 (version 20210301). Retrieved from
#' voterstudygroup.org/data/nationscape.
#'
#' @examples
#' # Design variables
#' head(ns_wave1[, c("response_id", "weight", "age", "gender")])
#'
#' # Inspect a battery item's metadata
#' attr(ns_wave1$group_favorability_blacks, "label")
#' attr(ns_wave1$group_favorability_blacks, "question_preface")
#' attr(ns_wave1$news_sources_cnn, "labels")
#'
#' # Create a calibrated survey design
#' svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#'
#' # Party identification distribution
#' table(ns_wave1$pid3)
"ns_wave1"
