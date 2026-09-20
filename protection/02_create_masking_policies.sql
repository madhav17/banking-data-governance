/*==============================================================================
 AVIDIA BANK - TAG-BASED MASKING POLICIES

 Purpose:
   Create reusable masking policies driven by the confirmed
   GOVERNANCE.TAGS.CLASSIFICATION tag.

 Role behavior:
   DATA_OWNER       -> clear value
   DATA_STEWARD     -> partial value
   DEPOSITS_ANALYST -> strongly masked value

 Notes:
   - STAGING remains internal and is not the proof surface.
   - Policies preserve the protected column data type.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

CREATE OR REPLACE MASKING POLICY GOVERNANCE.CATALOG.CLASSIFICATION_STRING_MASK
AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN(
            'GOVERNANCE.TAGS.CLASSIFICATION'
        ) IN ('PUBLIC', 'INTERNAL')
            THEN VAL

        WHEN IS_ROLE_IN_SESSION('DATA_OWNER')
            THEN VAL

        WHEN IS_ROLE_IN_SESSION('DATA_STEWARD')
            THEN
                CASE
                    WHEN VAL IS NULL THEN NULL
                    WHEN LENGTH(VAL) <= 4 THEN '***'
                    ELSE LEFT(VAL, 2) || '***' || RIGHT(VAL, 2)
                END

        WHEN IS_ROLE_IN_SESSION('DEPOSITS_ANALYST')
            THEN '***MASKED***'

        ELSE '***MASKED***'
    END;

CREATE OR REPLACE MASKING POLICY GOVERNANCE.CATALOG.CLASSIFICATION_DATE_MASK
AS (VAL DATE) RETURNS DATE ->
    CASE
        WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN(
            'GOVERNANCE.TAGS.CLASSIFICATION'
        ) IN ('PUBLIC', 'INTERNAL')
            THEN VAL

        WHEN IS_ROLE_IN_SESSION('DATA_OWNER')
            THEN VAL

        WHEN IS_ROLE_IN_SESSION('DATA_STEWARD')
            THEN DATE_FROM_PARTS(YEAR(VAL), 1, 1)

        WHEN IS_ROLE_IN_SESSION('DEPOSITS_ANALYST')
            THEN NULL

        ELSE NULL
    END;

SHOW MASKING POLICIES IN SCHEMA GOVERNANCE.CATALOG;
