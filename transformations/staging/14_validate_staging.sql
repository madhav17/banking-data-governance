/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      transformations/staging/14_validate_staging.sql

  Purpose:
      Validate that RAW -> STAGING processing completed successfully for all
      11 banking entities.

  This validation proves:
      1. All 11 STAGING tables contain data.
      2. RAW and STAGING row counts reconcile.
      3. CUSTOMER volume remains >= 3,000 rows.
      4. Required STAGING MERGE keys are populated.
      5. STAGING MERGE/business-key grains remain unique.
      6. RAW source keys are represented in STAGING.
      7. Deliberately misleading sensitive values used for classification
         survived RAW -> STAGING unchanged.
      8. One compact final RAW -> STAGING acceptance result is produced.

  Important:
      This is NOT the formal Block 3 Data Quality framework.

      Do not interpret these checks as the required:
          - completeness
          - uniqueness
          - validity
          - consistency
          - timeliness
          - accuracy / GL reconciliation

      Those controls belong later on the certified mart and should be written
      to GOVERNANCE.DQ.DQ_RESULT.

  Precondition:
      02_validate_raw_for_staging.sql returned PASS and the following scripts
      completed successfully:

          03_merge_branch.sql
          04_merge_product.sql
          05_merge_officer.sql
          06_merge_customer.sql
          07_merge_account.sql
          08_merge_account_daily_balance.sql
          09_merge_card.sql
          10_merge_loan.sql
          11_merge_loan_collateral.sql
          12_merge_transactions.sql
          13_merge_gl_control_total.sql
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_ENGINEER;

USE WAREHOUSE WH_GOVERNANCE_XS;



-- ============================================================================
-- 2. RAW -> STAGING ROW-COUNT RECONCILIATION
--
-- Because 02_validate_raw_for_staging.sql guarantees valid/non-duplicate
-- MERGE keys, the current initial load should reconcile 1:1.
--
-- Expected:
--      STATUS = PASS for all 11 tables.
--
-- Note:
--      The current MERGE design performs INSERT/UPDATE, not source-delete
--      propagation. If RAW records are later physically deleted, this check
--      will intentionally expose the difference.
-- ============================================================================

SELECT
    TABLE_NAME,
    RAW_ROWS,
    STAGING_ROWS,
    STAGING_ROWS - RAW_ROWS AS ROW_COUNT_DIFFERENCE,

    CASE
        WHEN RAW_ROWS = STAGING_ROWS
            THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS

FROM
(
    SELECT
        'BRANCH' AS TABLE_NAME,
        (SELECT COUNT(*) FROM RAW.BANKING.BRANCH) AS RAW_ROWS,
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_BRANCH) AS STAGING_ROWS

    UNION ALL

    SELECT
        'PRODUCT',
        (SELECT COUNT(*) FROM RAW.BANKING.PRODUCT),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_PRODUCT)

    UNION ALL

    SELECT
        'OFFICER',
        (SELECT COUNT(*) FROM RAW.BANKING.OFFICER),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_OFFICER)

    UNION ALL

    SELECT
        'CUSTOMER',
        (SELECT COUNT(*) FROM RAW.BANKING.CUSTOMER),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER)

    UNION ALL

    SELECT
        'ACCOUNT',
        (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT)

    UNION ALL

    SELECT
        'ACCOUNT_DAILY_BALANCE',
        (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE)

    UNION ALL

    SELECT
        'CARD',
        (SELECT COUNT(*) FROM RAW.BANKING.CARD),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CARD)

    UNION ALL

    SELECT
        'LOAN',
        (SELECT COUNT(*) FROM RAW.BANKING.LOAN),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN)

    UNION ALL

    SELECT
        'LOAN_COLLATERAL',
        (SELECT COUNT(*) FROM RAW.BANKING.LOAN_COLLATERAL),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL)

    UNION ALL

    SELECT
        'TRANSACTIONS',
        (SELECT COUNT(*) FROM RAW.BANKING.TRANSACTIONS),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_TRANSACTIONS)

    UNION ALL

    SELECT
        'GL_CONTROL_TOTAL',
        (SELECT COUNT(*) FROM RAW.BANKING.GL_CONTROL_TOTAL),
        (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL)
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 3. CUSTOMER VOLUME REQUIREMENT
--
-- Avidia requires at least 3,000 customers.
--
-- Expected:
--      CUSTOMER_VOLUME_STATUS = PASS
-- ============================================================================

SELECT
    COUNT(*) AS STAGING_CUSTOMER_COUNT,

    CASE
        WHEN COUNT(*) >= 3000
            THEN 'PASS'
        ELSE 'FAIL'
    END AS CUSTOMER_VOLUME_STATUS

FROM ANALYTICS.STAGING.STG_CUSTOMER;



-- ============================================================================
-- 4. REQUIRED STAGING KEY COMPLETENESS
--
-- Expected:
--      MISSING_KEY_COUNT = 0 for every target.
--
-- ACCOUNT_DAILY_BALANCE grain:
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
        'STG_BRANCH' AS TABLE_NAME,
        'BRANCH_ID' AS KEY_NAME,
        COUNT_IF(BRANCH_ID IS NULL OR TRIM(BRANCH_ID) = '')
            AS MISSING_KEY_COUNT
    FROM ANALYTICS.STAGING.STG_BRANCH

    UNION ALL

    SELECT
        'STG_PRODUCT',
        'PRODUCT_ID',
        COUNT_IF(PRODUCT_ID IS NULL OR TRIM(PRODUCT_ID) = '')
    FROM ANALYTICS.STAGING.STG_PRODUCT

    UNION ALL

    SELECT
        'STG_OFFICER',
        'OFFICER_ID',
        COUNT_IF(OFFICER_ID IS NULL OR TRIM(OFFICER_ID) = '')
    FROM ANALYTICS.STAGING.STG_OFFICER

    UNION ALL

    SELECT
        'STG_CUSTOMER',
        'CUSTOMER_ID',
        COUNT_IF(CUSTOMER_ID IS NULL OR TRIM(CUSTOMER_ID) = '')
    FROM ANALYTICS.STAGING.STG_CUSTOMER

    UNION ALL

    SELECT
        'STG_ACCOUNT',
        'ACCOUNT_ID',
        COUNT_IF(ACCOUNT_ID IS NULL OR TRIM(ACCOUNT_ID) = '')
    FROM ANALYTICS.STAGING.STG_ACCOUNT

    UNION ALL

    SELECT
        'STG_ACCOUNT_DAILY_BALANCE',
        'ACCOUNT_ID + BUSINESS_DATE',
        COUNT_IF(
            ACCOUNT_ID IS NULL
            OR TRIM(ACCOUNT_ID) = ''
            OR BUSINESS_DATE IS NULL
        )
    FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE

    UNION ALL

    SELECT
        'STG_CARD',
        'CARD_ID',
        COUNT_IF(CARD_ID IS NULL OR TRIM(CARD_ID) = '')
    FROM ANALYTICS.STAGING.STG_CARD

    UNION ALL

    SELECT
        'STG_LOAN',
        'LOAN_ID',
        COUNT_IF(LOAN_ID IS NULL OR TRIM(LOAN_ID) = '')
    FROM ANALYTICS.STAGING.STG_LOAN

    UNION ALL

    SELECT
        'STG_LOAN_COLLATERAL',
        'COLLATERAL_ID',
        COUNT_IF(COLLATERAL_ID IS NULL OR TRIM(COLLATERAL_ID) = '')
    FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL

    UNION ALL

    SELECT
        'STG_TRANSACTIONS',
        'TRANSACTION_ID',
        COUNT_IF(
            TRANSACTION_ID IS NULL
            OR TRIM(TRANSACTION_ID) = ''
        )
    FROM ANALYTICS.STAGING.STG_TRANSACTIONS

    UNION ALL

    SELECT
        'STG_GL_CONTROL_TOTAL',
        'GL_CONTROL_ID',
        COUNT_IF(
            GL_CONTROL_ID IS NULL
            OR TRIM(GL_CONTROL_ID) = ''
        )
    FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 5. STAGING MERGE-KEY UNIQUENESS
--
-- This is a pipeline-safety validation for the staging grain, not the formal
-- Block 3 business-key uniqueness control.
--
-- Expected:
--      DUPLICATE_KEY_GROUPS = 0 for every target.
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
        'STG_BRANCH' AS TABLE_NAME,
        'BRANCH_ID' AS KEY_NAME,
        COUNT(*) AS DUPLICATE_KEY_GROUPS
    FROM
    (
        SELECT BRANCH_ID
        FROM ANALYTICS.STAGING.STG_BRANCH
        GROUP BY BRANCH_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_PRODUCT',
        'PRODUCT_ID',
        COUNT(*)
    FROM
    (
        SELECT PRODUCT_ID
        FROM ANALYTICS.STAGING.STG_PRODUCT
        GROUP BY PRODUCT_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_OFFICER',
        'OFFICER_ID',
        COUNT(*)
    FROM
    (
        SELECT OFFICER_ID
        FROM ANALYTICS.STAGING.STG_OFFICER
        GROUP BY OFFICER_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_CUSTOMER',
        'CUSTOMER_ID',
        COUNT(*)
    FROM
    (
        SELECT CUSTOMER_ID
        FROM ANALYTICS.STAGING.STG_CUSTOMER
        GROUP BY CUSTOMER_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_ACCOUNT',
        'ACCOUNT_ID',
        COUNT(*)
    FROM
    (
        SELECT ACCOUNT_ID
        FROM ANALYTICS.STAGING.STG_ACCOUNT
        GROUP BY ACCOUNT_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_ACCOUNT_DAILY_BALANCE',
        'ACCOUNT_ID + BUSINESS_DATE',
        COUNT(*)
    FROM
    (
        SELECT
            ACCOUNT_ID,
            BUSINESS_DATE
        FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
        GROUP BY
            ACCOUNT_ID,
            BUSINESS_DATE
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_CARD',
        'CARD_ID',
        COUNT(*)
    FROM
    (
        SELECT CARD_ID
        FROM ANALYTICS.STAGING.STG_CARD
        GROUP BY CARD_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_LOAN',
        'LOAN_ID',
        COUNT(*)
    FROM
    (
        SELECT LOAN_ID
        FROM ANALYTICS.STAGING.STG_LOAN
        GROUP BY LOAN_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_LOAN_COLLATERAL',
        'COLLATERAL_ID',
        COUNT(*)
    FROM
    (
        SELECT COLLATERAL_ID
        FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL
        GROUP BY COLLATERAL_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_TRANSACTIONS',
        'TRANSACTION_ID',
        COUNT(*)
    FROM
    (
        SELECT TRANSACTION_ID
        FROM ANALYTICS.STAGING.STG_TRANSACTIONS
        GROUP BY TRANSACTION_ID
        HAVING COUNT(*) > 1
    )

    UNION ALL

    SELECT
        'STG_GL_CONTROL_TOTAL',
        'GL_CONTROL_ID',
        COUNT(*)
    FROM
    (
        SELECT GL_CONTROL_ID
        FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
        GROUP BY GL_CONTROL_ID
        HAVING COUNT(*) > 1
    )
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 6. SOURCE KEY COVERAGE
--
-- This confirms that every structurally valid RAW key is represented in its
-- STAGING target.
--
-- Expected:
--      MISSING_IN_STAGING = 0 for every source.
-- ============================================================================

SELECT
    TABLE_NAME,
    MISSING_IN_STAGING,

    CASE
        WHEN MISSING_IN_STAGING = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS

FROM
(
    SELECT
        'BRANCH' AS TABLE_NAME,
        COUNT(*) AS MISSING_IN_STAGING
    FROM RAW.BANKING.BRANCH R
    LEFT JOIN ANALYTICS.STAGING.STG_BRANCH S
           ON S.BRANCH_ID = TRIM(R.BRANCH_ID)
    WHERE R.BRANCH_ID IS NOT NULL
      AND TRIM(R.BRANCH_ID) <> ''
      AND S.BRANCH_ID IS NULL

    UNION ALL

    SELECT
        'PRODUCT',
        COUNT(*)
    FROM RAW.BANKING.PRODUCT R
    LEFT JOIN ANALYTICS.STAGING.STG_PRODUCT S
           ON S.PRODUCT_ID = TRIM(R.PRODUCT_ID)
    WHERE R.PRODUCT_ID IS NOT NULL
      AND TRIM(R.PRODUCT_ID) <> ''
      AND S.PRODUCT_ID IS NULL

    UNION ALL

    SELECT
        'OFFICER',
        COUNT(*)
    FROM RAW.BANKING.OFFICER R
    LEFT JOIN ANALYTICS.STAGING.STG_OFFICER S
           ON S.OFFICER_ID = TRIM(R.OFFICER_ID)
    WHERE R.OFFICER_ID IS NOT NULL
      AND TRIM(R.OFFICER_ID) <> ''
      AND S.OFFICER_ID IS NULL

    UNION ALL

    SELECT
        'CUSTOMER',
        COUNT(*)
    FROM RAW.BANKING.CUSTOMER R
    LEFT JOIN ANALYTICS.STAGING.STG_CUSTOMER S
           ON S.CUSTOMER_ID = TRIM(R.CUSTOMER_ID)
    WHERE R.CUSTOMER_ID IS NOT NULL
      AND TRIM(R.CUSTOMER_ID) <> ''
      AND S.CUSTOMER_ID IS NULL

    UNION ALL

    SELECT
        'ACCOUNT',
        COUNT(*)
    FROM RAW.BANKING.ACCOUNT R
    LEFT JOIN ANALYTICS.STAGING.STG_ACCOUNT S
           ON S.ACCOUNT_ID = TRIM(R.ACCOUNT_ID)
    WHERE R.ACCOUNT_ID IS NOT NULL
      AND TRIM(R.ACCOUNT_ID) <> ''
      AND S.ACCOUNT_ID IS NULL

    UNION ALL

    SELECT
        'ACCOUNT_DAILY_BALANCE',
        COUNT(*)
    FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE R
    LEFT JOIN ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE S
           ON S.ACCOUNT_ID = TRIM(R.ACCOUNT_ID)
          AND S.BUSINESS_DATE = R.BUSINESS_DATE
    WHERE R.ACCOUNT_ID IS NOT NULL
      AND TRIM(R.ACCOUNT_ID) <> ''
      AND R.BUSINESS_DATE IS NOT NULL
      AND S.ACCOUNT_ID IS NULL

    UNION ALL

    SELECT
        'CARD',
        COUNT(*)
    FROM RAW.BANKING.CARD R
    LEFT JOIN ANALYTICS.STAGING.STG_CARD S
           ON S.CARD_ID = TRIM(R.CARD_ID)
    WHERE R.CARD_ID IS NOT NULL
      AND TRIM(R.CARD_ID) <> ''
      AND S.CARD_ID IS NULL

    UNION ALL

    SELECT
        'LOAN',
        COUNT(*)
    FROM RAW.BANKING.LOAN R
    LEFT JOIN ANALYTICS.STAGING.STG_LOAN S
           ON S.LOAN_ID = TRIM(R.LOAN_ID)
    WHERE R.LOAN_ID IS NOT NULL
      AND TRIM(R.LOAN_ID) <> ''
      AND S.LOAN_ID IS NULL

    UNION ALL

    SELECT
        'LOAN_COLLATERAL',
        COUNT(*)
    FROM RAW.BANKING.LOAN_COLLATERAL R
    LEFT JOIN ANALYTICS.STAGING.STG_LOAN_COLLATERAL S
           ON S.COLLATERAL_ID = TRIM(R.COLLATERAL_ID)
    WHERE R.COLLATERAL_ID IS NOT NULL
      AND TRIM(R.COLLATERAL_ID) <> ''
      AND S.COLLATERAL_ID IS NULL

    UNION ALL

    SELECT
        'TRANSACTIONS',
        COUNT(*)
    FROM RAW.BANKING.TRANSACTIONS R
    LEFT JOIN ANALYTICS.STAGING.STG_TRANSACTIONS S
           ON S.TRANSACTION_ID = TRIM(R.TRANSACTION_ID)
    WHERE R.TRANSACTION_ID IS NOT NULL
      AND TRIM(R.TRANSACTION_ID) <> ''
      AND S.TRANSACTION_ID IS NULL

    UNION ALL

    SELECT
        'GL_CONTROL_TOTAL',
        COUNT(*)
    FROM RAW.BANKING.GL_CONTROL_TOTAL R
    LEFT JOIN ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL S
           ON S.GL_CONTROL_ID = TRIM(R.GL_CONTROL_ID)
    WHERE R.GL_CONTROL_ID IS NOT NULL
      AND TRIM(R.GL_CONTROL_ID) <> ''
      AND S.GL_CONTROL_ID IS NULL
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 7. HIDDEN-SENSITIVE VALUE PRESERVATION
--
-- The take-home deliberately places sensitive values in innocently named
-- columns. These values must remain available in STAGING for the precision /
-- recall classification exercise.
--
-- The corresponding MERGE scripts intentionally do not alter these values:
--
--      CUSTOMER.CUST_REF
--      CUSTOMER.NOTES
--      TRANSACTIONS.REFERENCE
--      TRANSACTIONS.MEMO
--
-- Expected:
--      all mismatch counts = 0
-- ============================================================================

SELECT
    COUNT(*) AS CUSTOMER_ROWS_COMPARED,

    COUNT_IF
    (
        COALESCE(R.CUST_REF, '')
        <> COALESCE(S.CUST_REF, '')
    )
        AS CUST_REF_MISMATCHES,

    COUNT_IF
    (
        COALESCE(R.NOTES, '')
        <> COALESCE(S.NOTES, '')
    )
        AS NOTES_MISMATCHES,

    CASE
        WHEN COUNT_IF
             (
                 COALESCE(R.CUST_REF, '')
                 <> COALESCE(S.CUST_REF, '')
             ) = 0

         AND COUNT_IF
             (
                 COALESCE(R.NOTES, '')
                 <> COALESCE(S.NOTES, '')
             ) = 0

        THEN 'PASS'
        ELSE 'FAIL'
    END AS CUSTOMER_HIDDEN_SENSITIVE_STATUS

FROM RAW.BANKING.CUSTOMER R

INNER JOIN ANALYTICS.STAGING.STG_CUSTOMER S
        ON S.CUSTOMER_ID = TRIM(R.CUSTOMER_ID);


SELECT
    COUNT(*) AS TRANSACTION_ROWS_COMPARED,

    COUNT_IF
    (
        COALESCE(R.REFERENCE, '')
        <> COALESCE(S.REFERENCE, '')
    )
        AS REFERENCE_MISMATCHES,

    COUNT_IF
    (
        COALESCE(R.MEMO, '')
        <> COALESCE(S.MEMO, '')
    )
        AS MEMO_MISMATCHES,

    CASE
        WHEN COUNT_IF
             (
                 COALESCE(R.REFERENCE, '')
                 <> COALESCE(S.REFERENCE, '')
             ) = 0

         AND COUNT_IF
             (
                 COALESCE(R.MEMO, '')
                 <> COALESCE(S.MEMO, '')
             ) = 0

        THEN 'PASS'
        ELSE 'FAIL'
    END AS TRANSACTION_HIDDEN_SENSITIVE_STATUS

FROM RAW.BANKING.TRANSACTIONS R

INNER JOIN ANALYTICS.STAGING.STG_TRANSACTIONS S
        ON S.TRANSACTION_ID = TRIM(R.TRANSACTION_ID);



-- ============================================================================
-- 8. STAGING AUDIT METADATA
--
-- Expected:
--      all staging rows have STG_SOURCE_TABLE, STG_LOADED_AT and
--      STG_UPDATED_AT populated.
-- ============================================================================

SELECT
    TABLE_NAME,
    INCOMPLETE_AUDIT_ROWS,

    CASE
        WHEN INCOMPLETE_AUDIT_ROWS = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS STATUS

FROM
(
    SELECT
        'STG_BRANCH' AS TABLE_NAME,
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        ) AS INCOMPLETE_AUDIT_ROWS
    FROM ANALYTICS.STAGING.STG_BRANCH

    UNION ALL

    SELECT
        'STG_PRODUCT',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_PRODUCT

    UNION ALL

    SELECT
        'STG_OFFICER',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_OFFICER

    UNION ALL

    SELECT
        'STG_CUSTOMER',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_CUSTOMER

    UNION ALL

    SELECT
        'STG_ACCOUNT',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_ACCOUNT

    UNION ALL

    SELECT
        'STG_ACCOUNT_DAILY_BALANCE',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE

    UNION ALL

    SELECT
        'STG_CARD',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_CARD

    UNION ALL

    SELECT
        'STG_LOAN',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_LOAN

    UNION ALL

    SELECT
        'STG_LOAN_COLLATERAL',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL

    UNION ALL

    SELECT
        'STG_TRANSACTIONS',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_TRANSACTIONS

    UNION ALL

    SELECT
        'STG_GL_CONTROL_TOTAL',
        COUNT_IF(
            STG_SOURCE_TABLE IS NULL
            OR STG_LOADED_AT IS NULL
            OR STG_UPDATED_AT IS NULL
        )
    FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
)

ORDER BY TABLE_NAME;



-- ============================================================================
-- 9. FINAL RAW -> STAGING ACCEPTANCE RESULT
--
-- PASS criteria:
--      - all 11 RAW/STAGING row counts reconcile
--      - >= 3,000 staged customers
--      - no missing STAGING merge keys
--      - no duplicate STAGING merge-key groups
--      - all valid RAW keys exist in STAGING
--      - hidden-sensitive values survived unchanged
--      - staging audit metadata is populated
-- ============================================================================

WITH ROW_COUNTS AS
(
    SELECT
        COUNT_IF(RAW_ROWS <> STAGING_ROWS) AS COUNT_MISMATCHES
    FROM
    (
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.BRANCH) AS RAW_ROWS,
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_BRANCH) AS STAGING_ROWS

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.PRODUCT),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_PRODUCT)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.OFFICER),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_OFFICER)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.CUSTOMER),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.CARD),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CARD)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.LOAN),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.LOAN_COLLATERAL),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.TRANSACTIONS),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_TRANSACTIONS)

        UNION ALL
        SELECT
            (SELECT COUNT(*) FROM RAW.BANKING.GL_CONTROL_TOTAL),
            (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL)
    )
),

KEY_ISSUES AS
(
    SELECT
          (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_BRANCH
           WHERE BRANCH_ID IS NULL OR TRIM(BRANCH_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_PRODUCT
           WHERE PRODUCT_ID IS NULL OR TRIM(PRODUCT_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_OFFICER
           WHERE OFFICER_ID IS NULL OR TRIM(OFFICER_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER
           WHERE CUSTOMER_ID IS NULL OR TRIM(CUSTOMER_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT
           WHERE ACCOUNT_ID IS NULL OR TRIM(ACCOUNT_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
           WHERE ACCOUNT_ID IS NULL
              OR TRIM(ACCOUNT_ID) = ''
              OR BUSINESS_DATE IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CARD
           WHERE CARD_ID IS NULL OR TRIM(CARD_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN
           WHERE LOAN_ID IS NULL OR TRIM(LOAN_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL
           WHERE COLLATERAL_ID IS NULL OR TRIM(COLLATERAL_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_TRANSACTIONS
           WHERE TRANSACTION_ID IS NULL OR TRIM(TRANSACTION_ID) = '')

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
           WHERE GL_CONTROL_ID IS NULL OR TRIM(GL_CONTROL_ID) = '')

        AS MISSING_KEYS
),

DUPLICATE_ISSUES AS
(
    SELECT
          (SELECT COUNT(*) FROM
             (SELECT BRANCH_ID
              FROM ANALYTICS.STAGING.STG_BRANCH
              GROUP BY BRANCH_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT PRODUCT_ID
              FROM ANALYTICS.STAGING.STG_PRODUCT
              GROUP BY PRODUCT_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT OFFICER_ID
              FROM ANALYTICS.STAGING.STG_OFFICER
              GROUP BY OFFICER_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT CUSTOMER_ID
              FROM ANALYTICS.STAGING.STG_CUSTOMER
              GROUP BY CUSTOMER_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT ACCOUNT_ID
              FROM ANALYTICS.STAGING.STG_ACCOUNT
              GROUP BY ACCOUNT_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT ACCOUNT_ID, BUSINESS_DATE
              FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
              GROUP BY ACCOUNT_ID, BUSINESS_DATE
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT CARD_ID
              FROM ANALYTICS.STAGING.STG_CARD
              GROUP BY CARD_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT LOAN_ID
              FROM ANALYTICS.STAGING.STG_LOAN
              GROUP BY LOAN_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT COLLATERAL_ID
              FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL
              GROUP BY COLLATERAL_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT TRANSACTION_ID
              FROM ANALYTICS.STAGING.STG_TRANSACTIONS
              GROUP BY TRANSACTION_ID
              HAVING COUNT(*) > 1))

        + (SELECT COUNT(*) FROM
             (SELECT GL_CONTROL_ID
              FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
              GROUP BY GL_CONTROL_ID
              HAVING COUNT(*) > 1))

        AS DUPLICATE_KEY_GROUPS
),

SOURCE_KEY_COVERAGE AS
(
    SELECT
          (SELECT COUNT(*)
           FROM RAW.BANKING.BRANCH R
           LEFT JOIN ANALYTICS.STAGING.STG_BRANCH S
                  ON S.BRANCH_ID = TRIM(R.BRANCH_ID)
           WHERE R.BRANCH_ID IS NOT NULL
             AND TRIM(R.BRANCH_ID) <> ''
             AND S.BRANCH_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.PRODUCT R
           LEFT JOIN ANALYTICS.STAGING.STG_PRODUCT S
                  ON S.PRODUCT_ID = TRIM(R.PRODUCT_ID)
           WHERE R.PRODUCT_ID IS NOT NULL
             AND TRIM(R.PRODUCT_ID) <> ''
             AND S.PRODUCT_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.OFFICER R
           LEFT JOIN ANALYTICS.STAGING.STG_OFFICER S
                  ON S.OFFICER_ID = TRIM(R.OFFICER_ID)
           WHERE R.OFFICER_ID IS NOT NULL
             AND TRIM(R.OFFICER_ID) <> ''
             AND S.OFFICER_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.CUSTOMER R
           LEFT JOIN ANALYTICS.STAGING.STG_CUSTOMER S
                  ON S.CUSTOMER_ID = TRIM(R.CUSTOMER_ID)
           WHERE R.CUSTOMER_ID IS NOT NULL
             AND TRIM(R.CUSTOMER_ID) <> ''
             AND S.CUSTOMER_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.ACCOUNT R
           LEFT JOIN ANALYTICS.STAGING.STG_ACCOUNT S
                  ON S.ACCOUNT_ID = TRIM(R.ACCOUNT_ID)
           WHERE R.ACCOUNT_ID IS NOT NULL
             AND TRIM(R.ACCOUNT_ID) <> ''
             AND S.ACCOUNT_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE R
           LEFT JOIN ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE S
                  ON S.ACCOUNT_ID = TRIM(R.ACCOUNT_ID)
                 AND S.BUSINESS_DATE = R.BUSINESS_DATE
           WHERE R.ACCOUNT_ID IS NOT NULL
             AND TRIM(R.ACCOUNT_ID) <> ''
             AND R.BUSINESS_DATE IS NOT NULL
             AND S.ACCOUNT_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.CARD R
           LEFT JOIN ANALYTICS.STAGING.STG_CARD S
                  ON S.CARD_ID = TRIM(R.CARD_ID)
           WHERE R.CARD_ID IS NOT NULL
             AND TRIM(R.CARD_ID) <> ''
             AND S.CARD_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.LOAN R
           LEFT JOIN ANALYTICS.STAGING.STG_LOAN S
                  ON S.LOAN_ID = TRIM(R.LOAN_ID)
           WHERE R.LOAN_ID IS NOT NULL
             AND TRIM(R.LOAN_ID) <> ''
             AND S.LOAN_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.LOAN_COLLATERAL R
           LEFT JOIN ANALYTICS.STAGING.STG_LOAN_COLLATERAL S
                  ON S.COLLATERAL_ID = TRIM(R.COLLATERAL_ID)
           WHERE R.COLLATERAL_ID IS NOT NULL
             AND TRIM(R.COLLATERAL_ID) <> ''
             AND S.COLLATERAL_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.TRANSACTIONS R
           LEFT JOIN ANALYTICS.STAGING.STG_TRANSACTIONS S
                  ON S.TRANSACTION_ID = TRIM(R.TRANSACTION_ID)
           WHERE R.TRANSACTION_ID IS NOT NULL
             AND TRIM(R.TRANSACTION_ID) <> ''
             AND S.TRANSACTION_ID IS NULL)

        + (SELECT COUNT(*)
           FROM RAW.BANKING.GL_CONTROL_TOTAL R
           LEFT JOIN ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL S
                  ON S.GL_CONTROL_ID = TRIM(R.GL_CONTROL_ID)
           WHERE R.GL_CONTROL_ID IS NOT NULL
             AND TRIM(R.GL_CONTROL_ID) <> ''
             AND S.GL_CONTROL_ID IS NULL)

        AS MISSING_SOURCE_KEYS
),

HIDDEN_SENSITIVE AS
(
    SELECT
        (
            SELECT
                COUNT_IF(
                    COALESCE(R.CUST_REF, '') <> COALESCE(S.CUST_REF, '')
                    OR COALESCE(R.NOTES, '') <> COALESCE(S.NOTES, '')
                )
            FROM RAW.BANKING.CUSTOMER R
            INNER JOIN ANALYTICS.STAGING.STG_CUSTOMER S
                    ON S.CUSTOMER_ID = TRIM(R.CUSTOMER_ID)
        )
        +
        (
            SELECT
                COUNT_IF(
                    COALESCE(R.REFERENCE, '') <> COALESCE(S.REFERENCE, '')
                    OR COALESCE(R.MEMO, '') <> COALESCE(S.MEMO, '')
                )
            FROM RAW.BANKING.TRANSACTIONS R
            INNER JOIN ANALYTICS.STAGING.STG_TRANSACTIONS S
                    ON S.TRANSACTION_ID = TRIM(R.TRANSACTION_ID)
        )
        AS HIDDEN_SENSITIVE_MISMATCHES
),

AUDIT_ISSUES AS
(
    SELECT
          (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_BRANCH
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_PRODUCT
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_OFFICER
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CARD
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_LOAN_COLLATERAL
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_TRANSACTIONS
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        + (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
           WHERE STG_SOURCE_TABLE IS NULL
              OR STG_LOADED_AT IS NULL
              OR STG_UPDATED_AT IS NULL)

        AS INCOMPLETE_AUDIT_ROWS
)

SELECT
    (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER)
        AS STAGING_CUSTOMERS,

    R.COUNT_MISMATCHES,

    K.MISSING_KEYS,

    D.DUPLICATE_KEY_GROUPS,

    C.MISSING_SOURCE_KEYS,

    H.HIDDEN_SENSITIVE_MISMATCHES,

    A.INCOMPLETE_AUDIT_ROWS,

    CASE
        WHEN (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER) >= 3000
         AND R.COUNT_MISMATCHES = 0
         AND K.MISSING_KEYS = 0
         AND D.DUPLICATE_KEY_GROUPS = 0
         AND C.MISSING_SOURCE_KEYS = 0
         AND H.HIDDEN_SENSITIVE_MISMATCHES = 0
         AND A.INCOMPLETE_AUDIT_ROWS = 0

        THEN 'PASS - RAW TO STAGING COMPLETE'

        ELSE 'FAIL - REVIEW STAGING VALIDATION RESULTS'

    END AS RAW_TO_STAGING_STATUS

FROM ROW_COUNTS R
CROSS JOIN KEY_ISSUES K
CROSS JOIN DUPLICATE_ISSUES D
CROSS JOIN SOURCE_KEY_COVERAGE C
CROSS JOIN HIDDEN_SENSITIVE H
CROSS JOIN AUDIT_ISSUES A;
