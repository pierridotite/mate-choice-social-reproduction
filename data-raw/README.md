# Raw data

Inputs of `R/01_jointure_census.R`. Nothing in this folder is edited by hand.

| File | In git | Source |
|---|---|---|
| `speed_dating.csv` | yes | Fisman et al. (2006), distributed by Columbia University: http://www.stat.columbia.edu/~gelman/arm/examples/speed.dating/Speed%20Dating%20Data.csv |
| `acs_b19013.dat` | no (18 MB) | ACS 5-year 2017–2021, table B19013, median household income |
| `acs_b19083.dat` | no (10 MB) | ACS 5-year 2017–2021, table B19083, Gini index |
| `acs_b01003.dat` | no (18 MB) | ACS 5-year 2017–2021, table B01003, total population |

## Getting the Census tables

The `.dat` files are not versioned. They are only needed to rebuild `data/` from scratch; the enriched
files in `data/` are versioned, so the analysis and the app run without them.

Download the three tables from the Census Bureau table-based summary file:

https://www2.census.gov/programs-surveys/acs/summary_file/2021/table-based-SF/data/5YRData/

| Download | Save as |
|---|---|
| `acsdt5y2021-b19013.dat` | `data-raw/acs_b19013.dat` |
| `acsdt5y2021-b19083.dat` | `data-raw/acs_b19083.dat` |
| `acsdt5y2021-b01003.dat` | `data-raw/acs_b01003.dat` |
