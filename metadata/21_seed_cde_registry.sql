/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/21_seed_cde_registry.sql

  Purpose:
      Register at least 25 Critical Data Elements (CDEs) for the RAW banking
      layer.

  Design:
      - 25 governed physical columns
      - Tiered as TIER_1 / TIER_2 / TIER_3
      - Business definitions sourced from DATA_DICTIONARY
      - Owner and steward explicitly recorded
      - MERGE makes execution idempotent
      - CDE_REGISTRY remains the business source of truth
      - Native Snowflake CDE tags are synchronized separately by
        05_sync_cde_tags.sql
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. SEED CRITICAL DATA ELEMENTS
-- ============================================================================

MERGE INTO GOVERNANCE.CATALOG.CDE_REGISTRY T

USING
(
    WITH CDE_SEED AS
    (
        SELECT

            COLUMN1::VARCHAR AS TABLE_NAME,
            COLUMN2::VARCHAR AS COLUMN_NAME,
            COLUMN3::VARCHAR AS CDE_TIER,
            COLUMN4::VARCHAR AS DATA_DOMAIN,
            COLUMN5::VARCHAR AS DATA_OWNER,
            COLUMN6::VARCHAR AS DATA_STEWARD,
            COLUMN7::VARCHAR AS BUSINESS_REASON,
            COLUMN8::VARCHAR AS REGULATORY_RELEVANCE,
            COLUMN9::BOOLEAN AS DQ_REQUIRED

        FROM VALUES


        /* ====================================================================
           CUSTOMER DOMAIN
        ==================================================================== */

        (
            'CUSTOMER',
            'CUSTOMER_ID',
            'TIER_1',
            'CUSTOMER',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Primary customer identifier used to join customer information across banking relationships.',
            'Customer identification, traceability and data integrity.',
            TRUE
        ),

        (
            'CUSTOMER',
            'TAX_ID',
            'TIER_1',
            'CUSTOMER',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Critical customer identity attribute requiring strong quality and protection controls.',
            'Customer identification and privacy controls.',
            TRUE
        ),

        (
            'CUSTOMER',
            'DATE_OF_BIRTH',
            'TIER_2',
            'CUSTOMER',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Important customer identity attribute used for customer verification.',
            'Customer identification and privacy controls.',
            TRUE
        ),

        (
            'CUSTOMER',
            'EMAIL',
            'TIER_3',
            'CUSTOMER',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Primary electronic contact channel for the customer.',
            'Customer privacy and contact-data protection.',
            TRUE
        ),

        (
            'CUSTOMER',
            'PHONE',
            'TIER_3',
            'CUSTOMER',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Primary telephone contact information for the customer.',
            'Customer privacy and contact-data protection.',
            TRUE
        ),

        (
            'CUSTOMER',
            'CUSTOMER_STATUS',
            'TIER_2',
            'CUSTOMER',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Determines the current lifecycle state of the banking relationship.',
            'Customer lifecycle and operational controls.',
            TRUE
        ),


        /* ====================================================================
           DEPOSITS DOMAIN
        ==================================================================== */

        (
            'ACCOUNT',
            'ACCOUNT_ID',
            'TIER_1',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Primary technical identifier for a deposit account.',
            'Account integrity and traceability.',
            TRUE
        ),

        (
            'ACCOUNT',
            'ACCOUNT_NUMBER',
            'TIER_1',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Customer-facing banking account identifier used across deposit processes.',
            'Banking identifier confidentiality and account integrity.',
            TRUE
        ),

        (
            'ACCOUNT',
            'CUSTOMER_ID',
            'TIER_1',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Defines the customer ownership relationship for the account.',
            'Customer-account relationship integrity.',
            TRUE
        ),

        (
            'ACCOUNT',
            'BRANCH_ID',
            'TIER_2',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Identifies the branch responsible for servicing the account.',
            'Branch servicing and access-control scope.',
            TRUE
        ),

        (
            'ACCOUNT',
            'CURRENT_BALANCE',
            'TIER_1',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Current monetary balance of the customer deposit account.',
            'Financial reporting, reconciliation and balance integrity.',
            TRUE
        ),

        (
            'ACCOUNT',
            'ACCOUNT_STATUS',
            'TIER_2',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Controls whether the account is active, dormant or closed.',
            'Account lifecycle and operational controls.',
            TRUE
        ),

        (
            'ACCOUNT_DAILY_BALANCE',
            'BUSINESS_DATE',
            'TIER_1',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Defines the business date represented by each daily account balance.',
            'Reporting period and timeliness controls.',
            TRUE
        ),

        (
            'ACCOUNT_DAILY_BALANCE',
            'CLOSING_BALANCE',
            'TIER_1',
            'DEPOSITS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'End-of-day monetary balance used for deposit reporting and reconciliation.',
            'Financial reporting and reconciliation controls.',
            TRUE
        ),


        /* ====================================================================
           TRANSACTIONS DOMAIN
        ==================================================================== */

        (
            'TRANSACTIONS',
            'TRANSACTION_ID',
            'TIER_1',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Unique identifier for an account transaction posting.',
            'Transaction traceability and uniqueness.',
            TRUE
        ),

        (
            'TRANSACTIONS',
            'ACCOUNT_ID',
            'TIER_1',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Identifies the customer account affected by the transaction posting.',
            'Transaction-to-account relationship integrity.',
            TRUE
        ),

        (
            'TRANSACTIONS',
            'CUSTOMER_ID',
            'TIER_1',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Customer identifier retained on the transaction for relationship consistency validation.',
            'Customer-account-transaction consistency control.',
            TRUE
        ),

        (
            'TRANSACTIONS',
            'TRANSACTION_DATE',
            'TIER_1',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Business date on which the financial transaction occurred.',
            'Transaction timeliness and reporting controls.',
            TRUE
        ),

        (
            'TRANSACTIONS',
            'AMOUNT',
            'TIER_1',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Monetary value of an individual account transaction posting.',
            'Financial transaction integrity and reconciliation.',
            TRUE
        ),

        (
            'TRANSACTIONS',
            'DEBIT_CREDIT',
            'TIER_2',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Indicates whether a transaction posting increases or decreases the account position.',
            'Transaction accounting and posting controls.',
            TRUE
        ),


        /* ====================================================================
           PAYMENT CARD
        ==================================================================== */

        (
            'CARD',
            'CARD_NUMBER',
            'TIER_1',
            'TRANSACTIONS',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Payment card identifier linked to the customer and deposit account.',
            'Payment-card confidentiality and protection controls.',
            TRUE
        ),


        /* ====================================================================
           LENDING DOMAIN
        ==================================================================== */

        (
            'LOAN',
            'LOAN_ID',
            'TIER_1',
            'LENDING',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Primary technical identifier for a customer loan.',
            'Lending traceability and loan integrity.',
            TRUE
        ),

        (
            'LOAN',
            'OUTSTANDING_AMOUNT',
            'TIER_1',
            'LENDING',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Current unpaid loan exposure used for lending and risk reporting.',
            'Credit exposure and financial reporting controls.',
            TRUE
        ),

        (
            'LOAN',
            'CREDIT_GRADE',
            'TIER_1',
            'LENDING',
            'DATA_OWNER',
            'DATA_STEWARD',
            'Credit quality grade assigned to the loan for risk assessment.',
            'Credit-risk monitoring and lending controls.',
            TRUE
        ),


        /* ====================================================================
           FINANCE / RECONCILIATION
        ==================================================================== */

        (
            'GL_CONTROL_TOTAL',
            'CONTROL_TOTAL',
            'TIER_1',
            'FINANCE',
            'DATA_OWNER',
            'DATA_STEWARD',
            'General-ledger control balance used to reconcile deposit balances.',
            'Financial reconciliation and control reporting.',
            TRUE
        )

    )


    /* ========================================================================
       Enrich the CDE seed from the already validated DATA_DICTIONARY.

       This prevents duplicating column definitions across governance stores.
    ======================================================================== */

    SELECT

        'RAW'
            AS DATABASE_NAME,

        'BANKING'
            AS SCHEMA_NAME,

        S.TABLE_NAME,

        S.COLUMN_NAME,

        S.CDE_TIER,

        COALESCE
        (
            D.BUSINESS_NAME,
            INITCAP(REPLACE(LOWER(S.COLUMN_NAME), '_', ' '))
        )
            AS BUSINESS_NAME,

        D.DESCRIPTION
            AS BUSINESS_DEFINITION,

        S.BUSINESS_REASON,

        S.DATA_DOMAIN,

        S.DATA_OWNER,

        S.DATA_STEWARD,

        S.REGULATORY_RELEVANCE,

        S.DQ_REQUIRED,

        TRUE
            AS ACTIVE_FLAG

    FROM CDE_SEED S

    LEFT JOIN GOVERNANCE.CATALOG.DATA_DICTIONARY D

           ON D.DATABASE_NAME = 'RAW'
          AND D.SCHEMA_NAME   = 'BANKING'
          AND D.TABLE_NAME    = S.TABLE_NAME
          AND D.COLUMN_NAME   = S.COLUMN_NAME

) S


ON  T.DATABASE_NAME = S.DATABASE_NAME
AND T.SCHEMA_NAME   = S.SCHEMA_NAME
AND T.TABLE_NAME    = S.TABLE_NAME
AND T.COLUMN_NAME   = S.COLUMN_NAME


WHEN MATCHED THEN

UPDATE SET

    T.CDE_TIER =
        S.CDE_TIER,

    T.BUSINESS_NAME =
        S.BUSINESS_NAME,

    T.BUSINESS_DEFINITION =
        S.BUSINESS_DEFINITION,

    T.BUSINESS_REASON =
        S.BUSINESS_REASON,

    T.DATA_DOMAIN =
        S.DATA_DOMAIN,

    T.DATA_OWNER =
        S.DATA_OWNER,

    T.DATA_STEWARD =
        S.DATA_STEWARD,

    T.REGULATORY_RELEVANCE =
        S.REGULATORY_RELEVANCE,

    T.DQ_REQUIRED =
        S.DQ_REQUIRED,

    T.ACTIVE_FLAG =
        TRUE,

    T.UPDATED_AT =
        CURRENT_TIMESTAMP()


WHEN NOT MATCHED THEN

INSERT
(
    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    CDE_TIER,
    BUSINESS_NAME,
    BUSINESS_DEFINITION,
    BUSINESS_REASON,
    DATA_DOMAIN,
    DATA_OWNER,
    DATA_STEWARD,
    REGULATORY_RELEVANCE,
    DQ_REQUIRED,
    ACTIVE_FLAG,
    CREATED_AT,
    UPDATED_AT
)

VALUES
(
    S.DATABASE_NAME,
    S.SCHEMA_NAME,
    S.TABLE_NAME,
    S.COLUMN_NAME,
    S.CDE_TIER,
    S.BUSINESS_NAME,
    S.BUSINESS_DEFINITION,
    S.BUSINESS_REASON,
    S.DATA_DOMAIN,
    S.DATA_OWNER,
    S.DATA_STEWARD,
    S.REGULATORY_RELEVANCE,
    S.DQ_REQUIRED,
    TRUE,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);



-- ============================================================================
-- 3. QUICK VERIFICATION
-- ============================================================================

SELECT

    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    CDE_TIER,
    BUSINESS_NAME,
    DATA_DOMAIN,
    DATA_OWNER,
    DATA_STEWARD,
    DQ_REQUIRED,
    ACTIVE_FLAG

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE

ORDER BY
    CDE_TIER,
    DATA_DOMAIN,
    TABLE_NAME,
    COLUMN_NAME;
