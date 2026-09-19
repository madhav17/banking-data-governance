/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/24_validate_metadata_foundation.sql

  Purpose:
      Final acceptance validation for Block 1 - Metadata Foundation.

  This file validates that the metadata foundation is not merely configured,
  but is populated, linked and visible through Snowflake-native metadata.

  Validates:
      1. Metadata harvest procedure exists
      2. Metadata harvest task exists / is enabled
      3. OBJECT_CATALOG and COLUMN_CATALOG are populated
      4. DATA_DICTIONARY covers RAW.BANKING
      5. Native/harvested descriptions are populated
      6. Required eight-tag taxonomy exists
      7. RAW tables have effective governance tags
      8. 10+ approved glossary terms exist
      9. Glossary terms are linked to real physical columns
     10. 25+ active CDEs exist
     11. Every active CDE has owner and steward
     12. CDE_REGISTRY has been synchronized into TAG_ASSIGNMENT
     13. Native CDE / DATA_OWNER / DATA_STEWARD tags match CDE_REGISTRY

  Important:
      Run this AFTER:

          21_seed_cde_registry.sql
          22_validate_cde_registry.sql
          05_sync_cde_tags.sql
          07_apply_tags.sql
          23_validate_cde_tags.sql

  Notes:
      - INFORMATION_SCHEMA tag functions are used for immediate runtime
        evidence because ACCOUNT_USAGE can lag.
      - CLASSIFICATION and CERTIFICATION values are intentionally not required
        to be populated yet; they belong to later blocks.
==============================================================================*/


-- ============================================================================
-- 1. METADATA HARVEST PROCEDURE
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


SELECT
    PROCEDURE_NAME,
    PROCEDURE_OWNER,
    ARGUMENT_SIGNATURE,
    DATA_TYPE
FROM GOVERNANCE.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'CATALOG'
  AND PROCEDURE_NAME = 'HARVEST_METADATA';


-- ============================================================================
-- 2. METADATA HARVEST TASK
--
-- Immediate check using SHOW rather than ACCOUNT_USAGE because ACCOUNT_USAGE
-- metadata can lag.
--
-- Expected:
--      METADATA_HARVEST_TASK exists
--      state = started
-- ============================================================================

SHOW TASKS
LIKE 'METADATA_HARVEST_TASK'
IN SCHEMA GOVERNANCE.CATALOG;


SELECT
    "name"          AS TASK_NAME,
    "state"         AS TASK_STATE,
    "warehouse"     AS WAREHOUSE,
    "schedule"      AS SCHEDULE,
    "definition"    AS DEFINITION,
    "owner"         AS TASK_OWNER
FROM TABLE
(
    RESULT_SCAN(LAST_QUERY_ID())
);


-- ============================================================================
-- 3. SWITCH TO SYSADMIN FOR CROSS-OBJECT RUNTIME VALIDATION
--
-- Existing tag validation/deployment scripts use SYSADMIN and this role can
-- inspect both the governed metadata tables and RAW objects.
-- ============================================================================

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


-- ============================================================================
-- 4. TECHNICAL METADATA HARVEST COVERAGE
--
-- Expected:
--      OBJECT_COUNT > 0
--      COLUMN_COUNT > 0
--      LAST_*_HARVEST is not null
-- ============================================================================

SELECT
    COUNT(*)          AS OBJECT_COUNT,
    MAX(HARVESTED_AT) AS LAST_OBJECT_HARVEST
FROM GOVERNANCE.CATALOG.OBJECT_CATALOG
WHERE
       (DATABASE_NAME = 'RAW'       AND SCHEMA_NAME = 'BANKING')
    OR (DATABASE_NAME = 'ANALYTICS' AND SCHEMA_NAME IN ('STAGING', 'MARTS'));


SELECT
    COUNT(*)          AS COLUMN_COUNT,
    MAX(HARVESTED_AT) AS LAST_COLUMN_HARVEST
FROM GOVERNANCE.CATALOG.COLUMN_CATALOG
WHERE
       (DATABASE_NAME = 'RAW'       AND SCHEMA_NAME = 'BANKING')
    OR (DATABASE_NAME = 'ANALYTICS' AND SCHEMA_NAME IN ('STAGING', 'MARTS'));


-- ============================================================================
-- 5. DATA DICTIONARY COVERAGE
--
-- Expected:
--      DICTIONARY_COVERAGE_PCT = 100.00
--      DESCRIPTION_SOURCE_COVERAGE_PCT = 100.00
-- ============================================================================

SELECT
    COUNT(*) AS TOTAL_RAW_COLUMNS,

    COUNT_IF(D.COLUMN_NAME IS NOT NULL)
        AS DICTIONARY_MAPPED_COLUMNS,

    COUNT_IF
    (
        D.DESCRIPTION IS NOT NULL
        AND TRIM(D.DESCRIPTION) <> ''
    )
        AS DESCRIBED_DICTIONARY_COLUMNS,

    ROUND
    (
        100.0
        * COUNT_IF(D.COLUMN_NAME IS NOT NULL)
        / NULLIF(COUNT(*), 0),
        2
    )
        AS DICTIONARY_COVERAGE_PCT,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              D.DESCRIPTION IS NOT NULL
              AND TRIM(D.DESCRIPTION) <> ''
          )
        / NULLIF(COUNT(*), 0),
        2
    )
        AS DESCRIPTION_SOURCE_COVERAGE_PCT

FROM GOVERNANCE.CATALOG.COLUMN_CATALOG C

LEFT JOIN GOVERNANCE.CATALOG.DATA_DICTIONARY D
       ON D.DATABASE_NAME = C.DATABASE_NAME
      AND D.SCHEMA_NAME   = C.SCHEMA_NAME
      AND D.TABLE_NAME    = C.TABLE_NAME
      AND D.COLUMN_NAME   = C.COLUMN_NAME

WHERE C.DATABASE_NAME = 'RAW'
  AND C.SCHEMA_NAME   = 'BANKING';


-- ============================================================================
-- 6. HARVESTED DESCRIPTION COVERAGE
--
-- 17_validate_description_coverage.sql already proves native comments through
-- RAW.INFORMATION_SCHEMA. This final file confirms those comments have also
-- been harvested into the custom governance catalog.
--
-- Expected:
--      COLUMN_DESCRIPTION_COVERAGE_PCT = 100.00
--      TABLE_DESCRIPTION_COVERAGE_PCT  = 100.00
-- ============================================================================

SELECT
    COUNT(*) AS RAW_COLUMNS,

    COUNT_IF
    (
        COMMENT IS NOT NULL
        AND TRIM(COMMENT) <> ''
    )
        AS DESCRIBED_RAW_COLUMNS,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              COMMENT IS NOT NULL
              AND TRIM(COMMENT) <> ''
          )
        / NULLIF(COUNT(*), 0),
        2
    )
        AS COLUMN_DESCRIPTION_COVERAGE_PCT

FROM GOVERNANCE.CATALOG.COLUMN_CATALOG

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING';


SELECT
    COUNT(*) AS RAW_OBJECTS,

    COUNT_IF
    (
        OBJECT_COMMENT IS NOT NULL
        AND TRIM(OBJECT_COMMENT) <> ''
    )
        AS DESCRIBED_RAW_OBJECTS,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              OBJECT_COMMENT IS NOT NULL
              AND TRIM(OBJECT_COMMENT) <> ''
          )
        / NULLIF(COUNT(*), 0),
        2
    )
        AS TABLE_DESCRIPTION_COVERAGE_PCT

FROM GOVERNANCE.CATALOG.OBJECT_CATALOG

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING';


-- ============================================================================
-- 7. REQUIRED TAG TAXONOMY
--
-- Capture SHOW TAGS output into a temporary table so the final acceptance
-- query can use immediate metadata rather than delayed ACCOUNT_USAGE.
-- ============================================================================

SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;


CREATE OR REPLACE TEMP TABLE TMP_FOUNDATION_TAGS AS

SELECT
    UPPER("name") AS TAG_NAME
FROM TABLE
(
    RESULT_SCAN(LAST_QUERY_ID())
);


SELECT
    R.TAG_NAME,
    CASE
        WHEN T.TAG_NAME IS NOT NULL THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS
FROM
(
    SELECT COLUMN1::VARCHAR AS TAG_NAME
    FROM VALUES
        ('DOMAIN'),
        ('LAYER'),
        ('CERTIFICATION'),
        ('DATA_OWNER'),
        ('DATA_STEWARD'),
        ('CDE'),
        ('CLASSIFICATION'),
        ('SOURCE_SYSTEM')
) R

LEFT JOIN TMP_FOUNDATION_TAGS T
       ON T.TAG_NAME = R.TAG_NAME

ORDER BY R.TAG_NAME;


-- ============================================================================
-- 8. IMMEDIATE EFFECTIVE TAG SNAPSHOT FOR ALL RAW TABLES
--
-- TAG_REFERENCES includes direct and inherited tag evidence for each table.
-- ============================================================================

CREATE OR REPLACE TEMP TABLE TMP_RAW_TABLE_TAGS AS

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.BRANCH',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.PRODUCT',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.OFFICER',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.CUSTOMER',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.ACCOUNT',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.ACCOUNT_DAILY_BALANCE',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.TRANSACTIONS',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.CARD',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.LOAN',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.LOAN_COLLATERAL',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'RAW.BANKING.GL_CONTROL_TOTAL',
        'TABLE'
    )
);


-- Effective table-level governance metadata.
-- SOURCE_SYSTEM is intentionally included: if it is missing, Block 1 still
-- has a real metadata-foundation gap to close before classification.

WITH TAG_PIVOT AS
(
    SELECT
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,

        MAX(IFF(TAG_NAME = 'LAYER',         TAG_VALUE, NULL)) AS LAYER_TAG,
        MAX(IFF(TAG_NAME = 'DOMAIN',        TAG_VALUE, NULL)) AS DOMAIN_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',    TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD',  TAG_VALUE, NULL)) AS STEWARD_TAG,
        MAX(IFF(TAG_NAME = 'SOURCE_SYSTEM', TAG_VALUE, NULL)) AS SOURCE_SYSTEM_TAG

    FROM TMP_RAW_TABLE_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME
)

SELECT
    OBJECT_NAME,
    LAYER_TAG,
    DOMAIN_TAG,
    OWNER_TAG,
    STEWARD_TAG,
    SOURCE_SYSTEM_TAG,

    CASE
        WHEN LAYER_TAG         IS NOT NULL
         AND DOMAIN_TAG        IS NOT NULL
         AND OWNER_TAG         IS NOT NULL
         AND STEWARD_TAG       IS NOT NULL
         AND SOURCE_SYSTEM_TAG IS NOT NULL
        THEN 'PASS'
        ELSE 'FAIL'
    END AS GOVERNANCE_TAG_STATUS

FROM TAG_PIVOT

ORDER BY OBJECT_NAME;


-- ============================================================================
-- 9. IMMEDIATE EFFECTIVE TAG SNAPSHOT FOR ALL RAW COLUMNS
--
-- TAG_REFERENCES_ALL_COLUMNS provides immediate effective tag evidence for
-- every column in a table and includes APPLY_METHOD.
-- ============================================================================

CREATE OR REPLACE TEMP TABLE TMP_RAW_COLUMN_TAGS AS

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.BRANCH',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.PRODUCT',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.OFFICER',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.CUSTOMER',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.ACCOUNT',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.ACCOUNT_DAILY_BALANCE',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.TRANSACTIONS',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.CARD',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.LOAN',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.LOAN_COLLATERAL',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.GL_CONTROL_TOTAL',
        'TABLE'
    )
);


-- ============================================================================
-- 10. GOVERNED BANKING GLOSSARY
--
-- Expected:
--      APPROVED_TERMS >= 10
--      LINKED_TERMS   >= 10
--      INVALID_LINKS  = 0
-- ============================================================================

SELECT
    COUNT_IF(STATUS = 'APPROVED')
        AS APPROVED_TERMS

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM;


SELECT
    COUNT(DISTINCT TERM_ID)
        AS LINKED_TERMS,

    COUNT(*)
        AS ACTIVE_GLOSSARY_LINKS

FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK

WHERE ACTIVE_FLAG = TRUE;


SELECT
    L.TERM_ID,
    L.DATABASE_NAME,
    L.SCHEMA_NAME,
    L.TABLE_NAME,
    L.COLUMN_NAME

FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK L

LEFT JOIN GOVERNANCE.CATALOG.COLUMN_CATALOG C
       ON C.DATABASE_NAME = L.DATABASE_NAME
      AND C.SCHEMA_NAME   = L.SCHEMA_NAME
      AND C.TABLE_NAME    = L.TABLE_NAME
      AND C.COLUMN_NAME   = L.COLUMN_NAME

WHERE L.ACTIVE_FLAG = TRUE
  AND C.COLUMN_NAME IS NULL

ORDER BY
    L.TERM_ID,
    L.TABLE_NAME,
    L.COLUMN_NAME;


-- ============================================================================
-- 11. CDE REGISTRY
--
-- Expected:
--      ACTIVE_CDES >= 25
--      MISSING_OWNER = 0
--      MISSING_STEWARD = 0
--      MISSING_DEFINITION = 0
-- ============================================================================

SELECT
    COUNT(*) AS ACTIVE_CDES,

    COUNT_IF
    (
        DATA_OWNER IS NULL
        OR TRIM(DATA_OWNER) = ''
    )
        AS MISSING_OWNER,

    COUNT_IF
    (
        DATA_STEWARD IS NULL
        OR TRIM(DATA_STEWARD) = ''
    )
        AS MISSING_STEWARD,

    COUNT_IF
    (
        BUSINESS_DEFINITION IS NULL
        OR TRIM(BUSINESS_DEFINITION) = ''
    )
        AS MISSING_DEFINITION

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE;


-- ============================================================================
-- 12. CDE REGISTRY -> TAG_ASSIGNMENT SYNCHRONIZATION
--
-- 05_sync_cde_tags.sql creates three desired-state assignments per active CDE:
--
--      CDE
--      DATA_OWNER
--      DATA_STEWARD
--
-- Expected for 25 CDEs:
--      75 active CDE_REGISTRY tag assignments
-- ============================================================================

SELECT
    COUNT(*) AS ACTIVE_CDE_TAG_ASSIGNMENTS,

    COUNT_IF(TAG_NAME = 'CDE')
        AS CDE_ASSIGNMENTS,

    COUNT_IF(TAG_NAME = 'DATA_OWNER')
        AS OWNER_ASSIGNMENTS,

    COUNT_IF(TAG_NAME = 'DATA_STEWARD')
        AS STEWARD_ASSIGNMENTS

FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT

WHERE ACTIVE_FLAG = TRUE
  AND SOURCE_TYPE = 'CDE_REGISTRY';


-- ============================================================================
-- 13. NATIVE CDE TAG EVIDENCE
--
-- Compare the effective Snowflake tags against the CDE_REGISTRY itself.
--
-- Expected:
--      CDE_TAG_MATCH        = ACTIVE_CDES
--      OWNER_TAG_MATCH      = ACTIVE_CDES
--      STEWARD_TAG_MATCH    = ACTIVE_CDES
--      COMPLETE_TAGGED_CDES = ACTIVE_CDES
-- ============================================================================

WITH COLUMN_TAG_PIVOT AS
(
    SELECT
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX(IFF(TAG_NAME = 'CDE',          TAG_VALUE, NULL)) AS CDE_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',   TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD', TAG_VALUE, NULL)) AS STEWARD_TAG

    FROM TMP_RAW_COLUMN_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
)

SELECT
    COUNT(*) AS ACTIVE_CDES,

    COUNT_IF(P.CDE_TAG = R.CDE_TIER)
        AS CDE_TAG_MATCH,

    COUNT_IF(P.OWNER_TAG = R.DATA_OWNER)
        AS OWNER_TAG_MATCH,

    COUNT_IF(P.STEWARD_TAG = R.DATA_STEWARD)
        AS STEWARD_TAG_MATCH,

    COUNT_IF
    (
           P.CDE_TAG     = R.CDE_TIER
       AND P.OWNER_TAG   = R.DATA_OWNER
       AND P.STEWARD_TAG = R.DATA_STEWARD
    )
        AS COMPLETE_TAGGED_CDES

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN COLUMN_TAG_PIVOT P
       ON P.OBJECT_DATABASE = R.DATABASE_NAME
      AND P.OBJECT_SCHEMA   = R.SCHEMA_NAME
      AND P.OBJECT_NAME     = R.TABLE_NAME
      AND P.COLUMN_NAME     = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE;


-- Detailed failures only.
-- Expected:
--      0 rows

WITH COLUMN_TAG_PIVOT AS
(
    SELECT
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX(IFF(TAG_NAME = 'CDE',          TAG_VALUE, NULL)) AS CDE_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',   TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD', TAG_VALUE, NULL)) AS STEWARD_TAG

    FROM TMP_RAW_COLUMN_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
)

SELECT
    R.TABLE_NAME,
    R.COLUMN_NAME,

    R.CDE_TIER     AS EXPECTED_CDE,
    P.CDE_TAG      AS ACTUAL_CDE,

    R.DATA_OWNER   AS EXPECTED_OWNER,
    P.OWNER_TAG    AS ACTUAL_OWNER,

    R.DATA_STEWARD AS EXPECTED_STEWARD,
    P.STEWARD_TAG  AS ACTUAL_STEWARD

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN COLUMN_TAG_PIVOT P
       ON P.OBJECT_DATABASE = R.DATABASE_NAME
      AND P.OBJECT_SCHEMA   = R.SCHEMA_NAME
      AND P.OBJECT_NAME     = R.TABLE_NAME
      AND P.COLUMN_NAME     = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE

  AND
  (
         COALESCE(P.CDE_TAG, '')     <> COALESCE(R.CDE_TIER, '')
      OR COALESCE(P.OWNER_TAG, '')   <> COALESCE(R.DATA_OWNER, '')
      OR COALESCE(P.STEWARD_TAG, '') <> COALESCE(R.DATA_STEWARD, '')
  )

ORDER BY
    R.TABLE_NAME,
    R.COLUMN_NAME;


-- ============================================================================
-- 14. DIRECT CDE TAG EVIDENCE / APPLY METHOD
--
-- Because 05_sync_cde_tags.sql creates direct column assignments, the CDE,
-- owner and steward evidence should normally have APPLY_METHOD = MANUAL.
--
-- This query is useful for the evidence pack.
-- ============================================================================

SELECT
    OBJECT_NAME AS TABLE_NAME,
    COLUMN_NAME,
    TAG_NAME,
    TAG_VALUE,
    APPLY_METHOD,
    LEVEL

FROM TMP_RAW_COLUMN_TAGS

WHERE TAG_DATABASE = 'GOVERNANCE'
  AND TAG_SCHEMA   = 'TAGS'
  AND TAG_NAME IN
      (
          'CDE',
          'DATA_OWNER',
          'DATA_STEWARD'
      )

ORDER BY
    TABLE_NAME,
    COLUMN_NAME,
    TAG_NAME;


-- ============================================================================
-- 15. FINAL BLOCK 1 ACCEPTANCE SUMMARY
--
-- This is the compact evidence query for the Metadata Foundation.
--
-- PASS criteria intentionally exclude confirmed CLASSIFICATION and
-- CERTIFICATION values because those belong to later blocks.
-- ============================================================================

WITH

RAW_COLUMN_STATS AS
(
    SELECT
        COUNT(*) AS TOTAL_COLUMNS,

        COUNT_IF
        (
            COMMENT IS NOT NULL
            AND TRIM(COMMENT) <> ''
        )
            AS DESCRIBED_COLUMNS

    FROM GOVERNANCE.CATALOG.COLUMN_CATALOG

    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
),

DICTIONARY_STATS AS
(
    SELECT
        COUNT(*) AS DICTIONARY_ROWS,

        COUNT_IF
        (
            DESCRIPTION IS NOT NULL
            AND TRIM(DESCRIPTION) <> ''
        )
            AS DESCRIBED_DICTIONARY_ROWS

    FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
),

GLOSSARY_STATS AS
(
    SELECT
        COUNT_IF(STATUS = 'APPROVED')
            AS APPROVED_TERMS

    FROM GOVERNANCE.CATALOG.GLOSSARY_TERM
),

GLOSSARY_LINK_STATS AS
(
    SELECT
        COUNT(DISTINCT TERM_ID)
            AS LINKED_TERMS

    FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK

    WHERE ACTIVE_FLAG = TRUE
),

CDE_STATS AS
(
    SELECT
        COUNT(*) AS ACTIVE_CDES,

        COUNT_IF
        (
            DATA_OWNER IS NULL
            OR TRIM(DATA_OWNER) = ''
        )
            AS MISSING_OWNER,

        COUNT_IF
        (
            DATA_STEWARD IS NULL
            OR TRIM(DATA_STEWARD) = ''
        )
            AS MISSING_STEWARD,

        COUNT_IF
        (
            BUSINESS_DEFINITION IS NULL
            OR TRIM(BUSINESS_DEFINITION) = ''
        )
            AS MISSING_DEFINITION

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY

    WHERE ACTIVE_FLAG = TRUE
),

CDE_ASSIGNMENT_STATS AS
(
    SELECT
        COUNT_IF(TAG_NAME = 'CDE')
            AS CDE_ASSIGNMENTS,

        COUNT_IF(TAG_NAME = 'DATA_OWNER')
            AS OWNER_ASSIGNMENTS,

        COUNT_IF(TAG_NAME = 'DATA_STEWARD')
            AS STEWARD_ASSIGNMENTS

    FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT

    WHERE ACTIVE_FLAG = TRUE
      AND SOURCE_TYPE = 'CDE_REGISTRY'
),

COLUMN_TAG_PIVOT AS
(
    SELECT
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX(IFF(TAG_NAME = 'CDE',          TAG_VALUE, NULL)) AS CDE_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',   TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD', TAG_VALUE, NULL)) AS STEWARD_TAG

    FROM TMP_RAW_COLUMN_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
),

CDE_NATIVE_TAG_STATS AS
(
    SELECT
        COUNT(*) AS ACTIVE_CDES,

        COUNT_IF
        (
               P.CDE_TAG     = R.CDE_TIER
           AND P.OWNER_TAG   = R.DATA_OWNER
           AND P.STEWARD_TAG = R.DATA_STEWARD
        )
            AS COMPLETE_TAGGED_CDES

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

    LEFT JOIN COLUMN_TAG_PIVOT P
           ON P.OBJECT_DATABASE = R.DATABASE_NAME
          AND P.OBJECT_SCHEMA   = R.SCHEMA_NAME
          AND P.OBJECT_NAME     = R.TABLE_NAME
          AND P.COLUMN_NAME     = R.COLUMN_NAME

    WHERE R.ACTIVE_FLAG = TRUE
),

TAG_TAXONOMY_STATS AS
(
    SELECT
        COUNT(DISTINCT T.TAG_NAME)
            AS REQUIRED_TAGS_PRESENT

    FROM
    (
        SELECT COLUMN1::VARCHAR AS TAG_NAME
        FROM VALUES
            ('DOMAIN'),
            ('LAYER'),
            ('CERTIFICATION'),
            ('DATA_OWNER'),
            ('DATA_STEWARD'),
            ('CDE'),
            ('CLASSIFICATION'),
            ('SOURCE_SYSTEM')
    ) R

    INNER JOIN TMP_FOUNDATION_TAGS T
            ON T.TAG_NAME = R.TAG_NAME
),

RAW_TABLE_TAG_PIVOT AS
(
    SELECT
        OBJECT_NAME,

        MAX(IFF(TAG_NAME = 'LAYER',         TAG_VALUE, NULL)) AS LAYER_TAG,
        MAX(IFF(TAG_NAME = 'DOMAIN',        TAG_VALUE, NULL)) AS DOMAIN_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',    TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD',  TAG_VALUE, NULL)) AS STEWARD_TAG,
        MAX(IFF(TAG_NAME = 'SOURCE_SYSTEM', TAG_VALUE, NULL)) AS SOURCE_SYSTEM_TAG

    FROM TMP_RAW_TABLE_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY OBJECT_NAME
),

RAW_TABLE_TAG_STATS AS
(
    SELECT
        COUNT(*) AS RAW_TABLES_WITH_TAGS,

        COUNT_IF
        (
               LAYER_TAG         IS NOT NULL
           AND DOMAIN_TAG        IS NOT NULL
           AND OWNER_TAG         IS NOT NULL
           AND STEWARD_TAG       IS NOT NULL
        )
            AS RAW_TABLES_WITH_BASE_GOVERNANCE,

        COUNT_IF
        (
            SOURCE_SYSTEM_TAG IS NOT NULL
        )
            AS RAW_TABLES_WITH_SOURCE_SYSTEM

    FROM RAW_TABLE_TAG_PIVOT
),

HARVEST_STATS AS
(
    SELECT
        (SELECT COUNT(*)
         FROM GOVERNANCE.CATALOG.OBJECT_CATALOG
         WHERE DATABASE_NAME = 'RAW'
           AND SCHEMA_NAME = 'BANKING')
            AS RAW_OBJECTS,

        (SELECT COUNT(*)
         FROM GOVERNANCE.CATALOG.COLUMN_CATALOG
         WHERE DATABASE_NAME = 'RAW'
           AND SCHEMA_NAME = 'BANKING')
            AS RAW_COLUMNS
)

SELECT *
FROM
(
    SELECT
        1 AS CONTROL_ORDER,
        'Technical metadata harvested' AS CONTROL,
        HARVEST_STATS.RAW_OBJECTS || ' objects / '
        || HARVEST_STATS.RAW_COLUMNS || ' columns' AS ACTUAL,
        '> 0 objects and columns' AS EXPECTED,
        IFF
        (
            HARVEST_STATS.RAW_OBJECTS > 0
            AND HARVEST_STATS.RAW_COLUMNS > 0,
            'PASS',
            'FAIL'
        ) AS STATUS
    FROM HARVEST_STATS

    UNION ALL

    SELECT
        2,
        'RAW dictionary coverage',
        DICTIONARY_STATS.DICTIONARY_ROWS || ' / '
        || RAW_COLUMN_STATS.TOTAL_COLUMNS,
        'dictionary rows = RAW columns',
        IFF
        (
            DICTIONARY_STATS.DICTIONARY_ROWS
                = RAW_COLUMN_STATS.TOTAL_COLUMNS,
            'PASS',
            'FAIL'
        )
    FROM DICTIONARY_STATS
    CROSS JOIN RAW_COLUMN_STATS

    UNION ALL

    SELECT
        3,
        'RAW harvested column descriptions',
        RAW_COLUMN_STATS.DESCRIBED_COLUMNS || ' / '
        || RAW_COLUMN_STATS.TOTAL_COLUMNS,
        '100% described',
        IFF
        (
            RAW_COLUMN_STATS.DESCRIBED_COLUMNS
                = RAW_COLUMN_STATS.TOTAL_COLUMNS,
            'PASS',
            'FAIL'
        )
    FROM RAW_COLUMN_STATS

    UNION ALL

    SELECT
        4,
        'Required governance tag taxonomy',
        TAG_TAXONOMY_STATS.REQUIRED_TAGS_PRESENT || ' / 8',
        '8 required tags',
        IFF
        (
            TAG_TAXONOMY_STATS.REQUIRED_TAGS_PRESENT = 8,
            'PASS',
            'FAIL'
        )
    FROM TAG_TAXONOMY_STATS

    UNION ALL

    SELECT
        5,
        'RAW base governance tag coverage',
        RAW_TABLE_TAG_STATS.RAW_TABLES_WITH_BASE_GOVERNANCE
        || ' / 11 tables',
        '11 / 11',
        IFF
        (
            RAW_TABLE_TAG_STATS.RAW_TABLES_WITH_BASE_GOVERNANCE = 11,
            'PASS',
            'FAIL'
        )
    FROM RAW_TABLE_TAG_STATS

    UNION ALL

    SELECT
        6,
        'RAW SOURCE_SYSTEM tag coverage',
        RAW_TABLE_TAG_STATS.RAW_TABLES_WITH_SOURCE_SYSTEM
        || ' / 11 tables',
        '11 / 11',
        IFF
        (
            RAW_TABLE_TAG_STATS.RAW_TABLES_WITH_SOURCE_SYSTEM = 11,
            'PASS',
            'FAIL'
        )
    FROM RAW_TABLE_TAG_STATS

    UNION ALL

    SELECT
        7,
        'Approved banking glossary terms',
        GLOSSARY_STATS.APPROVED_TERMS::VARCHAR,
        '>= 10',
        IFF
        (
            GLOSSARY_STATS.APPROVED_TERMS >= 10,
            'PASS',
            'FAIL'
        )
    FROM GLOSSARY_STATS

    UNION ALL

    SELECT
        8,
        'Glossary terms linked to columns',
        GLOSSARY_LINK_STATS.LINKED_TERMS::VARCHAR,
        '>= 10',
        IFF
        (
            GLOSSARY_LINK_STATS.LINKED_TERMS >= 10,
            'PASS',
            'FAIL'
        )
    FROM GLOSSARY_LINK_STATS

    UNION ALL

    SELECT
        9,
        'Active Critical Data Elements',
        CDE_STATS.ACTIVE_CDES::VARCHAR,
        '>= 25',
        IFF
        (
            CDE_STATS.ACTIVE_CDES >= 25,
            'PASS',
            'FAIL'
        )
    FROM CDE_STATS

    UNION ALL

    SELECT
        10,
        'CDE owner/steward/definition completeness',
        'owner_missing=' || CDE_STATS.MISSING_OWNER
        || ', steward_missing=' || CDE_STATS.MISSING_STEWARD
        || ', definition_missing=' || CDE_STATS.MISSING_DEFINITION,
        'all missing counts = 0',
        IFF
        (
               CDE_STATS.MISSING_OWNER = 0
           AND CDE_STATS.MISSING_STEWARD = 0
           AND CDE_STATS.MISSING_DEFINITION = 0,
            'PASS',
            'FAIL'
        )
    FROM CDE_STATS

    UNION ALL

    SELECT
        11,
        'CDE registry synchronized to TAG_ASSIGNMENT',
        'CDE=' || CDE_ASSIGNMENT_STATS.CDE_ASSIGNMENTS
        || ', owner=' || CDE_ASSIGNMENT_STATS.OWNER_ASSIGNMENTS
        || ', steward=' || CDE_ASSIGNMENT_STATS.STEWARD_ASSIGNMENTS,
        'each count = active CDE count',
        IFF
        (
               CDE_ASSIGNMENT_STATS.CDE_ASSIGNMENTS
                    = CDE_STATS.ACTIVE_CDES
           AND CDE_ASSIGNMENT_STATS.OWNER_ASSIGNMENTS
                    = CDE_STATS.ACTIVE_CDES
           AND CDE_ASSIGNMENT_STATS.STEWARD_ASSIGNMENTS
                    = CDE_STATS.ACTIVE_CDES,
            'PASS',
            'FAIL'
        )
    FROM CDE_ASSIGNMENT_STATS
    CROSS JOIN CDE_STATS

    UNION ALL

    SELECT
        12,
        'Native CDE + owner + steward tag evidence',
        CDE_NATIVE_TAG_STATS.COMPLETE_TAGGED_CDES || ' / '
        || CDE_NATIVE_TAG_STATS.ACTIVE_CDES,
        'all active CDEs',
        IFF
        (
            CDE_NATIVE_TAG_STATS.COMPLETE_TAGGED_CDES
                = CDE_NATIVE_TAG_STATS.ACTIVE_CDES,
            'PASS',
            'FAIL'
        )
    FROM CDE_NATIVE_TAG_STATS

) FOUNDATION_ACCEPTANCE

ORDER BY CONTROL_ORDER;


-- ============================================================================
-- 16. OVERALL BLOCK 1 RESULT
--
-- This compact result intentionally reuses the key persisted/runtime criteria.
--
-- IMPORTANT:
-- If RAW SOURCE_SYSTEM tag coverage fails, add/fix source-system assignments
-- before declaring Block 1 complete.
-- ============================================================================

WITH

RAW_COLUMNS AS
(
    SELECT
        COUNT(*) AS TOTAL_COLUMNS,
        COUNT_IF(COMMENT IS NOT NULL AND TRIM(COMMENT) <> '')
            AS DESCRIBED_COLUMNS

    FROM GOVERNANCE.CATALOG.COLUMN_CATALOG

    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
),

DICTIONARY AS
(
    SELECT COUNT(*) AS ROWS_COUNT
    FROM GOVERNANCE.CATALOG.DATA_DICTIONARY
    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
),

GLOSSARY AS
(
    SELECT COUNT_IF(STATUS = 'APPROVED') AS APPROVED_TERMS
    FROM GOVERNANCE.CATALOG.GLOSSARY_TERM
),

LINKS AS
(
    SELECT COUNT(DISTINCT TERM_ID) AS LINKED_TERMS
    FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK
    WHERE ACTIVE_FLAG = TRUE
),

CDES AS
(
    SELECT
        COUNT(*) AS ACTIVE_CDES,
        COUNT_IF
        (
               DATA_OWNER IS NULL
            OR TRIM(DATA_OWNER) = ''
            OR DATA_STEWARD IS NULL
            OR TRIM(DATA_STEWARD) = ''
            OR BUSINESS_DEFINITION IS NULL
            OR TRIM(BUSINESS_DEFINITION) = ''
        )
            AS INCOMPLETE_CDES
    FROM GOVERNANCE.CATALOG.CDE_REGISTRY
    WHERE ACTIVE_FLAG = TRUE
),

REQUIRED_TAGS AS
(
    SELECT COUNT(DISTINCT T.TAG_NAME) AS PRESENT
    FROM
    (
        SELECT COLUMN1::VARCHAR AS TAG_NAME
        FROM VALUES
            ('DOMAIN'),
            ('LAYER'),
            ('CERTIFICATION'),
            ('DATA_OWNER'),
            ('DATA_STEWARD'),
            ('CDE'),
            ('CLASSIFICATION'),
            ('SOURCE_SYSTEM')
    ) R
    INNER JOIN TMP_FOUNDATION_TAGS T
            ON T.TAG_NAME = R.TAG_NAME
),

TABLE_TAGS AS
(
    SELECT
        OBJECT_NAME,

        MAX(IFF(TAG_NAME = 'LAYER',         TAG_VALUE, NULL)) AS LAYER_TAG,
        MAX(IFF(TAG_NAME = 'DOMAIN',        TAG_VALUE, NULL)) AS DOMAIN_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',    TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD',  TAG_VALUE, NULL)) AS STEWARD_TAG,
        MAX(IFF(TAG_NAME = 'SOURCE_SYSTEM', TAG_VALUE, NULL)) AS SOURCE_SYSTEM_TAG

    FROM TMP_RAW_TABLE_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY OBJECT_NAME
),

TABLE_TAG_STATS AS
(
    SELECT
        COUNT_IF
        (
               LAYER_TAG         IS NOT NULL
           AND DOMAIN_TAG        IS NOT NULL
           AND OWNER_TAG         IS NOT NULL
           AND STEWARD_TAG       IS NOT NULL
           AND SOURCE_SYSTEM_TAG IS NOT NULL
        )
            AS COMPLETE_RAW_TABLES

    FROM TABLE_TAGS
),

COLUMN_TAGS AS
(
    SELECT
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX(IFF(TAG_NAME = 'CDE',          TAG_VALUE, NULL)) AS CDE_TAG,
        MAX(IFF(TAG_NAME = 'DATA_OWNER',   TAG_VALUE, NULL)) AS OWNER_TAG,
        MAX(IFF(TAG_NAME = 'DATA_STEWARD', TAG_VALUE, NULL)) AS STEWARD_TAG

    FROM TMP_RAW_COLUMN_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
),

NATIVE_CDES AS
(
    SELECT
        COUNT(*) AS ACTIVE_CDES,

        COUNT_IF
        (
               T.CDE_TAG     = R.CDE_TIER
           AND T.OWNER_TAG   = R.DATA_OWNER
           AND T.STEWARD_TAG = R.DATA_STEWARD
        )
            AS COMPLETE_TAGGED_CDES

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

    LEFT JOIN COLUMN_TAGS T
           ON T.OBJECT_DATABASE = R.DATABASE_NAME
          AND T.OBJECT_SCHEMA   = R.SCHEMA_NAME
          AND T.OBJECT_NAME     = R.TABLE_NAME
          AND T.COLUMN_NAME     = R.COLUMN_NAME

    WHERE R.ACTIVE_FLAG = TRUE
)

SELECT

    CASE
        WHEN RAW_COLUMNS.TOTAL_COLUMNS > 0

         AND RAW_COLUMNS.DESCRIBED_COLUMNS
                = RAW_COLUMNS.TOTAL_COLUMNS

         AND DICTIONARY.ROWS_COUNT
                = RAW_COLUMNS.TOTAL_COLUMNS

         AND REQUIRED_TAGS.PRESENT = 8

         AND TABLE_TAG_STATS.COMPLETE_RAW_TABLES = 11

         AND GLOSSARY.APPROVED_TERMS >= 10

         AND LINKS.LINKED_TERMS >= 10

         AND CDES.ACTIVE_CDES >= 25

         AND CDES.INCOMPLETE_CDES = 0

         AND NATIVE_CDES.COMPLETE_TAGGED_CDES
                = NATIVE_CDES.ACTIVE_CDES

        THEN 'PASS - BLOCK 1 METADATA FOUNDATION COMPLETE'

        ELSE 'FAIL - REVIEW FAILED CONTROLS ABOVE'

    END AS BLOCK_1_STATUS

FROM RAW_COLUMNS
CROSS JOIN DICTIONARY
CROSS JOIN GLOSSARY
CROSS JOIN LINKS
CROSS JOIN CDES
CROSS JOIN REQUIRED_TAGS
CROSS JOIN TABLE_TAG_STATS
CROSS JOIN NATIVE_CDES;
