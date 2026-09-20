/*==============================================================================
 AVIDIA BANK - EXTERNAL LINEAGE FALLBACK

 Purpose:
   Represent the two required external lineage endpoints without deploying
   Talend, Power BI or Snowflake External Lineage REST ingestion.

   This script intentionally resets LINEAGE_EDGE_EXTERNAL to exactly two
   metadata rows. The external objects are string identifiers only.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

DELETE FROM GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL;

INSERT INTO GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL
(
    SOURCE_SYSTEM,
    SOURCE_OBJECT,
    SOURCE_OBJECT_TYPE,
    TARGET_SYSTEM,
    TARGET_OBJECT,
    TARGET_OBJECT_TYPE,
    EDGE_TYPE,
    DESCRIPTION
)
SELECT
    SOURCE_SYSTEM,
    SOURCE_OBJECT,
    SOURCE_OBJECT_TYPE,
    TARGET_SYSTEM,
    TARGET_OBJECT,
    TARGET_OBJECT_TYPE,
    EDGE_TYPE,
    DESCRIPTION
FROM VALUES
    (
        'TALEND',
        'LEGACY_TALEND_DEPOSIT_LOAD',
        'EXTERNAL_ETL_JOB',
        'SNOWFLAKE',
        'RAW.BANKING.ACCOUNT_DAILY_BALANCE',
        'TABLE',
        'UPSTREAM_EXTERNAL',
        'Metadata-only representation of the legacy Talend upstream endpoint required by the take-home specification.'
    ),
    (
        'SNOWFLAKE',
        'ANALYTICS.MARTS.DEPOSITS_DAILY',
        'TABLE',
        'POWER_BI',
        'POWER_BI_DEPOSITS_MODEL',
        'EXTERNAL_BI_ENDPOINT',
        'DOWNSTREAM_EXTERNAL',
        'Metadata-only representation of the downstream Power BI endpoint required by the take-home specification.'
    )
    AS V
    (
        SOURCE_SYSTEM,
        SOURCE_OBJECT,
        SOURCE_OBJECT_TYPE,
        TARGET_SYSTEM,
        TARGET_OBJECT,
        TARGET_OBJECT_TYPE,
        EDGE_TYPE,
        DESCRIPTION
    );

SELECT *
FROM GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL
ORDER BY EDGE_TYPE, SOURCE_OBJECT, TARGET_OBJECT;
