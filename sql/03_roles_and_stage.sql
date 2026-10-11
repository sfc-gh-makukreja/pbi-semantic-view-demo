/*******************************************************************************
 Demo 4 - Power BI -> Snowflake Semantic View
 Step 3 of 3: Analyst role + upload stage

 Creates a least-privilege role to use for Power BI and Semantic View Autopilot,
 plus the stage Autopilot needs to hold the uploaded .pbit file.
*******************************************************************************/

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS TB_PBI_ANALYST COMMENT = 'Demo 4: Power BI + semantic view analyst';
SET me = (SELECT CURRENT_USER());
GRANT ROLE TB_PBI_ANALYST TO USER IDENTIFIER($me);

GRANT USAGE ON WAREHOUSE TB_PBI_WH TO ROLE TB_PBI_ANALYST;
GRANT USAGE ON DATABASE  TB_PBI_DEMO TO ROLE TB_PBI_ANALYST;
GRANT USAGE ON SCHEMA TB_PBI_DEMO.POWERBI  TO ROLE TB_PBI_ANALYST;
GRANT USAGE ON SCHEMA TB_PBI_DEMO.SEMANTIC TO ROLE TB_PBI_ANALYST;

-- read the star schema Power BI is wired to
GRANT SELECT ON ALL TABLES         IN SCHEMA TB_PBI_DEMO.POWERBI TO ROLE TB_PBI_ANALYST;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA TB_PBI_DEMO.POWERBI TO ROLE TB_PBI_ANALYST;

-- create + own semantic views and the upload stage in the SEMANTIC schema
GRANT CREATE SEMANTIC VIEW ON SCHEMA TB_PBI_DEMO.SEMANTIC TO ROLE TB_PBI_ANALYST;
GRANT CREATE STAGE         ON SCHEMA TB_PBI_DEMO.SEMANTIC TO ROLE TB_PBI_ANALYST;

USE ROLE TB_PBI_ANALYST;
CREATE STAGE IF NOT EXISTS TB_PBI_DEMO.SEMANTIC.PBI_FILES
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Autopilot upload area for the Power BI template';

SELECT 'step 3 complete' AS note;
