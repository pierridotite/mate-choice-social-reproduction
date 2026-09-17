# Speed Dating Experiment × US Census (Income & Gini)

This dataset enriches the **Speed Dating Experiment** data (Fisman, Iyengar, Kamenica & Simonson, 2006, *Quarterly Journal of Economics*, "Gender Differences in Mate Selection: Evidence From a Speed Dating Experiment") with **socio-economic indicators of each participant's childhood ZIP code**, taken from the US Census Bureau American Community Survey.

The goal is to study **socio-economic homophily**: does the gap between partners' neighbourhood of origin (median income, inequality) affect match probability, beyond the subjective ratings (attractiveness, intelligence, etc.)?

## Files

| File | Rows | Content |
|---|---|---|
| `speed_dating_census.csv` | 8,378 | One row per oriented speed date (`iid` rates `pid`). All 195 original columns + Census variables for the participant and the partner (`_o` suffix, same convention as the original data) + distances. |
| `participants_census.csv` | 551 | One row per participant (`iid`) with the cleaned ZIP code and Census variables. |
| `census_acs2021_zcta.csv` | 33,774 | Census variables for every US ZCTA (lookup table). |

## Added columns

| Column | Description |
|---|---|
| `zip5` / `zip5_o` | Cleaned 5-digit childhood ZIP code (participant / partner) |
| `census_match` / `census_match_o` | ZIP code found among Census ZCTAs |
| `income_2000` | Original `income` variable parsed as a number (median household income, 2000 Census, provided by the authors) |
| `zip_median_income_2021` (+ `_moe`, `_o`) | Median household income of the ZCTA, in 2021 dollars (table B19013) |
| `zip_gini_2021` (+ `_moe`, `_o`) | Gini index of income inequality of the ZCTA (table B19083) |
| `zip_population_2021` (+ `_moe`, `_o`) | Total population of the ZCTA (table B01003) |
| `diff_income_2021`, `abs_diff_income_2021` | Participant minus partner median income, and its absolute value |
| `diff_log_income_2021` | Difference in log median income |
| `diff_gini_2021`, `abs_diff_gini_2021` | Participant minus partner Gini, and its absolute value |

`_moe` = margin of error at 90% published by the Census Bureau.

## Coverage

- 551 participants, 426 with a usable ZIP code, **395 matched** to a Census ZCTA (394 with income, 395 with Gini).
- **4,450 speed dates** have the Gini index for both partners.
- Foreign participants and missing ZIP codes (`0` or empty in the original) have empty Census columns.

## Method

1. Original ZIP codes were stored as numbers (`"6,268"`, leading zeros lost). They were cleaned by removing non-digits and left-padding with zeros to 5 digits; values `0`, empty, or with fewer than 3 digits are treated as missing.
2. Census data: ACS 5-year estimates 2017–2021, *table-based summary files*, ZCTA geography (`860Z200US`). Negative Census codes (not available) are set to missing.
3. ZIP codes are joined directly on ZCTA codes (a ZCTA is the Census approximation of a ZIP code; PO-box-only ZIP codes have no ZCTA).

## Limitations

- **Time gap**: the experiment took place in 2002–2004 and participants grew up in the 1980s–90s, whereas the Census data are for 2017–2021. At ZIP level, the 2021 median income correlates at **r = 0.84** with the 2000 income provided by the authors (n = 281), but some neighbourhoods have gentrified or declined. Relative comparisons (gaps, ranks) are more robust than absolute levels.
- ZIP ≠ ZCTA exactly; a few ZIP codes are unmatched.
- Small ZCTAs have large margins of error (see `_moe` columns).

## Sources

- Speed dating data: Fisman et al. (2006), distributed by Columbia University — http://www.stat.columbia.edu/~gelman/arm/examples/speed.dating/
- US Census Bureau, American Community Survey 5-year 2017–2021, tables B19013, B19083, B01003 — https://www2.census.gov/programs-surveys/acs/summary_file/2021/table-based-SF/

Census data are public domain. The speed dating data belong to their original authors; please cite Fisman et al. (2006).
