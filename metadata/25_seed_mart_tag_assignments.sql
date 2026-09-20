/*==============================================================================
 AVIDIA BANKING DATA GOVERNANCE

 File:
     metadata/24_seed_mart_tag_assignments.sql

 Purpose:
     Add business-specific MART tag overrides.

 Notes:
     - LAYER, DATA_OWNER and DATA_STEWARD are inherited from
       ANALYTICS.MARTS schema-level baseline assignments.
     - DOMAIN is overridden at MART table level.
     - SOURCE_SYSTEM is assigned at MART table level.
     - CLASSIFICATION, CDE and CERTIFICATION are intentionally excluded.
==============================================================================*/

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


MERGE INTO GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

USING
(
    SELECT
        COLUMN1::VARCHAR AS DATABASE_NAME,
        COLUMN2::VARCHAR AS SCHEMA_NAME,
        COLUMN3::VARCHAR AS OBJECT_NAME,
        COLUMN4::VARCHAR AS COLUMN_NAME,
        COLUMN5::VARCHAR AS OBJECT_LEVEL,
        COLUMN6::VARCHAR AS OBJECT_TYPE,
        COLUMN7::VARCHAR AS TAG_NAME,
        COLUMN8::VARCHAR AS TAG_VALUE,
        COLUMN9::VARCHAR AS SOURCE_TYPE,
        COLUMN10::VARCHAR AS SOURCE_REFERENCE,
        COLUMN11::VARCHAR AS ASSIGNMENT_REASON,
        COLUMN12::NUMBER AS APPLY_ORDER

    FROM VALUES

    /* ========================================================================
       CUSTOMER_360
    ======================================================================== */

    (
        'ANALYTICS',
        'MARTS',
        'CUSTOMER_360',
        NULL,
        'TABLE',
        'TABLE',
        'DOMAIN',
        'CUSTOMER',
        'BASELINE',
        'DBT_MODEL:CUSTOMER_360',
        'Customer-centric MART belongs to CUSTOMER business domain',
        40
    ),

    (
        'ANALYTICS',
        'MARTS',
        'CUSTOMER_360',
        NULL,
        'TABLE',
        'TABLE',
        'SOURCE_SYSTEM',
        'MULTI_SOURCE',
        'BASELINE',
        'DBT_MODEL:CUSTOMER_360',
        'Customer 360 combines multiple governed upstream banking systems',
        40
    ),


    /* ========================================================================
       DEPOSITS_DAILY
    ======================================================================== */

    (
        'ANALYTICS',
        'MARTS',
        'DEPOSITS_DAILY',
        NULL,
        'TABLE',
        'TABLE',
        'DOMAIN',
        'DEPOSITS',
        'BASELINE',
        'DBT_MODEL:DEPOSITS_DAILY',
        'Daily deposit MART belongs to DEPOSITS business domain',
        40
    ),

    (
        'ANALYTICS',
        'MARTS',
        'DEPOSITS_DAILY',
        NULL,
        'TABLE',
        'TABLE',
        'SOURCE_SYSTEM',
        'CORE_BANKING',
        'BASELINE',
        'DBT_MODEL:DEPOSITS_DAILY',
        'Primary account and daily balance sources originate from core banking',
        40
    ),


    /* ========================================================================
       LOAN_PORTFOLIO
    ======================================================================== */

    (
        'ANALYTICS',
        'MARTS',
        'LOAN_PORTFOLIO',
        NULL,
        'TABLE',
        'TABLE',
        'DOMAIN',
        'LENDING',
        'BASELINE',
        'DBT_MODEL:LOAN_PORTFOLIO',
        'Loan portfolio MART belongs to LENDING business domain',
        40
    ),

    (
        'ANALYTICS',
        'MARTS',
        'LOAN_PORTFOLIO',
        NULL,
        'TABLE',
        'TABLE',
        'SOURCE_SYSTEM',
        'LOAN_SYSTEM',
        'BASELINE',
        'DBT_MODEL:LOAN_PORTFOLIO',
        'Primary loan and collateral sources originate from loan system',
        40
    )

) S

ON  T.DATABASE_NAME = S.DATABASE_NAME
AND COALESCE(T.SCHEMA_NAME, '') =
    COALESCE(S.SCHEMA_NAME, '')
AND COALESCE(T.OBJECT_NAME, '') =
    COALESCE(S.OBJECT_NAME, '')
AND COALESCE(T.COLUMN_NAME, '') =
    COALESCE(S.COLUMN_NAME, '')
AND T.OBJECT_LEVEL = S.OBJECT_LEVEL
AND T.TAG_NAME = S.TAG_NAME


WHEN MATCHED THEN

UPDATE SET

    T.OBJECT_TYPE =
        S.OBJECT_TYPE,

    T.TAG_VALUE =
        S.TAG_VALUE,

    T.SOURCE_TYPE =
        S.SOURCE_TYPE,

    T.SOURCE_REFERENCE =
        S.SOURCE_REFERENCE,

    T.ASSIGNMENT_REASON =
        S.ASSIGNMENT_REASON,

    T.APPLY_ORDER =
        S.APPLY_ORDER,

    T.ACTIVE_FLAG =
        TRUE,

    T.UPDATED_AT =
        CURRENT_TIMESTAMP()


WHEN NOT MATCHED THEN

INSERT
(
    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,

    OBJECT_LEVEL,
    OBJECT_TYPE,

    TAG_NAME,
    TAG_VALUE,

    SOURCE_TYPE,
    SOURCE_REFERENCE,
    ASSIGNMENT_REASON,

    APPLY_ORDER,
    ACTIVE_FLAG
)

VALUES
(
    S.DATABASE_NAME,
    S.SCHEMA_NAME,
    S.OBJECT_NAME,
    S.COLUMN_NAME,

    S.OBJECT_LEVEL,
    S.OBJECT_TYPE,

    S.TAG_NAME,
    S.TAG_VALUE,

    S.SOURCE_TYPE,
    S.SOURCE_REFERENCE,
    S.ASSIGNMENT_REASON,

    S.APPLY_ORDER,
    TRUE
);