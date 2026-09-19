/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/14_validate_data_dictionary.sql

  Purpose:
      Validate the loaded vendor data dictionary against the harvested
      Snowflake technical metadata.

  Expected:
      - No duplicate dictionary entries
      - No dictionary columns missing from Snowflake
      - No RAW columns missing from dictionary
      - No missing descriptions
      - 100% dictionary coverage
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. DUPLICATE DICTIONARY ROWS
--
-- Expected:
--      0 rows
--
-- Do not validate TMP_DATA_DICTIONARY_LOAD here.
-- It is a temporary table that only exists during file 13 execution.
-- ============================================================================

SELECT

    UPPER(TRIM(TABLE_NAME))  AS TABLE_NAME,
    UPPER(TRIM(COLUMN_NAME)) AS COLUMN_NAME,

    COUNT(*) AS RECORD_COUNT

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING'

GROUP BY
    UPPER(TRIM(TABLE_NAME)),
    UPPER(TRIM(COLUMN_NAME))

HAVING COUNT(*) > 1;



-- ============================================================================
-- 3. DICTIONARY ENTRIES THAT DO NOT EXIST IN SNOWFLAKE
--
-- Vendor dictionary says the column exists,
-- but COLUMN_CATALOG cannot find it.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    D.TABLE_NAME,
    D.COLUMN_NAME,
    D.EXPECTED_DATA_TYPE,
    D.DESCRIPTION

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

LEFT JOIN GOVERNANCE.CATALOG.COLUMN_CATALOG C

       ON C.DATABASE_NAME = D.DATABASE_NAME
      AND C.SCHEMA_NAME   = D.SCHEMA_NAME
      AND C.TABLE_NAME    = D.TABLE_NAME
      AND C.COLUMN_NAME   = D.COLUMN_NAME

WHERE D.DATABASE_NAME = 'RAW'
  AND D.SCHEMA_NAME   = 'BANKING'

  AND C.COLUMN_NAME IS NULL

ORDER BY
    D.TABLE_NAME,
    D.COLUMN_NAME;



-- ============================================================================
-- 4. PHYSICAL RAW COLUMNS MISSING FROM DICTIONARY
--
-- Snowflake contains the column,
-- but the vendor dictionary does not describe it.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    C.TABLE_NAME,
    C.COLUMN_NAME,
    C.DATA_TYPE

FROM GOVERNANCE.CATALOG.COLUMN_CATALOG C

LEFT JOIN GOVERNANCE.CATALOG.DATA_DICTIONARY D

       ON D.DATABASE_NAME = C.DATABASE_NAME
      AND D.SCHEMA_NAME   = C.SCHEMA_NAME
      AND D.TABLE_NAME    = C.TABLE_NAME
      AND D.COLUMN_NAME   = C.COLUMN_NAME

WHERE C.DATABASE_NAME = 'RAW'
  AND C.SCHEMA_NAME   = 'BANKING'

  AND D.COLUMN_NAME IS NULL

ORDER BY
    C.TABLE_NAME,
    C.ORDINAL_POSITION;



-- ============================================================================
-- 5. DICTIONARY AND DESCRIPTION SOURCE COVERAGE
--
-- Expected:
--      DICTIONARY_COVERAGE_PCT          = 100
--      DESCRIPTION_SOURCE_COVERAGE_PCT = 100
-- ============================================================================

SELECT

    COUNT(*) AS TOTAL_RAW_COLUMNS,

    COUNT_IF
    (
        D.COLUMN_NAME IS NOT NULL
    )
        AS DICTIONARY_MAPPED_COLUMNS,

    COUNT_IF
    (
        D.DESCRIPTION IS NOT NULL
        AND TRIM(D.DESCRIPTION) <> ''
    )
        AS DESCRIBED_COLUMNS,

    ROUND
    (
        100.0 *
        COUNT_IF(D.COLUMN_NAME IS NOT NULL)
        /
        NULLIF(COUNT(*), 0),

        2
    )
        AS DICTIONARY_COVERAGE_PCT,

    ROUND
    (
        100.0 *
        COUNT_IF
        (
            D.DESCRIPTION IS NOT NULL
            AND TRIM(D.DESCRIPTION) <> ''
        )
        /
        NULLIF(COUNT(*), 0),

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
-- 6. MISSING DESCRIPTIONS
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    TABLE_NAME,
    COLUMN_NAME

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING'

  AND
  (
         DESCRIPTION IS NULL
      OR TRIM(DESCRIPTION) = ''
  )

ORDER BY
    TABLE_NAME,
    COLUMN_NAME;



-- ============================================================================
-- 7. DICTIONARY LOAD SUMMARY
-- ============================================================================

SELECT

    COUNT(*) AS DICTIONARY_ROWS,

    COUNT(DISTINCT TABLE_NAME)
        AS DICTIONARY_TABLES,

    COUNT_IF
    (
        DESCRIPTION IS NOT NULL
        AND TRIM(DESCRIPTION) <> ''
    )
        AS ROWS_WITH_DESCRIPTION,

    MAX(UPDATED_AT)
        AS LAST_UPDATED_AT

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING';



-- ============================================================================
-- 8. DICTIONARY DATA INSPECTION
-- ============================================================================

SELECT

    TABLE_NAME,
    COLUMN_NAME,
    DESCRIPTION,
    EXPECTED_DATA_TYPE,
    SENSITIVITY_HINT,
    DATA_DOMAIN,
    SOURCE_SYSTEM,
    SOURCE_FILE

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING'

ORDER BY
    TABLE_NAME,
    COLUMN_NAME;