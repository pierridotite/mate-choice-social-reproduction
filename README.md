# mate-choice-social-reproduction

**To what extent does partner choice follow a logic of social reproduction?**

R analysis and Shiny app on the Columbia speed dating experiment (Fisman et al., 2006), enriched with
US Census income and inequality data from participants' childhood ZIP codes.

Data science project, M2 Data Science, L'Institut Agro Montpellier (2026–2027).

> **Status: analysis done, app in progress.** The analysis is written up in three documents:
> [exploration.md](exploration.md), [modeles.md](modeles.md) and [robustesse.md](robustesse.md). The
> Shiny app has its data exploration part; the model results part and the slides are still to come.

## Research question

Social reproduction cannot be observed directly. We test one of its mechanisms, **socio-economic
homophily**: are people more likely to say yes to someone who grew up in a similar neighbourhood?

| | Hypothesis |
|---|---|
| **H1** | The larger the socio-economic gap between two people, the less likely they are to say yes. |
| **H2** | The effect holds once attractiveness, race, age and field of study are controlled for. |
| **H3** | The effect differs by gender and by social background. |

The experiment is well suited to the question: within each event, who meets whom is close to random,
so observed choices can be compared with what chance alone would produce.

## Data

| | |
|---|---|
| **Speed dating** | Fisman, Iyengar, Kamenica & Simonson (2006): 551 Columbia graduate students, 8,378 four-minute dates, 2002–2004 |
| **Enrichment** | Median household income, Gini index and population of each participant's childhood ZIP code (US Census, ACS 2017–2021) |
| **Coverage** | 395 of 551 participants matched to a Census area; 4,450 dates with data for both partners |

One row of `data/speed_dating_census.csv` is one *oriented* date (`iid` rates `pid`), so each meeting
appears twice. Full documentation, method and limitations: [data/README.md](data/README.md).

The enriched dataset is also published on Kaggle:
[pierridotite/speed-dating-census-income-gini](https://www.kaggle.com/datasets/pierridotite/speed-dating-census-income-gini).

## Repository structure

```
├── R/                  analysis scripts, run in order
│   ├── commun.R                shared chart theme, formats and labels (used by 02 to 05 and the app)
│   ├── 01_jointure_census.R    builds data/ from data-raw/
│   ├── 02_exploration.R        exploratory figures -> outputs/exploration/
│   ├── 03_preparation.R        analysis dataset -> outputs/dates.rds, participants.rds
│   ├── 04_modeles.R            mixed logistic models -> outputs/modeles.rds, outputs/modeles/
│   └── 05_robustesse.R         robustness checks -> outputs/robustesse.rds, outputs/robustesse/
├── exploration.md      exploratory data analysis (in French), figures and commentary
├── modeles.md          models and answer to the research question (in French)
├── robustesse.md       robustness checks (in French)
├── data-raw/           raw inputs (Census .dat files are not versioned, see data-raw/README.md)
├── data/               enriched dataset + its documentation
├── outputs/            figures and pre-computed results (.rds) loaded by the app
├── app/                Shiny app (global.R, ui.R, server.R)
│   ├── fonctions/      data preparation, variable dictionary and chart functions
│   └── www/            stylesheet
├── slides/             defence slides
└── kaggle/             Kaggle dataset description and metadata
```

Scripts compute, the app displays: models are fitted offline and saved to `outputs/`, so the app only
loads results and stays responsive.

### Scripts

| Script | Role | Status |
|---|---|---|
| `01_jointure_census.R` | ZIP cleaning and join with Census tables | done |
| `02_exploration.R` | Structure, missing data, key variables, first look at the social gap; written up in [exploration.md](exploration.md) | done |
| `03_preparation.R` | Derived variables (signed and absolute social gap, age gap, same field, income terciles), analysis sample of 4,424 dates, robustness sample of 4,128 | done |
| `04_modeles.R` | Mixed-effects logistic regressions on `dec`, random effects for rater and partner, nested models M1–M4, written up in [modeles.md](modeles.md) | done |
| `05_robustesse.R` | M2 refitted changing one choice at a time (sample, income 2000, Gini gap, same income tercile) and test of the preference for partners from affluent areas, written up in [robustesse.md](robustesse.md) | done |

### App

| Part | Content | Status |
|---|---|---|
| **1. Discover the data** | Five interactive charts that summarise the dataset, one per block of columns, each with a "key points" box: the structure of an event (one grid showing every meeting and its outcome), the participants (profile, attitudes, interests by gender, or two of them crossed), stated preferences (by question and time), what makes people say yes (rate of yes by rating, or a 3D surface for two ratings at once), and data reliability (missing values by event and collection time) | done |
| **2. Predict a match** | Two logistic regressions, one per gender, estimate the probability that each person says yes from both profiles, the gap between their childhood neighbourhoods' income and, after the meeting, the ratings they give each other; the match probability is the product. Criteria are set by hand (social background as a bracket of childhood neighbourhood income) or loaded from a real couple. The research question is read on the starred bar of the multipliers chart: the income gap multiplies the odds of yes by 0.94 (women) and 0.99 (men) per doubling, both intervals contain 1, and adding it leaves the match AUC unchanged (0.846). Fitted on the analysis sample, cross-validated by event | done |
| **3. Model results** | Social gap across models, other similarities, predicted probabilities, robustness | planned |

Launch it from the repository root, after `R/03_preparation.R`:

```r
shiny::runApp("app")
```

## Reproducing

Developed with R 4.6.1. Required packages: `tidyverse`, `patchwork`, `lme4` for the analysis, plus
`shiny`, `bslib`, `plotly` and `DT` for the app.

```r
install.packages(c("tidyverse", "patchwork", "lme4", "shiny", "bslib", "plotly", "DT"))
```

All paths are relative to the repository root. Open `mate-choice-social-reproduction.Rproj` in RStudio,
or run from the root, in this order:

```bash
Rscript R/01_jointure_census.R   # optional: needs the raw Census tables
Rscript R/02_exploration.R
Rscript R/03_preparation.R
Rscript R/04_modeles.R           # about 2 minutes
Rscript R/05_robustesse.R        # about 2 minutes
```

The first step needs the raw Census tables, see [data-raw/README.md](data-raw/README.md). It can be
skipped: `data/` is versioned. Rerunning it reproduces the files of `data/` exactly.

## Authors

- Pierre Raffalli ([@pierridotite](https://github.com/pierridotite))

## Sources

- Fisman, R., Iyengar, S. S., Kamenica, E., & Simonson, I. (2006). Gender Differences in Mate
  Selection: Evidence From a Speed Dating Experiment. *Quarterly Journal of Economics*, 121(2), 673–697.
  Data distributed by Columbia University:
  http://www.stat.columbia.edu/~gelman/arm/examples/speed.dating/
- US Census Bureau, American Community Survey 5-year estimates 2017–2021, tables B19013, B19083, B01003.

Census data are public domain. The speed dating data belong to their original authors.
