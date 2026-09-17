## Does where you grew up decide who you click with?

In 2002–2004, researchers at Columbia University ran speed dating events where hundreds of graduate students met for four minutes each, then said **yes or no** to seeing each other again. The resulting data (Fisman, Iyengar, Kamenica & Simonson, *Quarterly Journal of Economics*, 2006) became a classic: men weighted physical attractiveness more, women weighted intelligence and race more, and women preferred men who grew up in **affluent ZIP codes**.

But the original data only tell us that a ZIP code is "rich" through a single income figure. This dataset goes further by attaching **objective neighbourhood indicators from the US Census Bureau** to the childhood ZIP code of every participant *and* of their partner, so that each speed date carries a measure of the **socio-economic distance** between the two people sitting at the table.

### What's new compared with the original Speed Dating dataset

- **Gini index** of the childhood neighbourhood, a measure of local income inequality that isn't in the original data
- **Median household income** of the neighbourhood (ACS 2017–2021), with margins of error
- **Neighbourhood population**, to spot small, noisy areas
- The same variables **for the partner** (`_o` suffix, as in the original data)
- **Ready-made distance variables**: income gap, log-income gap and Gini gap, signed and absolute
- **Cleaned ZIP codes**: the original stored them as numbers, so `06268` had become `"6,268"`

### Questions you can explore

- **Socio-economic homophily**: are matches more likely when two people grew up in similar neighbourhoods?
- Do partners' ratings of each other's attractiveness or intelligence absorb the effect of background, or does background still matter once ratings are controlled for?
- Is the "affluent background" premium found by Fisman et al. about **wealth** or about **inequality**?
- Do men and women react differently to a partner from a richer or poorer neighbourhood than their own?
- Suggested models: mixed-effects logistic regression `match ~ abs_diff_gini_2021 + ratings + (1|iid) + (1|pid) + (1|wave)`

### Files

| File | Rows | Description |
|---|---|---|
| `speed_dating_census.csv` | 8,378 | One row per speed date (`iid` rates `pid`). All 195 original columns plus 22 new ones. Start here. |
| `participants_census.csv` | 551 | One row per participant, with cleaned ZIP code and neighbourhood indicators. |
| `census_acs2021_zcta.csv` | 33,774 | Lookup table covering every US ZIP Code Tabulation Area. |

### New columns

| Column | Meaning |
|---|---|
| `zip5`, `zip5_o` | Cleaned 5-digit childhood ZIP code (participant, partner) |
| `census_match`, `census_match_o` | Whether the ZIP code was found in the Census data |
| `income_2000` | Original `income` column converted to a number (2000 Census median income, from the authors) |
| `zip_median_income_2021` | Median household income of the ZIP area, 2021 dollars (ACS table B19013) |
| `zip_gini_2021` | Gini index of income inequality, 0 = perfect equality (ACS table B19083) |
| `zip_population_2021` | Population of the ZIP area (ACS table B01003) |
| `*_moe` | 90% margin of error published by the Census Bureau |
| `*_o` | Same variable for the partner |
| `diff_income_2021`, `abs_diff_income_2021` | Participant income minus partner income, and absolute gap |
| `diff_log_income_2021` | Gap in log income (relative difference) |
| `diff_gini_2021`, `abs_diff_gini_2021` | Participant Gini minus partner Gini, and absolute gap |

### Coverage

- 551 participants: 426 gave a US ZIP code, and **395** were matched to Census data.
- **4,450 of the 8,378 speed dates** have neighbourhood data for both partners.
- Participants who grew up abroad or left the ZIP code blank have empty Census columns.

### How it was built

1. ZIP codes were cleaned: non-digits removed, zeros restored on the left to 5 digits. Values `0`, empty or with fewer than 3 digits were treated as missing.
2. Census data come from the **American Community Survey 5-year estimates 2017–2021** (table-based summary files, ZCTA level). Census "not available" codes were set to missing.
3. ZIP codes were joined to ZCTAs (the Census Bureau's geographic version of ZIP codes).

The full, reproducible R script is included: `jointure_census.R`.

### Caveats

- **Time gap.** Participants grew up in the 1980s–90s, but the Census figures are from 2017–2021. The two income measures are strongly correlated (**r = 0.84**, n = 281), but some neighbourhoods have gentrified or declined since. Gaps and rankings between partners are more reliable than absolute dollar amounts.
- A ZIP code and a ZCTA are not always identical, and ZIP codes used only for PO boxes have no Census match.
- Small areas have wide margins of error: check the `_moe` columns.

### Sources and citation

- Fisman, R., Iyengar, S. S., Kamenica, E., & Simonson, I. (2006). *Gender Differences in Mate Selection: Evidence From a Speed Dating Experiment*. Quarterly Journal of Economics, 121(2), 673–697. Data distributed by Columbia University: http://www.stat.columbia.edu/~gelman/arm/examples/speed.dating/
- U.S. Census Bureau, American Community Survey 5-Year Estimates 2017–2021, tables B19013, B19083 and B01003: https://www2.census.gov/programs-surveys/acs/summary_file/2021/table-based-SF/

Census data are in the public domain. The speed dating data remain the work of their original authors: please cite Fisman et al. (2006) if you use this dataset.
