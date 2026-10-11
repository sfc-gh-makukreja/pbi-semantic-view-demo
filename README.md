# From Power BI to a Snowflake Semantic View

**Hands-on lab · NZ SI Partner HOL · Demo 4**

You already have business logic in Power BI: measures, relationships, a data model your customers trust.
In this lab you bring that logic into Snowflake as a **semantic view**, so the same definitions power
Power BI, Cortex Analyst and AI agents, with no re-keying.

```
 Tasty Bytes data ──► star schema (dynamic tables) ──► Power BI template (.pbit)
                                                              │
                                              Semantic View Autopilot
                                                              ▼
                              Snowflake semantic view ──► SQL · Cortex Analyst · Power BI
```

## What you will do

| # | Step | You end up with |
|---|------|-----------------|
| 1 | Build the data foundation | Tasty Bytes star schema in `TB_PBI_DEMO.POWERBI` |
| 2 | Verify it | 7 checks, all `PASS` |
| 3 | Prepare the Power BI template | A `.pbit` bound to *your* account |
| 4 | Import it with Semantic View Autopilot | A semantic view generated from the Power BI model |
| 5 | Review what converted | Which measures made it, which did not, and why |
| 6 | Query the semantic view | Governed metrics from plain SQL |
| 7 | Ask it questions in natural language | Cortex Analyst on top of your Power BI logic |
| 8 | Reconnect Power BI to Snowflake | Power BI reading the semantic view |
| 9 | Clean up | Everything removed |

Steps 1-7 work on any laptop. **Power BI Desktop runs on Windows only**, so Mac users can do everything
except step 8.

## Prerequisites

- A Snowflake account where you can use `ACCOUNTADMIN` (a trial account is fine: <https://tinyurl.com/spn-hol>).
- Python 3 (only for step 3, standard library only).
- Optional: Power BI Desktop (Windows) for step 8 and for the manual route in step 3.

## Where the data comes from

The Tasty Bytes sample data lives in a **public Snowflake bucket**, `s3://sfquickstarts/frostbyte_tastybytes/`.
Nothing to download or upload: `sql/01_setup.sql` creates a stage pointing at it and loads from there.
The lab loads **trucks 1-30 only** (about 4.7M orders, 2019-2022) so it builds quickly; the full data set is
about 900M rows.

> The Tasty Bytes model and Power BI template come from the Snowflake quickstart
> [End-to-End Analytics with Snowflake and Power BI](https://github.com/Snowflake-Labs/sfguide-end-to-end-analytics-with-snowflake-and-power-bi).

## Repo layout

```
sql/01_setup.sql              database, warehouse, stage, raw data (filtered load)
sql/02_star_schema.sql        date/time dimensions + dynamic tables (the model Power BI reads)
sql/03_roles_and_stage.sql    least-privilege analyst role + stage for the template upload
sql/04_verify.sql             checks that everything is right
sql/99_teardown.sql           removes everything
powerbi/Tasty Bytes Direct Query Quickstart.pbit    the Power BI template (parameters blank)
scripts/bind_pbit.py          fills in the template's connection parameters
docs/images/                  screenshots used in this guide
```

Objects created: database `TB_PBI_DEMO`, warehouse `TB_PBI_WH`, role `TB_PBI_ANALYST`. Nothing else in
your account is touched.

---

## Step 1 - Build the data foundation

Open a Snowsight SQL worksheet (or Cortex Code) and run these three files **in order**, each one fully
before the next:

1. `sql/01_setup.sql`
2. `sql/02_star_schema.sql`
3. `sql/03_roles_and_stage.sql`

Steps 1 and 2 take several minutes because they load and transform millions of rows on an XL warehouse.
`02_star_schema.sql` scales the warehouse back to XSMALL when it finishes.

**Check:** the last statement of each file returns a `step N complete` row.

## Step 2 - Verify

Run `sql/04_verify.sql`. Part A returns seven rows; every `RESULT` must be `PASS`:

| Check | Why it matters |
|-------|----------------|
| Raw headers / lines loaded | The filtered load worked |
| Fact lines = raw lines | The star schema joins lost no rows |
| Dimensions populated | Dynamic tables refreshed |
| More than one year of data | Year-over-year measures need history |

Part B switches to `TB_PBI_ANALYST` and shows the role can read the star schema but **not** the raw
tables. That second query is supposed to fail with `Schema ... does not exist or not authorized`, and
that error is the pass.

> **Gotcha:** run `USE SECONDARY ROLES NONE` before testing a role. If your other roles stay active,
> the test passes even when the role is wrong.

## Step 3 - Prepare the Power BI template

The template ships with its five Snowflake connection parameters empty. If you upload it as is,
Autopilot drops every table (`UNBOUND_PARAMETERS`). Fill them in with **one** of these routes.

### Route A - script (no Power BI needed)

Use your own account host. Take the org and account name from `SELECT CURRENT_ORGANIZATION_NAME(),
CURRENT_ACCOUNT_NAME();` and turn underscores into hyphens.

```bash
python3 scripts/bind_pbit.py --server <org>-<account>.snowflakecomputing.com
```

This writes `powerbi/TastyBytes_bound.pbit`. The script changes only the five parameter values; the
tables, relationships and measures are untouched.

### Route B - Power BI Desktop (Windows)

1. Open `Tasty Bytes Direct Query Quickstart.pbit`.
2. Enter Server = `<org>-<account>.snowflakecomputing.com`, Warehouse = `TB_PBI_WH`,
   Role = `TB_PBI_ANALYST`, Database = `TB_PBI_DEMO`, Schema = `POWERBI`.
3. Sign in to Snowflake when asked and let the report load.
4. **File > Export > Power BI template** and save it.

### Check it works (Windows)

Open the bound `.pbit` in Power BI Desktop and sign in to Snowflake (key-pair authentication works). You
should see the **Order Summary** page, and the headline numbers must match Snowflake exactly:

| Card | Value |
|------|-------|
| Order Line Count | 12,738,517 |
| Order Count | 4,656,869 |
| Order Amt | $187,563,644 |
| Order Qty | 19,317,939 |

![Order Summary dashboard in Power BI Desktop, DirectQuery against Snowflake](docs/images/01-powerbi-order-summary-dashboard.png)

This is the model Autopilot will read. Switch to **Model view** (left rail) to see it: 10 tables, **7 measures**,
**18 relationships** and the **5 expressions** that hold the connection parameters. The three
time-intelligence measures (`Order Amt YTD`, `Order Amt PYTD`, `YoY Order Amt Growth`) are the ones that will not
convert in step 5.

![Model view: tables, 7 measures, 18 relationships and the 5 Snowflake parameters](docs/images/02-powerbi-model-view.png)

> **Why only Denver and San Mateo?** The lab loads trucks 1-30 to keep the build fast, and those trucks only
> operate in two cities, both in North America. The APAC and EMEA slicers will therefore show no data. The
> full data set covers many more cities.

## Step 4 - Import it with Semantic View Autopilot

1. In Snowsight, switch to role **`TB_PBI_ANALYST`**.
2. Go to **Workspaces > Add new > Semantic View**.
3. Location: database `TB_PBI_DEMO`, schema `SEMANTIC`. Name it `TASTY_BYTES_SV`.
4. When asked for context, choose **Upload Power BI file** and select your bound `.pbit`.
   The upload stage is `TB_PBI_DEMO.SEMANTIC.PBI_FILES`.
5. Select the tables from `TB_PBI_DEMO.POWERBI` (all ten), then **Create and save**.

Wait for generation to finish. When it does, you have a semantic view built from your Power BI model.

## Step 5 - Review what converted

Autopilot lists anything it could not convert, grouped by cause. Expect this for the template:

| Power BI measure | DAX | Expected |
|------------------|-----|----------|
| Order Count | `DISTINCTCOUNT(...)` | converts |
| Order Line Count | `COUNTROWS(...)` | converts |
| Order Amt | `SUM(...)` | converts |
| Order Qty | `SUM(...)` | converts |
| Order Amt YTD | `TOTALYTD(...)` | **not converted** (time intelligence) |
| Order Amt PYTD | `SAMEPERIODLASTYEAR` | **not converted** (time intelligence) |
| YoY Order Amt Growth | built on the two above | **not converted** |

This is the point of the exercise: **DAX time intelligence has no direct SQL equivalent**, so migrating a
model means deciding what to rebuild by hand. Open **Semantic Studio** and try asking CoCo to add a
year-to-date metric to the view.

Per the [Power BI ingestion docs](https://docs.snowflake.com/en/user-guide/views-semantic/power-bi-ingestion),
also unsupported: `SELECTEDVALUE`, `ALLSELECTED`, statistical aggregates (`MEDIAN`, `STDEV`),
`RELATEDTABLE`, calculated tables and measures stored in the report layer instead of the data model.

## Step 6 - Query the semantic view with SQL

Metrics are queried with `AGG()`; dimensions go in `GROUP BY`. Use the names Autopilot generated (see
`SHOW SEMANTIC METRICS IN TB_PBI_DEMO.SEMANTIC.TASTY_BYTES_SV;` and `SHOW SEMANTIC DIMENSIONS IN ...`):

```sql
USE ROLE TB_PBI_ANALYST;
USE SECONDARY ROLES NONE;
USE WAREHOUSE TB_PBI_WH;

SELECT <a dimension>, AGG(<a metric>)
FROM TB_PBI_DEMO.SEMANTIC.TASTY_BYTES_SV
GROUP BY <a dimension>;
```

**Check your answer:** total sales across all years must equal **187,563,644** (the sum of
`DT_FACT_ORDER_DETAIL.line_total`). Yearly sales are 7,413,440.50 (2019), 25,329,368.00 (2020),
72,485,093.50 (2021) and 82,335,742.00 (2022). If the semantic view disagrees with these, a relationship or
metric was converted wrongly: compare against `04_verify.sql`.

## Step 7 - Ask it in natural language

Open the semantic view in Snowsight and ask Cortex Analyst, for example:

- *"What were total sales by year?"*
- *"Which truck brand sold the most units in 2022?"*
- *"How many orders did we take per country?"*

Answers come from the metric definitions you brought across from Power BI, not from ad-hoc SQL.

## Step 8 - Reconnect Power BI to Snowflake (Windows)

Power BI Desktop > **Get data > Snowflake**, then enter the same server and warehouse and set the role
to `TB_PBI_ANALYST`. Under **Advanced options**, run a SQL statement against the semantic view, for
example:

```sql
SELECT <dimension>, AGG(<metric>) AS value
FROM TB_PBI_DEMO.SEMANTIC.TASTY_BYTES_SV
GROUP BY <dimension>
```

The point to land: the report now reads governed metrics defined once in Snowflake.

## Step 9 - Clean up

Run `sql/99_teardown.sql`. It drops `TB_PBI_DEMO`, `TB_PBI_WH` and `TB_PBI_ANALYST`, including any
semantic views you created inside the database.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Autopilot says `UNBOUND_PARAMETERS` or finds no tables | The template's parameters are still empty. Redo step 3 |
| Autopilot cannot see tables | You are not on `TB_PBI_ANALYST`, or `03_roles_and_stage.sql` did not finish |
| A verify check shows `FAIL` | Re-run the file named in the message |
| `Schema ... does not exist or not authorized` in step 6 | Expected for `RAW_POS`; for `POWERBI`/`SEMANTIC`, re-run step 1 part 3 |
| Role test passes when it should fail | Run `USE SECONDARY ROLES NONE` first |
| Power BI cannot connect | Check the server host (hyphens, not underscores) and that you sign in as a user holding `TB_PBI_ANALYST` |

## Test status of this guide

| Step | Status |
|------|--------|
| 1 Data foundation | Tested: counts match the source data exactly |
| 2 Verify | Tested: 7/7 PASS, role boundary confirmed |
| 3 Bind template | Tested: only 5 parameter values differ from the original; opens in Power BI Desktop, connects (key-pair auth) and totals match Snowflake exactly |
| 4 Autopilot import | **Not yet run** |
| 5 Conversion review | **Expectations from the docs, not yet observed** |
| 6 Query | **Pending step 4**; reference totals are verified |
| 7 Natural language | **Pending step 4** |
| 8 Power BI reconnect | **Not yet run**; method needs validating |
