-- ============================================================
-- Avidia Bank Take-Home
-- Snowflake Warehouse Setup
-- ============================================================

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS WH_GOVERNANCE_XS
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Avidia governance take-home warehouse';

-- Enforce expected configuration if warehouse already exists.
ALTER WAREHOUSE WH_GOVERNANCE_XS
    SET
        WAREHOUSE_SIZE = XSMALL,
        AUTO_SUSPEND = 60,
        AUTO_RESUME = TRUE;


-- ============================================================
-- Warehouse Access
-- ============================================================

USE ROLE SECURITYADMIN;

GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE DATA_OWNER;
GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE DATA_STEWARD;
GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE DEPOSITS_ANALYST;
GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE BRANCH_HUDSON;

GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE DATA_GOVERNANCE_ADMIN;

GRANT USAGE ON WAREHOUSE WH_GOVERNANCE_XS TO ROLE SVC_PIPELINE;

-- Optional if retained in your role model.
GRANT USAGE, OPERATE, MONITOR
    ON WAREHOUSE WH_GOVERNANCE_XS
    TO ROLE DATA_PLATFORM_ADMIN;