/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE
  File: transformations/staging/06_merge_branch.sql

  Purpose:
      Standardize RAW.BANKING.BRANCH and idempotently MERGE it into
      ANALYTICS.STAGING.STG_BRANCH.

  Precondition:
      transformations/staging/02_validate_raw_for_staging.sql returned PASS.

  Data-quality boundary:
      - Require BRANCH_ID for deterministic MERGE.
      - Duplicate BRANCH_ID is expected to have been rejected by the pre-check.
      - No business-validity or referential filtering is performed here.
==============================================================================*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;

MERGE INTO ANALYTICS.STAGING.STG_BRANCH T
USING
(
    SELECT
        TRIM(BRANCH_ID)                    AS BRANCH_ID,
        NULLIF(TRIM(BRANCH_CODE), '')      AS BRANCH_CODE,
        NULLIF(TRIM(BRANCH_NAME), '')      AS BRANCH_NAME,
        NULLIF(UPPER(TRIM(REGION)), '')    AS REGION,
        NULLIF(TRIM(CITY), '')             AS CITY,
        NULLIF(UPPER(TRIM(STATE)), '')     AS STATE,
        NULLIF(TRIM(POSTAL_CODE), '')      AS POSTAL_CODE,
        NULLIF(UPPER(TRIM(BRANCH_STATUS)), '') AS BRANCH_STATUS
    FROM RAW.BANKING.BRANCH
    WHERE BRANCH_ID IS NOT NULL
      AND TRIM(BRANCH_ID) <> ''
) S
ON T.BRANCH_ID = S.BRANCH_ID

WHEN MATCHED
AND HASH(
        T.BRANCH_CODE, T.BRANCH_NAME, T.REGION, T.CITY,
        T.STATE, T.POSTAL_CODE, T.BRANCH_STATUS
    )
    <>
    HASH(
        S.BRANCH_CODE, S.BRANCH_NAME, S.REGION, S.CITY,
        S.STATE, S.POSTAL_CODE, S.BRANCH_STATUS
    )
THEN UPDATE SET
    T.BRANCH_CODE       = S.BRANCH_CODE,
    T.BRANCH_NAME       = S.BRANCH_NAME,
    T.REGION            = S.REGION,
    T.CITY              = S.CITY,
    T.STATE             = S.STATE,
    T.POSTAL_CODE       = S.POSTAL_CODE,
    T.BRANCH_STATUS     = S.BRANCH_STATUS,
    T.STG_UPDATED_AT    = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN INSERT
(
    BRANCH_ID, BRANCH_CODE, BRANCH_NAME, REGION,
    CITY, STATE, POSTAL_CODE, BRANCH_STATUS
)
VALUES
(
    S.BRANCH_ID, S.BRANCH_CODE, S.BRANCH_NAME, S.REGION,
    S.CITY, S.STATE, S.POSTAL_CODE, S.BRANCH_STATUS
);

SELECT
    (SELECT COUNT(*) FROM RAW.BANKING.BRANCH) AS RAW_ROWS,
    (SELECT COUNT(*) FROM ANALYTICS.STAGING.STG_BRANCH) AS STAGING_ROWS;
