-- =====================================================================
-- Avidia Bank Take-Home
-- File: setup/05_raw_tables.sql
--
-- Purpose:
--   Create source-aligned RAW banking tables.
--
-- Prerequisites:
--   01_roles.sql
--   02_warehouse.sql
--   03_databases_schemas.sql
--   04_base_grants.sql
--
-- Database / Schema:
--   RAW.BANKING
--
-- Design:
--   * Source-aligned column names.
--   * No enforced business constraints in RAW.
--   * Preserve sensitive and deliberately misleading columns.
--   * Business cleansing / standardization happens in STAGING.
-- =====================================================================


USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE RAW;
USE SCHEMA BANKING;


-- =====================================================================
-- 1. BRANCH
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.BRANCH
(
    BRANCH_ID       VARCHAR(20),
    BRANCH_CODE     VARCHAR(20),
    BRANCH_NAME     VARCHAR(150),
    REGION          VARCHAR(50),
    CITY            VARCHAR(100),
    STATE           VARCHAR(100),
    POSTAL_CODE     VARCHAR(20),
    BRANCH_STATUS   VARCHAR(20)
);


-- =====================================================================
-- 2. OFFICER
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.OFFICER
(
    OFFICER_ID      VARCHAR(20),
    OFFICER_CODE    VARCHAR(20),
    OFFICER_NAME    VARCHAR(200),
    BRANCH_ID       VARCHAR(20),
    ROLE            VARCHAR(50),
    EMAIL           VARCHAR(320),
    STATUS          VARCHAR(20)
);


-- =====================================================================
-- 3. PRODUCT
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.PRODUCT
(
    PRODUCT_ID       VARCHAR(20),
    PRODUCT_CODE     VARCHAR(30),
    PRODUCT_NAME     VARCHAR(150),
    PRODUCT_TYPE     VARCHAR(50),
    CURRENCY         VARCHAR(3),
    INTEREST_RATE    NUMBER(9,4),
    MIN_BALANCE      NUMBER(18,2),
    PRODUCT_STATUS   VARCHAR(20)
);


-- =====================================================================
-- 4. CUSTOMER
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.CUSTOMER
(
    CUSTOMER_ID          VARCHAR(20),
    CUSTOMER_TYPE        VARCHAR(30),

    FIRST_NAME           VARCHAR(100),
    LAST_NAME            VARCHAR(100),
    BUSINESS_NAME        VARCHAR(250),

    TAX_ID               VARCHAR(50),
    DATE_OF_BIRTH        DATE,

    EMAIL                VARCHAR(320),
    PHONE                VARCHAR(50),

    ADDRESS_LINE1        VARCHAR(500),
    CITY                 VARCHAR(100),
    STATE                VARCHAR(100),
    POSTAL_CODE          VARCHAR(20),
    COUNTRY              VARCHAR(100),

    BRANCH_ID            VARCHAR(20),
    OFFICER_ID           VARCHAR(20),

    CUSTOMER_STATUS      VARCHAR(30),

    CREATED_DATE         DATE,
    UPDATED_TIMESTAMP    TIMESTAMP_NTZ,

    CUST_REF             VARCHAR(500),
    NOTES                VARCHAR(2000)
);


-- =====================================================================
-- 5. ACCOUNT
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.ACCOUNT
(
    ACCOUNT_ID          VARCHAR(20),
    ACCOUNT_NUMBER      VARCHAR(50),

    CUSTOMER_ID         VARCHAR(20),
    PRODUCT_ID          VARCHAR(20),
    BRANCH_ID           VARCHAR(20),

    OPEN_DATE           DATE,
    CLOSE_DATE          DATE,

    ACCOUNT_STATUS      VARCHAR(30),
    CURRENCY            VARCHAR(3),

    CURRENT_BALANCE     NUMBER(18,2),

    ACCOUNT_TYPE        VARCHAR(50)
);


-- =====================================================================
-- 6. ACCOUNT DAILY BALANCE
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.ACCOUNT_DAILY_BALANCE
(
    ACCOUNT_ID          VARCHAR(20),
    BUSINESS_DATE       DATE,

    OPENING_BALANCE     NUMBER(18,2),
    CLOSING_BALANCE     NUMBER(18,2),
    AVAILABLE_BALANCE   NUMBER(18,2),

    CURRENCY            VARCHAR(3),
    SOURCE_SYSTEM       VARCHAR(100),

    LOAD_TIMESTAMP      TIMESTAMP_NTZ
);


-- =====================================================================
-- 7. CARD
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.CARD
(
    CARD_ID         VARCHAR(20),
    ACCOUNT_ID      VARCHAR(20),
    CUSTOMER_ID     VARCHAR(20),

    CARD_NUMBER     VARCHAR(50),
    CARD_TYPE       VARCHAR(30),

    ISSUE_DATE      DATE,
    EXPIRY_DATE     DATE,

    CARD_STATUS     VARCHAR(30)
);


-- =====================================================================
-- 8. LOAN
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.LOAN
(
    LOAN_ID               VARCHAR(20),
    LOAN_NUMBER           VARCHAR(50),

    CUSTOMER_ID           VARCHAR(20),
    PRODUCT_ID            VARCHAR(20),
    BRANCH_ID             VARCHAR(20),
    OFFICER_ID            VARCHAR(20),

    LOAN_TYPE             VARCHAR(50),

    LOAN_AMOUNT           NUMBER(18,2),
    OUTSTANDING_AMOUNT    NUMBER(18,2),

    INTEREST_RATE         NUMBER(9,4),
    TENURE_MONTHS         NUMBER(6,0),

    START_DATE            DATE,
    MATURITY_DATE         DATE,

    CREDIT_GRADE          VARCHAR(20),
    LOAN_STATUS           VARCHAR(30)
);


-- =====================================================================
-- 9. LOAN COLLATERAL
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.LOAN_COLLATERAL
(
    COLLATERAL_ID        VARCHAR(20),
    LOAN_ID              VARCHAR(20),

    COLLATERAL_TYPE      VARCHAR(50),
    DESCRIPTION          VARCHAR(1000),

    VALUATION_AMOUNT     NUMBER(18,2),
    VALUATION_DATE       DATE,

    OWNER_NAME           VARCHAR(250),

    COLLATERAL_STATUS    VARCHAR(30)
);


-- =====================================================================
-- 10. GL CONTROL TOTAL
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.GL_CONTROL_TOTAL
(
    GL_CONTROL_ID       VARCHAR(20),
    BUSINESS_DATE       DATE,

    GL_ACCOUNT_CODE     VARCHAR(50),
    PRODUCT_TYPE        VARCHAR(50),
    CURRENCY            VARCHAR(3),

    CONTROL_TOTAL       NUMBER(20,2),
    TRANSACTION_COUNT   NUMBER(38,0),

    SOURCE_SYSTEM       VARCHAR(100),
    LOAD_TIMESTAMP      TIMESTAMP_NTZ
);


-- =====================================================================
-- 11. TRANSACTIONS
--
-- Use TRANSACTIONS instead of TRANSACTION to avoid ambiguity with the
-- SQL concept/keyword TRANSACTION.
-- =====================================================================

CREATE TABLE IF NOT EXISTS RAW.BANKING.TRANSACTIONS
(
    TRANSACTION_ID                VARCHAR(30),

    ACCOUNT_ID                    VARCHAR(20),
    CUSTOMER_ID                   VARCHAR(20),

    TRANSACTION_DATE              DATE,
    POSTING_DATE                  DATE,

    TRANSACTION_TYPE              VARCHAR(50),
    TRANSACTION_CODE              VARCHAR(30),

    AMOUNT                        NUMBER(18,2),
    CURRENCY                      VARCHAR(3),

    DEBIT_CREDIT                  VARCHAR(10),
    CHANNEL                       VARCHAR(50),

    MERCHANT_NAME                 VARCHAR(250),

    STATUS                        VARCHAR(30),

    REFERENCE                     VARCHAR(1000),
    MEMO                          VARCHAR(2000),

    BALANCE_AFTER_TRANSACTION     NUMBER(18,2),

    LOAD_TIMESTAMP                TIMESTAMP_NTZ,

    TRANSACTION_GROUP_ID          VARCHAR(50)
);


-- =====================================================================
-- Verification
-- =====================================================================

SHOW TABLES IN SCHEMA RAW.BANKING;