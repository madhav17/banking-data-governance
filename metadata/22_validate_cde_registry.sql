/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/22_validate_cde_registry.sql

  Purpose:
      Validate the Critical Data Element registry before synchronizing CDE,
      DATA_OWNER and DATA_STEWARD tags into Snowflake.

  Expected:
      - At least 25 active CDEs
      - No duplicate CDE physical keys
      - Every CDE exists physically
      - Every CDE has definition, domain, tier, owner and steward
      - All CDEs have a source dictionary definition
      - All three CDE tiers are represented
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. CDE REQUIREMENT SUMMARY
--
-- Requirement:
--      At least 25 active Critical Data Elements.
--
-- Use >= 25 rather than = 25 because the live review may add another CDE.
-- ============================================================================

SELECT

    COUNT_IF(ACTIVE_FLAG = TRUE)
        AS ACTIVE_CDE_COUNT,

    CASE

        WHEN COUNT_IF(ACTIVE_FLAG = TRUE) >= 25
            THEN 'PASS'

        ELSE 'FAIL'

    END
        AS CDE_COUNT_STATUS

FROM GOVERNANCE.CATALOG.CDE_REGISTRY;



-- ============================================================================
-- 3. CDE TIER DISTRIBUTION
--
-- Demonstrates that criticality is tiered rather than binary.
-- ============================================================================

SELECT

    CDE_TIER,

    COUNT(*) AS CDE_COUNT

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE

GROUP BY CDE_TIER

ORDER BY CDE_TIER;



-- ============================================================================
-- 4. DOMAIN DISTRIBUTION
-- ============================================================================

SELECT

    DATA_DOMAIN,

    COUNT(*) AS CDE_COUNT

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE

GROUP BY DATA_DOMAIN

ORDER BY DATA_DOMAIN;



-- ============================================================================
-- 5. DUPLICATE CDE PHYSICAL KEYS
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,

    COUNT(*) AS RECORD_COUNT

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

GROUP BY
    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME

HAVING COUNT(*) > 1;



-- ============================================================================
-- 6. ACTIVE CDEs MISSING REQUIRED GOVERNANCE METADATA
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,

    CDE_TIER,
    BUSINESS_NAME,
    BUSINESS_DEFINITION,
    DATA_DOMAIN,
    DATA_OWNER,
    DATA_STEWARD

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE

  AND
  (
         CDE_TIER IS NULL
      OR TRIM(CDE_TIER) = ''

      OR BUSINESS_NAME IS NULL
      OR TRIM(BUSINESS_NAME) = ''

      OR BUSINESS_DEFINITION IS NULL
      OR TRIM(BUSINESS_DEFINITION) = ''

      OR DATA_DOMAIN IS NULL
      OR TRIM(DATA_DOMAIN) = ''

      OR DATA_OWNER IS NULL
      OR TRIM(DATA_OWNER) = ''

      OR DATA_STEWARD IS NULL
      OR TRIM(DATA_STEWARD) = ''
  )

ORDER BY
    TABLE_NAME,
    COLUMN_NAME;



-- ============================================================================
-- 7. ACTIVE CDEs THAT DO NOT EXIST PHYSICALLY
--
-- COLUMN_CATALOG is the harvested technical metadata source of truth.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    R.DATABASE_NAME,
    R.SCHEMA_NAME,
    R.TABLE_NAME,
    R.COLUMN_NAME,
    R.CDE_TIER

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN GOVERNANCE.CATALOG.COLUMN_CATALOG C

       ON C.DATABASE_NAME = R.DATABASE_NAME
      AND C.SCHEMA_NAME   = R.SCHEMA_NAME
      AND C.TABLE_NAME    = R.TABLE_NAME
      AND C.COLUMN_NAME   = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE

  AND C.COLUMN_NAME IS NULL

ORDER BY
    R.TABLE_NAME,
    R.COLUMN_NAME;



-- ============================================================================
-- 8. CDEs WITHOUT DATA DICTIONARY DEFINITIONS
--
-- The CDE registry should build on the already governed dictionary rather
-- than create disconnected business definitions.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    R.TABLE_NAME,
    R.COLUMN_NAME,
    R.CDE_TIER

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN GOVERNANCE.CATALOG.DATA_DICTIONARY D

       ON D.DATABASE_NAME = R.DATABASE_NAME
      AND D.SCHEMA_NAME   = R.SCHEMA_NAME
      AND D.TABLE_NAME    = R.TABLE_NAME
      AND D.COLUMN_NAME   = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE

  AND
  (
         D.COLUMN_NAME IS NULL
      OR D.DESCRIPTION IS NULL
      OR TRIM(D.DESCRIPTION) = ''
  )

ORDER BY
    R.TABLE_NAME,
    R.COLUMN_NAME;



-- ============================================================================
-- 9. CDEs WITH DQ CONTROL DISABLED
--
-- For the initial governed seed, all 25 CDEs are expected to require DQ.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    TABLE_NAME,
    COLUMN_NAME,
    CDE_TIER,
    DQ_REQUIRED

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE

  AND COALESCE(DQ_REQUIRED, FALSE) = FALSE

ORDER BY
    TABLE_NAME,
    COLUMN_NAME;



-- ============================================================================
-- 10. OWNER / STEWARD COVERAGE
--
-- Expected:
--      OWNER_COVERAGE_PCT   = 100.00
--      STEWARD_COVERAGE_PCT = 100.00
-- ============================================================================

SELECT

    COUNT(*) AS ACTIVE_CDES,

    COUNT_IF
    (
        DATA_OWNER IS NOT NULL
        AND TRIM(DATA_OWNER) <> ''
    )
        AS CDE_WITH_OWNER,

    COUNT_IF
    (
        DATA_STEWARD IS NOT NULL
        AND TRIM(DATA_STEWARD) <> ''
    )
        AS CDE_WITH_STEWARD,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              DATA_OWNER IS NOT NULL
              AND TRIM(DATA_OWNER) <> ''
          )
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS OWNER_COVERAGE_PCT,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              DATA_STEWARD IS NOT NULL
              AND TRIM(DATA_STEWARD) <> ''
          )
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS STEWARD_COVERAGE_PCT

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE;



-- ============================================================================
-- 11. FINAL CDE REGISTER
--
-- Useful as evidence before native tag synchronization.
-- ============================================================================

SELECT

    TABLE_NAME
        || '.'
        || COLUMN_NAME
            AS CDE,

    CDE_TIER,

    BUSINESS_NAME,

    BUSINESS_DEFINITION,

    DATA_DOMAIN,

    DATA_OWNER,

    DATA_STEWARD,

    BUSINESS_REASON,

    REGULATORY_RELEVANCE,

    DQ_REQUIRED

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE

ORDER BY
    CDE_TIER,
    DATA_DOMAIN,
    TABLE_NAME,
    COLUMN_NAME;

