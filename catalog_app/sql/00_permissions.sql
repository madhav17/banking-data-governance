/*==============================================================================
 AVIDIA BANK - STREAMLIT CATALOG PERMISSIONS

 Purpose:
   Grant the minimum privileges needed for the existing Streamlit app role to
   read the consolidated catalog view created in the next script.

 Notes:
   - The app continues to deploy as GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG.
   - CATALOG_APP_ROLE does not receive direct access to every governance source.
   - DATA_GOVERNANCE_ADMIN owns the view and supplies the governed metadata.
==============================================================================*/

USE ROLE SECURITYADMIN;

GRANT USAGE
ON DATABASE GOVERNANCE
TO ROLE CATALOG_APP_ROLE;

GRANT USAGE
ON SCHEMA GOVERNANCE.CATALOG
TO ROLE CATALOG_APP_ROLE;

GRANT USAGE
ON WAREHOUSE WH_GOVERNANCE_XS
TO ROLE CATALOG_APP_ROLE;

-- The catalog view reads MART metadata and tag references from
-- ANALYTICS.INFORMATION_SCHEMA. This does not grant SELECT on MART tables.
GRANT USAGE
ON DATABASE ANALYTICS
TO ROLE CATALOG_APP_ROLE;

GRANT USAGE
ON SCHEMA ANALYTICS.MARTS
TO ROLE CATALOG_APP_ROLE;

-- The Streamlit catalog uses INFORMATION_SCHEMA tag/policy metadata for these
-- MART objects. REFERENCES allows metadata visibility without granting SELECT
-- access to business rows.
GRANT REFERENCES
ON TABLE ANALYTICS.MARTS.CUSTOMER_360
TO ROLE CATALOG_APP_ROLE;

GRANT REFERENCES
ON TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
TO ROLE CATALOG_APP_ROLE;

GRANT REFERENCES
ON TABLE ANALYTICS.MARTS.LOAN_PORTFOLIO
TO ROLE CATALOG_APP_ROLE;

GRANT CREATE VIEW
ON SCHEMA GOVERNANCE.CATALOG
TO ROLE DATA_GOVERNANCE_ADMIN;

-- The catalog view uses CERTIFICATION_LOG as a fallback evidence source for
-- objects certified by GOVERNANCE.EVIDENCE.CERTIFY(object). CERTIFY applies the
-- native tag directly and writes the log; it does not store certification in
-- TAG_ASSIGNMENT.
GRANT USAGE
ON SCHEMA GOVERNANCE.EVIDENCE
TO ROLE DATA_GOVERNANCE_ADMIN;

GRANT SELECT
ON ALL TABLES IN SCHEMA GOVERNANCE.EVIDENCE
TO ROLE DATA_GOVERNANCE_ADMIN;

-- Existing lineage work grants SNOWFLAKE.GOVERNANCE_VIEWER to
-- DATA_GOVERNANCE_ADMIN for ACCESS_HISTORY / QUERY_HISTORY evidence. If this
-- check returns no row, rerun lineage/00_permissions.sql before creating the
-- catalog view.
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER;

SHOW GRANTS TO ROLE CATALOG_APP_ROLE;

SHOW GRANTS ON SCHEMA GOVERNANCE.CATALOG;
