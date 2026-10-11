/*******************************************************************************
 Demo 4 - Teardown. Removes everything this lab created.
 Safe to run more than once. Does not touch any other database.
*******************************************************************************/

USE ROLE ACCOUNTADMIN;

DROP DATABASE  IF EXISTS TB_PBI_DEMO;     -- tables, dynamic tables, stage and any semantic views inside
DROP WAREHOUSE IF EXISTS TB_PBI_WH;
DROP ROLE      IF EXISTS TB_PBI_ANALYST;

SELECT 'teardown complete' AS note;
