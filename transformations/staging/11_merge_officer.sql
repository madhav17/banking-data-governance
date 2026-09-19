/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE
  File: transformations/staging/11_merge_officer.sql

  Purpose:
      Standardize RAW.BANKING.OFFICER and MERGE it into STG_OFFICER.

  Data-quality boundary:
      - OFFICER_ID must be present.
      - No branch referential filtering is performed here.
==============================================================================*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;

MERGE INTO ANALYTICS.STAGING.STG_OFFICER T
USING
(
    SELECT
        TRIM(OFFICER_ID)                    AS OFFICER_ID,
        NULLIF(TRIM(OFFICER_CODE), '')      AS OFFICER_CODE,
        NULLIF(TRIM(OFFICER_NAME), '')      AS OFFICER_NAME,
        NULLIF(TRIM(BRANCH_ID), '')         AS BRANCH_ID,
        NULLIF(UPPER(TRIM(ROLE)), '')       AS ROLE,
        NULLIF(LOWER(TRIM(EMAIL)), '')      AS EMAIL,
        NULLIF(UPPER(TRIM(STATUS)), '')     AS STATUS
    FROM RAW.BANKING.OFFICER
    WHERE OFFICER_ID IS NOT NULL
      AND TRIM(OFFICER_ID) <> ''
) S
ON T.OFFICER_ID = S.OFFICER_ID

WHEN MATCHED
AND HASH(
        T.OFFICER_CODE, T.OFFICER_NAME, T.BRANCH_ID,
        T.ROLE, T.EMAIL, T.STATUS
    )
    <>
    HASH(
        S.OFFICER_CODE, S.OFFICER_NAME, S.BRANCH_ID,
        S.ROLE, S.EMAIL, S.STATUS
    )
THEN UPDATE SET
    T.OFFICER_CODE   = S.OFFICER_CODE,
    T.OFFICER_NAME   = S.OFFICER_NAME,
    T.BRANCH_ID      = S.BRANCH_ID,
    T.ROLE           = S.ROLE,
    T.EMAIL          = S.EMAIL,
    T.STATUS         = S.STATUS,
    T.STG_UPDATED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN INSERT
(
    OFFICER_ID, OFFICER_CODE, OFFICER_NAME,
    BRANCH_ID, ROLE, EMAIL, STATUS
)
VALUES
(
    S.OFFICER_ID, S.OFFICER_CODE, S.OFFICER_NAME,
    S.BRANCH_ID, S.ROLE, S.EMAIL, S.STATUS
);

SELECT
    (SELECT COUNT(*) FROM RAW.BANKING.OFFICER) AS RAW_ROWS,
    (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_OFFICER) AS STAGING_ROWS;
