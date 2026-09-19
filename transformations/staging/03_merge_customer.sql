/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE
  File: transformations/staging/03_merge_customer.sql

  Purpose:
      Standardize RAW.BANKING.CUSTOMER and MERGE it into STG_CUSTOMER.

  Important:
      Sensitive columns are preserved for later STAGING classification.
      CUST_REF and NOTES are deliberately preserved without semantic cleanup
      because they contain misleading sensitive test values.

  Data-quality boundary:
      - CUSTOMER_ID must be present.
      - No tax-ID validity, status validity, or branch/officer FK filtering.
==============================================================================*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;

MERGE INTO ANALYTICS.STAGING.STG_CUSTOMER T
USING
(
    SELECT
        TRIM(CUSTOMER_ID)                         AS CUSTOMER_ID,
        NULLIF(UPPER(TRIM(CUSTOMER_TYPE)), '')    AS CUSTOMER_TYPE,
        NULLIF(TRIM(FIRST_NAME), '')              AS FIRST_NAME,
        NULLIF(TRIM(LAST_NAME), '')               AS LAST_NAME,
        NULLIF(TRIM(BUSINESS_NAME), '')           AS BUSINESS_NAME,

        NULLIF(TRIM(TAX_ID), '')                  AS TAX_ID,
        DATE_OF_BIRTH,
        NULLIF(LOWER(TRIM(EMAIL)), '')            AS EMAIL,
        NULLIF(TRIM(PHONE), '')                   AS PHONE,

        NULLIF(TRIM(ADDRESS_LINE1), '')           AS ADDRESS_LINE1,
        NULLIF(TRIM(CITY), '')                    AS CITY,
        NULLIF(UPPER(TRIM(STATE)), '')            AS STATE,
        NULLIF(TRIM(POSTAL_CODE), '')             AS POSTAL_CODE,
        NULLIF(UPPER(TRIM(COUNTRY)), '')          AS COUNTRY,

        NULLIF(TRIM(BRANCH_ID), '')               AS BRANCH_ID,
        NULLIF(TRIM(OFFICER_ID), '')              AS OFFICER_ID,
        NULLIF(UPPER(TRIM(CUSTOMER_STATUS)), '')  AS CUSTOMER_STATUS,

        CREATED_DATE,
        UPDATED_TIMESTAMP,

        CUST_REF,
        NOTES

    FROM RAW.BANKING.CUSTOMER
    WHERE CUSTOMER_ID IS NOT NULL
      AND TRIM(CUSTOMER_ID) <> ''
) S
ON T.CUSTOMER_ID = S.CUSTOMER_ID

WHEN MATCHED
AND HASH(
        T.CUSTOMER_TYPE, T.FIRST_NAME, T.LAST_NAME, T.BUSINESS_NAME,
        T.TAX_ID, T.DATE_OF_BIRTH, T.EMAIL, T.PHONE,
        T.ADDRESS_LINE1, T.CITY, T.STATE, T.POSTAL_CODE, T.COUNTRY,
        T.BRANCH_ID, T.OFFICER_ID, T.CUSTOMER_STATUS,
        T.CREATED_DATE, T.UPDATED_TIMESTAMP, T.CUST_REF, T.NOTES
    )
    <>
    HASH(
        S.CUSTOMER_TYPE, S.FIRST_NAME, S.LAST_NAME, S.BUSINESS_NAME,
        S.TAX_ID, S.DATE_OF_BIRTH, S.EMAIL, S.PHONE,
        S.ADDRESS_LINE1, S.CITY, S.STATE, S.POSTAL_CODE, S.COUNTRY,
        S.BRANCH_ID, S.OFFICER_ID, S.CUSTOMER_STATUS,
        S.CREATED_DATE, S.UPDATED_TIMESTAMP, S.CUST_REF, S.NOTES
    )
THEN UPDATE SET
    T.CUSTOMER_TYPE      = S.CUSTOMER_TYPE,
    T.FIRST_NAME         = S.FIRST_NAME,
    T.LAST_NAME          = S.LAST_NAME,
    T.BUSINESS_NAME      = S.BUSINESS_NAME,
    T.TAX_ID             = S.TAX_ID,
    T.DATE_OF_BIRTH      = S.DATE_OF_BIRTH,
    T.EMAIL              = S.EMAIL,
    T.PHONE              = S.PHONE,
    T.ADDRESS_LINE1      = S.ADDRESS_LINE1,
    T.CITY               = S.CITY,
    T.STATE              = S.STATE,
    T.POSTAL_CODE        = S.POSTAL_CODE,
    T.COUNTRY            = S.COUNTRY,
    T.BRANCH_ID          = S.BRANCH_ID,
    T.OFFICER_ID         = S.OFFICER_ID,
    T.CUSTOMER_STATUS    = S.CUSTOMER_STATUS,
    T.CREATED_DATE       = S.CREATED_DATE,
    T.UPDATED_TIMESTAMP  = S.UPDATED_TIMESTAMP,
    T.CUST_REF           = S.CUST_REF,
    T.NOTES              = S.NOTES,
    T.STG_UPDATED_AT     = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN INSERT
(
    CUSTOMER_ID, CUSTOMER_TYPE, FIRST_NAME, LAST_NAME, BUSINESS_NAME,
    TAX_ID, DATE_OF_BIRTH, EMAIL, PHONE,
    ADDRESS_LINE1, CITY, STATE, POSTAL_CODE, COUNTRY,
    BRANCH_ID, OFFICER_ID, CUSTOMER_STATUS,
    CREATED_DATE, UPDATED_TIMESTAMP, CUST_REF, NOTES
)
VALUES
(
    S.CUSTOMER_ID, S.CUSTOMER_TYPE, S.FIRST_NAME, S.LAST_NAME, S.BUSINESS_NAME,
    S.TAX_ID, S.DATE_OF_BIRTH, S.EMAIL, S.PHONE,
    S.ADDRESS_LINE1, S.CITY, S.STATE, S.POSTAL_CODE, S.COUNTRY,
    S.BRANCH_ID, S.OFFICER_ID, S.CUSTOMER_STATUS,
    S.CREATED_DATE, S.UPDATED_TIMESTAMP, S.CUST_REF, S.NOTES
);

SELECT
    (SELECT COUNT(*) FROM RAW.BANKING.CUSTOMER) AS RAW_ROWS,
    (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CUSTOMER) AS STAGING_ROWS;
