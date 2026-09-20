/*==============================================================================
 AVIDIA BANK - BRANCH ENTITLEMENTS

 Purpose:
   Create a small governed mapping table for branch-scoped row access.

 Note:
   The generated branch data does not currently include a Hudson branch. This
   script chooses one actual branch deterministically:
     1. branch with HUDSON in name/city when present;
     2. otherwise the first ACTIVE branch by BRANCH_ID;
     3. otherwise the first branch by BRANCH_ID.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

CREATE TABLE IF NOT EXISTS GOVERNANCE.CATALOG.BRANCH_ENTITLEMENT
(
    ROLE_NAME       VARCHAR(255) NOT NULL,
    BRANCH_ID       VARCHAR(20) NOT NULL,
    ACTIVE_FLAG     BOOLEAN DEFAULT TRUE,
    CREATED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Role-to-branch entitlement mapping used by branch row access policy.';

MERGE INTO GOVERNANCE.CATALOG.BRANCH_ENTITLEMENT T
USING
(
    SELECT
        'BRANCH_HUDSON' AS ROLE_NAME,
        BRANCH_ID,
        TRUE AS ACTIVE_FLAG
    FROM ANALYTICS.STAGING.STG_BRANCH
    QUALIFY ROW_NUMBER() OVER
    (
        ORDER BY
            IFF(
                UPPER(BRANCH_NAME) LIKE '%HUDSON%'
                OR UPPER(CITY) LIKE '%HUDSON%',
                0,
                1
            ),
            IFF(BRANCH_STATUS = 'ACTIVE', 0, 1),
            BRANCH_ID
    ) = 1
) S
ON  T.ROLE_NAME = S.ROLE_NAME
AND T.BRANCH_ID = S.BRANCH_ID
WHEN MATCHED THEN UPDATE SET
    ACTIVE_FLAG = S.ACTIVE_FLAG,
    UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT
(
    ROLE_NAME,
    BRANCH_ID,
    ACTIVE_FLAG
)
VALUES
(
    S.ROLE_NAME,
    S.BRANCH_ID,
    S.ACTIVE_FLAG
);

SELECT
    E.ROLE_NAME,
    E.BRANCH_ID,
    B.BRANCH_NAME,
    B.CITY,
    B.BRANCH_STATUS,
    E.ACTIVE_FLAG
FROM GOVERNANCE.CATALOG.BRANCH_ENTITLEMENT E
LEFT JOIN ANALYTICS.STAGING.STG_BRANCH B
    ON E.BRANCH_ID = B.BRANCH_ID
ORDER BY E.ROLE_NAME;
