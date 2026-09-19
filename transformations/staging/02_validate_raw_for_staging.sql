/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      transformations/staging/02_validate_raw_for_staging.sql

  Purpose:
      Validate that RAW.BANKING is structurally safe for deterministic,
      idempotent RAW -> STAGING MERGE processing.

  Scope:
      This file intentionally performs only lightweight staging-gate checks:

          1. Expected RAW tables contain data.
          2. CUSTOMER contains at least 3,000 rows.
          3. Required MERGE/business keys are present.
          4. MERGE/business keys are unique at the expected grain.

  Important:
      This is NOT the formal Block 3 Data Quality framework.

      The following checks are deliberately deferred to Block 3 on the
      certified mart:
          - CDE completeness
          - business-key uniqueness as a trust metric
          - tax-ID/status validity
          - account -> customer consistency
          - timeliness
          - GL reconciliation / accuracy

      Sensitive and deliberately misleading columns must also remain unchanged
      so Snowflake classification can operate on STAGING later.

  Expected:
      All validation status values should be PASS before executing the
      RAW -> STAGING MERGE scripts.
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_ENGINEER;

USE WAREHOUSE WH_GOVERNANCE_XS;



-- ============================================================================
-- 2. RAW SOURCE POPULATION
--
-- Expected:
--      Every source table has at least one record.
--
-- CUSTOMER has an additional >= 3,000 row requirement below.
-- ============================================================================

SELECT
    TABLE_NAME,
    ROW_COUNT,

    CASE
        WHEN ROW_COUNT > 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS

FROM
(
    SELECT
        'BRANCH' AS TABLE_NAME,
        COUNT(*) AS ROW_COUNT
    FROM RAW.BANKING.BRANCH

    UNION ALL

    SELECT
        'PRODUCT',
        COUNT(*)
    FROM RAW.BANKING.PRODUCT

    UNION ALL

    SELECT
        'OFFICER',
        COUNT(*)
    FROM RAW.BANKING.OFFICER

    UNION ALL

    SELECT
        'CUSTOMER',
        COUNT(*)
    FROM RAW.BANKING.CUSTOMER

    UNION ALL

    SELECT
        'ACCOUNT',
        COUNT(*)
    FROM RAW.BANKING.ACCOUNT

    UNION ALL

    SELECT
        'ACCOUNT_DAILY_BALANCE',
        COUNT(*)
    FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE

    UNION ALL

    SELECT
        'CARD',
        COUNT(*)
    FROM RAW.BANKING.CARD

    UNION ALL

    SELECT
        'LOAN',
        COUNT(*)
    FROM RAW.BANKING.LOAN

    UNION ALL

    SELECT
        'LOAN_COLLATERAL',
        COUNT(*)
    FROM RAW.BANKING.LOAN_COLLATERAL

    UNION ALL

    SELECT
        'TRANSACTIONS',
        COUNT(*)
    FROM RAW.BANKING.TRANSACTIONS

    UNION ALL

    SELECT
        'GL_CONTROL_TOTAL',
        COUNT(*)
    FROM RAW.BANKING.GL_CONTROL_TOTAL
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 3. CUSTOMER VOLUME REQUIREMENT
--
-- Avidia requires at least 3,000 synthetic customers.
--
-- Expected:
--      CUSTOMER_COUNT >= 3000
-- ============================================================================

SELECT
    COUNT(*) AS CUSTOMER_COUNT,

    CASE
        WHEN COUNT(*) >= 3000
            THEN 'PASS'
        ELSE 'FAIL'
    END AS CUSTOMER_VOLUME_STATUS

FROM RAW.BANKING.CUSTOMER;



-- ============================================================================
-- 4. REQUIRED MERGE-KEY COMPLETENESS
--
-- These are structural requirements for deterministic MERGE operations.
--
-- Expected:
--      MISSING_KEY_COUNT = 0 for every source.
--
-- ACCOUNT_DAILY_BALANCE uses the compound grain:
--      ACCOUNT_ID + BUSINESS_DATE
-- ============================================================================

SELECT
    TABLE_NAME,
    KEY_NAME,
    MISSING_KEY_COUNT,

    CASE
        WHEN MISSING_KEY_COUNT = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS

FROM
(
    SELECT
        'BRANCH' AS TABLE_NAME,
        'BRANCH_ID' AS KEY_NAME,
        COUNT_IF(BRANCH_ID IS NULL OR TRIM(BRANCH_ID) = '')
            AS MISSING_KEY_COUNT
    FROM RAW.BANKING.BRANCH

    UNION ALL

    SELECT
        'PRODUCT',
        'PRODUCT_ID',
        COUNT_IF(PRODUCT_ID IS NULL OR TRIM(PRODUCT_ID) = '')
    FROM RAW.BANKING.PRODUCT

    UNION ALL

    SELECT
        'OFFICER',
        'OFFICER_ID',
        COUNT_IF(OFFICER_ID IS NULL OR TRIM(OFFICER_ID) = '')
    FROM RAW.BANKING.OFFICER

    UNION ALL

    SELECT
        'CUSTOMER',
        'CUSTOMER_ID',
        COUNT_IF(CUSTOMER_ID IS NULL OR TRIM(CUSTOMER_ID) = '')
    FROM RAW.BANKING.CUSTOMER

    UNION ALL

    SELECT
        'ACCOUNT',
        'ACCOUNT_ID',
        COUNT_IF(ACCOUNT_ID IS NULL OR TRIM(ACCOUNT_ID) = '')
    FROM RAW.BANKING.ACCOUNT

    UNION ALL

    SELECT
        'ACCOUNT_DAILY_BALANCE',
        'ACCOUNT_ID + BUSINESS_DATE',
        COUNT_IF(
            ACCOUNT_ID IS NULL
            OR TRIM(ACCOUNT_ID) = ''
            OR BUSINESS_DATE IS NULL
        )
    FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE

    UNION ALL

    SELECT
        'CARD',
        'CARD_ID',
        COUNT_IF(CARD_ID IS NULL OR TRIM(CARD_ID) = '')
    FROM RAW.BANKING.CARD

    UNION ALL

    SELECT
        'LOAN',
        'LOAN_ID',
        COUNT_IF(LOAN_ID IS NULL OR TRIM(LOAN_ID) = '')
    FROM RAW.BANKING.LOAN

    UNION ALL

    SELECT
        'LOAN_COLLATERAL',
        'COLLATERAL_ID',
        COUNT_IF(COLLATERAL_ID IS NULL OR TRIM(COLLATERAL_ID) = '')
    FROM RAW.BANKING.LOAN_COLLATERAL

    UNION ALL

    SELECT
        'TRANSACTIONS',
        'TRANSACTION_ID',
        COUNT_IF(
            TRANSACTION_ID IS NULL
            OR TRIM(TRANSACTION_ID) = ''
        )
    FROM RAW.BANKING.TRANSACTIONS

    UNION ALL

    SELECT
        'GL_CONTROL_TOTAL',
        'GL_CONTROL_ID',
        COUNT_IF(
            GL_CONTROL_ID IS NULL
            OR TRIM(GL_CONTROL_ID) = ''
        )
    FROM RAW.BANKING.GL_CONTROL_TOTAL
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 5. DUPLICATE MERGE-KEY SUMMARY
--
-- A duplicate source key can make MERGE nondeterministic because multiple
-- source records may match the same target record.
--
-- Expected:
--      DUPLICATE_KEY_GROUPS = 0 for every source.
-- ============================================================================

SELECT
    TABLE_NAME,
    KEY_NAME,
    DUPLICATE_KEY_GROUPS,

    CASE
        WHEN DUPLICATE_KEY_GROUPS = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS

FROM
(
    SELECT
        'BRANCH' AS TABLE_NAME,
        'BRANCH_ID' AS KEY_NAME,
        COUNT(*) AS DUPLICATE_KEY_GROUPS
    FROM
    (
        SELECT BRANCH_ID
        FROM RAW.BANKING.BRANCH
        WHERE BRANCH_ID IS NOT NULL
          AND TRIM(BRANCH_ID) <> ''
        GROUP BY BRANCH_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'PRODUCT',
        'PRODUCT_ID',
        COUNT(*)
    FROM
    (
        SELECT PRODUCT_ID
        FROM RAW.BANKING.PRODUCT
        WHERE PRODUCT_ID IS NOT NULL
          AND TRIM(PRODUCT_ID) <> ''
        GROUP BY PRODUCT_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'OFFICER',
        'OFFICER_ID',
        COUNT(*)
    FROM
    (
        SELECT OFFICER_ID
        FROM RAW.BANKING.OFFICER
        WHERE OFFICER_ID IS NOT NULL
          AND TRIM(OFFICER_ID) <> ''
        GROUP BY OFFICER_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'CUSTOMER',
        'CUSTOMER_ID',
        COUNT(*)
    FROM
    (
        SELECT CUSTOMER_ID
        FROM RAW.BANKING.CUSTOMER
        WHERE CUSTOMER_ID IS NOT NULL
          AND TRIM(CUSTOMER_ID) <> ''
        GROUP BY CUSTOMER_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'ACCOUNT',
        'ACCOUNT_ID',
        COUNT(*)
    FROM
    (
        SELECT ACCOUNT_ID
        FROM RAW.BANKING.ACCOUNT
        WHERE ACCOUNT_ID IS NOT NULL
          AND TRIM(ACCOUNT_ID) <> ''
        GROUP BY ACCOUNT_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'ACCOUNT_DAILY_BALANCE',
        'ACCOUNT_ID + BUSINESS_DATE',
        COUNT(*)
    FROM
    (
        SELECT
            ACCOUNT_ID,
            BUSINESS_DATE
        FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
        WHERE ACCOUNT_ID IS NOT NULL
          AND TRIM(ACCOUNT_ID) <> ''
          AND BUSINESS_DATE IS NOT NULL
        GROUP BY
            ACCOUNT_ID,
            BUSINESS_DATE
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'CARD',
        'CARD_ID',
        COUNT(*)
    FROM
    (
        SELECT CARD_ID
        FROM RAW.BANKING.CARD
        WHERE CARD_ID IS NOT NULL
          AND TRIM(CARD_ID) <> ''
        GROUP BY CARD_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'LOAN',
        'LOAN_ID',
        COUNT(*)
    FROM
    (
        SELECT LOAN_ID
        FROM RAW.BANKING.LOAN
        WHERE LOAN_ID IS NOT NULL
          AND TRIM(LOAN_ID) <> ''
        GROUP BY LOAN_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'LOAN_COLLATERAL',
        'COLLATERAL_ID',
        COUNT(*)
    FROM
    (
        SELECT COLLATERAL_ID
        FROM RAW.BANKING.LOAN_COLLATERAL
        WHERE COLLATERAL_ID IS NOT NULL
          AND TRIM(COLLATERAL_ID) <> ''
        GROUP BY COLLATERAL_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'TRANSACTIONS',
        'TRANSACTION_ID',
        COUNT(*)
    FROM
    (
        SELECT TRANSACTION_ID
        FROM RAW.BANKING.TRANSACTIONS
        WHERE TRANSACTION_ID IS NOT NULL
          AND TRIM(TRANSACTION_ID) <> ''
        GROUP BY TRANSACTION_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'GL_CONTROL_TOTAL',
        'GL_CONTROL_ID',
        COUNT(*)
    FROM
    (
        SELECT GL_CONTROL_ID
        FROM RAW.BANKING.GL_CONTROL_TOTAL
        WHERE GL_CONTROL_ID IS NOT NULL
          AND TRIM(GL_CONTROL_ID) <> ''
        GROUP BY GL_CONTROL_ID
        HAVING COUNT(*) > 1
    )
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 6. DETAIL QUERY: MISSING KEYS
--
-- Returns only records that would make the STAGING MERGE structurally unsafe.
--
-- Expected:
--      0 rows from each query.
-- ============================================================================

SELECT *
FROM RAW.BANKING.BRANCH
WHERE BRANCH_ID IS NULL
   OR TRIM(BRANCH_ID) = '';


SELECT *
FROM RAW.BANKING.PRODUCT
WHERE PRODUCT_ID IS NULL
   OR TRIM(PRODUCT_ID) = '';


SELECT *
FROM RAW.BANKING.OFFICER
WHERE OFFICER_ID IS NULL
   OR TRIM(OFFICER_ID) = '';


SELECT *
FROM RAW.BANKING.CUSTOMER
WHERE CUSTOMER_ID IS NULL
   OR TRIM(CUSTOMER_ID) = '';


SELECT *
FROM RAW.BANKING.ACCOUNT
WHERE ACCOUNT_ID IS NULL
   OR TRIM(ACCOUNT_ID) = '';


SELECT *
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
WHERE ACCOUNT_ID IS NULL
   OR TRIM(ACCOUNT_ID) = ''
   OR BUSINESS_DATE IS NULL;


SELECT *
FROM RAW.BANKING.CARD
WHERE CARD_ID IS NULL
   OR TRIM(CARD_ID) = '';


SELECT *
FROM RAW.BANKING.LOAN
WHERE LOAN_ID IS NULL
   OR TRIM(LOAN_ID) = '';


SELECT *
FROM RAW.BANKING.LOAN_COLLATERAL
WHERE COLLATERAL_ID IS NULL
   OR TRIM(COLLATERAL_ID) = '';


SELECT *
FROM RAW.BANKING.TRANSACTIONS
WHERE TRANSACTION_ID IS NULL
   OR TRIM(TRANSACTION_ID) = '';


SELECT *
FROM RAW.BANKING.GL_CONTROL_TOTAL
WHERE GL_CONTROL_ID IS NULL
   OR TRIM(GL_CONTROL_ID) = '';



-- ============================================================================
-- 7. DETAIL QUERY: DUPLICATE KEYS
--
-- Expected:
--      0 rows from each query.
-- ============================================================================

SELECT
    BRANCH_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.BRANCH
WHERE BRANCH_ID IS NOT NULL
  AND TRIM(BRANCH_ID) <> ''
GROUP BY BRANCH_ID
HAVING COUNT(*) > 1;


SELECT
    PRODUCT_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.PRODUCT
WHERE PRODUCT_ID IS NOT NULL
  AND TRIM(PRODUCT_ID) <> ''
GROUP BY PRODUCT_ID
HAVING COUNT(*) > 1;


SELECT
    OFFICER_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.OFFICER
WHERE OFFICER_ID IS NOT NULL
  AND TRIM(OFFICER_ID) <> ''
GROUP BY OFFICER_ID
HAVING COUNT(*) > 1;


SELECT
    CUSTOMER_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.CUSTOMER
WHERE CUSTOMER_ID IS NOT NULL
  AND TRIM(CUSTOMER_ID) <> ''
GROUP BY CUSTOMER_ID
HAVING COUNT(*) > 1;


SELECT
    ACCOUNT_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.ACCOUNT
WHERE ACCOUNT_ID IS NOT NULL
  AND TRIM(ACCOUNT_ID) <> ''
GROUP BY ACCOUNT_ID
HAVING COUNT(*) > 1;


SELECT
    ACCOUNT_ID,
    BUSINESS_DATE,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
WHERE ACCOUNT_ID IS NOT NULL
  AND TRIM(ACCOUNT_ID) <> ''
  AND BUSINESS_DATE IS NOT NULL
GROUP BY
    ACCOUNT_ID,
    BUSINESS_DATE
HAVING COUNT(*) > 1;


SELECT
    CARD_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.CARD
WHERE CARD_ID IS NOT NULL
  AND TRIM(CARD_ID) <> ''
GROUP BY CARD_ID
HAVING COUNT(*) > 1;


SELECT
    LOAN_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.LOAN
WHERE LOAN_ID IS NOT NULL
  AND TRIM(LOAN_ID) <> ''
GROUP BY LOAN_ID
HAVING COUNT(*) > 1;


SELECT
    COLLATERAL_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.LOAN_COLLATERAL
WHERE COLLATERAL_ID IS NOT NULL
  AND TRIM(COLLATERAL_ID) <> ''
GROUP BY COLLATERAL_ID
HAVING COUNT(*) > 1;


SELECT
    TRANSACTION_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.TRANSACTIONS
WHERE TRANSACTION_ID IS NOT NULL
  AND TRIM(TRANSACTION_ID) <> ''
GROUP BY TRANSACTION_ID
HAVING COUNT(*) > 1;


SELECT
    GL_CONTROL_ID,
    COUNT(*) AS RECORD_COUNT
FROM RAW.BANKING.GL_CONTROL_TOTAL
WHERE GL_CONTROL_ID IS NOT NULL
  AND TRIM(GL_CONTROL_ID) <> ''
GROUP BY GL_CONTROL_ID
HAVING COUNT(*) > 1;



-- ============================================================================
-- 8. FINAL RAW -> STAGING GATE
--
-- This compact query gives one overall result before running the MERGE files.
--
-- PASS means:
--      - all 11 RAW tables contain data
--      - CUSTOMER has at least 3,000 rows
--      - no required MERGE keys are missing
--      - no duplicate MERGE-key groups exist
--
-- It deliberately does NOT check formal Block 3 DQ dimensions.
-- ============================================================================

WITH SOURCE_COUNTS AS
(
    SELECT
        (SELECT COUNT(*) FROM RAW.BANKING.BRANCH) AS BRANCH_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.PRODUCT) AS PRODUCT_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.OFFICER) AS OFFICER_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.CUSTOMER) AS CUSTOMER_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT) AS ACCOUNT_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE) AS BALANCE_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.CARD) AS CARD_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.LOAN) AS LOAN_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.LOAN_COLLATERAL) AS COLLATERAL_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.TRANSACTIONS) AS TRANSACTION_COUNT,
        (SELECT COUNT(*) FROM RAW.BANKING.GL_CONTROL_TOTAL) AS GL_COUNT
),

MISSING_KEYS AS
(
    SELECT
          (SELECT COUNT(*) FROM RAW.BANKING.BRANCH
           WHERE BRANCH_ID IS NULL OR TRIM(BRANCH_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.PRODUCT
           WHERE PRODUCT_ID IS NULL OR TRIM(PRODUCT_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.OFFICER
           WHERE OFFICER_ID IS NULL OR TRIM(OFFICER_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.CUSTOMER
           WHERE CUSTOMER_ID IS NULL OR TRIM(CUSTOMER_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT
           WHERE ACCOUNT_ID IS NULL OR TRIM(ACCOUNT_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
           WHERE ACCOUNT_ID IS NULL
              OR TRIM(ACCOUNT_ID) = ''
              OR BUSINESS_DATE IS NULL)

        + (SELECT COUNT(*) FROM RAW.BANKING.CARD
           WHERE CARD_ID IS NULL OR TRIM(CARD_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.LOAN
           WHERE LOAN_ID IS NULL OR TRIM(LOAN_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.LOAN_COLLATERAL
           WHERE COLLATERAL_ID IS NULL OR TRIM(COLLATERAL_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.TRANSACTIONS
           WHERE TRANSACTION_ID IS NULL
              OR TRIM(TRANSACTION_ID) = '')

        + (SELECT COUNT(*) FROM RAW.BANKING.GL_CONTROL_TOTAL
           WHERE GL_CONTROL_ID IS NULL
              OR TRIM(GL_CONTROL_ID) = '')

        AS TOTAL_MISSING_KEYS
),

DUPLICATE_KEYS AS
(
    SELECT

          (SELECT COUNT(*)
           FROM
           (
               SELECT BRANCH_ID
               FROM RAW.BANKING.BRANCH
               WHERE BRANCH_ID IS NOT NULL
                 AND TRIM(BRANCH_ID) <> ''
               GROUP BY BRANCH_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT PRODUCT_ID
               FROM RAW.BANKING.PRODUCT
               WHERE PRODUCT_ID IS NOT NULL
                 AND TRIM(PRODUCT_ID) <> ''
               GROUP BY PRODUCT_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT OFFICER_ID
               FROM RAW.BANKING.OFFICER
               WHERE OFFICER_ID IS NOT NULL
                 AND TRIM(OFFICER_ID) <> ''
               GROUP BY OFFICER_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT CUSTOMER_ID
               FROM RAW.BANKING.CUSTOMER
               WHERE CUSTOMER_ID IS NOT NULL
                 AND TRIM(CUSTOMER_ID) <> ''
               GROUP BY CUSTOMER_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT ACCOUNT_ID
               FROM RAW.BANKING.ACCOUNT
               WHERE ACCOUNT_ID IS NOT NULL
                 AND TRIM(ACCOUNT_ID) <> ''
               GROUP BY ACCOUNT_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT ACCOUNT_ID, BUSINESS_DATE
               FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
               WHERE ACCOUNT_ID IS NOT NULL
                 AND TRIM(ACCOUNT_ID) <> ''
                 AND BUSINESS_DATE IS NOT NULL
               GROUP BY ACCOUNT_ID, BUSINESS_DATE
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT CARD_ID
               FROM RAW.BANKING.CARD
               WHERE CARD_ID IS NOT NULL
                 AND TRIM(CARD_ID) <> ''
               GROUP BY CARD_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT LOAN_ID
               FROM RAW.BANKING.LOAN
               WHERE LOAN_ID IS NOT NULL
                 AND TRIM(LOAN_ID) <> ''
               GROUP BY LOAN_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT COLLATERAL_ID
               FROM RAW.BANKING.LOAN_COLLATERAL
               WHERE COLLATERAL_ID IS NOT NULL
                 AND TRIM(COLLATERAL_ID) <> ''
               GROUP BY COLLATERAL_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT TRANSACTION_ID
               FROM RAW.BANKING.TRANSACTIONS
               WHERE TRANSACTION_ID IS NOT NULL
                 AND TRIM(TRANSACTION_ID) <> ''
               GROUP BY TRANSACTION_ID
               HAVING COUNT(*) > 1
           ))

        + (SELECT COUNT(*)
           FROM
           (
               SELECT GL_CONTROL_ID
               FROM RAW.BANKING.GL_CONTROL_TOTAL
               WHERE GL_CONTROL_ID IS NOT NULL
                 AND TRIM(GL_CONTROL_ID) <> ''
               GROUP BY GL_CONTROL_ID
               HAVING COUNT(*) > 1
           ))

        AS TOTAL_DUPLICATE_KEY_GROUPS
)

SELECT
    S.CUSTOMER_COUNT,

    M.TOTAL_MISSING_KEYS,

    D.TOTAL_DUPLICATE_KEY_GROUPS,

    CASE
        WHEN S.BRANCH_COUNT      > 0
         AND S.PRODUCT_COUNT     > 0
         AND S.OFFICER_COUNT     > 0
         AND S.CUSTOMER_COUNT    >= 3000
         AND S.ACCOUNT_COUNT     > 0
         AND S.BALANCE_COUNT     > 0
         AND S.CARD_COUNT        > 0
         AND S.LOAN_COUNT        > 0
         AND S.COLLATERAL_COUNT  > 0
         AND S.TRANSACTION_COUNT > 0
         AND S.GL_COUNT          > 0
         AND M.TOTAL_MISSING_KEYS = 0
         AND D.TOTAL_DUPLICATE_KEY_GROUPS = 0

        THEN 'PASS - RAW DATA IS READY FOR STAGING'

        ELSE 'FAIL - REVIEW RAW TO STAGING VALIDATION RESULTS'

    END AS RAW_TO_STAGING_STATUS

FROM SOURCE_COUNTS S

CROSS JOIN MISSING_KEYS M

CROSS JOIN DUPLICATE_KEYS D;
