-- ============================================================================
-- File: setup/07_prepare_dbt_deployment.sql
--
-- Purpose:
--   Prepare Snowflake objects and privileges required for:
--     1. snow dbt deploy
--     2. Snowflake DBT PROJECT object creation
--     3. STAGING -> MARTS execution
--
-- Service User : SVC_PIPELINE
-- Pipeline Role: SVC_PIPELINE_ROLE
-- Warehouse    : WH_GOVERNANCE_XS
-- ============================================================================


-- ============================================================================
-- 1. CREATE DBT PROJECT SCHEMA
-- ============================================================================

-- snow sql -c avidia -f dbt_setup/02_prepare_dbt_deployment.sql

USE ROLE SYSADMIN;

CREATE SCHEMA IF NOT EXISTS ANALYTICS.DBT_PROJECTS
    COMMENT = 'Snowflake DBT PROJECT objects deployed through CI/CD';


-- ============================================================================
-- 2. DATABASE ACCESS
-- ============================================================================

USE ROLE SECURITYADMIN;

GRANT USAGE
ON DATABASE ANALYTICS
TO ROLE SVC_PIPELINE_ROLE;


-- ============================================================================
-- 3. DBT PROJECT DEPLOYMENT PRIVILEGES
-- ============================================================================

GRANT USAGE
ON SCHEMA ANALYTICS.DBT_PROJECTS
TO ROLE SVC_PIPELINE_ROLE;

GRANT CREATE DBT PROJECT
ON SCHEMA ANALYTICS.DBT_PROJECTS
TO ROLE SVC_PIPELINE_ROLE;


-- ============================================================================
-- 4. WAREHOUSE ACCESS
-- ============================================================================

GRANT USAGE
ON WAREHOUSE WH_GOVERNANCE_XS
TO ROLE SVC_PIPELINE_ROLE;


-- ============================================================================
-- 5. STAGING - READ ONLY
-- ============================================================================

GRANT USAGE
ON SCHEMA ANALYTICS.STAGING
TO ROLE SVC_PIPELINE_ROLE;

GRANT SELECT
ON ALL TABLES IN SCHEMA ANALYTICS.STAGING
TO ROLE SVC_PIPELINE_ROLE;

GRANT SELECT
ON FUTURE TABLES IN SCHEMA ANALYTICS.STAGING
TO ROLE SVC_PIPELINE_ROLE;


-- ============================================================================
-- 6. MARTS - DBT WRITE ACCESS
-- ============================================================================

GRANT USAGE
ON SCHEMA ANALYTICS.MARTS
TO ROLE SVC_PIPELINE_ROLE;

GRANT CREATE TABLE
ON SCHEMA ANALYTICS.MARTS
TO ROLE SVC_PIPELINE_ROLE;

GRANT CREATE VIEW
ON SCHEMA ANALYTICS.MARTS
TO ROLE SVC_PIPELINE_ROLE;


-- ============================================================================
-- 7. VERIFICATION
-- ============================================================================

SHOW GRANTS TO ROLE SVC_PIPELINE_ROLE;