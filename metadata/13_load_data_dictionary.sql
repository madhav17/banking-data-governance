/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/13_load_data_dictionary.sql

  Purpose:
      Load the committed vendor-style RAW data dictionary into
      GOVERNANCE.CATALOG.DATA_DICTIONARY.

  Source:
      data/vendor_dictionary.csv
          ->
      GOVERNANCE.CATALOG.DICTIONARY_STAGE

  Target:
      GOVERNANCE.CATALOG.DATA_DICTIONARY

  Design:
      - CSV remains the source-controlled vendor metadata artifact
      - Temporary table isolates ingestion from governed target
      - MERGE makes the load idempotent
      - RAW / BANKING are assigned explicitly
      - Source filename retained for traceability
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. CREATE CSV FILE FORMAT
-- ============================================================================

CREATE FILE FORMAT IF NOT EXISTS
    GOVERNANCE.CATALOG.DICTIONARY_CSV_FORMAT

    TYPE = CSV

    SKIP_HEADER = 1

    FIELD_OPTIONALLY_ENCLOSED_BY = '"'

    TRIM_SPACE = TRUE

    EMPTY_FIELD_AS_NULL = TRUE

    NULL_IF = ('', 'NULL')

    COMMENT =
        'CSV format for vendor-supplied RAW data dictionary';



-- ============================================================================
-- 3. CREATE INTERNAL STAGE
-- ============================================================================

CREATE STAGE IF NOT EXISTS
    GOVERNANCE.CATALOG.DICTIONARY_STAGE

    FILE_FORMAT =
        GOVERNANCE.CATALOG.DICTIONARY_CSV_FORMAT

    COMMENT =
        'Internal stage for committed vendor data dictionary files';



-- ============================================================================
-- 4. CREATE TEMPORARY LANDING TABLE
--
-- Important:
-- This table is not the governed system of record.
-- It only isolates raw CSV ingestion from DATA_DICTIONARY.
-- ============================================================================

CREATE OR REPLACE TEMP TABLE
    TMP_DATA_DICTIONARY_LOAD
(
    TABLE_NAME          VARCHAR(255),
    COLUMN_NAME         VARCHAR(255),
    DESCRIPTION         VARCHAR(5000),
    EXPECTED_DATA_TYPE  VARCHAR(255),
    SENSITIVITY_HINT    VARCHAR(255)
);



-- ============================================================================
-- 5. LOAD THE STAGED CSV
-- ============================================================================

COPY INTO TMP_DATA_DICTIONARY_LOAD
(
    TABLE_NAME,
    COLUMN_NAME,
    DESCRIPTION,
    EXPECTED_DATA_TYPE,
    SENSITIVITY_HINT
)

FROM
    @GOVERNANCE.CATALOG.DICTIONARY_STAGE/vendor_dictionary.csv

FILE_FORMAT =
(
    FORMAT_NAME =
        GOVERNANCE.CATALOG.DICTIONARY_CSV_FORMAT
)

ON_ERROR = 'ABORT_STATEMENT'

FORCE = TRUE;



-- ============================================================================
-- 6. NORMALISE + MERGE INTO GOVERNED DATA_DICTIONARY
--
-- Idempotency:
--
-- Existing table/column:
--      UPDATE
--
-- New table/column:
--      INSERT
-- ============================================================================

MERGE INTO GOVERNANCE.CATALOG.DATA_DICTIONARY T

USING
(
    SELECT

        'RAW'
            AS DATABASE_NAME,

        'BANKING'
            AS SCHEMA_NAME,

        UPPER(TRIM(TABLE_NAME))
            AS TABLE_NAME,

        UPPER(TRIM(COLUMN_NAME))
            AS COLUMN_NAME,

        INITCAP
        (
            REPLACE
            (
                LOWER(TRIM(COLUMN_NAME)),
                '_',
                ' '
            )
        )
            AS BUSINESS_NAME,

        NULLIF
        (
            TRIM(DESCRIPTION),
            ''
        )
            AS DESCRIPTION,

        UPPER
        (
            TRIM(EXPECTED_DATA_TYPE)
        )
            AS EXPECTED_DATA_TYPE,

        NULLIF
        (
            TRIM(SENSITIVITY_HINT),
            ''
        )
            AS SENSITIVITY_HINT,

        'BANKING'
            AS DATA_DOMAIN,

        CAST(NULL AS VARCHAR)
            AS SOURCE_SYSTEM,

        'data/vendor_dictionary.csv'
            AS SOURCE_FILE

    FROM TMP_DATA_DICTIONARY_LOAD

    WHERE TABLE_NAME IS NOT NULL
      AND COLUMN_NAME IS NOT NULL

) S


ON  T.DATABASE_NAME = S.DATABASE_NAME
AND T.SCHEMA_NAME   = S.SCHEMA_NAME
AND T.TABLE_NAME    = S.TABLE_NAME
AND T.COLUMN_NAME   = S.COLUMN_NAME


WHEN MATCHED THEN

UPDATE SET

    T.BUSINESS_NAME =
        S.BUSINESS_NAME,

    T.DESCRIPTION =
        S.DESCRIPTION,

    T.EXPECTED_DATA_TYPE =
        S.EXPECTED_DATA_TYPE,

    T.SENSITIVITY_HINT =
        S.SENSITIVITY_HINT,

    T.DATA_DOMAIN =
        S.DATA_DOMAIN,

    T.SOURCE_SYSTEM =
        S.SOURCE_SYSTEM,

    T.SOURCE_FILE =
        S.SOURCE_FILE,

    T.UPDATED_AT =
        CURRENT_TIMESTAMP()


WHEN NOT MATCHED THEN

INSERT
(
    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    BUSINESS_NAME,
    DESCRIPTION,
    EXPECTED_DATA_TYPE,
    SENSITIVITY_HINT,
    DATA_DOMAIN,
    SOURCE_SYSTEM,
    SOURCE_FILE,
    LOADED_AT,
    UPDATED_AT
)

VALUES
(
    S.DATABASE_NAME,
    S.SCHEMA_NAME,
    S.TABLE_NAME,
    S.COLUMN_NAME,
    S.BUSINESS_NAME,
    S.DESCRIPTION,
    S.EXPECTED_DATA_TYPE,
    S.SENSITIVITY_HINT,
    S.DATA_DOMAIN,
    S.SOURCE_SYSTEM,
    S.SOURCE_FILE,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);



-- ============================================================================
-- 7. LOAD SUMMARY
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
        AS LAST_DICTIONARY_UPDATE

FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING';