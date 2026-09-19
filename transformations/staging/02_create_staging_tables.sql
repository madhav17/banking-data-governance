/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      transformations/staging/02_create_staging_tables.sql

  Purpose:
      Create standardized physical STAGING tables populated from
      RAW.BANKING through idempotent MERGE operations.

  Design:
      - Preserve source/business column names for traceability.
      - Preserve sensitive values for Snowflake classification.
      - Enforce NOT NULL only on essential staging business keys.
      - Do not enforce PK/FK relationships physically.
      - Add staging operational metadata.
      - Cleansing/validation happens in the subsequent MERGE scripts.
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_ENGINEER;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE ANALYTICS;

USE SCHEMA STAGING;



-- ============================================================================
-- 2. BRANCH
--
-- Source:
--      RAW.BANKING.BRANCH
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_BRANCH
(
    BRANCH_ID              VARCHAR(20) NOT NULL,
    BRANCH_CODE            VARCHAR(20),
    BRANCH_NAME            VARCHAR(150),
    REGION                 VARCHAR(50),
    CITY                   VARCHAR(100),
    STATE                  VARCHAR(100),
    POSTAL_CODE            VARCHAR(20),
    BRANCH_STATUS          VARCHAR(20),

    -- STAGING audit metadata
    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.BRANCH',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized branch reference data derived from RAW.BANKING.BRANCH';



-- ============================================================================
-- 3. PRODUCT
--
-- Source:
--      RAW.BANKING.PRODUCT
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_PRODUCT
(
    PRODUCT_ID             VARCHAR(20) NOT NULL,
    PRODUCT_CODE           VARCHAR(30),
    PRODUCT_NAME           VARCHAR(150),
    PRODUCT_TYPE           VARCHAR(50),
    CURRENCY               VARCHAR(3),
    INTEREST_RATE          NUMBER(9,4),
    MIN_BALANCE            NUMBER(18,2),
    PRODUCT_STATUS         VARCHAR(20),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.PRODUCT',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized banking product reference data derived from RAW.BANKING.PRODUCT';



-- ============================================================================
-- 4. OFFICER
--
-- Source:
--      RAW.BANKING.OFFICER
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_OFFICER
(
    OFFICER_ID             VARCHAR(20) NOT NULL,
    OFFICER_CODE           VARCHAR(20),
    OFFICER_NAME           VARCHAR(200),
    BRANCH_ID              VARCHAR(20),
    ROLE                   VARCHAR(50),
    EMAIL                  VARCHAR(320),
    STATUS                 VARCHAR(20),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.OFFICER',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized bank officer reference data derived from RAW.BANKING.OFFICER';



-- ============================================================================
-- 5. CUSTOMER
--
-- Sensitive and deliberately misleading fields such as TAX_ID,
-- DATE_OF_BIRTH, EMAIL, PHONE, CUST_REF and NOTES are intentionally
-- preserved because Snowflake classification will operate on STAGING.
--
-- Source:
--      RAW.BANKING.CUSTOMER
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_CUSTOMER
(
    CUSTOMER_ID            VARCHAR(20) NOT NULL,
    CUSTOMER_TYPE          VARCHAR(30),
    FIRST_NAME             VARCHAR(100),
    LAST_NAME              VARCHAR(100),
    BUSINESS_NAME          VARCHAR(250),

    TAX_ID                 VARCHAR(50),
    DATE_OF_BIRTH          DATE,
    EMAIL                  VARCHAR(320),
    PHONE                  VARCHAR(50),

    ADDRESS_LINE1          VARCHAR(500),
    CITY                   VARCHAR(100),
    STATE                  VARCHAR(100),
    POSTAL_CODE            VARCHAR(20),
    COUNTRY                VARCHAR(100),

    BRANCH_ID              VARCHAR(20),
    OFFICER_ID             VARCHAR(20),

    CUSTOMER_STATUS        VARCHAR(30),

    CREATED_DATE           DATE,
    UPDATED_TIMESTAMP      TIMESTAMP_NTZ,

    CUST_REF               VARCHAR(500),
    NOTES                  VARCHAR(2000),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.CUSTOMER',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized customer data derived from RAW.BANKING.CUSTOMER';



-- ============================================================================
-- 6. ACCOUNT
--
-- Source:
--      RAW.BANKING.ACCOUNT
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_ACCOUNT
(
    ACCOUNT_ID             VARCHAR(20) NOT NULL,
    ACCOUNT_NUMBER         VARCHAR(50),

    CUSTOMER_ID            VARCHAR(20),
    PRODUCT_ID             VARCHAR(20),
    BRANCH_ID              VARCHAR(20),

    OPEN_DATE              DATE,
    CLOSE_DATE             DATE,

    ACCOUNT_STATUS         VARCHAR(30),

    CURRENCY               VARCHAR(3),

    CURRENT_BALANCE        NUMBER(18,2),

    ACCOUNT_TYPE           VARCHAR(50),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.ACCOUNT',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized deposit account data derived from RAW.BANKING.ACCOUNT';



-- ============================================================================
-- 7. ACCOUNT DAILY BALANCE
--
-- Logical business grain:
--
--      ACCOUNT_ID + BUSINESS_DATE
--
-- Source:
--      RAW.BANKING.ACCOUNT_DAILY_BALANCE
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
(
    ACCOUNT_ID             VARCHAR(20) NOT NULL,

    BUSINESS_DATE          DATE NOT NULL,

    OPENING_BALANCE        NUMBER(18,2),
    CLOSING_BALANCE        NUMBER(18,2),
    AVAILABLE_BALANCE      NUMBER(18,2),

    CURRENCY               VARCHAR(3),

    SOURCE_SYSTEM          VARCHAR(100),

    LOAD_TIMESTAMP         TIMESTAMP_NTZ,

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.ACCOUNT_DAILY_BALANCE',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized daily account balances derived from RAW.BANKING.ACCOUNT_DAILY_BALANCE';



-- ============================================================================
-- 8. CARD
--
-- CARD_NUMBER is deliberately preserved for classification/masking testing.
--
-- Source:
--      RAW.BANKING.CARD
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_CARD
(
    CARD_ID                VARCHAR(20) NOT NULL,

    ACCOUNT_ID             VARCHAR(20),
    CUSTOMER_ID            VARCHAR(20),

    CARD_NUMBER            VARCHAR(50),

    CARD_TYPE              VARCHAR(30),

    ISSUE_DATE             DATE,
    EXPIRY_DATE            DATE,

    CARD_STATUS            VARCHAR(30),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.CARD',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized payment card data derived from RAW.BANKING.CARD';



-- ============================================================================
-- 9. LOAN
--
-- Source:
--      RAW.BANKING.LOAN
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_LOAN
(
    LOAN_ID                VARCHAR(20) NOT NULL,

    LOAN_NUMBER            VARCHAR(50),

    CUSTOMER_ID            VARCHAR(20),
    PRODUCT_ID             VARCHAR(20),
    BRANCH_ID              VARCHAR(20),
    OFFICER_ID             VARCHAR(20),

    LOAN_TYPE              VARCHAR(50),

    LOAN_AMOUNT            NUMBER(18,2),
    OUTSTANDING_AMOUNT     NUMBER(18,2),

    INTEREST_RATE          NUMBER(9,4),

    TENURE_MONTHS          NUMBER(6,0),

    START_DATE             DATE,
    MATURITY_DATE          DATE,

    CREDIT_GRADE           VARCHAR(20),

    LOAN_STATUS            VARCHAR(30),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.LOAN',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized customer lending data derived from RAW.BANKING.LOAN';



-- ============================================================================
-- 10. LOAN COLLATERAL
--
-- Source:
--      RAW.BANKING.LOAN_COLLATERAL
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_LOAN_COLLATERAL
(
    COLLATERAL_ID          VARCHAR(20) NOT NULL,

    LOAN_ID                VARCHAR(20),

    COLLATERAL_TYPE        VARCHAR(50),

    DESCRIPTION            VARCHAR(1000),

    VALUATION_AMOUNT       NUMBER(18,2),

    VALUATION_DATE         DATE,

    OWNER_NAME             VARCHAR(250),

    COLLATERAL_STATUS      VARCHAR(30),

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.LOAN_COLLATERAL',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized loan collateral data derived from RAW.BANKING.LOAN_COLLATERAL';



-- ============================================================================
-- 11. TRANSACTIONS
--
-- REFERENCE and MEMO are deliberately preserved because the take-home uses
-- innocently named fields containing sensitive values to test classification.
--
-- Source:
--      RAW.BANKING.TRANSACTIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_TRANSACTIONS
(
    TRANSACTION_ID                 VARCHAR(30) NOT NULL,

    ACCOUNT_ID                     VARCHAR(20),
    CUSTOMER_ID                    VARCHAR(20),

    TRANSACTION_DATE               DATE,
    POSTING_DATE                   DATE,

    TRANSACTION_TYPE               VARCHAR(50),
    TRANSACTION_CODE               VARCHAR(30),

    AMOUNT                         NUMBER(18,2),

    CURRENCY                       VARCHAR(3),

    DEBIT_CREDIT                   VARCHAR(10),

    CHANNEL                        VARCHAR(50),

    MERCHANT_NAME                  VARCHAR(250),

    STATUS                         VARCHAR(30),

    REFERENCE                      VARCHAR(1000),
    MEMO                           VARCHAR(2000),

    BALANCE_AFTER_TRANSACTION      NUMBER(18,2),

    LOAD_TIMESTAMP                 TIMESTAMP_NTZ,

    TRANSACTION_GROUP_ID           VARCHAR(50),

    STG_SOURCE_TABLE               VARCHAR(255)
                                   DEFAULT 'RAW.BANKING.TRANSACTIONS',

    STG_LOADED_AT                  TIMESTAMP_LTZ
                                   DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT                 TIMESTAMP_LTZ
                                   DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized transaction postings derived from RAW.BANKING.TRANSACTIONS';



-- ============================================================================
-- 12. GL CONTROL TOTAL
--
-- This table becomes particularly important later for the Block 3 accuracy /
-- reconciliation check against deposit balances.
--
-- Source:
--      RAW.BANKING.GL_CONTROL_TOTAL
-- ============================================================================

CREATE TABLE IF NOT EXISTS ANALYTICS.STAGING.STG_GL_CONTROL_TOTAL
(
    GL_CONTROL_ID          VARCHAR(20) NOT NULL,

    BUSINESS_DATE          DATE,

    GL_ACCOUNT_CODE        VARCHAR(50),

    PRODUCT_TYPE           VARCHAR(50),

    CURRENCY               VARCHAR(3),

    CONTROL_TOTAL          NUMBER(20,2),

    TRANSACTION_COUNT      NUMBER(38,0),

    SOURCE_SYSTEM          VARCHAR(100),

    LOAD_TIMESTAMP         TIMESTAMP_NTZ,

    STG_SOURCE_TABLE       VARCHAR(255)
                           DEFAULT 'RAW.BANKING.GL_CONTROL_TOTAL',

    STG_LOADED_AT          TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP(),

    STG_UPDATED_AT         TIMESTAMP_LTZ
                           DEFAULT CURRENT_TIMESTAMP()
)

COMMENT =
    'Standardized general-ledger control totals derived from RAW.BANKING.GL_CONTROL_TOTAL';



-- ============================================================================
-- 13. VERIFICATION
-- ============================================================================

SHOW TABLES IN SCHEMA ANALYTICS.STAGING;
