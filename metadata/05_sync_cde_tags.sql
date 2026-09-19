/*==============================================================================
 AVIDIA
 Phase 2 - Generate tag assignments from CDE Registry
==============================================================================*/

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


MERGE INTO GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

USING
(
    /* ------------------------------------------------------------------------
       CDE tag
    ------------------------------------------------------------------------ */

    SELECT
        C.DATABASE_NAME,
        C.SCHEMA_NAME,
        C.TABLE_NAME                    AS OBJECT_NAME,
        C.COLUMN_NAME,

        'COLUMN'                        AS OBJECT_LEVEL,

        CASE
            WHEN UPPER(O.OBJECT_TYPE) LIKE '%VIEW%'
                THEN 'VIEW'
            ELSE 'TABLE'
        END                             AS OBJECT_TYPE,

        'CDE'                           AS TAG_NAME,

        C.CDE_TIER                      AS TAG_VALUE,

        'CDE_REGISTRY'                  AS SOURCE_TYPE,

        C.DATABASE_NAME || '.' ||
        C.SCHEMA_NAME   || '.' ||
        C.TABLE_NAME    || '.' ||
        C.COLUMN_NAME                   AS SOURCE_REFERENCE,

        'Critical Data Element assignment from CDE_REGISTRY'
                                            AS ASSIGNMENT_REASON,

        100                             AS APPLY_ORDER

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY C

    LEFT JOIN GOVERNANCE.CATALOG.OBJECT_CATALOG O
      ON O.DATABASE_NAME = C.DATABASE_NAME
     AND O.SCHEMA_NAME   = C.SCHEMA_NAME
     AND O.OBJECT_NAME   = C.TABLE_NAME

    WHERE C.ACTIVE_FLAG = TRUE


    UNION ALL


    /* ------------------------------------------------------------------------
       DATA OWNER directly on CDE

       This intentionally makes TAG_REFERENCES evidence easier:
       each CDE carries its accountability metadata.
    ------------------------------------------------------------------------ */

    SELECT
        C.DATABASE_NAME,
        C.SCHEMA_NAME,
        C.TABLE_NAME,
        C.COLUMN_NAME,

        'COLUMN',

        CASE
            WHEN UPPER(O.OBJECT_TYPE) LIKE '%VIEW%'
                THEN 'VIEW'
            ELSE 'TABLE'
        END,

        'DATA_OWNER',

        C.DATA_OWNER,

        'CDE_REGISTRY',

        C.DATABASE_NAME || '.' ||
        C.SCHEMA_NAME   || '.' ||
        C.TABLE_NAME    || '.' ||
        C.COLUMN_NAME,

        'Owner copied from CDE_REGISTRY for CDE evidence',

        110

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY C

    LEFT JOIN GOVERNANCE.CATALOG.OBJECT_CATALOG O
      ON O.DATABASE_NAME = C.DATABASE_NAME
     AND O.SCHEMA_NAME   = C.SCHEMA_NAME
     AND O.OBJECT_NAME   = C.TABLE_NAME

    WHERE C.ACTIVE_FLAG = TRUE
      AND C.DATA_OWNER IS NOT NULL


    UNION ALL


    /* ------------------------------------------------------------------------
       DATA STEWARD directly on CDE
    ------------------------------------------------------------------------ */

    SELECT
        C.DATABASE_NAME,
        C.SCHEMA_NAME,
        C.TABLE_NAME,
        C.COLUMN_NAME,

        'COLUMN',

        CASE
            WHEN UPPER(O.OBJECT_TYPE) LIKE '%VIEW%'
                THEN 'VIEW'
            ELSE 'TABLE'
        END,

        'DATA_STEWARD',

        C.DATA_STEWARD,

        'CDE_REGISTRY',

        C.DATABASE_NAME || '.' ||
        C.SCHEMA_NAME   || '.' ||
        C.TABLE_NAME    || '.' ||
        C.COLUMN_NAME,

        'Steward copied from CDE_REGISTRY for CDE evidence',

        110

    FROM GOVERNANCE.CATALOG.CDE_REGISTRY C

    LEFT JOIN GOVERNANCE.CATALOG.OBJECT_CATALOG O
      ON O.DATABASE_NAME = C.DATABASE_NAME
     AND O.SCHEMA_NAME   = C.SCHEMA_NAME
     AND O.OBJECT_NAME   = C.TABLE_NAME

    WHERE C.ACTIVE_FLAG = TRUE
      AND C.DATA_STEWARD IS NOT NULL

) S


ON  T.DATABASE_NAME = S.DATABASE_NAME
AND T.SCHEMA_NAME = S.SCHEMA_NAME
AND T.OBJECT_NAME = S.OBJECT_NAME
AND T.COLUMN_NAME = S.COLUMN_NAME
AND T.OBJECT_LEVEL = S.OBJECT_LEVEL
AND T.TAG_NAME = S.TAG_NAME


WHEN MATCHED THEN

UPDATE SET

    TAG_VALUE =
        S.TAG_VALUE,

    OBJECT_TYPE =
        S.OBJECT_TYPE,

    SOURCE_TYPE =
        S.SOURCE_TYPE,

    SOURCE_REFERENCE =
        S.SOURCE_REFERENCE,

    ASSIGNMENT_REASON =
        S.ASSIGNMENT_REASON,

    APPLY_ORDER =
        S.APPLY_ORDER,

    ACTIVE_FLAG =
        TRUE,

    UPDATED_AT =
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