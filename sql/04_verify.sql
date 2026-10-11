/*******************************************************************************
 Demo 4 - Power BI -> Snowflake Semantic View
 Step 4: Verify the data foundation (run after 01-03)

 Every check should return PASS. If one returns FAIL, re-run the step it names.
*******************************************************************************/

-- Part A: data checks. Run as ACCOUNTADMIN because they read the RAW_POS tables,
-- which the analyst role deliberately cannot see.
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TB_PBI_WH;
USE DATABASE TB_PBI_DEMO;

WITH c AS (
    SELECT
        (SELECT COUNT(*) FROM RAW_POS.ORDER_HEADER)             AS raw_headers,
        (SELECT COUNT(*) FROM RAW_POS.ORDER_DETAIL)             AS raw_lines,
        (SELECT COUNT(*) FROM POWERBI.DT_FACT_ORDER_DETAIL)     AS fact_lines,
        (SELECT COUNT(*) FROM POWERBI.DT_FACT_ORDER_HEADER)     AS fact_headers,
        (SELECT COUNT(*) FROM POWERBI.DT_FACT_ORDER_AGG)        AS fact_agg,
        (SELECT COUNT(*) FROM POWERBI.DT_DIM_TRUCK)             AS dim_truck,
        (SELECT COUNT(*) FROM POWERBI.DT_DIM_CUSTOMER)          AS dim_customer,
        (SELECT COUNT(*) FROM POWERBI.DIM_DATE)                 AS dim_date,
        (SELECT COUNT(DISTINCT YEAR(order_ts)) FROM RAW_POS.ORDER_HEADER) AS years_of_data
)
SELECT 'raw order headers loaded (expect 4,656,869)' AS check_name, raw_headers AS actual,
       IFF(raw_headers = 4656869, 'PASS', 'FAIL - re-run 01_setup.sql') AS result FROM c
UNION ALL SELECT 'raw order lines loaded (expect 12,738,517)', raw_lines,
       IFF(raw_lines = 12738517, 'PASS', 'FAIL - re-run 01_setup.sql') FROM c
UNION ALL SELECT 'fact lines = raw lines (no rows lost in joins)', fact_lines,
       IFF(fact_lines = raw_lines, 'PASS', 'FAIL - re-run 02_star_schema.sql') FROM c
UNION ALL SELECT 'fact headers = raw headers', fact_headers,
       IFF(fact_headers = raw_headers, 'PASS', 'FAIL - re-run 02_star_schema.sql') FROM c
UNION ALL SELECT 'order_agg built (expect > 0)', fact_agg,
       IFF(fact_agg > 0, 'PASS', 'FAIL - re-run 02_star_schema.sql') FROM c
UNION ALL SELECT 'dimensions populated (trucks, customers, dates)', dim_truck + dim_customer + dim_date,
       IFF(dim_truck > 0 AND dim_customer > 0 AND dim_date > 0, 'PASS', 'FAIL - re-run 02_star_schema.sql') FROM c
UNION ALL SELECT 'multiple years of data (YTD / prior-year measures need > 1)', years_of_data,
       IFF(years_of_data > 1, 'PASS', 'FAIL - re-run 01_setup.sql') FROM c;

-- Part B: switch to the least-privilege analyst role (what Power BI and Autopilot use).
-- SECONDARY ROLES NONE matters: otherwise your other roles leak into the test.
USE ROLE TB_PBI_ANALYST;
USE SECONDARY ROLES NONE;
USE WAREHOUSE TB_PBI_WH;

-- Expect: works. The analyst can read the star schema.
SELECT d.year AS order_year,
       COUNT(DISTINCT f.order_id) AS orders,
       SUM(f.quantity)            AS units,
       SUM(f.line_total)          AS sales
FROM TB_PBI_DEMO.POWERBI.DT_FACT_ORDER_DETAIL f
JOIN TB_PBI_DEMO.POWERBI.DIM_DATE d ON d.date_id = f.date_id
GROUP BY 1 ORDER BY 1;

-- Expect: ERROR "Schema 'TB_PBI_DEMO.RAW_POS' does not exist or not authorized".
-- That error is the PASS - the analyst never touches raw data.
SELECT COUNT(*) FROM TB_PBI_DEMO.RAW_POS.ORDER_HEADER;
