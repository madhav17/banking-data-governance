/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/17_validate_description_coverage.sql

  Purpose:
      Prove that business descriptions from DATA_DICTIONARY have been applied
      as native Snowflake comments and harvested back into the custom
      governance metadata catalog.

  Validation layers:
      1. DATA_DICTIONARY                     -> expected descriptions
      2. RAW.INFORMATION_SCHEMA              -> native Snowflake comments
      3. GOVERNANCE.CATALOG                  -> harvested metadata copy

  Expected:
      - 100% native column description coverage
      - 0 columns missing comments
      - 0 dictionary/native comment mismatches
      - 100% native table description coverage
      - 0 tables missing comments
      - 100% harvested column description coverage
      - 100% harvested table description coverage
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. NATIVE COLUMN DESCRIPTION COVERAGE
--
-- INFORMATION_SCHEMA is used for immediate verification because it reflects
-- the current native Snowflake metadata state.
--
-- Expected:
--      NATIVE_COLUMN_DESCRIPTION_COVERAGE_PCT = 100.00
-- ============================================================================

SELECT

    COUNT(*) AS TOTAL_DICTIONARY_COLUMNS,

    COUNT_IF
    (
        C.COLUMN_NAME IS NOT NULL
    )
        AS PHYSICAL_COLUMNS_FOUND,

    COUNT_IF
    (
        C.COMMENT IS NOT NULL
        AND TRIM(C.COMMENT) <> ''
    )
        AS DESCRIBED_COLUMNS,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              C.COMMENT IS NOT NULL
              AND TRIM(C.COMMENT) <> ''
          )
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS NATIVE_COLUMN_DESCRIPTION_COVERAGE_PCT

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

LEFT JOIN RAW.INFORMATION_SCHEMA.COLUMNS C

       ON C.TABLE_CATALOG = D.DATABASE_NAME
      AND C.TABLE_SCHEMA  = D.SCHEMA_NAME
      AND C.TABLE_NAME    = D.TABLE_NAME
      AND C.COLUMN_NAME   = D.COLUMN_NAME

WHERE D.DATABASE_NAME = 'RAW'
  AND D.SCHEMA_NAME   = 'BANKING';



-- ============================================================================
-- 3. COLUMNS WITH MISSING NATIVE COMMENTS
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    D.TABLE_NAME,
    D.COLUMN_NAME,
    D.DESCRIPTION AS DICTIONARY_DESCRIPTION,
    C.COMMENT     AS SNOWFLAKE_COMMENT

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

LEFT JOIN RAW.INFORMATION_SCHEMA.COLUMNS C

       ON C.TABLE_CATALOG = D.DATABASE_NAME
      AND C.TABLE_SCHEMA  = D.SCHEMA_NAME
      AND C.TABLE_NAME    = D.TABLE_NAME
      AND C.COLUMN_NAME   = D.COLUMN_NAME

WHERE D.DATABASE_NAME = 'RAW'
  AND D.SCHEMA_NAME   = 'BANKING'

  AND
  (
         C.COLUMN_NAME IS NULL
      OR C.COMMENT IS NULL
      OR TRIM(C.COMMENT) = ''
  )

ORDER BY
    D.TABLE_NAME,
    D.COLUMN_NAME;



-- ============================================================================
-- 4. DICTIONARY DESCRIPTION VS NATIVE COMMENT MISMATCH
--
-- This validates content equality, not just presence.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    D.TABLE_NAME,
    D.COLUMN_NAME,

    D.DESCRIPTION
        AS EXPECTED_COMMENT,

    C.COMMENT
        AS ACTUAL_COMMENT

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

INNER JOIN RAW.INFORMATION_SCHEMA.COLUMNS C

        ON C.TABLE_CATALOG = D.DATABASE_NAME
       AND C.TABLE_SCHEMA  = D.SCHEMA_NAME
       AND C.TABLE_NAME    = D.TABLE_NAME
       AND C.COLUMN_NAME   = D.COLUMN_NAME

WHERE D.DATABASE_NAME = 'RAW'
  AND D.SCHEMA_NAME   = 'BANKING'

  AND COALESCE(TRIM(C.COMMENT), '')
      <> COALESCE(TRIM(D.DESCRIPTION), '')

ORDER BY
    D.TABLE_NAME,
    D.COLUMN_NAME;



-- ============================================================================
-- 5. NATIVE TABLE DESCRIPTION COVERAGE
--
-- DATA_DICTIONARY is column-grain, so DISTINCT TABLE_NAME defines the set
-- of RAW tables that are expected to have native table comments.
--
-- Expected:
--      TABLE_DESCRIPTION_COVERAGE_PCT = 100.00
-- ============================================================================

WITH DICTIONARY_TABLES AS
(
    SELECT DISTINCT

        TABLE_NAME

    FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
)

SELECT

    COUNT(*) AS TOTAL_DICTIONARY_TABLES,

    COUNT_IF
    (
        T.TABLE_NAME IS NOT NULL
    )
        AS PHYSICAL_TABLES_FOUND,

    COUNT_IF
    (
        T.COMMENT IS NOT NULL
        AND TRIM(T.COMMENT) <> ''
    )
        AS DESCRIBED_TABLES,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              T.COMMENT IS NOT NULL
              AND TRIM(T.COMMENT) <> ''
          )
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS TABLE_DESCRIPTION_COVERAGE_PCT

FROM DICTIONARY_TABLES D

LEFT JOIN RAW.INFORMATION_SCHEMA.TABLES T

       ON T.TABLE_CATALOG = 'RAW'
      AND T.TABLE_SCHEMA  = 'BANKING'
      AND T.TABLE_NAME    = D.TABLE_NAME;



-- ============================================================================
-- 6. TABLES WITH MISSING NATIVE COMMENTS
--
-- Expected:
--      0 rows
-- ============================================================================

WITH DICTIONARY_TABLES AS
(
    SELECT DISTINCT

        TABLE_NAME

    FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
)

SELECT

    D.TABLE_NAME,
    T.COMMENT

FROM DICTIONARY_TABLES D

LEFT JOIN RAW.INFORMATION_SCHEMA.TABLES T

       ON T.TABLE_CATALOG = 'RAW'
      AND T.TABLE_SCHEMA  = 'BANKING'
      AND T.TABLE_NAME    = D.TABLE_NAME

WHERE T.TABLE_NAME IS NULL
   OR T.COMMENT IS NULL
   OR TRIM(T.COMMENT) = ''

ORDER BY
    D.TABLE_NAME;



-- ============================================================================
-- 7. HARVESTED COLUMN DESCRIPTION COVERAGE
--
-- Verifies HARVEST_METADATA() copied native comments into COLUMN_CATALOG.
--
-- Expected:
--      HARVESTED_DESCRIPTION_COVERAGE_PCT = 100.00
-- ============================================================================

SELECT

    COUNT(*) AS HARVESTED_DICTIONARY_COLUMNS,

    COUNT_IF
    (
        C.COMMENT IS NOT NULL
        AND TRIM(C.COMMENT) <> ''
    )
        AS HARVESTED_DESCRIBED_COLUMNS,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              C.COMMENT IS NOT NULL
              AND TRIM(C.COMMENT) <> ''
          )
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS HARVESTED_DESCRIPTION_COVERAGE_PCT

FROM GOVERNANCE.CATALOG.COLUMN_CATALOG C

INNER JOIN GOVERNANCE.CATALOG.DATA_DICTIONARY D

        ON D.DATABASE_NAME = C.DATABASE_NAME
       AND D.SCHEMA_NAME   = C.SCHEMA_NAME
       AND D.TABLE_NAME    = C.TABLE_NAME
       AND D.COLUMN_NAME   = C.COLUMN_NAME

WHERE C.DATABASE_NAME = 'RAW'
  AND C.SCHEMA_NAME   = 'BANKING';



-- ============================================================================
-- 8. HARVESTED COLUMN COMMENT MISMATCHES
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    D.TABLE_NAME,
    D.COLUMN_NAME,

    D.DESCRIPTION
        AS EXPECTED_DESCRIPTION,

    C.COMMENT
        AS HARVESTED_COMMENT

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

LEFT JOIN GOVERNANCE.CATALOG.COLUMN_CATALOG C

       ON C.DATABASE_NAME = D.DATABASE_NAME
      AND C.SCHEMA_NAME   = D.SCHEMA_NAME
      AND C.TABLE_NAME    = D.TABLE_NAME
      AND C.COLUMN_NAME   = D.COLUMN_NAME

WHERE D.DATABASE_NAME = 'RAW'
  AND D.SCHEMA_NAME   = 'BANKING'

  AND
  (
         C.COLUMN_NAME IS NULL
      OR COALESCE(TRIM(C.COMMENT), '')
         <> COALESCE(TRIM(D.DESCRIPTION), '')
  )

ORDER BY
    D.TABLE_NAME,
    D.COLUMN_NAME;



-- ============================================================================
-- 9. HARVESTED TABLE DESCRIPTION COVERAGE
--
-- Verifies table comments were copied into OBJECT_CATALOG.
--
-- Expected:
--      HARVESTED_TABLE_DESCRIPTION_COVERAGE_PCT = 100.00
-- ============================================================================

WITH DICTIONARY_TABLES AS
(
    SELECT DISTINCT

        TABLE_NAME

    FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

    WHERE DATABASE_NAME = 'RAW'
      AND SCHEMA_NAME   = 'BANKING'
)

SELECT

    COUNT(*) AS RAW_DICTIONARY_TABLES,

    COUNT_IF
    (
        O.OBJECT_NAME IS NOT NULL
    )
        AS HARVESTED_TABLES_FOUND,

    COUNT_IF
    (
        O.OBJECT_COMMENT IS NOT NULL
        AND TRIM(O.OBJECT_COMMENT) <> ''
    )
        AS HARVESTED_DESCRIBED_TABLES,

    ROUND
    (
        100.0
        * COUNT_IF
          (
              O.OBJECT_COMMENT IS NOT NULL
              AND TRIM(O.OBJECT_COMMENT) <> ''
          )
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS HARVESTED_TABLE_DESCRIPTION_COVERAGE_PCT

FROM DICTIONARY_TABLES D

LEFT JOIN GOVERNANCE.CATALOG.OBJECT_CATALOG O

       ON O.DATABASE_NAME = 'RAW'
      AND O.SCHEMA_NAME   = 'BANKING'
      AND O.OBJECT_NAME   = D.TABLE_NAME;



-- ============================================================================
-- 10. FINAL DESCRIPTION COVERAGE SUMMARY
--
-- Compact evidence query for screenshots / evidence pack.
-- ============================================================================

WITH COLUMN_STATS AS
(
    SELECT

        COUNT(*) AS TOTAL_COLUMNS,

        COUNT_IF
        (
            C.COMMENT IS NOT NULL
            AND TRIM(C.COMMENT) <> ''
        )
            AS DESCRIBED_COLUMNS

    FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

    LEFT JOIN RAW.INFORMATION_SCHEMA.COLUMNS C

           ON C.TABLE_CATALOG = D.DATABASE_NAME
          AND C.TABLE_SCHEMA  = D.SCHEMA_NAME
          AND C.TABLE_NAME    = D.TABLE_NAME
          AND C.COLUMN_NAME   = D.COLUMN_NAME

    WHERE D.DATABASE_NAME = 'RAW'
      AND D.SCHEMA_NAME   = 'BANKING'
),

TABLE_STATS AS
(
    SELECT

        COUNT(*) AS TOTAL_TABLES,

        COUNT_IF
        (
            T.COMMENT IS NOT NULL
            AND TRIM(T.COMMENT) <> ''
        )
            AS DESCRIBED_TABLES

    FROM
    (
        SELECT DISTINCT
            TABLE_NAME

        FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

        WHERE DATABASE_NAME = 'RAW'
          AND SCHEMA_NAME   = 'BANKING'
    ) D

    LEFT JOIN RAW.INFORMATION_SCHEMA.TABLES T

           ON T.TABLE_CATALOG = 'RAW'
          AND T.TABLE_SCHEMA  = 'BANKING'
          AND T.TABLE_NAME    = D.TABLE_NAME
)

SELECT

    C.TOTAL_COLUMNS,

    C.DESCRIBED_COLUMNS,

    ROUND
    (
        100.0 * C.DESCRIBED_COLUMNS
        / NULLIF(C.TOTAL_COLUMNS, 0),
        2
    )
        AS COLUMN_DESCRIPTION_COVERAGE_PCT,

    T.TOTAL_TABLES,

    T.DESCRIBED_TABLES,

    ROUND
    (
        100.0 * T.DESCRIBED_TABLES
        / NULLIF(T.TOTAL_TABLES, 0),
        2
    )
        AS TABLE_DESCRIPTION_COVERAGE_PCT

FROM COLUMN_STATS C

CROSS JOIN TABLE_STATS T;
