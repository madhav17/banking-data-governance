-- Need to run chmod +x scripts/upload_raw_to_stage.sh, ./scripts/upload_raw_to_stage.sh if data is not available in stage

-- ============================================================
-- Avidia Bank
-- Full RAW Banking Data Load
-- ============================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;


-- ============================================================
-- 1. BRANCH
-- ============================================================

COPY INTO RAW.BANKING.BRANCH
FROM @RAW.BANKING.STG_BANKING_CSV/branch/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 2. OFFICER
-- ============================================================

COPY INTO RAW.BANKING.OFFICER
FROM @RAW.BANKING.STG_BANKING_CSV/officer/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 3. PRODUCT
-- ============================================================

COPY INTO RAW.BANKING.PRODUCT
FROM @RAW.BANKING.STG_BANKING_CSV/product/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 4. CUSTOMER
-- ============================================================

COPY INTO RAW.BANKING.CUSTOMER
FROM @RAW.BANKING.STG_BANKING_CSV/customer/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 5. ACCOUNT
-- ============================================================

COPY INTO RAW.BANKING.ACCOUNT
FROM @RAW.BANKING.STG_BANKING_CSV/account/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 6. ACCOUNT DAILY BALANCE
-- ============================================================

COPY INTO RAW.BANKING.ACCOUNT_DAILY_BALANCE
FROM @RAW.BANKING.STG_BANKING_CSV/account_daily_balance/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 7. CARD
-- ============================================================

COPY INTO RAW.BANKING.CARD
FROM @RAW.BANKING.STG_BANKING_CSV/card/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 8. LOAN
-- ============================================================

COPY INTO RAW.BANKING.LOAN
FROM @RAW.BANKING.STG_BANKING_CSV/loan/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 9. LOAN COLLATERAL
-- ============================================================

COPY INTO RAW.BANKING.LOAN_COLLATERAL
FROM @RAW.BANKING.STG_BANKING_CSV/loan_collateral/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 10. TRANSACTIONS
-- ============================================================

COPY INTO RAW.BANKING.TRANSACTIONS
FROM @RAW.BANKING.STG_BANKING_CSV/transactions/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';


-- ============================================================
-- 11. GL CONTROL TOTAL
-- ============================================================

COPY INTO RAW.BANKING.GL_CONTROL_TOTAL
FROM @RAW.BANKING.STG_BANKING_CSV/gl_control_total/
FILE_FORMAT = (
    FORMAT_NAME = 'RAW.BANKING.FF_BANKING_CSV'
)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
FORCE = TRUE
ON_ERROR = 'ABORT_STATEMENT';