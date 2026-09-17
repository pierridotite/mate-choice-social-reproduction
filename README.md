# mate-choice-social-reproduction

**To what extent does partner choice follow a logic of social reproduction?**

R analysis and Shiny app on the Columbia speed dating experiment (Fisman et al., 2006), enriched with
US Census income and inequality data from participants' childhood ZIP codes.

Data science project, M2 Data Science, L'Institut Agro Montpellier (2026–2027).

> **Status: exploration.** The dataset is built and documented, and a first exploratory analysis is in
> [exploration.md](exploration.md). The models, the Shiny app and the slides are not written yet; the
> sections below describe the planned structure.

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
│   ├── 01_jointure_census.R    builds data/ from data-raw/
│   └── 02_exploration.R        exploratory figures
├── exploration.md      exploratory data analysis (in French), figures and commentary
├── data-raw/           raw inputs (Census .dat files are not versioned, see data-raw/README.md)
├── data/               enriched dataset + its documentation
├── outputs/            figures (exploration/) and pre-computed results (.rds) loaded by the app
├── app/                Shiny app
│   ├── modules/        one module per tab
│   └── www/            static assets
├── slides/             defence slides
└── kaggle/             Kaggle dataset description and metadata
```

Scripts compute, the app displays: models are fitted offline and saved to `outputs/`, so the app only
loads results and stays responsive.

### Planned scripts

| Script | Role | Status |
|---|---|---|
| `01_jointure_census.R` | ZIP cleaning and join with Census tables | done |
| `02_exploration.R` | Structure, missing data, key variables, first look at the social gap; written up in [exploration.md](exploration.md) | done |
| `03_preparation.R` | Derived variables, analysis sample | planned |
| `04_modeles.R` | Mixed-effects logistic regressions on `dec`, random effects for rater and partner, nested models M1–M4 | planned |
| `05_robustesse.R` | Income 2000 instead of 2021, within-event permutation test, noisy ZIP areas excluded, signed gap | planned |

### Planned app

| Part | Tabs |
|---|---|
| **1. Interactive descriptive analysis** | The data · The participants · Who says yes? · Social homophily |
| **2. In-depth analysis** | Models · Simulator · Robustness |

## Reproducing

All paths are relative to the repository root. Open `mate-choice-social-reproduction.Rproj` in RStudio,
or run from the root:

```bash
Rscript R/01_jointure_census.R
```

This step needs the raw Census tables, see [data-raw/README.md](data-raw/README.md). It can be skipped:
`data/` is versioned.

## Authors

- Pierre Raffalli ([@pierridotite](https://github.com/pierridotite))

## Sources

- Fisman, R., Iyengar, S. S., Kamenica, E., & Simonson, I. (2006). Gender Differences in Mate
  Selection: Evidence From a Speed Dating Experiment. *Quarterly Journal of Economics*, 121(2), 673–697.
  Data distributed by Columbia University:
  http://www.stat.columbia.edu/~gelman/arm/examples/speed.dating/
- US Census Bureau, American Community Survey 5-year estimates 2017–2021, tables B19013, B19083, B01003.

Census data are public domain. The speed dating data belong to their original authors.
