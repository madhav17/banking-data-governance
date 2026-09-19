/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/23_validate_cde_tags.sql

  Purpose:
      Validate that active CDE_REGISTRY rows have been synchronized into
      TAG_ASSIGNMENT and applied as native Snowflake tags.

  Run after:
      metadata/21_seed_cde_registry.sql
      metadata/22_validate_cde_registry.sql
      metadata/05_sync_cde_tags.sql
      metadata/07_apply_tags.sql

  Validates:
      1. At least 25 active CDEs exist.
      2. Every active CDE has CDE / DATA_OWNER / DATA_STEWARD desired-state
         rows in TAG_ASSIGNMENT.
      3. Desired-state tag values match CDE_REGISTRY.
      4. Native Snowflake tags are present on the physical CDE columns.
      5. Native tag values match CDE_REGISTRY.
      6. CDE / owner / steward tags are direct column-level assignments.
      7. No orphan CDE tag assignments remain for inactive/nonexistent CDEs.

  Expected:
      - ACTIVE_CDES >= 25
      - 3 active CDE_REGISTRY tag assignments per active CDE
      - 0 desired-state mismatches
      - 0 native-tag mismatches
      - 0 orphan CDE_REGISTRY tag assignments
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. ACTIVE CDE SUMMARY
--
-- Expected:
--      ACTIVE_CDES >= 25
-- ============================================================================

SELECT

    COUNT(*) AS ACTIVE_CDES,

    COUNT_IF(CDE_TIER = 'TIER_1')
        AS TIER_1_CDES,

    COUNT_IF(CDE_TIER = 'TIER_2')
        AS TIER_2_CDES,

    COUNT_IF(CDE_TIER = 'TIER_3')
        AS TIER_3_CDES,

    CASE
        WHEN COUNT(*) >= 25
            THEN 'PASS'
        ELSE 'FAIL'
    END
        AS CDE_COUNT_STATUS

FROM GOVERNANCE.CATALOG.CDE_REGISTRY

WHERE ACTIVE_FLAG = TRUE;



-- ============================================================================
-- 3. EXPECTED TAG_ASSIGNMENT COUNT
--
-- 05_sync_cde_tags.sql creates three desired-state assignments per active CDE:
--
--      CDE
--      DATA_OWNER
--      DATA_STEWARD
--
-- For exactly 25 active CDEs:
--      expected active assignments = 75
-- ============================================================================

WITH ACTIVE_CDES AS
(
    SELECT COUNT(*) AS CDE_COUNT

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY

    WHERE ACTIVE_FLAG = TRUE
)

SELECT

    A.CDE_COUNT
        AS ACTIVE_CDES,

    A.CDE_COUNT * 3
        AS EXPECTED_CDE_REGISTRY_ASSIGNMENTS,

    COALESCE(COUNT_IF(T.TAG_NAME = 'CDE'), 0)
        AS CDE_ASSIGNMENTS,

    COALESCE(COUNT_IF(T.TAG_NAME = 'DATA_OWNER'), 0)
        AS OWNER_ASSIGNMENTS,

    COALESCE(COUNT_IF(T.TAG_NAME = 'DATA_STEWARD'), 0)
        AS STEWARD_ASSIGNMENTS,

    COUNT(T.TAG_NAME)
        AS TOTAL_CDE_REGISTRY_ASSIGNMENTS,

    CASE
        WHEN COALESCE(COUNT_IF(T.TAG_NAME = 'CDE'), 0) = A.CDE_COUNT
         AND COALESCE(COUNT_IF(T.TAG_NAME = 'DATA_OWNER'), 0) = A.CDE_COUNT
         AND COALESCE(COUNT_IF(T.TAG_NAME = 'DATA_STEWARD'), 0) = A.CDE_COUNT
         AND COUNT(T.TAG_NAME) = A.CDE_COUNT * 3
            THEN 'PASS'
        ELSE 'FAIL'
    END
        AS TAG_ASSIGNMENT_SYNC_STATUS

FROM ACTIVE_CDES A

LEFT JOIN GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

       ON T.ACTIVE_FLAG = TRUE
      AND T.SOURCE_TYPE = 'CDE_REGISTRY'
      AND T.TAG_NAME IN
          (
              'CDE',
              'DATA_OWNER',
              'DATA_STEWARD'
          )

GROUP BY A.CDE_COUNT;



-- ============================================================================
-- 4. DESIRED-STATE TAG VALUE MISMATCHES
--
-- Compare CDE_REGISTRY against TAG_ASSIGNMENT.
--
-- Expected:
--      0 rows
-- ============================================================================

WITH EXPECTED_TAGS AS
(
    SELECT

        DATABASE_NAME,
        SCHEMA_NAME,
        TABLE_NAME AS OBJECT_NAME,
        COLUMN_NAME,

        'CDE' AS TAG_NAME,
        CDE_TIER AS EXPECTED_TAG_VALUE

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY

    WHERE ACTIVE_FLAG = TRUE


    UNION ALL


    SELECT

        DATABASE_NAME,
        SCHEMA_NAME,
        TABLE_NAME,
        COLUMN_NAME,

        'DATA_OWNER',
        DATA_OWNER

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY

    WHERE ACTIVE_FLAG = TRUE


    UNION ALL


    SELECT

        DATABASE_NAME,
        SCHEMA_NAME,
        TABLE_NAME,
        COLUMN_NAME,

        'DATA_STEWARD',
        DATA_STEWARD

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY

    WHERE ACTIVE_FLAG = TRUE
)

SELECT

    E.DATABASE_NAME,
    E.SCHEMA_NAME,
    E.OBJECT_NAME,
    E.COLUMN_NAME,
    E.TAG_NAME,

    E.EXPECTED_TAG_VALUE,

    T.TAG_VALUE
        AS ACTUAL_TAG_VALUE,

    T.OBJECT_LEVEL,

    T.OBJECT_TYPE,

    T.SOURCE_TYPE

FROM EXPECTED_TAGS E

LEFT JOIN GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

       ON T.DATABASE_NAME = E.DATABASE_NAME
      AND T.SCHEMA_NAME   = E.SCHEMA_NAME
      AND T.OBJECT_NAME   = E.OBJECT_NAME
      AND T.COLUMN_NAME   = E.COLUMN_NAME
      AND T.TAG_NAME      = E.TAG_NAME
      AND T.ACTIVE_FLAG   = TRUE

WHERE T.TAG_NAME IS NULL

   OR COALESCE(T.TAG_VALUE, '')
      <> COALESCE(E.EXPECTED_TAG_VALUE, '')

   OR T.OBJECT_LEVEL <> 'COLUMN'

   OR T.SOURCE_TYPE <> 'CDE_REGISTRY'

ORDER BY
    E.OBJECT_NAME,
    E.COLUMN_NAME,
    E.TAG_NAME;



-- ============================================================================
-- 5. DUPLICATE ACTIVE CDE-REGISTRY TAG ASSIGNMENTS
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,
    TAG_NAME,

    COUNT(*) AS RECORD_COUNT

FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT

WHERE ACTIVE_FLAG = TRUE
  AND SOURCE_TYPE = 'CDE_REGISTRY'
  AND TAG_NAME IN
      (
          'CDE',
          'DATA_OWNER',
          'DATA_STEWARD'
      )

GROUP BY
    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,
    TAG_NAME

HAVING COUNT(*) > 1

ORDER BY
    OBJECT_NAME,
    COLUMN_NAME,
    TAG_NAME;



-- ============================================================================
-- 6. BUILD IMMEDIATE NATIVE TAG SNAPSHOT FOR RAW.BANKING COLUMNS
--
-- INFORMATION_SCHEMA is used rather than ACCOUNT_USAGE so validation reflects
-- the current state immediately after 07_apply_tags.sql.
-- ============================================================================

CREATE OR REPLACE TEMP TABLE TMP_CDE_NATIVE_TAGS AS

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.BRANCH',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.PRODUCT',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.OFFICER',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.CUSTOMER',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.ACCOUNT',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.ACCOUNT_DAILY_BALANCE',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.TRANSACTIONS',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.CARD',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.LOAN',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.LOAN_COLLATERAL',
        'TABLE'
    )
)

UNION ALL

SELECT * FROM TABLE
(
    RAW.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
    (
        'RAW.BANKING.GL_CONTROL_TOTAL',
        'TABLE'
    )
);



-- ============================================================================
-- 7. NATIVE CDE TAG COVERAGE
--
-- Expected:
--      COMPLETE_TAGGED_CDES = ACTIVE_CDES
--      NATIVE_CDE_TAG_STATUS = PASS
-- ============================================================================

WITH NATIVE_TAGS AS
(
    SELECT

        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'CDE',
                TAG_VALUE,
                NULL
            )
        )
            AS CDE_TAG,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'DATA_OWNER',
                TAG_VALUE,
                NULL
            )
        )
            AS OWNER_TAG,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'DATA_STEWARD',
                TAG_VALUE,
                NULL
            )
        )
            AS STEWARD_TAG

    FROM TMP_CDE_NATIVE_TAGS

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
)

SELECT

    COUNT(*) AS ACTIVE_CDES,

    COUNT_IF(N.CDE_TAG = R.CDE_TIER)
        AS CDE_TAG_MATCHES,

    COUNT_IF(N.OWNER_TAG = R.DATA_OWNER)
        AS OWNER_TAG_MATCHES,

    COUNT_IF(N.STEWARD_TAG = R.DATA_STEWARD)
        AS STEWARD_TAG_MATCHES,

    COUNT_IF
    (
           N.CDE_TAG     = R.CDE_TIER
       AND N.OWNER_TAG   = R.DATA_OWNER
       AND N.STEWARD_TAG = R.DATA_STEWARD
    )
        AS COMPLETE_TAGGED_CDES,

    CASE

        WHEN COUNT_IF
             (
                    N.CDE_TAG     = R.CDE_TIER
                AND N.OWNER_TAG   = R.DATA_OWNER
                AND N.STEWARD_TAG = R.DATA_STEWARD
             )
             = COUNT(*)

            THEN 'PASS'

        ELSE 'FAIL'

    END
        AS NATIVE_CDE_TAG_STATUS

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN NATIVE_TAGS N

       ON N.OBJECT_DATABASE = R.DATABASE_NAME
      AND N.OBJECT_SCHEMA   = R.SCHEMA_NAME
      AND N.OBJECT_NAME     = R.TABLE_NAME
      AND N.COLUMN_NAME     = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE;



-- ============================================================================
-- 8. NATIVE TAG VALUE MISMATCH DETAILS
--
-- This is the most useful failure query.
--
-- Expected:
--      0 rows
-- ============================================================================

WITH NATIVE_TAGS AS
(
    SELECT

        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'CDE',
                TAG_VALUE,
                NULL
            )
        )
            AS CDE_TAG,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'DATA_OWNER',
                TAG_VALUE,
                NULL
            )
        )
            AS OWNER_TAG,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'DATA_STEWARD',
                TAG_VALUE,
                NULL
            )
        )
            AS STEWARD_TAG

    FROM TMP_CDE_NATIVE_TAGS

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
)

SELECT

    R.TABLE_NAME,
    R.COLUMN_NAME,

    R.CDE_TIER
        AS EXPECTED_CDE,

    N.CDE_TAG
        AS ACTUAL_CDE,

    R.DATA_OWNER
        AS EXPECTED_OWNER,

    N.OWNER_TAG
        AS ACTUAL_OWNER,

    R.DATA_STEWARD
        AS EXPECTED_STEWARD,

    N.STEWARD_TAG
        AS ACTUAL_STEWARD

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN NATIVE_TAGS N

       ON N.OBJECT_DATABASE = R.DATABASE_NAME
      AND N.OBJECT_SCHEMA   = R.SCHEMA_NAME
      AND N.OBJECT_NAME     = R.TABLE_NAME
      AND N.COLUMN_NAME     = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE

  AND
  (
         COALESCE(N.CDE_TAG, '')
            <> COALESCE(R.CDE_TIER, '')

      OR COALESCE(N.OWNER_TAG, '')
            <> COALESCE(R.DATA_OWNER, '')

      OR COALESCE(N.STEWARD_TAG, '')
            <> COALESCE(R.DATA_STEWARD, '')
  )

ORDER BY
    R.TABLE_NAME,
    R.COLUMN_NAME;



-- ============================================================================
-- 9. DIRECT COLUMN-LEVEL TAG EVIDENCE
--
-- 05_sync_cde_tags.sql intentionally writes CDE, DATA_OWNER and DATA_STEWARD
-- directly to each CDE column so TAG_REFERENCES evidence can show all three
-- without relying only on inheritance.
--
-- Expected:
--      Each active CDE has 3 relevant tag rows.
-- ============================================================================

SELECT

    OBJECT_NAME
        AS TABLE_NAME,

    COLUMN_NAME,

    TAG_NAME,

    TAG_VALUE,

    APPLY_METHOD,

    LEVEL

FROM TMP_CDE_NATIVE_TAGS

WHERE TAG_DATABASE = 'GOVERNANCE'
  AND TAG_SCHEMA   = 'TAGS'

  AND TAG_NAME IN
      (
          'CDE',
          'DATA_OWNER',
          'DATA_STEWARD'
      )

ORDER BY
    TABLE_NAME,
    COLUMN_NAME,
    TAG_NAME;



-- ============================================================================
-- 10. CDE COLUMNS MISSING ONE OR MORE DIRECT GOVERNANCE TAGS
--
-- Expected:
--      0 rows
-- ============================================================================

WITH DIRECT_TAG_COUNTS AS
(
    SELECT

        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        COUNT_IF
        (
            TAG_NAME = 'CDE'
        )
            AS CDE_TAG_COUNT,

        COUNT_IF
        (
            TAG_NAME = 'DATA_OWNER'
        )
            AS OWNER_TAG_COUNT,

        COUNT_IF
        (
            TAG_NAME = 'DATA_STEWARD'
        )
            AS STEWARD_TAG_COUNT

    FROM TMP_CDE_NATIVE_TAGS

    WHERE TAG_DATABASE = 'GOVERNANCE'
      AND TAG_SCHEMA   = 'TAGS'

      AND TAG_NAME IN
          (
              'CDE',
              'DATA_OWNER',
              'DATA_STEWARD'
          )

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
)

SELECT

    R.TABLE_NAME,
    R.COLUMN_NAME,

    COALESCE(D.CDE_TAG_COUNT, 0)
        AS CDE_TAG_COUNT,

    COALESCE(D.OWNER_TAG_COUNT, 0)
        AS OWNER_TAG_COUNT,

    COALESCE(D.STEWARD_TAG_COUNT, 0)
        AS STEWARD_TAG_COUNT

FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

LEFT JOIN DIRECT_TAG_COUNTS D

       ON D.OBJECT_DATABASE = R.DATABASE_NAME
      AND D.OBJECT_SCHEMA   = R.SCHEMA_NAME
      AND D.OBJECT_NAME     = R.TABLE_NAME
      AND D.COLUMN_NAME     = R.COLUMN_NAME

WHERE R.ACTIVE_FLAG = TRUE

  AND
  (
         COALESCE(D.CDE_TAG_COUNT, 0) <> 1
      OR COALESCE(D.OWNER_TAG_COUNT, 0) <> 1
      OR COALESCE(D.STEWARD_TAG_COUNT, 0) <> 1
  )

ORDER BY
    R.TABLE_NAME,
    R.COLUMN_NAME;



-- ============================================================================
-- 11. ORPHAN CDE_REGISTRY TAG_ASSIGNMENTS
--
-- Finds desired-state assignments generated from CDE_REGISTRY that no longer
-- correspond to an active registry row.
--
-- Expected:
--      0 rows
--
-- Note:
--      If this returns rows after intentionally retiring a CDE, the current
--      05_sync_cde_tags.sql lifecycle logic will need a retirement/reconcile
--      enhancement before deployment.
-- ============================================================================

SELECT

    T.DATABASE_NAME,
    T.SCHEMA_NAME,
    T.OBJECT_NAME,
    T.COLUMN_NAME,
    T.TAG_NAME,
    T.TAG_VALUE,
    T.ACTIVE_FLAG

FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

LEFT JOIN GOVERNANCE.CATALOG.CDE_REGISTRY R

       ON R.DATABASE_NAME = T.DATABASE_NAME
      AND R.SCHEMA_NAME   = T.SCHEMA_NAME
      AND R.TABLE_NAME    = T.OBJECT_NAME
      AND R.COLUMN_NAME   = T.COLUMN_NAME
      AND R.ACTIVE_FLAG   = TRUE

WHERE T.SOURCE_TYPE = 'CDE_REGISTRY'
  AND T.ACTIVE_FLAG = TRUE

  AND R.COLUMN_NAME IS NULL

ORDER BY
    T.OBJECT_NAME,
    T.COLUMN_NAME,
    T.TAG_NAME;



-- ============================================================================
-- 12. NATIVE CDE TAGS WITHOUT AN ACTIVE REGISTRY ROW
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT DISTINCT

    N.OBJECT_DATABASE,
    N.OBJECT_SCHEMA,
    N.OBJECT_NAME,
    N.COLUMN_NAME,
    N.TAG_VALUE AS CDE_TAG

FROM TMP_CDE_NATIVE_TAGS N

LEFT JOIN GOVERNANCE.CATALOG.CDE_REGISTRY R

       ON R.DATABASE_NAME = N.OBJECT_DATABASE
      AND R.SCHEMA_NAME   = N.OBJECT_SCHEMA
      AND R.TABLE_NAME    = N.OBJECT_NAME
      AND R.COLUMN_NAME   = N.COLUMN_NAME
      AND R.ACTIVE_FLAG   = TRUE

WHERE N.TAG_DATABASE = 'GOVERNANCE'
  AND N.TAG_SCHEMA   = 'TAGS'
  AND N.TAG_NAME     = 'CDE'

  AND R.COLUMN_NAME IS NULL

ORDER BY
    N.OBJECT_NAME,
    N.COLUMN_NAME;



-- ============================================================================
-- 13. FINAL CDE TAG VALIDATION SUMMARY
--
-- Compact evidence query.
-- ============================================================================

WITH ACTIVE_CDES AS
(
    SELECT

        COUNT(*) AS CDE_COUNT

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY

    WHERE ACTIVE_FLAG = TRUE
),

ASSIGNMENT_STATS AS
(
    SELECT

        COALESCE(COUNT_IF(TAG_NAME = 'CDE'), 0)
            AS CDE_ASSIGNMENTS,

        COALESCE(COUNT_IF(TAG_NAME = 'DATA_OWNER'), 0)
            AS OWNER_ASSIGNMENTS,

        COALESCE(COUNT_IF(TAG_NAME = 'DATA_STEWARD'), 0)
            AS STEWARD_ASSIGNMENTS

    FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT

    WHERE ACTIVE_FLAG = TRUE
      AND SOURCE_TYPE = 'CDE_REGISTRY'
),

NATIVE_TAGS AS
(
    SELECT

        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'CDE',
                TAG_VALUE,
                NULL
            )
        )
            AS CDE_TAG,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'DATA_OWNER',
                TAG_VALUE,
                NULL
            )
        )
            AS OWNER_TAG,

        MAX
        (
            IFF
            (
                TAG_DATABASE = 'GOVERNANCE'
                AND TAG_SCHEMA = 'TAGS'
                AND TAG_NAME = 'DATA_STEWARD',
                TAG_VALUE,
                NULL
            )
        )
            AS STEWARD_TAG

    FROM TMP_CDE_NATIVE_TAGS

    GROUP BY
        OBJECT_DATABASE,
        OBJECT_SCHEMA,
        OBJECT_NAME,
        COLUMN_NAME
),

NATIVE_STATS AS
(
    SELECT

        COUNT(*) AS ACTIVE_CDES,

        COUNT_IF
        (
               N.CDE_TAG     = R.CDE_TIER
           AND N.OWNER_TAG   = R.DATA_OWNER
           AND N.STEWARD_TAG = R.DATA_STEWARD
        )
            AS COMPLETE_TAGGED_CDES

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY R

    LEFT JOIN NATIVE_TAGS N

           ON N.OBJECT_DATABASE = R.DATABASE_NAME
          AND N.OBJECT_SCHEMA   = R.SCHEMA_NAME
          AND N.OBJECT_NAME     = R.TABLE_NAME
          AND N.COLUMN_NAME     = R.COLUMN_NAME

    WHERE R.ACTIVE_FLAG = TRUE
)

SELECT

    A.CDE_COUNT
        AS ACTIVE_CDES,

    S.CDE_ASSIGNMENTS,

    S.OWNER_ASSIGNMENTS,

    S.STEWARD_ASSIGNMENTS,

    N.COMPLETE_TAGGED_CDES,

    CASE

        WHEN A.CDE_COUNT >= 25

         AND S.CDE_ASSIGNMENTS
                = A.CDE_COUNT

         AND S.OWNER_ASSIGNMENTS
                = A.CDE_COUNT

         AND S.STEWARD_ASSIGNMENTS
                = A.CDE_COUNT

         AND N.COMPLETE_TAGGED_CDES
                = A.CDE_COUNT

        THEN 'PASS - CDE TAGGING COMPLETE'

        ELSE 'FAIL - REVIEW CDE TAG CONTROLS ABOVE'

    END
        AS CDE_TAG_VALIDATION_STATUS

FROM ACTIVE_CDES A

CROSS JOIN ASSIGNMENT_STATS S

CROSS JOIN NATIVE_STATS N;
