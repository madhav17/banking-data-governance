/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/18_seed_banking_glossary.sql

  Purpose:
      Seed the governed banking business glossary with ten approved
      enterprise banking terms.

  Design:
      - Exactly 10 core terms required for the take-home
      - Stable TERM_ID values
      - MERGE makes execution idempotent
      - Business concepts remain independent of physical Snowflake columns
      - Physical mappings are created separately in file 19
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. SEED BANKING GLOSSARY
-- ============================================================================

MERGE INTO GOVERNANCE.CATALOG.GLOSSARY_TERM T

USING
(
    SELECT
        COLUMN1::VARCHAR AS TERM_ID,
        COLUMN2::VARCHAR AS TERM_NAME,
        COLUMN3::VARCHAR AS DEFINITION,
        COLUMN4::VARCHAR AS DOMAIN,
        COLUMN5::VARCHAR AS DATA_OWNER,
        COLUMN6::VARCHAR AS DATA_STEWARD,
        COLUMN7::VARCHAR AS STATUS,
        COLUMN8::NUMBER  AS VERSION

    FROM VALUES

    (
        'CUSTOMER',
        'Customer',
        'A person or business entity that has a banking relationship with the bank.',
        'CUSTOMER',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'DEPOSIT_ACCOUNT',
        'Deposit Account',
        'A customer banking account used to hold deposit products such as savings, current or fixed-deposit balances.',
        'DEPOSITS',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'ACCOUNT_BALANCE',
        'Account Balance',
        'The monetary balance associated with a deposit account at a point in time or on a business date.',
        'DEPOSITS',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'TRANSACTION_POSTING',
        'Transaction Posting',
        'An individual financial posting that affects one customer account.',
        'TRANSACTIONS',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'TRANSACTION_AMOUNT',
        'Transaction Amount',
        'The monetary value associated with an individual transaction posting.',
        'TRANSACTIONS',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'LOAN',
        'Loan',
        'A credit facility extended by the bank to a customer and tracked through origination, maturity, exposure and status.',
        'LENDING',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'CREDIT_GRADE',
        'Credit Grade',
        'A categorical assessment of the credit quality associated with a customer loan.',
        'LENDING',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'COLLATERAL',
        'Collateral',
        'An asset associated with a loan that supports or secures the lending exposure.',
        'LENDING',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'BRANCH',
        'Branch',
        'A bank operating location responsible for serving customers and servicing banking relationships.',
        'REFERENCE',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    ),

    (
        'GL_CONTROL_TOTAL',
        'General Ledger Control Total',
        'A persisted financial control total used to reconcile deposit balances for a business date.',
        'FINANCE',
        'DATA_OWNER',
        'DATA_STEWARD',
        'APPROVED',
        1
    )

) S


ON T.TERM_ID = S.TERM_ID


WHEN MATCHED THEN

UPDATE SET

    T.TERM_NAME =
        S.TERM_NAME,

    T.DEFINITION =
        S.DEFINITION,

    T.DOMAIN =
        S.DOMAIN,

    T.DATA_OWNER =
        S.DATA_OWNER,

    T.DATA_STEWARD =
        S.DATA_STEWARD,

    T.STATUS =
        S.STATUS,

    T.VERSION =
        S.VERSION,

    T.UPDATED_AT =
        CURRENT_TIMESTAMP()


WHEN NOT MATCHED THEN

INSERT
(
    TERM_ID,
    TERM_NAME,
    DEFINITION,
    DOMAIN,
    DATA_OWNER,
    DATA_STEWARD,
    STATUS,
    VERSION,
    CREATED_AT,
    UPDATED_AT
)

VALUES
(
    S.TERM_ID,
    S.TERM_NAME,
    S.DEFINITION,
    S.DOMAIN,
    S.DATA_OWNER,
    S.DATA_STEWARD,
    S.STATUS,
    S.VERSION,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);



-- ============================================================================
-- 3. QUICK VERIFICATION
-- ============================================================================

SELECT

    TERM_ID,
    TERM_NAME,
    DOMAIN,
    DATA_OWNER,
    DATA_STEWARD,
    STATUS,
    VERSION

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM

ORDER BY TERM_ID;