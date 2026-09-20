/*==============================================================================
 AVIDIA BANK - BRANCH ROW ACCESS POLICY

 Purpose:
   Create exactly one branch-scoped row access policy.

 Behavior:
   DATA_OWNER       -> all rows
   DATA_STEWARD     -> all rows
   DEPOSITS_ANALYST -> all deposit rows; masking controls sensitive columns
   BRANCH_HUDSON    -> rows for its active branch entitlement only
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

CREATE OR REPLACE ROW ACCESS POLICY
    GOVERNANCE.CATALOG.BRANCH_SCOPE_ROW_ACCESS_POLICY
AS (P_BRANCH_ID VARCHAR) RETURNS BOOLEAN ->
    IS_ROLE_IN_SESSION('DATA_OWNER')
    OR IS_ROLE_IN_SESSION('DATA_STEWARD')
    OR IS_ROLE_IN_SESSION('DEPOSITS_ANALYST')
    OR (
        IS_ROLE_IN_SESSION('BRANCH_HUDSON')
        AND EXISTS
        (
            SELECT 1
            FROM GOVERNANCE.CATALOG.BRANCH_ENTITLEMENT E
            WHERE E.ROLE_NAME = 'BRANCH_HUDSON'
              AND E.BRANCH_ID = P_BRANCH_ID
              AND E.ACTIVE_FLAG = TRUE
        )
    );

SHOW ROW ACCESS POLICIES IN SCHEMA GOVERNANCE.CATALOG;
