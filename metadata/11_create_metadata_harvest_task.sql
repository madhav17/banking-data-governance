/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/11_create_metadata_harvest_task.sql

  Purpose:
      Automate periodic execution of the Snowflake metadata harvest procedure.

  Procedure:
      GOVERNANCE.CATALOG.HARVEST_METADATA()

  Task:
      GOVERNANCE.CATALOG.METADATA_HARVEST_TASK

  Design:
      - Uses WH_GOVERNANCE_XS
      - Runs every 6 hours
      - Calls the already-tested HARVEST_METADATA procedure
      - Prevents overlapping executions
      - Automatically suspends after repeated failures
      - Resumed after creation so scheduled execution is active
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. CREATE METADATA HARVEST TASK
-- ============================================================================

CREATE OR REPLACE TASK GOVERNANCE.CATALOG.METADATA_HARVEST_TASK

    WAREHOUSE = WH_GOVERNANCE_XS

    SCHEDULE = '6 HOURS'

    OVERLAP_POLICY = NO_OVERLAP

    USER_TASK_TIMEOUT_MS = 300000

    SUSPEND_TASK_AFTER_NUM_FAILURES = 3

    COMMENT =
        'Periodically refreshes GOVERNANCE.CATALOG object and column metadata
         from Snowflake INFORMATION_SCHEMA and ACCOUNT_USAGE'

AS

    CALL GOVERNANCE.CATALOG.HARVEST_METADATA();



-- ============================================================================
-- 3. ENABLE SCHEDULED EXECUTION
-- ============================================================================

ALTER TASK GOVERNANCE.CATALOG.METADATA_HARVEST_TASK
RESUME;

--For your live demo, you won't wait six hours. You'll use:
--EXECUTE TASK GOVERNANCE.CATALOG.METADATA_HARVEST_TASK;