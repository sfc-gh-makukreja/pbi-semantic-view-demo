/*******************************************************************************
 Demo 4 - Power BI -> Snowflake Semantic View
 Step 2 of 3: Star schema (date/time dims + dynamic tables) in TB_PBI_DEMO.POWERBI

 This is the model the Power BI template (.pbit) is wired to. Object and column
 names must stay exactly as written - the template binds to them by name
 (including the original quickstart's "customer_favorite_band" spelling).
*******************************************************************************/

USE ROLE ACCOUNTADMIN;
USE DATABASE TB_PBI_DEMO;
USE SCHEMA POWERBI;
USE WAREHOUSE TB_PBI_WH;

/*------------------------------------------------------------------------------
 Static date + time dimensions
------------------------------------------------------------------------------*/
SET min_date = TO_DATE('2018-01-01');
SET max_date = TO_DATE('2024-12-31');
SET days     = (SELECT $max_date - $min_date);

CREATE OR REPLACE TABLE DIM_DATE (
    date_id INT, date DATE, year STRING, month SMALLINT, month_name STRING,
    day_of_month SMALLINT, day_of_week SMALLINT, weekday STRING,
    week_of_year SMALLINT, day_of_year SMALLINT, weekend_flag BOOLEAN)
AS
WITH dates AS (
    SELECT DATEADD(DAY, SEQ4(), $min_date) AS my_date
    FROM TABLE(GENERATOR(ROWCOUNT => $days))
)
SELECT
    TO_NUMBER(REPLACE(TO_VARCHAR(my_date), '-')),
    my_date, YEAR(my_date), MONTH(my_date), MONTHNAME(my_date), DAY(my_date),
    DAYOFWEEK(my_date), DAYNAME(my_date), WEEKOFYEAR(my_date), DAYOFYEAR(my_date),
    CASE WHEN DAYOFWEEK(my_date) IN (0,6) THEN 1 ELSE 0 END
FROM dates;

SET min_time = TO_TIME('00:00:00');
SET seconds  = 86400;

CREATE OR REPLACE TABLE DIM_TIME (
    time_id INT, time TIME, hour SMALLINT, minute SMALLINT, second SMALLINT,
    am_or_pm STRING, hour_am_pm STRING)
AS
WITH secs AS (
    SELECT TIMEADD(SECOND, SEQ4(), $min_time) AS my_time
    FROM TABLE(GENERATOR(ROWCOUNT => $seconds))
)
SELECT
    TO_NUMBER(LEFT(TO_VARCHAR(my_time), 2) || SUBSTR(TO_VARCHAR(my_time), 4, 2) || RIGHT(TO_VARCHAR(my_time), 2)),
    my_time, HOUR(my_time), MINUTE(my_time), SECOND(my_time),
    CASE WHEN HOUR(my_time) < 12 THEN 'AM' ELSE 'PM' END,
    CASE
        WHEN HOUR(my_time) = 0  THEN '12AM'
        WHEN HOUR(my_time) < 12 THEN HOUR(my_time) || 'AM'
        WHEN HOUR(my_time) = 12 THEN '12PM'
        ELSE (HOUR(my_time) - 12) || 'PM'
    END
FROM secs;

/*------------------------------------------------------------------------------
 Dimension dynamic tables
------------------------------------------------------------------------------*/
CREATE OR REPLACE DYNAMIC TABLE DT_DIM_TRUCK
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
SELECT DISTINCT
    t.truck_id, t.franchise_id, m.truck_brand_name,
    t.primary_city AS truck_city, t.region AS truck_region, t.iso_region AS truck_region_iso,
    t.country AS truck_country, t.iso_country_code AS truck_country_iso, t.franchise_flag,
    year AS truck_year, (2023 - year) AS truck_age,
    REPLACE(t.make, 'Ford_', 'Ford') AS truck_make, t.model AS truck_model,
    t.ev_flag, t.truck_opening_date
FROM TB_PBI_DEMO.RAW_POS.TRUCK t
JOIN TB_PBI_DEMO.RAW_POS.MENU  m ON m.menu_type_id = t.menu_type_id;

CREATE OR REPLACE DYNAMIC TABLE DT_DIM_FRANCHISE
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
WITH remove_duplicates AS (
    SELECT DISTINCT
        f.franchise_id,
        f.first_name   AS franchise_first_name,
        f.last_name    AS franchise_last_name,
        f.city         AS franchise_city,
        f.country      AS franchise_country,
        f.e_mail       AS franchise_email,
        f.phone_number AS franchise_phone_number,
        ROW_NUMBER() OVER (PARTITION BY franchise_id ORDER BY franchise_city) AS row_num
    FROM TB_PBI_DEMO.RAW_POS.FRANCHISE f
)
SELECT * FROM remove_duplicates WHERE row_num = 1;

CREATE OR REPLACE DYNAMIC TABLE DT_DIM_MENU_ITEM
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
SELECT
    menu_item_id, menu_type_id, menu_type,
    item_category    AS menu_item_category,
    item_subcategory AS menu_item_subcategory,
    menu_item_name,
    cost_of_goods_usd AS cogs_usd,
    sale_price_usd,
    menu_item_health_metrics_obj:menu_item_health_metrics[0].ingredients          AS ingredients,
    menu_item_health_metrics_obj:menu_item_health_metrics[0].is_dairy_free_flag   AS is_dairy_free_flag,
    menu_item_health_metrics_obj:menu_item_health_metrics[0].is_gluten_free_flag  AS is_gluten_free_flag,
    menu_item_health_metrics_obj:menu_item_health_metrics[0].is_healthy_flag      AS is_healthy_flag,
    menu_item_health_metrics_obj:menu_item_health_metrics[0].is_nut_free_flag     AS is_nut_free_flag
FROM TB_PBI_DEMO.RAW_POS.MENU m;

CREATE OR REPLACE DYNAMIC TABLE DT_DIM_LOCATION
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
SELECT
    l.location_id, l.location, l.city AS location_city,
    CASE
        WHEN l.country IN ('England','France','Germany','Poland','Spain','Sweden') THEN 'EMEA'
        WHEN l.country IN ('Canada','Mexico','United States')                      THEN 'North America'
        WHEN l.country IN ('Australia','India','Japan','South Korea')              THEN 'APAC'
        ELSE 'Other'
    END AS location_region,
    l.country AS location_country,
    l.iso_country_code AS location_country_iso
FROM TB_PBI_DEMO.RAW_POS.LOCATION l;

CREATE OR REPLACE DYNAMIC TABLE DT_DIM_CUSTOMER
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
SELECT
    cl.customer_id,
    cl.first_name AS customer_first_name,
    cl.last_name  AS customer_last_name,
    cl.first_name || ' ' || cl.last_name  AS customer_full_name,
    cl.last_name  || ', ' || cl.first_name AS customer_last_first_name,
    cl.city AS customer_city, cl.country AS customer_country,
    cl.postal_code AS customer_postal_code,
    cl.preferred_language AS customer_preferred_language,
    cl.gender AS customer_gender,
    cl.favourite_brand AS customer_favorite_band,
    cl.marital_status AS customer_marital_status,
    cl.children_count AS customer_children_count,
    cl.sign_up_date AS customer_signup_date,
    cl.birthday_date AS customer_dob,
    cl.e_mail AS customer_email,
    cl.phone_number AS customer_phone_number
FROM TB_PBI_DEMO.RAW_CUSTOMER.CUSTOMER_LOYALTY cl;

/*------------------------------------------------------------------------------
 Fact dynamic tables
------------------------------------------------------------------------------*/
CREATE OR REPLACE DYNAMIC TABLE DT_FACT_ORDER_DETAIL
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = INCREMENTAL INITIALIZE = ON_CREATE
AS
WITH natural_keys AS (
    SELECT
        od.order_id, od.order_detail_id, oh.truck_id, t.franchise_id,
        CAST(oh.location_id AS INT) AS location_id,
        od.menu_item_id,
        TO_DATE(oh.order_ts) AS date_id,
        TO_TIME(oh.order_ts) AS time_id,
        oh.customer_id, od.quantity, od.unit_price, od.price AS line_total
    FROM TB_PBI_DEMO.RAW_POS.ORDER_DETAIL od
    JOIN TB_PBI_DEMO.RAW_POS.ORDER_HEADER oh ON oh.order_id = od.order_id
    JOIN TB_PBI_DEMO.RAW_POS.TRUCK        t  ON t.truck_id  = oh.truck_id
)
SELECT
    nk.order_id, nk.order_detail_id,
    dt.truck_id, df.franchise_id, dl.location_id, dmi.menu_item_id, dc.customer_id,
    dd.date_id, ti.time_id,
    nk.quantity, nk.unit_price, nk.line_total
FROM natural_keys nk
JOIN TB_PBI_DEMO.POWERBI.DT_DIM_TRUCK     dt  ON dt.truck_id = nk.truck_id AND dt.franchise_id = nk.franchise_id
JOIN TB_PBI_DEMO.POWERBI.DT_DIM_FRANCHISE df  ON df.franchise_id = nk.franchise_id
JOIN TB_PBI_DEMO.POWERBI.DT_DIM_LOCATION  dl  ON dl.location_id = nk.location_id
JOIN TB_PBI_DEMO.POWERBI.DT_DIM_MENU_ITEM dmi ON dmi.menu_item_id = nk.menu_item_id
JOIN TB_PBI_DEMO.POWERBI.DIM_DATE         dd  ON dd.date = nk.date_id
JOIN TB_PBI_DEMO.POWERBI.DIM_TIME         ti  ON ti.time = nk.time_id
LEFT JOIN TB_PBI_DEMO.POWERBI.DT_DIM_CUSTOMER dc ON dc.customer_id = nk.customer_id;

CREATE OR REPLACE DYNAMIC TABLE DT_FACT_ORDER_HEADER
    TARGET_LAG = 'DOWNSTREAM' WAREHOUSE = TB_PBI_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
AS
SELECT
    order_id, truck_id, franchise_id, location_id, customer_id, date_id, time_id,
    COUNT(order_detail_id) AS order_line_count,
    SUM(quantity)          AS order_qty,
    SUM(line_total)        AS order_total
FROM DT_FACT_ORDER_DETAIL
GROUP BY order_id, truck_id, franchise_id, location_id, customer_id, date_id, time_id;

CREATE OR REPLACE DYNAMIC TABLE DT_FACT_ORDER_AGG
    TARGET_LAG = '1 hour' WAREHOUSE = TB_PBI_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
AS
SELECT
    truck_id, franchise_id, location_id, customer_id, date_id,
    COUNT(order_id)         AS order_count,
    SUM(order_line_count)   AS order_line_count,
    SUM(order_qty)          AS order_qty,
    SUM(order_total)        AS order_total
FROM DT_FACT_ORDER_HEADER
GROUP BY truck_id, franchise_id, location_id, customer_id, date_id;

-- Build is done: scale the warehouse down (Power BI queries run on it later)
ALTER WAREHOUSE TB_PBI_WH SET WAREHOUSE_SIZE = 'XSMALL';

SELECT 'step 2 complete' AS note;
