--snow sql -c avidia -f streamlit_setup/01_prepare_streamlit_deployment.sql
-- ============================================================================
-- File: setup/08_prepare_streamlit_deployment.sql
--
-- Purpose:
--   Prepare the minimum Snowflake privileges required to deploy the mock
--   Avidia Data Catalog Streamlit application to:
--
--     GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG
--
-- Service User : SVC_PIPELINE
-- Runtime Role : CATALOG_APP_ROLE
-- Warehouse    : WH_GOVERNANCE_XS
-- ============================================================================


-- ============================================================================
-- 1. CREATE DEDICATED STREAMLIT ROLE
-- ============================================================================

USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS CATALOG_APP_ROLE
    COMMENT = 'Deploys and owns the Avidia Data Catalog Streamlit application';

GRANT ROLE CATALOG_APP_ROLE
TO USER SVC_PIPELINE;


-- ============================================================================
-- 2. DATABASE AND SCHEMA ACCESS
-- ============================================================================

GRANT USAGE
ON DATABASE GOVERNANCE
TO ROLE CATALOG_APP_ROLE;

GRANT USAGE
ON SCHEMA GOVERNANCE.CATALOG
TO ROLE CATALOG_APP_ROLE;


-- ============================================================================
-- 3. STREAMLIT DEPLOYMENT PRIVILEGES
-- ============================================================================

GRANT CREATE STREAMLIT
ON SCHEMA GOVERNANCE.CATALOG
TO ROLE CATALOG_APP_ROLE;

GRANT CREATE STAGE
ON SCHEMA GOVERNANCE.CATALOG
TO ROLE CATALOG_APP_ROLE;


-- ============================================================================
-- 4. WAREHOUSE ACCESS
-- ============================================================================

GRANT USAGE
ON WAREHOUSE WH_GOVERNANCE_XS
TO ROLE CATALOG_APP_ROLE;


-- ============================================================================
-- 5. VERIFICATION
-- ============================================================================

SHOW GRANTS TO ROLE CATALOG_APP_ROLE;
