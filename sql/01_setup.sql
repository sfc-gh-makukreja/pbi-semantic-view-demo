/*******************************************************************************
 Demo 4 - Power BI -> Snowflake Semantic View
 Step 1 of 3: Environment + raw Tasty Bytes data (lean subset)

 Creates:  TB_PBI_DEMO database, TB_PBI_WH warehouse
 Loads:    Tasty Bytes raw tables from the public Snowflake quickstart S3 bucket.
           Orders are limited to trucks 1-30 (~4.7M orders, 2019-2022) so the
           whole build finishes in a few minutes instead of loading ~900M rows.
 Run as:   ACCOUNTADMIN (trial account) or any role that can CREATE DATABASE /
           CREATE WAREHOUSE.
*******************************************************************************/

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS TB_PBI_DEMO;
CREATE SCHEMA   IF NOT EXISTS TB_PBI_DEMO.RAW_POS;
CREATE SCHEMA   IF NOT EXISTS TB_PBI_DEMO.RAW_CUSTOMER;
CREATE SCHEMA   IF NOT EXISTS TB_PBI_DEMO.POWERBI;      -- star schema Power BI reads from
CREATE SCHEMA   IF NOT EXISTS TB_PBI_DEMO.SEMANTIC;     -- semantic view lands here

CREATE WAREHOUSE IF NOT EXISTS TB_PBI_WH
    WAREHOUSE_SIZE = 'XLARGE'          -- resized down at the end of 02_star_schema.sql
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE TB_PBI_WH;
USE DATABASE  TB_PBI_DEMO;

-- Public, read-only stage with the Tasty Bytes quickstart data
CREATE OR REPLACE FILE FORMAT TB_PBI_DEMO.RAW_POS.CSV_FF TYPE = 'CSV';
CREATE OR REPLACE STAGE TB_PBI_DEMO.RAW_POS.S3LOAD
    URL = 's3://sfquickstarts/frostbyte_tastybytes/'
    FILE_FORMAT = TB_PBI_DEMO.RAW_POS.CSV_FF;

/*------------------------------------------------------------------------------
 Raw tables
------------------------------------------------------------------------------*/
CREATE OR REPLACE TABLE RAW_POS.COUNTRY (
    country_id NUMBER(18,0), country VARCHAR, iso_currency VARCHAR(3),
    iso_country VARCHAR(2), city_id NUMBER(19,0), city VARCHAR, city_population VARCHAR);

CREATE OR REPLACE TABLE RAW_POS.FRANCHISE (
    franchise_id NUMBER(38,0), first_name VARCHAR, last_name VARCHAR, city VARCHAR,
    country VARCHAR, e_mail VARCHAR, phone_number VARCHAR);

CREATE OR REPLACE TABLE RAW_POS.LOCATION (
    location_id NUMBER(19,0), placekey VARCHAR, location VARCHAR, city VARCHAR,
    region VARCHAR, iso_country_code VARCHAR, country VARCHAR);

CREATE OR REPLACE TABLE RAW_POS.MENU (
    menu_id NUMBER(19,0), menu_type_id NUMBER(38,0), menu_type VARCHAR,
    truck_brand_name VARCHAR, menu_item_id NUMBER(38,0), menu_item_name VARCHAR,
    item_category VARCHAR, item_subcategory VARCHAR, cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4), menu_item_health_metrics_obj VARIANT);

CREATE OR REPLACE TABLE RAW_POS.TRUCK (
    truck_id NUMBER(38,0), menu_type_id NUMBER(38,0), primary_city VARCHAR, region VARCHAR,
    iso_region VARCHAR, country VARCHAR, iso_country_code VARCHAR, franchise_flag NUMBER(38,0),
    year NUMBER(38,0), make VARCHAR, model VARCHAR, ev_flag NUMBER(38,0),
    franchise_id NUMBER(38,0), truck_opening_date DATE);

CREATE OR REPLACE TABLE RAW_POS.ORDER_HEADER (
    order_id NUMBER(38,0), truck_id NUMBER(38,0), location_id FLOAT, customer_id NUMBER(38,0),
    discount_id VARCHAR, shift_id NUMBER(38,0), shift_start_time TIME(9), shift_end_time TIME(9),
    order_channel VARCHAR, order_ts TIMESTAMP_NTZ(9), served_ts VARCHAR, order_currency VARCHAR(3),
    order_amount NUMBER(38,4), order_tax_amount VARCHAR, order_discount_amount VARCHAR,
    order_total NUMBER(38,4));

CREATE OR REPLACE TABLE RAW_POS.ORDER_DETAIL (
    order_detail_id NUMBER(38,0), order_id NUMBER(38,0), menu_item_id NUMBER(38,0),
    discount_id VARCHAR, line_number NUMBER(38,0), quantity NUMBER(5,0),
    unit_price NUMBER(38,4), price NUMBER(38,4), order_item_discount_amount VARCHAR);

CREATE OR REPLACE TABLE RAW_CUSTOMER.CUSTOMER_LOYALTY (
    customer_id NUMBER(38,0), first_name VARCHAR, last_name VARCHAR, city VARCHAR,
    country VARCHAR, postal_code VARCHAR, preferred_language VARCHAR, gender VARCHAR,
    favourite_brand VARCHAR, marital_status VARCHAR, children_count VARCHAR,
    sign_up_date DATE, birthday_date DATE, e_mail VARCHAR, phone_number VARCHAR);

/*------------------------------------------------------------------------------
 Load the small reference tables in full
------------------------------------------------------------------------------*/
COPY INTO RAW_POS.COUNTRY               FROM @RAW_POS.S3LOAD/raw_pos/country/;
COPY INTO RAW_POS.FRANCHISE             FROM @RAW_POS.S3LOAD/raw_pos/franchise/;
COPY INTO RAW_POS.LOCATION              FROM @RAW_POS.S3LOAD/raw_pos/location/;
COPY INTO RAW_POS.MENU                  FROM @RAW_POS.S3LOAD/raw_pos/menu/;
COPY INTO RAW_POS.TRUCK                 FROM @RAW_POS.S3LOAD/raw_pos/truck/;
COPY INTO RAW_CUSTOMER.CUSTOMER_LOYALTY FROM @RAW_POS.S3LOAD/raw_customer/customer_loyalty/;

/*------------------------------------------------------------------------------
 Load the big order tables, keeping only trucks 1-30
 (reads the staged files and filters on the way in; no full-size copy is kept)
------------------------------------------------------------------------------*/
INSERT INTO RAW_POS.ORDER_HEADER
SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
FROM @RAW_POS.S3LOAD/raw_pos/order_header/
WHERE $2::NUMBER <= 30;

INSERT INTO RAW_POS.ORDER_DETAIL
SELECT d.$1, d.$2, d.$3, d.$4, d.$5, d.$6, d.$7, d.$8, d.$9
FROM @RAW_POS.S3LOAD/raw_pos/order_detail/ d
JOIN RAW_POS.ORDER_HEADER h ON h.order_id = d.$2::NUMBER;

SELECT 'step 1 complete' AS note,
       (SELECT COUNT(*) FROM RAW_POS.ORDER_HEADER) AS order_headers,
       (SELECT COUNT(*) FROM RAW_POS.ORDER_DETAIL) AS order_lines;
