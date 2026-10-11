# Before You Migrate a Real Model

The lab uses a small, clean model so every step works the first time. A customer's Power BI model rarely starts that way. This page is the short checklist to run through before you point Semantic View Autopilot at a real `.pbit` or `.pbix`.

Autopilot gives you a good **first draft**, not a finished model. The pattern that works is a hybrid: ingest the Power BI model to get a baseline, then refactor it into a governed Snowflake semantic view.

## 1. Clean the Power BI Model First

Before you export the file:

- Use a star schema where possible.
- Remove unused tables, columns, measures and relationships.
- Make sure table and column names map cleanly to Snowflake objects.
- Resolve duplicate or ambiguous relationships, and know the grain and key of every table.
- Separate reusable business measures from report-only calculations.
- Write down the fiscal-calendar and time-intelligence logic you expect.

## 2. Record a Baseline

Capture trusted results from the Power BI report for a handful of representative questions, such as revenue by month, top customers, a ratio, a distinct count and a time-intelligence figure. They become the reconciliation baseline. In this lab the baseline is the report's order amount by year, which Step 6 checks against the semantic view.

## 3. Classify What You Have

| Power BI element | Becomes | What to check |
|---|---|---|
| Table | Logical table | Source mapping and business grain |
| Column used to group or filter | Dimension | Description and synonyms |
| Date column | Time dimension | Calendar and fiscal interpretation |
| Numeric row-level value | Fact | Keep it at row level |
| Model measure | Metric | DAX filter context and aggregation |
| Calculated column | Dimension | Single-table only; review the expression |
| Relationship | Relationship | Keys, direction, cardinality |
| Report-level measure | Manual work | Move it into a governed metric |
| Time-intelligence measure | Manual work | Rebuild with explicit time logic |
| Row-level security | Snowflake policies and roles | Reimplement and test with the consumer role |

## 4. Review Before You Promote

After Autopilot generates the view, check the logical tables, primary keys, relationship direction, metric expressions, descriptions and the date logic. Rewrite any metric that is technically valid but does not express the enterprise definition clearly.

For each important measure, compare the DAX with the generated metric, test totals at more than one grain, check null and zero handling, and add a verified query for the question people will actually ask.

## 5. Plan for Time Intelligence

Report-level measures and functions such as `TOTALYTD`, `SAMEPERIODLASTYEAR` and `PREVIOUSMONTH` are not yet fully supported. You will see this in Step 5: the upload wizard converted four of the seven measures, and the three time-intelligence ones needed rework. Typical fixes are to define the periods explicitly in Snowflake, replace context-dependent DAX with explicit SQL, and use derived metrics for calculations that combine other metrics.

## 6. Validate With Golden Questions

Run the same set of questions against the Power BI baseline and the semantic view, and compare both the generated SQL and the results. A model is ready when it gives the correct metric, join path and grain with no double counting, the right date behaviour, the right filtering and security, and results you can reproduce.

## When to Redesign Instead

Use ingestion when the Power BI model is structurally sound. Choose a manual redesign when the model is heavily report-specific, depends on complex filter-context behaviour, has extensive time intelligence or ambiguous many-to-many relationships, or mixes several business domains.

## Learn More

- [Power BI ingestion feature support](https://docs.snowflake.com/en/user-guide/views-semantic/power-bi-ingestion)
- [Power BI ingestion general availability release note](https://docs.snowflake.com/en/release-notes/2026/other/2026-08-18-semantic-views-power-bi-ingestion-ga)
- [Best practices for modeling semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling)
- [Best practices for developing and deploying semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-dev)
