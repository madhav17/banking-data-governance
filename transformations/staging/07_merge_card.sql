/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE
  File: transformations/staging/07_merge_card.sql

  Purpose:
      Standardize RAW.BANKING.CARD and MERGE it into STG_CARD.

  Important:
      CARD_NUMBER remains fully present for later classification/masking.

  Data-quality boundary:
      - CARD_ID must be present.
      - No account/customer FK filtering.
      - No PAN-format validation here.
==============================================================================*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;

MERGE INTO ANALYTICS.STAGING.STG_CARD T
USING
(
    SELECT
        TRIM(CARD_ID)                         AS CARD_ID,
        NULLIF(TRIM(ACCOUNT_ID), '')          AS ACCOUNT_ID,
        NULLIF(TRIM(CUSTOMER_ID), '')         AS CUSTOMER_ID,
        NULLIF(TRIM(CARD_NUMBER), '')         AS CARD_NUMBER,
        NULLIF(UPPER(TRIM(CARD_TYPE)), '')    AS CARD_TYPE,
        ISSUE_DATE,
        EXPIRY_DATE,
        NULLIF(UPPER(TRIM(CARD_STATUS)), '')  AS CARD_STATUS
    FROM RAW.BANKING.CARD
    WHERE CARD_ID IS NOT NULL
      AND TRIM(CARD_ID) <> ''
) S
ON T.CARD_ID = S.CARD_ID

WHEN MATCHED
AND HASH(
        T.ACCOUNT_ID, T.CUSTOMER_ID, T.CARD_NUMBER,
        T.CARD_TYPE, T.ISSUE_DATE, T.EXPIRY_DATE, T.CARD_STATUS
    )
    <>
    HASH(
        S.ACCOUNT_ID, S.CUSTOMER_ID, S.CARD_NUMBER,
        S.CARD_TYPE, S.ISSUE_DATE, S.EXPIRY_DATE, S.CARD_STATUS
    )
THEN UPDATE SET
    T.ACCOUNT_ID      = S.ACCOUNT_ID,
    T.CUSTOMER_ID     = S.CUSTOMER_ID,
    T.CARD_NUMBER     = S.CARD_NUMBER,
    T.CARD_TYPE       = S.CARD_TYPE,
    T.ISSUE_DATE      = S.ISSUE_DATE,
    T.EXPIRY_DATE     = S.EXPIRY_DATE,
    T.CARD_STATUS     = S.CARD_STATUS,
    T.STG_UPDATED_AT  = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN INSERT
(
    CARD_ID, ACCOUNT_ID, CUSTOMER_ID, CARD_NUMBER,
    CARD_TYPE, ISSUE_DATE, EXPIRY_DATE, CARD_STATUS
)
VALUES
(
    S.CARD_ID, S.ACCOUNT_ID, S.CUSTOMER_ID, S.CARD_NUMBER,
    S.CARD_TYPE, S.ISSUE_DATE, S.EXPIRY_DATE, S.CARD_STATUS
);

SELECT
    (SELECT COUNT(*) FROM RAW.BANKING.CARD) AS RAW_ROWS,
    (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_CARD) AS STAGING_ROWS;
