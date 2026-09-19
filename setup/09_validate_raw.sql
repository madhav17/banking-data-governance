-- =====================================================================
-- Avidia Bank Take-Home
-- File: ingestion/04_validate_raw.sql
--
-- Purpose:
--   Validate RAW.BANKING after CSV ingestion and before building STAGING.
--
-- This script validates:
--
--   1. Expected RAW tables exist
--   2. Expected columns exist
--   3. No unexpected schema drift
--   4. All RAW tables contain data
--   5. Minimum customer volume requirement
--   6. PERSON and BUSINESS customers exist
--   7. Primary/business keys are populated
--   8. Primary/business keys are unique
--   9. Foreign-key relationships are logically valid
--  10. Cross-table relationships are internally consistent
--  11. Dates are logically valid
--  12. Numeric measures are reasonable
--  13. Basic identifier/email/card/account formats are reasonable
--  14. Required sensitive attributes are populated
--  15. Hidden/misleading sensitive fields are ready for classification
--  16. Source-system/date coverage is profiled
--  17. COPY INTO load history is available
--
-- IMPORTANT:
--   These are RAW ingestion checks.
--
--   They do NOT replace the six formal data-quality dimensions required
--   later against the certified MART:
--
--     completeness
--     uniqueness
--     validity
--     consistency
--     timeliness
--     accuracy / GL reconciliation
--
-- =====================================================================


-- =====================================================================
-- 0. SESSION CONTEXT
-- =====================================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE RAW;
USE SCHEMA BANKING;


-- =====================================================================
-- 1. RECORD EXECUTION CONTEXT
-- =====================================================================

SELECT
    CURRENT_TIMESTAMP()   AS VALIDATION_TIMESTAMP,
    CURRENT_USER()        AS EXECUTED_BY,
    CURRENT_ROLE()        AS CURRENT_ROLE,
    CURRENT_WAREHOUSE()   AS CURRENT_WAREHOUSE,
    CURRENT_DATABASE()    AS CURRENT_DATABASE,
    CURRENT_SCHEMA()      AS CURRENT_SCHEMA;


-- =====================================================================
-- 2. EXPECTED RAW TABLE INVENTORY
-- =====================================================================
--
-- Keep this explicit.
--
-- This becomes useful later if:
--   * somebody accidentally drops a table
--   * a table gets renamed
--   * a new unexpected RAW table appears
--
-- =====================================================================

CREATE OR REPLACE TEMP TABLE EXPECTED_RAW_TABLES (
    TABLE_NAME VARCHAR
);

INSERT INTO EXPECTED_RAW_TABLES (TABLE_NAME)
SELECT COLUMN1
FROM VALUES
    ('ACCOUNT'),
    ('ACCOUNT_DAILY_BALANCE'),
    ('BRANCH'),
    ('CARD'),
    ('CUSTOMER'),
    ('GL_CONTROL_TOTAL'),
    ('LOAN'),
    ('LOAN_COLLATERAL'),
    ('OFFICER'),
    ('PRODUCT'),
    ('TRANSACTIONS');


-- ---------------------------------------------------------------------
-- Missing tables
-- ---------------------------------------------------------------------

SELECT
    E.TABLE_NAME AS MISSING_TABLE
FROM EXPECTED_RAW_TABLES E
LEFT JOIN RAW.INFORMATION_SCHEMA.TABLES T
    ON T.TABLE_SCHEMA = 'BANKING'
   AND T.TABLE_NAME = E.TABLE_NAME
   AND T.TABLE_TYPE = 'BASE TABLE'
WHERE T.TABLE_NAME IS NULL
ORDER BY E.TABLE_NAME;


-- ---------------------------------------------------------------------
-- Unexpected RAW tables
-- ---------------------------------------------------------------------

SELECT
    T.TABLE_NAME AS UNEXPECTED_TABLE
FROM RAW.INFORMATION_SCHEMA.TABLES T
LEFT JOIN EXPECTED_RAW_TABLES E
    ON T.TABLE_NAME = E.TABLE_NAME
WHERE T.TABLE_SCHEMA = 'BANKING'
  AND T.TABLE_TYPE = 'BASE TABLE'
  AND E.TABLE_NAME IS NULL
ORDER BY T.TABLE_NAME;


-- =====================================================================
-- 3. EXPECTED COLUMN INVENTORY
-- =====================================================================
--
-- This protects against schema drift.
--
-- We explicitly define the source contract represented by your CSVs.
--
-- =====================================================================

CREATE OR REPLACE TEMP TABLE EXPECTED_RAW_COLUMNS (
    TABLE_NAME  VARCHAR,
    COLUMN_NAME VARCHAR
);


-- ---------------------------------------------------------------------
-- ACCOUNT
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('ACCOUNT', 'ACCOUNT_ID'),
    ('ACCOUNT', 'ACCOUNT_NUMBER'),
    ('ACCOUNT', 'CUSTOMER_ID'),
    ('ACCOUNT', 'PRODUCT_ID'),
    ('ACCOUNT', 'BRANCH_ID'),
    ('ACCOUNT', 'OPEN_DATE'),
    ('ACCOUNT', 'CLOSE_DATE'),
    ('ACCOUNT', 'ACCOUNT_STATUS'),
    ('ACCOUNT', 'CURRENCY'),
    ('ACCOUNT', 'CURRENT_BALANCE'),
    ('ACCOUNT', 'ACCOUNT_TYPE');


-- ---------------------------------------------------------------------
-- ACCOUNT_DAILY_BALANCE
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('ACCOUNT_DAILY_BALANCE', 'ACCOUNT_ID'),
    ('ACCOUNT_DAILY_BALANCE', 'BUSINESS_DATE'),
    ('ACCOUNT_DAILY_BALANCE', 'OPENING_BALANCE'),
    ('ACCOUNT_DAILY_BALANCE', 'CLOSING_BALANCE'),
    ('ACCOUNT_DAILY_BALANCE', 'AVAILABLE_BALANCE'),
    ('ACCOUNT_DAILY_BALANCE', 'CURRENCY'),
    ('ACCOUNT_DAILY_BALANCE', 'SOURCE_SYSTEM'),
    ('ACCOUNT_DAILY_BALANCE', 'LOAD_TIMESTAMP');


-- ---------------------------------------------------------------------
-- BRANCH
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('BRANCH', 'BRANCH_ID'),
    ('BRANCH', 'BRANCH_CODE'),
    ('BRANCH', 'BRANCH_NAME'),
    ('BRANCH', 'REGION'),
    ('BRANCH', 'CITY'),
    ('BRANCH', 'STATE'),
    ('BRANCH', 'POSTAL_CODE'),
    ('BRANCH', 'BRANCH_STATUS');


-- ---------------------------------------------------------------------
-- CARD
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('CARD', 'CARD_ID'),
    ('CARD', 'ACCOUNT_ID'),
    ('CARD', 'CUSTOMER_ID'),
    ('CARD', 'CARD_NUMBER'),
    ('CARD', 'CARD_TYPE'),
    ('CARD', 'ISSUE_DATE'),
    ('CARD', 'EXPIRY_DATE'),
    ('CARD', 'CARD_STATUS');


-- ---------------------------------------------------------------------
-- CUSTOMER
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('CUSTOMER', 'CUSTOMER_ID'),
    ('CUSTOMER', 'CUSTOMER_TYPE'),
    ('CUSTOMER', 'FIRST_NAME'),
    ('CUSTOMER', 'LAST_NAME'),
    ('CUSTOMER', 'BUSINESS_NAME'),
    ('CUSTOMER', 'TAX_ID'),
    ('CUSTOMER', 'DATE_OF_BIRTH'),
    ('CUSTOMER', 'EMAIL'),
    ('CUSTOMER', 'PHONE'),
    ('CUSTOMER', 'ADDRESS_LINE1'),
    ('CUSTOMER', 'CITY'),
    ('CUSTOMER', 'STATE'),
    ('CUSTOMER', 'POSTAL_CODE'),
    ('CUSTOMER', 'COUNTRY'),
    ('CUSTOMER', 'BRANCH_ID'),
    ('CUSTOMER', 'OFFICER_ID'),
    ('CUSTOMER', 'CUSTOMER_STATUS'),
    ('CUSTOMER', 'CREATED_DATE'),
    ('CUSTOMER', 'UPDATED_TIMESTAMP'),
    ('CUSTOMER', 'CUST_REF'),
    ('CUSTOMER', 'NOTES');


-- ---------------------------------------------------------------------
-- GL_CONTROL_TOTAL
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('GL_CONTROL_TOTAL', 'GL_CONTROL_ID'),
    ('GL_CONTROL_TOTAL', 'BUSINESS_DATE'),
    ('GL_CONTROL_TOTAL', 'GL_ACCOUNT_CODE'),
    ('GL_CONTROL_TOTAL', 'PRODUCT_TYPE'),
    ('GL_CONTROL_TOTAL', 'CURRENCY'),
    ('GL_CONTROL_TOTAL', 'CONTROL_TOTAL'),
    ('GL_CONTROL_TOTAL', 'TRANSACTION_COUNT'),
    ('GL_CONTROL_TOTAL', 'SOURCE_SYSTEM'),
    ('GL_CONTROL_TOTAL', 'LOAD_TIMESTAMP');


-- ---------------------------------------------------------------------
-- LOAN
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('LOAN', 'LOAN_ID'),
    ('LOAN', 'LOAN_NUMBER'),
    ('LOAN', 'CUSTOMER_ID'),
    ('LOAN', 'PRODUCT_ID'),
    ('LOAN', 'BRANCH_ID'),
    ('LOAN', 'OFFICER_ID'),
    ('LOAN', 'LOAN_TYPE'),
    ('LOAN', 'LOAN_AMOUNT'),
    ('LOAN', 'OUTSTANDING_AMOUNT'),
    ('LOAN', 'INTEREST_RATE'),
    ('LOAN', 'TENURE_MONTHS'),
    ('LOAN', 'START_DATE'),
    ('LOAN', 'MATURITY_DATE'),
    ('LOAN', 'CREDIT_GRADE'),
    ('LOAN', 'LOAN_STATUS');


-- ---------------------------------------------------------------------
-- LOAN_COLLATERAL
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('LOAN_COLLATERAL', 'COLLATERAL_ID'),
    ('LOAN_COLLATERAL', 'LOAN_ID'),
    ('LOAN_COLLATERAL', 'COLLATERAL_TYPE'),
    ('LOAN_COLLATERAL', 'DESCRIPTION'),
    ('LOAN_COLLATERAL', 'VALUATION_AMOUNT'),
    ('LOAN_COLLATERAL', 'VALUATION_DATE'),
    ('LOAN_COLLATERAL', 'OWNER_NAME'),
    ('LOAN_COLLATERAL', 'COLLATERAL_STATUS');


-- ---------------------------------------------------------------------
-- OFFICER
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('OFFICER', 'OFFICER_ID'),
    ('OFFICER', 'OFFICER_CODE'),
    ('OFFICER', 'OFFICER_NAME'),
    ('OFFICER', 'BRANCH_ID'),
    ('OFFICER', 'ROLE'),
    ('OFFICER', 'EMAIL'),
    ('OFFICER', 'STATUS');


-- ---------------------------------------------------------------------
-- PRODUCT
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('PRODUCT', 'PRODUCT_ID'),
    ('PRODUCT', 'PRODUCT_CODE'),
    ('PRODUCT', 'PRODUCT_NAME'),
    ('PRODUCT', 'PRODUCT_TYPE'),
    ('PRODUCT', 'CURRENCY'),
    ('PRODUCT', 'INTEREST_RATE'),
    ('PRODUCT', 'MIN_BALANCE'),
    ('PRODUCT', 'PRODUCT_STATUS');


-- ---------------------------------------------------------------------
-- TRANSACTIONS
-- ---------------------------------------------------------------------

INSERT INTO EXPECTED_RAW_COLUMNS
SELECT COLUMN1, COLUMN2
FROM VALUES
    ('TRANSACTIONS', 'TRANSACTION_ID'),
    ('TRANSACTIONS', 'ACCOUNT_ID'),
    ('TRANSACTIONS', 'CUSTOMER_ID'),
    ('TRANSACTIONS', 'TRANSACTION_DATE'),
    ('TRANSACTIONS', 'POSTING_DATE'),
    ('TRANSACTIONS', 'TRANSACTION_TYPE'),
    ('TRANSACTIONS', 'TRANSACTION_CODE'),
    ('TRANSACTIONS', 'AMOUNT'),
    ('TRANSACTIONS', 'CURRENCY'),
    ('TRANSACTIONS', 'DEBIT_CREDIT'),
    ('TRANSACTIONS', 'CHANNEL'),
    ('TRANSACTIONS', 'MERCHANT_NAME'),
    ('TRANSACTIONS', 'STATUS'),
    ('TRANSACTIONS', 'REFERENCE'),
    ('TRANSACTIONS', 'MEMO'),
    ('TRANSACTIONS', 'BALANCE_AFTER_TRANSACTION'),
    ('TRANSACTIONS', 'LOAD_TIMESTAMP'),
    ('TRANSACTIONS', 'TRANSACTION_GROUP_ID');


-- =====================================================================
-- 4. SCHEMA DRIFT CHECK
-- =====================================================================

CREATE OR REPLACE TEMP TABLE RAW_SCHEMA_DIFF AS

-- Expected but missing
SELECT
    'MISSING_COLUMN' AS ISSUE_TYPE,
    E.TABLE_NAME,
    E.COLUMN_NAME
FROM EXPECTED_RAW_COLUMNS E
LEFT JOIN RAW.INFORMATION_SCHEMA.COLUMNS A
    ON A.TABLE_SCHEMA = 'BANKING'
   AND A.TABLE_NAME = E.TABLE_NAME
   AND A.COLUMN_NAME = E.COLUMN_NAME
WHERE A.COLUMN_NAME IS NULL

UNION ALL

-- Present but not expected
SELECT
    'UNEXPECTED_COLUMN' AS ISSUE_TYPE,
    A.TABLE_NAME,
    A.COLUMN_NAME
FROM RAW.INFORMATION_SCHEMA.COLUMNS A
LEFT JOIN EXPECTED_RAW_COLUMNS E
    ON A.TABLE_NAME = E.TABLE_NAME
   AND A.COLUMN_NAME = E.COLUMN_NAME
WHERE A.TABLE_SCHEMA = 'BANKING'
  AND A.TABLE_NAME IN (
      SELECT TABLE_NAME
      FROM EXPECTED_RAW_TABLES
  )
  AND E.COLUMN_NAME IS NULL;


SELECT *
FROM RAW_SCHEMA_DIFF
ORDER BY TABLE_NAME, ISSUE_TYPE, COLUMN_NAME;


-- =====================================================================
-- 5. ROW COUNTS
-- =====================================================================

CREATE OR REPLACE TEMP TABLE RAW_ROW_COUNTS AS

SELECT 'ACCOUNT' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.ACCOUNT

UNION ALL

SELECT 'ACCOUNT_DAILY_BALANCE', COUNT(*)
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE

UNION ALL

SELECT 'BRANCH', COUNT(*)
FROM RAW.BANKING.BRANCH

UNION ALL

SELECT 'CARD', COUNT(*)
FROM RAW.BANKING.CARD

UNION ALL

SELECT 'CUSTOMER', COUNT(*)
FROM RAW.BANKING.CUSTOMER

UNION ALL

SELECT 'GL_CONTROL_TOTAL', COUNT(*)
FROM RAW.BANKING.GL_CONTROL_TOTAL

UNION ALL

SELECT 'LOAN', COUNT(*)
FROM RAW.BANKING.LOAN

UNION ALL

SELECT 'LOAN_COLLATERAL', COUNT(*)
FROM RAW.BANKING.LOAN_COLLATERAL

UNION ALL

SELECT 'OFFICER', COUNT(*)
FROM RAW.BANKING.OFFICER

UNION ALL

SELECT 'PRODUCT', COUNT(*)
FROM RAW.BANKING.PRODUCT

UNION ALL

SELECT 'TRANSACTIONS', COUNT(*)
FROM RAW.BANKING.TRANSACTIONS;


SELECT *
FROM RAW_ROW_COUNTS
ORDER BY TABLE_NAME;


-- =====================================================================
-- 6. EMPTY TABLE CHECK
-- =====================================================================

SELECT
    TABLE_NAME,
    ROW_COUNT,
    IFF(ROW_COUNT > 0, 'PASS', 'FAIL') AS STATUS
FROM RAW_ROW_COUNTS
ORDER BY TABLE_NAME;


-- =====================================================================
-- 7. AVIDIA MINIMUM CUSTOMER REQUIREMENT
-- =====================================================================
--
-- Specification:
--     >= 3,000 customers
--
-- =====================================================================

SELECT
    COUNT(*) AS CUSTOMER_COUNT,
    3000 AS MINIMUM_REQUIRED,
    IFF(COUNT(*) >= 3000, 'PASS', 'FAIL') AS STATUS
FROM RAW.BANKING.CUSTOMER;


-- =====================================================================
-- 8. CUSTOMER TYPE COVERAGE
-- =====================================================================
--
-- Specification requires persons AND businesses.
--
-- =====================================================================

SELECT
    CUSTOMER_TYPE,
    COUNT(*) AS CUSTOMER_COUNT
FROM RAW.BANKING.CUSTOMER
GROUP BY CUSTOMER_TYPE
ORDER BY CUSTOMER_TYPE;


SELECT
    COUNT_IF(UPPER(CUSTOMER_TYPE) = 'PERSON') AS PERSON_COUNT,
    COUNT_IF(UPPER(CUSTOMER_TYPE) = 'BUSINESS') AS BUSINESS_COUNT,

    IFF(
        COUNT_IF(UPPER(CUSTOMER_TYPE) = 'PERSON') > 0
        AND
        COUNT_IF(UPPER(CUSTOMER_TYPE) = 'BUSINESS') > 0,
        'PASS',
        'FAIL'
    ) AS STATUS

FROM RAW.BANKING.CUSTOMER;


-- =====================================================================
-- 9. PRIMARY KEY NULL CHECKS
-- =====================================================================

SELECT 'ACCOUNT' AS TABLE_NAME,
       COUNT_IF(ACCOUNT_ID IS NULL) AS NULL_KEY_COUNT
FROM RAW.BANKING.ACCOUNT

UNION ALL

SELECT 'ACCOUNT_DAILY_BALANCE',
       COUNT_IF(ACCOUNT_ID IS NULL OR BUSINESS_DATE IS NULL)
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE

UNION ALL

SELECT 'BRANCH',
       COUNT_IF(BRANCH_ID IS NULL)
FROM RAW.BANKING.BRANCH

UNION ALL

SELECT 'CARD',
       COUNT_IF(CARD_ID IS NULL)
FROM RAW.BANKING.CARD

UNION ALL

SELECT 'CUSTOMER',
       COUNT_IF(CUSTOMER_ID IS NULL)
FROM RAW.BANKING.CUSTOMER

UNION ALL

SELECT 'GL_CONTROL_TOTAL',
       COUNT_IF(GL_CONTROL_ID IS NULL)
FROM RAW.BANKING.GL_CONTROL_TOTAL

UNION ALL

SELECT 'LOAN',
       COUNT_IF(LOAN_ID IS NULL)
FROM RAW.BANKING.LOAN

UNION ALL

SELECT 'LOAN_COLLATERAL',
       COUNT_IF(COLLATERAL_ID IS NULL)
FROM RAW.BANKING.LOAN_COLLATERAL

UNION ALL

SELECT 'OFFICER',
       COUNT_IF(OFFICER_ID IS NULL)
FROM RAW.BANKING.OFFICER

UNION ALL

SELECT 'PRODUCT',
       COUNT_IF(PRODUCT_ID IS NULL)
FROM RAW.BANKING.PRODUCT

UNION ALL

SELECT 'TRANSACTIONS',
       COUNT_IF(TRANSACTION_ID IS NULL)
FROM RAW.BANKING.TRANSACTIONS;


-- =====================================================================
-- 10. PRIMARY KEY DUPLICATE CHECKS
-- =====================================================================

SELECT
    'ACCOUNT' AS TABLE_NAME,
    COUNT(ACCOUNT_ID) - COUNT(DISTINCT ACCOUNT_ID) AS DUPLICATE_COUNT
FROM RAW.BANKING.ACCOUNT

UNION ALL

SELECT
    'BRANCH',
    COUNT(BRANCH_ID) - COUNT(DISTINCT BRANCH_ID)
FROM RAW.BANKING.BRANCH

UNION ALL

SELECT
    'CARD',
    COUNT(CARD_ID) - COUNT(DISTINCT CARD_ID)
FROM RAW.BANKING.CARD

UNION ALL

SELECT
    'CUSTOMER',
    COUNT(CUSTOMER_ID) - COUNT(DISTINCT CUSTOMER_ID)
FROM RAW.BANKING.CUSTOMER

UNION ALL

SELECT
    'GL_CONTROL_TOTAL',
    COUNT(GL_CONTROL_ID) - COUNT(DISTINCT GL_CONTROL_ID)
FROM RAW.BANKING.GL_CONTROL_TOTAL

UNION ALL

SELECT
    'LOAN',
    COUNT(LOAN_ID) - COUNT(DISTINCT LOAN_ID)
FROM RAW.BANKING.LOAN

UNION ALL

SELECT
    'LOAN_COLLATERAL',
    COUNT(COLLATERAL_ID) - COUNT(DISTINCT COLLATERAL_ID)
FROM RAW.BANKING.LOAN_COLLATERAL

UNION ALL

SELECT
    'OFFICER',
    COUNT(OFFICER_ID) - COUNT(DISTINCT OFFICER_ID)
FROM RAW.BANKING.OFFICER

UNION ALL

SELECT
    'PRODUCT',
    COUNT(PRODUCT_ID) - COUNT(DISTINCT PRODUCT_ID)
FROM RAW.BANKING.PRODUCT

UNION ALL

SELECT
    'TRANSACTIONS',
    COUNT(TRANSACTION_ID) - COUNT(DISTINCT TRANSACTION_ID)
FROM RAW.BANKING.TRANSACTIONS;


-- =====================================================================
-- 11. ACCOUNT DAILY BALANCE COMPOSITE KEY
-- =====================================================================
--
-- Logical key:
--
--     ACCOUNT_ID + BUSINESS_DATE
--
-- =====================================================================

SELECT
    ACCOUNT_ID,
    BUSINESS_DATE,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
GROUP BY
    ACCOUNT_ID,
    BUSINESS_DATE
HAVING COUNT(*) > 1
ORDER BY DUPLICATE_COUNT DESC;


-- =====================================================================
-- 12. BUSINESS KEY UNIQUENESS
-- =====================================================================

SELECT
    ACCOUNT_NUMBER,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.ACCOUNT
GROUP BY ACCOUNT_NUMBER
HAVING COUNT(*) > 1;


SELECT
    BRANCH_CODE,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.BRANCH
GROUP BY BRANCH_CODE
HAVING COUNT(*) > 1;


SELECT
    OFFICER_CODE,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.OFFICER
GROUP BY OFFICER_CODE
HAVING COUNT(*) > 1;


SELECT
    PRODUCT_CODE,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.PRODUCT
GROUP BY PRODUCT_CODE
HAVING COUNT(*) > 1;


SELECT
    LOAN_NUMBER,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.LOAN
GROUP BY LOAN_NUMBER
HAVING COUNT(*) > 1;


SELECT
    CARD_NUMBER,
    COUNT(*) AS DUPLICATE_COUNT
FROM RAW.BANKING.CARD
GROUP BY CARD_NUMBER
HAVING COUNT(*) > 1;


-- =====================================================================
-- 13. ACCOUNT -> CUSTOMER REFERENTIAL INTEGRITY
-- =====================================================================

SELECT
    A.ACCOUNT_ID,
    A.CUSTOMER_ID
FROM RAW.BANKING.ACCOUNT A
LEFT JOIN RAW.BANKING.CUSTOMER C
    ON A.CUSTOMER_ID = C.CUSTOMER_ID
WHERE C.CUSTOMER_ID IS NULL;


-- =====================================================================
-- 14. ACCOUNT -> PRODUCT
-- =====================================================================

SELECT
    A.ACCOUNT_ID,
    A.PRODUCT_ID
FROM RAW.BANKING.ACCOUNT A
LEFT JOIN RAW.BANKING.PRODUCT P
    ON A.PRODUCT_ID = P.PRODUCT_ID
WHERE P.PRODUCT_ID IS NULL;


-- =====================================================================
-- 15. ACCOUNT -> BRANCH
-- =====================================================================

SELECT
    A.ACCOUNT_ID,
    A.BRANCH_ID
FROM RAW.BANKING.ACCOUNT A
LEFT JOIN RAW.BANKING.BRANCH B
    ON A.BRANCH_ID = B.BRANCH_ID
WHERE B.BRANCH_ID IS NULL;


-- =====================================================================
-- 16. ACCOUNT DAILY BALANCE -> ACCOUNT
-- =====================================================================

SELECT
    D.ACCOUNT_ID,
    D.BUSINESS_DATE
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE D
LEFT JOIN RAW.BANKING.ACCOUNT A
    ON D.ACCOUNT_ID = A.ACCOUNT_ID
WHERE A.ACCOUNT_ID IS NULL;


-- =====================================================================
-- 17. CARD -> ACCOUNT / CUSTOMER
-- =====================================================================

SELECT
    C.CARD_ID,
    C.ACCOUNT_ID
FROM RAW.BANKING.CARD C
LEFT JOIN RAW.BANKING.ACCOUNT A
    ON C.ACCOUNT_ID = A.ACCOUNT_ID
WHERE A.ACCOUNT_ID IS NULL;


SELECT
    C.CARD_ID,
    C.CUSTOMER_ID
FROM RAW.BANKING.CARD C
LEFT JOIN RAW.BANKING.CUSTOMER CU
    ON C.CUSTOMER_ID = CU.CUSTOMER_ID
WHERE CU.CUSTOMER_ID IS NULL;


-- =====================================================================
-- 18. LOAN RELATIONSHIPS
-- =====================================================================

-- Customer
SELECT
    L.LOAN_ID,
    L.CUSTOMER_ID
FROM RAW.BANKING.LOAN L
LEFT JOIN RAW.BANKING.CUSTOMER C
    ON L.CUSTOMER_ID = C.CUSTOMER_ID
WHERE C.CUSTOMER_ID IS NULL;


-- Product
SELECT
    L.LOAN_ID,
    L.PRODUCT_ID
FROM RAW.BANKING.LOAN L
LEFT JOIN RAW.BANKING.PRODUCT P
    ON L.PRODUCT_ID = P.PRODUCT_ID
WHERE P.PRODUCT_ID IS NULL;


-- Branch
SELECT
    L.LOAN_ID,
    L.BRANCH_ID
FROM RAW.BANKING.LOAN L
LEFT JOIN RAW.BANKING.BRANCH B
    ON L.BRANCH_ID = B.BRANCH_ID
WHERE B.BRANCH_ID IS NULL;


-- Officer
SELECT
    L.LOAN_ID,
    L.OFFICER_ID
FROM RAW.BANKING.LOAN L
LEFT JOIN RAW.BANKING.OFFICER O
    ON L.OFFICER_ID = O.OFFICER_ID
WHERE O.OFFICER_ID IS NULL;


-- =====================================================================
-- 19. COLLATERAL -> LOAN
-- =====================================================================

SELECT
    C.COLLATERAL_ID,
    C.LOAN_ID
FROM RAW.BANKING.LOAN_COLLATERAL C
LEFT JOIN RAW.BANKING.LOAN L
    ON C.LOAN_ID = L.LOAN_ID
WHERE L.LOAN_ID IS NULL;


-- =====================================================================
-- 20. OFFICER -> BRANCH
-- =====================================================================

SELECT
    O.OFFICER_ID,
    O.BRANCH_ID
FROM RAW.BANKING.OFFICER O
LEFT JOIN RAW.BANKING.BRANCH B
    ON O.BRANCH_ID = B.BRANCH_ID
WHERE B.BRANCH_ID IS NULL;


-- =====================================================================
-- 21. TRANSACTION -> ACCOUNT / CUSTOMER
-- =====================================================================

SELECT
    T.TRANSACTION_ID,
    T.ACCOUNT_ID
FROM RAW.BANKING.TRANSACTIONS T
LEFT JOIN RAW.BANKING.ACCOUNT A
    ON T.ACCOUNT_ID = A.ACCOUNT_ID
WHERE A.ACCOUNT_ID IS NULL;


SELECT
    T.TRANSACTION_ID,
    T.CUSTOMER_ID
FROM RAW.BANKING.TRANSACTIONS T
LEFT JOIN RAW.BANKING.CUSTOMER C
    ON T.CUSTOMER_ID = C.CUSTOMER_ID
WHERE C.CUSTOMER_ID IS NULL;


-- =====================================================================
-- 22. TRANSACTION CUSTOMER MUST MATCH ACCOUNT OWNER
-- =====================================================================
--
-- Particularly useful because the specification later requires an
-- account -> customer consistency DQ check.
--
-- Catching generator defects now avoids carrying bad RAW data forward.
--
-- =====================================================================

SELECT
    T.TRANSACTION_ID,
    T.ACCOUNT_ID,
    T.CUSTOMER_ID AS TRANSACTION_CUSTOMER,
    A.CUSTOMER_ID AS ACCOUNT_CUSTOMER
FROM RAW.BANKING.TRANSACTIONS T
JOIN RAW.BANKING.ACCOUNT A
    ON T.ACCOUNT_ID = A.ACCOUNT_ID
WHERE T.CUSTOMER_ID <> A.CUSTOMER_ID;


-- =====================================================================
-- 23. CARD CUSTOMER MUST MATCH ACCOUNT OWNER
-- =====================================================================

SELECT
    C.CARD_ID,
    C.ACCOUNT_ID,
    C.CUSTOMER_ID AS CARD_CUSTOMER,
    A.CUSTOMER_ID AS ACCOUNT_CUSTOMER
FROM RAW.BANKING.CARD C
JOIN RAW.BANKING.ACCOUNT A
    ON C.ACCOUNT_ID = A.ACCOUNT_ID
WHERE C.CUSTOMER_ID <> A.CUSTOMER_ID;


-- =====================================================================
-- 24. ACCOUNT DAILY BALANCE CURRENCY VS ACCOUNT CURRENCY
-- =====================================================================

SELECT
    D.ACCOUNT_ID,
    D.BUSINESS_DATE,
    D.CURRENCY AS DAILY_BALANCE_CURRENCY,
    A.CURRENCY AS ACCOUNT_CURRENCY
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE D
JOIN RAW.BANKING.ACCOUNT A
    ON D.ACCOUNT_ID = A.ACCOUNT_ID
WHERE D.CURRENCY <> A.CURRENCY;


-- =====================================================================
-- 25. TRANSACTION CURRENCY VS ACCOUNT CURRENCY
-- =====================================================================

SELECT
    T.TRANSACTION_ID,
    T.ACCOUNT_ID,
    T.CURRENCY AS TRANSACTION_CURRENCY,
    A.CURRENCY AS ACCOUNT_CURRENCY
FROM RAW.BANKING.TRANSACTIONS T
JOIN RAW.BANKING.ACCOUNT A
    ON T.ACCOUNT_ID = A.ACCOUNT_ID
WHERE T.CURRENCY <> A.CURRENCY;


-- =====================================================================
-- 26. ACCOUNT CURRENCY VS PRODUCT CURRENCY
-- =====================================================================

SELECT
    A.ACCOUNT_ID,
    A.PRODUCT_ID,
    A.CURRENCY AS ACCOUNT_CURRENCY,
    P.CURRENCY AS PRODUCT_CURRENCY
FROM RAW.BANKING.ACCOUNT A
JOIN RAW.BANKING.PRODUCT P
    ON A.PRODUCT_ID = P.PRODUCT_ID
WHERE A.CURRENCY <> P.CURRENCY;


-- =====================================================================
-- 27. CUSTOMER OFFICER / BRANCH CONSISTENCY
-- =====================================================================

SELECT
    C.CUSTOMER_ID,
    C.BRANCH_ID AS CUSTOMER_BRANCH,
    C.OFFICER_ID,
    O.BRANCH_ID AS OFFICER_BRANCH
FROM RAW.BANKING.CUSTOMER C
JOIN RAW.BANKING.OFFICER O
    ON C.OFFICER_ID = O.OFFICER_ID
WHERE C.BRANCH_ID <> O.BRANCH_ID;


-- =====================================================================
-- 28. LOAN OFFICER / BRANCH CONSISTENCY
-- =====================================================================

SELECT
    L.LOAN_ID,
    L.BRANCH_ID AS LOAN_BRANCH,
    L.OFFICER_ID,
    O.BRANCH_ID AS OFFICER_BRANCH
FROM RAW.BANKING.LOAN L
JOIN RAW.BANKING.OFFICER O
    ON L.OFFICER_ID = O.OFFICER_ID
WHERE L.BRANCH_ID <> O.BRANCH_ID;


-- =====================================================================
-- 29. DATE VALIDATION
-- =====================================================================


-- ACCOUNT close cannot precede open
SELECT
    ACCOUNT_ID,
    OPEN_DATE,
    CLOSE_DATE
FROM RAW.BANKING.ACCOUNT
WHERE CLOSE_DATE IS NOT NULL
  AND CLOSE_DATE < OPEN_DATE;


-- CARD expiry cannot precede issue
SELECT
    CARD_ID,
    ISSUE_DATE,
    EXPIRY_DATE
FROM RAW.BANKING.CARD
WHERE EXPIRY_DATE < ISSUE_DATE;


-- LOAN maturity cannot precede start
SELECT
    LOAN_ID,
    START_DATE,
    MATURITY_DATE
FROM RAW.BANKING.LOAN
WHERE MATURITY_DATE < START_DATE;


-- TRANSACTION posting should not precede transaction date
SELECT
    TRANSACTION_ID,
    TRANSACTION_DATE,
    POSTING_DATE
FROM RAW.BANKING.TRANSACTIONS
WHERE POSTING_DATE < TRANSACTION_DATE;


-- CUSTOMER DOB cannot be in future
SELECT
    CUSTOMER_ID,
    DATE_OF_BIRTH
FROM RAW.BANKING.CUSTOMER
WHERE DATE_OF_BIRTH > CURRENT_DATE();


-- Customer update timestamp should not precede creation date
SELECT
    CUSTOMER_ID,
    CREATED_DATE,
    UPDATED_TIMESTAMP
FROM RAW.BANKING.CUSTOMER
WHERE UPDATED_TIMESTAMP::DATE < CREATED_DATE;


-- Business dates should not be in the future
SELECT
    ACCOUNT_ID,
    BUSINESS_DATE
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
WHERE BUSINESS_DATE > CURRENT_DATE();


SELECT
    GL_CONTROL_ID,
    BUSINESS_DATE
FROM RAW.BANKING.GL_CONTROL_TOTAL
WHERE BUSINESS_DATE > CURRENT_DATE();


-- =====================================================================
-- 30. NUMERIC SANITY CHECKS
-- =====================================================================


-- Transactions should carry positive absolute transaction amounts.
SELECT
    TRANSACTION_ID,
    AMOUNT
FROM RAW.BANKING.TRANSACTIONS
WHERE AMOUNT IS NULL
   OR AMOUNT <= 0;


-- Loan amounts
SELECT
    LOAN_ID,
    LOAN_AMOUNT,
    OUTSTANDING_AMOUNT
FROM RAW.BANKING.LOAN
WHERE LOAN_AMOUNT <= 0
   OR OUTSTANDING_AMOUNT < 0;


-- Interest rate
SELECT
    LOAN_ID,
    INTEREST_RATE
FROM RAW.BANKING.LOAN
WHERE INTEREST_RATE < 0
   OR INTEREST_RATE > 100;


-- Loan tenure
SELECT
    LOAN_ID,
    TENURE_MONTHS
FROM RAW.BANKING.LOAN
WHERE TENURE_MONTHS <= 0;


-- Collateral valuation
SELECT
    COLLATERAL_ID,
    VALUATION_AMOUNT
FROM RAW.BANKING.LOAN_COLLATERAL
WHERE VALUATION_AMOUNT <= 0;


-- Product rates and minimum balance
SELECT
    PRODUCT_ID,
    INTEREST_RATE,
    MIN_BALANCE
FROM RAW.BANKING.PRODUCT
WHERE INTEREST_RATE < 0
   OR INTEREST_RATE > 100
   OR MIN_BALANCE < 0;


-- GL controls
SELECT
    GL_CONTROL_ID,
    CONTROL_TOTAL,
    TRANSACTION_COUNT
FROM RAW.BANKING.GL_CONTROL_TOTAL
WHERE CONTROL_TOTAL < 0
   OR TRANSACTION_COUNT < 0;


-- =====================================================================
-- 31. IDENTIFIER FORMAT CHECKS
-- =====================================================================
--
-- These intentionally validate only prefix + numeric suffix.
-- That makes them less brittle than hard-coding exact lengths.
--
-- =====================================================================

SELECT CUSTOMER_ID
FROM RAW.BANKING.CUSTOMER
WHERE CUSTOMER_ID IS NOT NULL
  AND NOT REGEXP_LIKE(CUSTOMER_ID, '^CU[0-9]+$');


SELECT ACCOUNT_ID
FROM RAW.BANKING.ACCOUNT
WHERE ACCOUNT_ID IS NOT NULL
  AND NOT REGEXP_LIKE(ACCOUNT_ID, '^AC[0-9]+$');


SELECT BRANCH_ID
FROM RAW.BANKING.BRANCH
WHERE BRANCH_ID IS NOT NULL
  AND NOT REGEXP_LIKE(BRANCH_ID, '^BR[0-9]+$');


SELECT CARD_ID
FROM RAW.BANKING.CARD
WHERE CARD_ID IS NOT NULL
  AND NOT REGEXP_LIKE(CARD_ID, '^CA[0-9]+$');


SELECT LOAN_ID
FROM RAW.BANKING.LOAN
WHERE LOAN_ID IS NOT NULL
  AND NOT REGEXP_LIKE(LOAN_ID, '^LN[0-9]+$');


SELECT COLLATERAL_ID
FROM RAW.BANKING.LOAN_COLLATERAL
WHERE COLLATERAL_ID IS NOT NULL
  AND NOT REGEXP_LIKE(COLLATERAL_ID, '^CO[0-9]+$');


SELECT OFFICER_ID
FROM RAW.BANKING.OFFICER
WHERE OFFICER_ID IS NOT NULL
  AND NOT REGEXP_LIKE(OFFICER_ID, '^OF[0-9]+$');


SELECT PRODUCT_ID
FROM RAW.BANKING.PRODUCT
WHERE PRODUCT_ID IS NOT NULL
  AND NOT REGEXP_LIKE(PRODUCT_ID, '^PR[0-9]+$');


SELECT TRANSACTION_ID
FROM RAW.BANKING.TRANSACTIONS
WHERE TRANSACTION_ID IS NOT NULL
  AND NOT REGEXP_LIKE(TRANSACTION_ID, '^TX[0-9]+$');


-- =====================================================================
-- 32. ACCOUNT NUMBER FORMAT
-- =====================================================================

SELECT
    ACCOUNT_ID,
    ACCOUNT_NUMBER
FROM RAW.BANKING.ACCOUNT
WHERE ACCOUNT_NUMBER IS NULL
   OR NOT REGEXP_LIKE(ACCOUNT_NUMBER, '^[0-9]+$');


-- =====================================================================
-- 33. CARD PAN SHAPE
-- =====================================================================
--
-- Remove dashes/spaces and check that PAN contains 16 digits.
--
-- This is NOT your Snowflake custom classifier yet.
-- It is only an ingestion sanity check.
--
-- =====================================================================

SELECT
    CARD_ID,
    CARD_NUMBER
FROM RAW.BANKING.CARD
WHERE CARD_NUMBER IS NULL
   OR LENGTH(REGEXP_REPLACE(CARD_NUMBER, '[^0-9]', '')) <> 16;


-- =====================================================================
-- 34. EMAIL SHAPE
-- =====================================================================

SELECT
    CUSTOMER_ID,
    EMAIL
FROM RAW.BANKING.CUSTOMER
WHERE EMAIL IS NOT NULL
  AND NOT REGEXP_LIKE(
      EMAIL,
      '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
  );


SELECT
    OFFICER_ID,
    EMAIL
FROM RAW.BANKING.OFFICER
WHERE EMAIL IS NOT NULL
  AND NOT REGEXP_LIKE(
      EMAIL,
      '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
  );


-- =====================================================================
-- 35. PERSON / BUSINESS ATTRIBUTE CONSISTENCY
-- =====================================================================


-- PERSON should normally have first/last name and DOB.
SELECT
    CUSTOMER_ID,
    CUSTOMER_TYPE,
    FIRST_NAME,
    LAST_NAME,
    DATE_OF_BIRTH
FROM RAW.BANKING.CUSTOMER
WHERE UPPER(CUSTOMER_TYPE) = 'PERSON'
  AND (
       FIRST_NAME IS NULL
       OR LAST_NAME IS NULL
       OR DATE_OF_BIRTH IS NULL
  );


-- BUSINESS should normally have business name.
SELECT
    CUSTOMER_ID,
    CUSTOMER_TYPE,
    BUSINESS_NAME
FROM RAW.BANKING.CUSTOMER
WHERE UPPER(CUSTOMER_TYPE) = 'BUSINESS'
  AND BUSINESS_NAME IS NULL;


-- =====================================================================
-- 36. CORE SENSITIVE DATA COMPLETENESS
-- =====================================================================
--
-- The specification explicitly expects customer tax ID, DOB, address,
-- e-mail and phone in the synthetic banking dataset.
--
-- =====================================================================

SELECT
    COUNT(*) AS CUSTOMER_COUNT,

    COUNT_IF(TAX_ID IS NULL) AS MISSING_TAX_ID,

    COUNT_IF(
        CUSTOMER_TYPE = 'PERSON'
        AND DATE_OF_BIRTH IS NULL
    ) AS MISSING_PERSON_DOB,

    COUNT_IF(EMAIL IS NULL) AS MISSING_EMAIL,

    COUNT_IF(PHONE IS NULL) AS MISSING_PHONE,

    COUNT_IF(ADDRESS_LINE1 IS NULL) AS MISSING_ADDRESS

FROM RAW.BANKING.CUSTOMER;


-- =====================================================================
-- 37. CLASSIFICATION READINESS
-- =====================================================================
--
-- The specification requires at least four deliberately mislabeled
-- sensitive columns such as CUST_REF or MEMO.
--
-- The following query assumes these four columns are candidates:
--
--     CUSTOMER.CUST_REF
--     CUSTOMER.NOTES
--     TRANSACTIONS.REFERENCE
--     TRANSACTIONS.MEMO
--
-- IMPORTANT:
-- Adjust this section if your sealed_sensitive_columns.json identifies
-- different deliberately misleading fields.
--
-- =====================================================================

SELECT
    'CUSTOMER.CUST_REF' AS COLUMN_NAME,
    COUNT(*) AS TOTAL_ROWS,
    COUNT_IF(CUST_REF IS NOT NULL AND TRIM(CUST_REF) <> '') AS POPULATED_ROWS
FROM RAW.BANKING.CUSTOMER

UNION ALL

SELECT
    'CUSTOMER.NOTES',
    COUNT(*),
    COUNT_IF(NOTES IS NOT NULL AND TRIM(NOTES) <> '')
FROM RAW.BANKING.CUSTOMER

UNION ALL

SELECT
    'TRANSACTIONS.REFERENCE',
    COUNT(*),
    COUNT_IF(REFERENCE IS NOT NULL AND TRIM(REFERENCE) <> '')
FROM RAW.BANKING.TRANSACTIONS

UNION ALL

SELECT
    'TRANSACTIONS.MEMO',
    COUNT(*),
    COUNT_IF(MEMO IS NOT NULL AND TRIM(MEMO) <> '')
FROM RAW.BANKING.TRANSACTIONS;


-- =====================================================================
-- 38. DOMAIN VALUE PROFILING
-- =====================================================================
--
-- Do not hard-code every allowed value prematurely.
--
-- First inspect the actual generated domain values. These results can
-- later inform STAGING standardisation rules and DQ validity checks.
--
-- =====================================================================


-- CUSTOMER_TYPE
SELECT
    CUSTOMER_TYPE,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.CUSTOMER
GROUP BY CUSTOMER_TYPE
ORDER BY ROW_COUNT DESC;


-- CUSTOMER_STATUS
SELECT
    CUSTOMER_STATUS,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.CUSTOMER
GROUP BY CUSTOMER_STATUS
ORDER BY ROW_COUNT DESC;


-- ACCOUNT_STATUS
SELECT
    ACCOUNT_STATUS,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.ACCOUNT
GROUP BY ACCOUNT_STATUS
ORDER BY ROW_COUNT DESC;


-- ACCOUNT_TYPE
SELECT
    ACCOUNT_TYPE,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.ACCOUNT
GROUP BY ACCOUNT_TYPE
ORDER BY ROW_COUNT DESC;


-- TRANSACTION_TYPE
SELECT
    TRANSACTION_TYPE,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.TRANSACTIONS
GROUP BY TRANSACTION_TYPE
ORDER BY ROW_COUNT DESC;


-- TRANSACTION STATUS
SELECT
    STATUS,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.TRANSACTIONS
GROUP BY STATUS
ORDER BY ROW_COUNT DESC;


-- DEBIT / CREDIT
SELECT
    DEBIT_CREDIT,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.TRANSACTIONS
GROUP BY DEBIT_CREDIT
ORDER BY ROW_COUNT DESC;


-- CARD TYPE
SELECT
    CARD_TYPE,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.CARD
GROUP BY CARD_TYPE
ORDER BY ROW_COUNT DESC;


-- CARD STATUS
SELECT
    CARD_STATUS,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.CARD
GROUP BY CARD_STATUS
ORDER BY ROW_COUNT DESC;


-- LOAN TYPE
SELECT
    LOAN_TYPE,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.LOAN
GROUP BY LOAN_TYPE
ORDER BY ROW_COUNT DESC;


-- LOAN STATUS
SELECT
    LOAN_STATUS,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.LOAN
GROUP BY LOAN_STATUS
ORDER BY ROW_COUNT DESC;


-- CREDIT GRADE
SELECT
    CREDIT_GRADE,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.LOAN
GROUP BY CREDIT_GRADE
ORDER BY ROW_COUNT DESC;


-- CURRENCIES
SELECT
    CURRENCY,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.ACCOUNT
GROUP BY CURRENCY
ORDER BY ROW_COUNT DESC;


-- =====================================================================
-- 39. BUSINESS DATE COVERAGE
-- =====================================================================

SELECT
    MIN(BUSINESS_DATE) AS MIN_BUSINESS_DATE,
    MAX(BUSINESS_DATE) AS MAX_BUSINESS_DATE,
    COUNT(DISTINCT BUSINESS_DATE) AS BUSINESS_DATE_COUNT
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE;


SELECT
    MIN(TRANSACTION_DATE) AS MIN_TRANSACTION_DATE,
    MAX(TRANSACTION_DATE) AS MAX_TRANSACTION_DATE,
    COUNT(DISTINCT TRANSACTION_DATE) AS TRANSACTION_DATE_COUNT
FROM RAW.BANKING.TRANSACTIONS;


SELECT
    MIN(BUSINESS_DATE) AS MIN_GL_DATE,
    MAX(BUSINESS_DATE) AS MAX_GL_DATE,
    COUNT(DISTINCT BUSINESS_DATE) AS GL_DATE_COUNT
FROM RAW.BANKING.GL_CONTROL_TOTAL;


-- =====================================================================
-- 40. SOURCE SYSTEM PROFILING
-- =====================================================================

SELECT
    SOURCE_SYSTEM,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE
GROUP BY SOURCE_SYSTEM
ORDER BY ROW_COUNT DESC;


SELECT
    SOURCE_SYSTEM,
    COUNT(*) AS ROW_COUNT
FROM RAW.BANKING.GL_CONTROL_TOTAL
GROUP BY SOURCE_SYSTEM
ORDER BY ROW_COUNT DESC;


-- =====================================================================
-- 41. LOAD TIMESTAMP COVERAGE
-- =====================================================================

SELECT
    MIN(LOAD_TIMESTAMP) AS EARLIEST_LOAD,
    MAX(LOAD_TIMESTAMP) AS LATEST_LOAD,
    COUNT_IF(LOAD_TIMESTAMP IS NULL) AS MISSING_LOAD_TIMESTAMP
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE;


SELECT
    MIN(LOAD_TIMESTAMP) AS EARLIEST_LOAD,
    MAX(LOAD_TIMESTAMP) AS LATEST_LOAD,
    COUNT_IF(LOAD_TIMESTAMP IS NULL) AS MISSING_LOAD_TIMESTAMP
FROM RAW.BANKING.TRANSACTIONS;


SELECT
    MIN(LOAD_TIMESTAMP) AS EARLIEST_LOAD,
    MAX(LOAD_TIMESTAMP) AS LATEST_LOAD,
    COUNT_IF(LOAD_TIMESTAMP IS NULL) AS MISSING_LOAD_TIMESTAMP
FROM RAW.BANKING.GL_CONTROL_TOTAL;


-- =====================================================================
-- 42. COPY INTO LOAD HISTORY
-- =====================================================================
--
-- Useful evidence that the CSV files actually loaded successfully.
--
-- INFORMATION_SCHEMA is intentionally used here for an immediate check.
--
-- =====================================================================

SELECT
    TABLE_NAME,
    FILE_NAME,
    LAST_LOAD_TIME,
    STATUS,
    ROW_COUNT,
    ROW_PARSED,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM RAW.INFORMATION_SCHEMA.LOAD_HISTORY
WHERE SCHEMA_NAME = 'BANKING'
ORDER BY LAST_LOAD_TIME DESC;


-- =====================================================================
-- 43. HIGH-LEVEL VALIDATION SUMMARY
-- =====================================================================
--
-- This creates a compact result set suitable for:
--
--   * README evidence
--   * screenshots
--   * evidence/
--   * live walkthrough
--
-- =====================================================================

CREATE OR REPLACE TEMP TABLE RAW_VALIDATION_SUMMARY (
    CHECK_NAME       VARCHAR,
    ACTUAL_VALUE     VARCHAR,
    EXPECTED_VALUE   VARCHAR,
    STATUS           VARCHAR
);


-- Schema contract
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'RAW schema matches expected columns',
    COUNT(*)::VARCHAR,
    '0 schema differences',
    IFF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM RAW_SCHEMA_DIFF;


-- All tables populated
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'All RAW tables populated',
    COUNT_IF(ROW_COUNT = 0)::VARCHAR || ' empty tables',
    '0 empty tables',
    IFF(COUNT_IF(ROW_COUNT = 0) = 0, 'PASS', 'FAIL')
FROM RAW_ROW_COUNTS;


-- Customer volume
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'Minimum customer volume',
    COUNT(*)::VARCHAR,
    '>= 3000',
    IFF(COUNT(*) >= 3000, 'PASS', 'FAIL')
FROM RAW.BANKING.CUSTOMER;


-- Person customers
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'PERSON customers exist',
    COUNT_IF(UPPER(CUSTOMER_TYPE) = 'PERSON')::VARCHAR,
    '> 0',
    IFF(
        COUNT_IF(UPPER(CUSTOMER_TYPE) = 'PERSON') > 0,
        'PASS',
        'FAIL'
    )
FROM RAW.BANKING.CUSTOMER;


-- Business customers
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'BUSINESS customers exist',
    COUNT_IF(UPPER(CUSTOMER_TYPE) = 'BUSINESS')::VARCHAR,
    '> 0',
    IFF(
        COUNT_IF(UPPER(CUSTOMER_TYPE) = 'BUSINESS') > 0,
        'PASS',
        'FAIL'
    )
FROM RAW.BANKING.CUSTOMER;


-- Account orphan check
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'ACCOUNT -> CUSTOMER integrity',
    COUNT(*)::VARCHAR || ' orphan rows',
    '0 orphan rows',
    IFF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM RAW.BANKING.ACCOUNT A
LEFT JOIN RAW.BANKING.CUSTOMER C
    ON A.CUSTOMER_ID = C.CUSTOMER_ID
WHERE C.CUSTOMER_ID IS NULL;


-- Transaction/account consistency
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'TRANSACTION customer matches ACCOUNT customer',
    COUNT(*)::VARCHAR || ' mismatches',
    '0 mismatches',
    IFF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM RAW.BANKING.TRANSACTIONS T
JOIN RAW.BANKING.ACCOUNT A
    ON T.ACCOUNT_ID = A.ACCOUNT_ID
WHERE T.CUSTOMER_ID <> A.CUSTOMER_ID;


-- Future business-date check
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'No future daily-balance dates',
    COUNT_IF(BUSINESS_DATE > CURRENT_DATE())::VARCHAR,
    '0 future dates',
    IFF(
        COUNT_IF(BUSINESS_DATE > CURRENT_DATE()) = 0,
        'PASS',
        'FAIL'
    )
FROM RAW.BANKING.ACCOUNT_DAILY_BALANCE;


-- Card PAN length
INSERT INTO RAW_VALIDATION_SUMMARY
SELECT
    'Card PAN shape',
    COUNT_IF(
        CARD_NUMBER IS NULL
        OR LENGTH(REGEXP_REPLACE(CARD_NUMBER, '[^0-9]', '')) <> 16
    )::VARCHAR || ' invalid values',
    '0 invalid values',
    IFF(
        COUNT_IF(
            CARD_NUMBER IS NULL
            OR LENGTH(REGEXP_REPLACE(CARD_NUMBER, '[^0-9]', '')) <> 16
        ) = 0,
        'PASS',
        'FAIL'
    )
FROM RAW.BANKING.CARD;


-- =====================================================================
-- 44. FINAL DASHBOARD
-- =====================================================================

SELECT
    CHECK_NAME,
    ACTUAL_VALUE,
    EXPECTED_VALUE,
    STATUS
FROM RAW_VALIDATION_SUMMARY
ORDER BY
    CASE STATUS
        WHEN 'FAIL' THEN 1
        WHEN 'PASS' THEN 2
        ELSE 3
    END,
    CHECK_NAME;


-- =====================================================================
-- 45. OVERALL STATUS
-- =====================================================================

SELECT
    COUNT(*) AS TOTAL_CHECKS,

    COUNT_IF(STATUS = 'PASS') AS PASSED_CHECKS,

    COUNT_IF(STATUS = 'FAIL') AS FAILED_CHECKS,

    IFF(
        COUNT_IF(STATUS = 'FAIL') = 0,
        'RAW VALIDATION PASSED',
        'RAW VALIDATION FAILED - REVIEW RESULTS'
    ) AS OVERALL_STATUS

FROM RAW_VALIDATION_SUMMARY;


-- =====================================================================
-- END OF RAW VALIDATION
-- =====================================================================