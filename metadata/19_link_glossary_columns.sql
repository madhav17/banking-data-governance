/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/19_link_glossary_columns.sql

  Purpose:
      Link approved banking glossary terms to physical RAW.BANKING columns.

  Design:
      - One glossary term may map to multiple physical columns
      - DIRECT    = direct representation of the concept
      - REFERENCE = reference/foreign-key representation
      - DERIVED   = derived representation
      - MERGE makes the mapping idempotent
==============================================================================*/


USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



MERGE INTO GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK T

USING
(
    SELECT

        COLUMN1::VARCHAR AS TERM_ID,
        COLUMN2::VARCHAR AS DATABASE_NAME,
        COLUMN3::VARCHAR AS SCHEMA_NAME,
        COLUMN4::VARCHAR AS TABLE_NAME,
        COLUMN5::VARCHAR AS COLUMN_NAME,
        COLUMN6::VARCHAR AS RELATIONSHIP_TYPE

    FROM VALUES


    /* ========================================================================
       CUSTOMER
    ======================================================================== */

    (
        'CUSTOMER',
        'RAW',
        'BANKING',
        'CUSTOMER',
        'CUSTOMER_ID',
        'DIRECT'
    ),

    (
        'CUSTOMER',
        'RAW',
        'BANKING',
        'ACCOUNT',
        'CUSTOMER_ID',
        'REFERENCE'
    ),

    (
        'CUSTOMER',
        'RAW',
        'BANKING',
        'TRANSACTIONS',
        'CUSTOMER_ID',
        'REFERENCE'
    ),

    (
        'CUSTOMER',
        'RAW',
        'BANKING',
        'CARD',
        'CUSTOMER_ID',
        'REFERENCE'
    ),

    (
        'CUSTOMER',
        'RAW',
        'BANKING',
        'LOAN',
        'CUSTOMER_ID',
        'REFERENCE'
    ),


    /* ========================================================================
       DEPOSIT ACCOUNT
    ======================================================================== */

    (
        'DEPOSIT_ACCOUNT',
        'RAW',
        'BANKING',
        'ACCOUNT',
        'ACCOUNT_ID',
        'DIRECT'
    ),

    (
        'DEPOSIT_ACCOUNT',
        'RAW',
        'BANKING',
        'ACCOUNT_DAILY_BALANCE',
        'ACCOUNT_ID',
        'REFERENCE'
    ),

    (
        'DEPOSIT_ACCOUNT',
        'RAW',
        'BANKING',
        'TRANSACTIONS',
        'ACCOUNT_ID',
        'REFERENCE'
    ),

    (
        'DEPOSIT_ACCOUNT',
        'RAW',
        'BANKING',
        'CARD',
        'ACCOUNT_ID',
        'REFERENCE'
    ),


    /* ========================================================================
       ACCOUNT BALANCE
    ======================================================================== */

    (
        'ACCOUNT_BALANCE',
        'RAW',
        'BANKING',
        'ACCOUNT',
        'CURRENT_BALANCE',
        'DERIVED'
    ),

    (
        'ACCOUNT_BALANCE',
        'RAW',
        'BANKING',
        'ACCOUNT_DAILY_BALANCE',
        'OPENING_BALANCE',
        'DIRECT'
    ),

    (
        'ACCOUNT_BALANCE',
        'RAW',
        'BANKING',
        'ACCOUNT_DAILY_BALANCE',
        'CLOSING_BALANCE',
        'DIRECT'
    ),

    (
        'ACCOUNT_BALANCE',
        'RAW',
        'BANKING',
        'ACCOUNT_DAILY_BALANCE',
        'AVAILABLE_BALANCE',
        'DIRECT'
    ),


    /* ========================================================================
       TRANSACTION
    ======================================================================== */

    (
        'TRANSACTION_POSTING',
        'RAW',
        'BANKING',
        'TRANSACTIONS',
        'TRANSACTION_ID',
        'DIRECT'
    ),

    (
        'TRANSACTION_AMOUNT',
        'RAW',
        'BANKING',
        'TRANSACTIONS',
        'AMOUNT',
        'DIRECT'
    ),


    /* ========================================================================
       LOAN
    ======================================================================== */

    (
        'LOAN',
        'RAW',
        'BANKING',
        'LOAN',
        'LOAN_ID',
        'DIRECT'
    ),

    (
        'LOAN',
        'RAW',
        'BANKING',
        'LOAN_COLLATERAL',
        'LOAN_ID',
        'REFERENCE'
    ),


    /* ========================================================================
       CREDIT GRADE
    ======================================================================== */

    (
        'CREDIT_GRADE',
        'RAW',
        'BANKING',
        'LOAN',
        'CREDIT_GRADE',
        'DIRECT'
    ),


    /* ========================================================================
       COLLATERAL
    ======================================================================== */

    (
        'COLLATERAL',
        'RAW',
        'BANKING',
        'LOAN_COLLATERAL',
        'COLLATERAL_ID',
        'DIRECT'
    ),

    (
        'COLLATERAL',
        'RAW',
        'BANKING',
        'LOAN_COLLATERAL',
        'COLLATERAL_TYPE',
        'DIRECT'
    ),

    (
        'COLLATERAL',
        'RAW',
        'BANKING',
        'LOAN_COLLATERAL',
        'VALUATION_AMOUNT',
        'DIRECT'
    ),


    /* ========================================================================
       BRANCH
    ======================================================================== */

    (
        'BRANCH',
        'RAW',
        'BANKING',
        'BRANCH',
        'BRANCH_ID',
        'DIRECT'
    ),

    (
        'BRANCH',
        'RAW',
        'BANKING',
        'OFFICER',
        'BRANCH_ID',
        'REFERENCE'
    ),

    (
        'BRANCH',
        'RAW',
        'BANKING',
        'CUSTOMER',
        'BRANCH_ID',
        'REFERENCE'
    ),

    (
        'BRANCH',
        'RAW',
        'BANKING',
        'ACCOUNT',
        'BRANCH_ID',
        'REFERENCE'
    ),

    (
        'BRANCH',
        'RAW',
        'BANKING',
        'LOAN',
        'BRANCH_ID',
        'REFERENCE'
    ),


    /* ========================================================================
       GL CONTROL TOTAL
    ======================================================================== */

    (
        'GL_CONTROL_TOTAL',
        'RAW',
        'BANKING',
        'GL_CONTROL_TOTAL',
        'CONTROL_TOTAL',
        'DIRECT'
    )

) S


ON  T.TERM_ID       = S.TERM_ID
AND T.DATABASE_NAME = S.DATABASE_NAME
AND T.SCHEMA_NAME   = S.SCHEMA_NAME
AND T.TABLE_NAME    = S.TABLE_NAME
AND T.COLUMN_NAME   = S.COLUMN_NAME


WHEN MATCHED THEN

UPDATE SET

    T.RELATIONSHIP_TYPE =
        S.RELATIONSHIP_TYPE,

    T.ACTIVE_FLAG =
        TRUE,

    T.UPDATED_AT =
        CURRENT_TIMESTAMP()


WHEN NOT MATCHED THEN

INSERT
(
    TERM_ID,
    DATABASE_NAME,
    SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    RELATIONSHIP_TYPE,
    ACTIVE_FLAG,
    CREATED_AT,
    UPDATED_AT
)

VALUES
(
    S.TERM_ID,
    S.DATABASE_NAME,
    S.SCHEMA_NAME,
    S.TABLE_NAME,
    S.COLUMN_NAME,
    S.RELATIONSHIP_TYPE,
    TRUE,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);



-- ============================================================================
-- QUICK INSPECTION
-- ============================================================================

SELECT

    G.TERM_NAME,

    L.DATABASE_NAME,
    L.SCHEMA_NAME,
    L.TABLE_NAME,
    L.COLUMN_NAME,

    L.RELATIONSHIP_TYPE

FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK L

INNER JOIN GOVERNANCE.CATALOG.GLOSSARY_TERM G
        ON G.TERM_ID = L.TERM_ID

WHERE L.ACTIVE_FLAG = TRUE

ORDER BY
    G.TERM_NAME,
    L.TABLE_NAME,
    L.COLUMN_NAME;