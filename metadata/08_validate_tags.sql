/*==============================================================================
 AVIDIA
 Phase 2 - Tagging Evidence
==============================================================================*/

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;


/* ============================================================================
   1. Taxonomy
============================================================================ */

SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;


/* ============================================================================
   2. Metadata configuration
============================================================================ */

SELECT
    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,

    OBJECT_LEVEL,
    OBJECT_TYPE,

    TAG_NAME,
    TAG_VALUE,

    SOURCE_TYPE,
    ACTIVE_FLAG

FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT

ORDER BY
    APPLY_ORDER,
    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,
    TAG_NAME;


/* ============================================================================
   3. Direct/inherited tags on RAW ACCOUNT table

   Replace ACCOUNT if your actual table uses a different name.
============================================================================ */

SELECT
    TAG_NAME,
    TAG_VALUE,
    APPLY_METHOD,
    LEVEL,
    DOMAIN

FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.ACCOUNT',
        'TABLE'
    )
)

ORDER BY TAG_NAME;


/* ============================================================================
   4. All effective tags on ACCOUNT columns
============================================================================ */

SELECT
    COLUMN_NAME,
    TAG_NAME,
    TAG_VALUE,
    APPLY_METHOD,
    LEVEL

FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.ACCOUNT',
        'TABLE'
    )
)

ORDER BY
    COLUMN_NAME,
    TAG_NAME;
