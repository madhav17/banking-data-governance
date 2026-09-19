/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/12_validate_metadata_harvest_task.sql

  Purpose:
      Validate creation, configuration and execution of
      GOVERNANCE.CATALOG.METADATA_HARVEST_TASK.
==============================================================================*/


USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 1. VERIFY TASK EXISTS
-- ============================================================================

SHOW TASKS
LIKE 'METADATA_HARVEST_TASK'
IN SCHEMA GOVERNANCE.CATALOG;



-- ============================================================================
-- 2. INSPECT TASK CONFIGURATION
-- ============================================================================

DESCRIBE TASK GOVERNANCE.CATALOG.METADATA_HARVEST_TASK;



-- ============================================================================
-- 3. MANUALLY TRIGGER THE TASK
--
-- This proves the task can execute without waiting for the 6-hour schedule.
-- ============================================================================

EXECUTE TASK GOVERNANCE.CATALOG.METADATA_HARVEST_TASK;



-- ============================================================================
-- 4. CHECK IMMEDIATE TASK EXECUTION HISTORY
--
-- Re-run this query after a few seconds if the task is still EXECUTING.
-- ============================================================================

SELECT

    NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_FROM,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    QUERY_ID,
    ERROR_CODE,
    ERROR_MESSAGE

FROM TABLE
(
    SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY
    (
        DATABASE_NAME => 'GOVERNANCE',
        SCHEMA_NAME   => 'CATALOG',
        RESULT_LIMIT  => 20
    )
)

WHERE NAME = 'METADATA_HARVEST_TASK'

ORDER BY SCHEDULED_TIME DESC;



-- ============================================================================
-- 5. VERIFY THAT THE TASK REFRESHED OBJECT METADATA
-- ============================================================================

SELECT

    COUNT(*) AS OBJECT_COUNT,

    MAX(HARVESTED_AT) AS LAST_OBJECT_HARVEST

FROM GOVERNANCE.CATALOG.OBJECT_CATALOG;



-- ============================================================================
-- 6. VERIFY THAT THE TASK REFRESHED COLUMN METADATA
-- ============================================================================

SELECT

    COUNT(*) AS COLUMN_COUNT,

    MAX(HARVESTED_AT) AS LAST_COLUMN_HARVEST

FROM GOVERNANCE.CATALOG.COLUMN_CATALOG;



-- ============================================================================
-- 7. VERIFY TASK IS ENABLED
-- ============================================================================

SHOW TASKS
LIKE 'METADATA_HARVEST_TASK'
IN SCHEMA GOVERNANCE.CATALOG;