/*==============================================================================
 AVIDIA BANK - BLOCK 2 CLASSIFICATION PROFILE

 Purpose:
   Create a Snowflake classification profile for ANALYTICS.STAGING only.

 Important:
   - auto_tag = true allows Snowflake system classification tags to be applied.
   - This profile does NOT map Snowflake classification directly to the custom
     GOVERNANCE.TAGS.CLASSIFICATION tag.
   - GOVERNANCE.TAGS.CLASSIFICATION is assigned only after steward approval.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE
    GOVERNANCE.CATALOG.STAGING_CLASSIFICATION_PROFILE
(
    {
        'minimum_object_age_for_classification_days': 0,
        'auto_tag': true,
        'classify_views': false
    }
);

ALTER SCHEMA ANALYTICS.STAGING
    SET CLASSIFICATION_PROFILE =
        'GOVERNANCE.CATALOG.STAGING_CLASSIFICATION_PROFILE';

SELECT
    GOVERNANCE.CATALOG.STAGING_CLASSIFICATION_PROFILE!DESCRIBE()
        AS CLASSIFICATION_PROFILE_CONFIGURATION;

SHOW PARAMETERS LIKE 'CLASSIFICATION_PROFILE'
    IN SCHEMA ANALYTICS.STAGING;
