-- ============================================================================

-- snow sql -c avidia -f dbt_setup/01_permissions.sql


GRANT SELECT
ON ALL VIEWS IN SCHEMA ANALYTICS.STAGING
TO ROLE SVC_PIPELINE_ROLE;

GRANT SELECT
ON FUTURE VIEWS IN SCHEMA ANALYTICS.STAGING
TO ROLE SVC_PIPELINE_ROLE;