/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/09_create_metadata_harvest_procedure.sql

  Purpose:
      Harvest technical metadata from Snowflake into the custom
      GOVERNANCE metadata catalog.

  Sources:
      RAW.INFORMATION_SCHEMA
      ANALYTICS.INFORMATION_SCHEMA
      SNOWFLAKE.ACCOUNT_USAGE

  Targets:
      GOVERNANCE.CATALOG.OBJECT_CATALOG
      GOVERNANCE.CATALOG.COLUMN_CATALOG

  Design:
      - INFORMATION_SCHEMA = current/immediate metadata
      - ACCOUNT_USAGE      = account-level enrichment/history
      - MERGE              = idempotent deployment
      - EXECUTE AS OWNER   = task can later invoke the procedure
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


-- ============================================================================
-- 2. CREATE METADATA HARVEST PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE GOVERNANCE.CATALOG.HARVEST_METADATA()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$

DECLARE

    V_OBJECT_COUNT NUMBER DEFAULT 0;
    V_COLUMN_COUNT NUMBER DEFAULT 0;

BEGIN


    /* ========================================================================
       STEP 1
       HARVEST OBJECT-LEVEL METADATA
    ======================================================================== */

    MERGE INTO GOVERNANCE.CATALOG.OBJECT_CATALOG T

    USING
    (

        /* --------------------------------------------------------------------
           INFORMATION_SCHEMA

           This represents the CURRENT state of the governed databases.
        -------------------------------------------------------------------- */

        WITH CURRENT_OBJECTS AS
        (

            SELECT

                TABLE_CATALOG,
                TABLE_SCHEMA,
                TABLE_NAME,
                TABLE_OWNER,
                TABLE_TYPE,
                COMMENT,
                CREATED,
                LAST_ALTERED,
                ROW_COUNT

            FROM RAW.INFORMATION_SCHEMA.TABLES

            WHERE TABLE_SCHEMA = 'BANKING'


            UNION ALL


            SELECT

                TABLE_CATALOG,
                TABLE_SCHEMA,
                TABLE_NAME,
                TABLE_OWNER,
                TABLE_TYPE,
                COMMENT,
                CREATED,
                LAST_ALTERED,
                ROW_COUNT

            FROM ANALYTICS.INFORMATION_SCHEMA.TABLES

            WHERE TABLE_SCHEMA IN
            (
                'STAGING',
                'MARTS'
            )

        ),


        /* --------------------------------------------------------------------
           ACCOUNT_USAGE

           Provides account-level metadata/history.

           ACCOUNT_USAGE may lag, therefore it is enrichment rather than
           the authoritative current inventory.
        -------------------------------------------------------------------- */

        ACCOUNT_OBJECTS AS
        (

            SELECT

                TABLE_CATALOG,
                TABLE_SCHEMA,
                TABLE_NAME,
                TABLE_OWNER,
                TABLE_TYPE,
                COMMENT,
                CREATED,
                LAST_ALTERED,
                ROW_COUNT

            FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES

            WHERE DELETED IS NULL

              AND
              (
                    (
                        TABLE_CATALOG = 'RAW'
                        AND TABLE_SCHEMA = 'BANKING'
                    )

                    OR

                    (
                        TABLE_CATALOG = 'ANALYTICS'
                        AND TABLE_SCHEMA IN
                        (
                            'STAGING',
                            'MARTS'
                        )
                    )
              )

        )


        SELECT

            I.TABLE_CATALOG
                AS DATABASE_NAME,

            I.TABLE_SCHEMA
                AS SCHEMA_NAME,

            I.TABLE_NAME
                AS OBJECT_NAME,

            I.TABLE_TYPE
                AS OBJECT_TYPE,

            COALESCE
            (
                I.TABLE_OWNER,
                A.TABLE_OWNER
            )
                AS OBJECT_OWNER,

            COALESCE
            (
                I.COMMENT,
                A.COMMENT
            )
                AS OBJECT_COMMENT,

            COALESCE
            (
                I.CREATED,
                A.CREATED
            )
                AS CREATED_AT,

            COALESCE
            (
                I.LAST_ALTERED,
                A.LAST_ALTERED
            )
                AS LAST_ALTERED_AT,

            COALESCE
            (
                I.ROW_COUNT,
                A.ROW_COUNT
            )
                AS ROW_COUNT,

            CASE

                WHEN A.TABLE_NAME IS NOT NULL
                    THEN 'INFORMATION_SCHEMA + ACCOUNT_USAGE'

                ELSE 'INFORMATION_SCHEMA'

            END
                AS SOURCE_METADATA

        FROM CURRENT_OBJECTS I

        LEFT JOIN ACCOUNT_OBJECTS A

          ON A.TABLE_CATALOG = I.TABLE_CATALOG
         AND A.TABLE_SCHEMA  = I.TABLE_SCHEMA
         AND A.TABLE_NAME    = I.TABLE_NAME

    ) S


    ON  T.DATABASE_NAME = S.DATABASE_NAME
    AND T.SCHEMA_NAME   = S.SCHEMA_NAME
    AND T.OBJECT_NAME   = S.OBJECT_NAME


    /* ------------------------------------------------------------------------
       Object already exists in governance catalog
    ------------------------------------------------------------------------ */

    WHEN MATCHED THEN

        UPDATE SET

            T.OBJECT_TYPE =
                S.OBJECT_TYPE,

            T.OBJECT_OWNER =
                S.OBJECT_OWNER,

            T.OBJECT_COMMENT =
                S.OBJECT_COMMENT,

            T.CREATED_AT =
                S.CREATED_AT,

            T.LAST_ALTERED_AT =
                S.LAST_ALTERED_AT,

            T.ROW_COUNT =
                S.ROW_COUNT,

            T.SOURCE_METADATA =
                S.SOURCE_METADATA,

            T.HARVESTED_AT =
                CURRENT_TIMESTAMP(),

            T.UPDATED_AT =
                CURRENT_TIMESTAMP()


    /* ------------------------------------------------------------------------
       New Snowflake object discovered
    ------------------------------------------------------------------------ */

    WHEN NOT MATCHED THEN

        INSERT
        (
            DATABASE_NAME,
            SCHEMA_NAME,
            OBJECT_NAME,
            OBJECT_TYPE,
            OBJECT_OWNER,
            OBJECT_COMMENT,
            CREATED_AT,
            LAST_ALTERED_AT,
            ROW_COUNT,
            SOURCE_METADATA,
            HARVESTED_AT,
            UPDATED_AT
        )

        VALUES
        (
            S.DATABASE_NAME,
            S.SCHEMA_NAME,
            S.OBJECT_NAME,
            S.OBJECT_TYPE,
            S.OBJECT_OWNER,
            S.OBJECT_COMMENT,
            S.CREATED_AT,
            S.LAST_ALTERED_AT,
            S.ROW_COUNT,
            S.SOURCE_METADATA,
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );



    /* ========================================================================
       STEP 2
       HARVEST COLUMN-LEVEL METADATA
    ======================================================================== */

    MERGE INTO GOVERNANCE.CATALOG.COLUMN_CATALOG T

    USING
    (

        WITH CURRENT_COLUMNS AS
        (

            SELECT

                TABLE_CATALOG,
                TABLE_SCHEMA,
                TABLE_NAME,
                COLUMN_NAME,
                ORDINAL_POSITION,
                DATA_TYPE,
                IS_NULLABLE,
                COLUMN_DEFAULT,
                COMMENT

            FROM RAW.INFORMATION_SCHEMA.COLUMNS

            WHERE TABLE_SCHEMA = 'BANKING'


            UNION ALL


            SELECT

                TABLE_CATALOG,
                TABLE_SCHEMA,
                TABLE_NAME,
                COLUMN_NAME,
                ORDINAL_POSITION,
                DATA_TYPE,
                IS_NULLABLE,
                COLUMN_DEFAULT,
                COMMENT

            FROM ANALYTICS.INFORMATION_SCHEMA.COLUMNS

            WHERE TABLE_SCHEMA IN
            (
                'STAGING',
                'MARTS'
            )

        ),


        ACCOUNT_COLUMNS AS
        (

            SELECT

                TABLE_CATALOG,
                TABLE_SCHEMA,
                TABLE_NAME,
                COLUMN_NAME,
                ORDINAL_POSITION,
                DATA_TYPE,
                IS_NULLABLE,
                COLUMN_DEFAULT,
                COMMENT

            FROM SNOWFLAKE.ACCOUNT_USAGE.COLUMNS

            WHERE DELETED IS NULL

              AND
              (
                    (
                        TABLE_CATALOG = 'RAW'
                        AND TABLE_SCHEMA = 'BANKING'
                    )

                    OR

                    (
                        TABLE_CATALOG = 'ANALYTICS'
                        AND TABLE_SCHEMA IN
                        (
                            'STAGING',
                            'MARTS'
                        )
                    )
              )

        )


        SELECT

            I.TABLE_CATALOG
                AS DATABASE_NAME,

            I.TABLE_SCHEMA
                AS SCHEMA_NAME,

            I.TABLE_NAME,

            I.COLUMN_NAME,

            COALESCE
            (
                I.ORDINAL_POSITION,
                A.ORDINAL_POSITION
            )
                AS ORDINAL_POSITION,

            COALESCE
            (
                I.DATA_TYPE,
                A.DATA_TYPE
            )
                AS DATA_TYPE,

            COALESCE
            (
                I.IS_NULLABLE,
                A.IS_NULLABLE
            )
                AS IS_NULLABLE,

            COALESCE
            (
                I.COLUMN_DEFAULT,
                A.COLUMN_DEFAULT
            )
                AS COLUMN_DEFAULT,

            COALESCE
            (
                I.COMMENT,
                A.COMMENT
            )
                AS COMMENT,

            CASE

                WHEN A.COLUMN_NAME IS NOT NULL
                    THEN 'INFORMATION_SCHEMA + ACCOUNT_USAGE'

                ELSE 'INFORMATION_SCHEMA'

            END
                AS SOURCE_METADATA

        FROM CURRENT_COLUMNS I

        LEFT JOIN ACCOUNT_COLUMNS A

          ON A.TABLE_CATALOG = I.TABLE_CATALOG
         AND A.TABLE_SCHEMA  = I.TABLE_SCHEMA
         AND A.TABLE_NAME    = I.TABLE_NAME
         AND A.COLUMN_NAME   = I.COLUMN_NAME

    ) S


    ON  T.DATABASE_NAME = S.DATABASE_NAME
    AND T.SCHEMA_NAME   = S.SCHEMA_NAME
    AND T.TABLE_NAME    = S.TABLE_NAME
    AND T.COLUMN_NAME   = S.COLUMN_NAME


    WHEN MATCHED THEN

        UPDATE SET

            T.ORDINAL_POSITION =
                S.ORDINAL_POSITION,

            T.DATA_TYPE =
                S.DATA_TYPE,

            T.IS_NULLABLE =
                S.IS_NULLABLE,

            T.COLUMN_DEFAULT =
                S.COLUMN_DEFAULT,

            T.COMMENT =
                S.COMMENT,

            T.SOURCE_METADATA =
                S.SOURCE_METADATA,

            T.HARVESTED_AT =
                CURRENT_TIMESTAMP(),

            T.UPDATED_AT =
                CURRENT_TIMESTAMP()


    WHEN NOT MATCHED THEN

        INSERT
        (
            DATABASE_NAME,
            SCHEMA_NAME,
            TABLE_NAME,
            COLUMN_NAME,
            ORDINAL_POSITION,
            DATA_TYPE,
            IS_NULLABLE,
            COLUMN_DEFAULT,
            COMMENT,
            SOURCE_METADATA,
            HARVESTED_AT,
            UPDATED_AT
        )

        VALUES
        (
            S.DATABASE_NAME,
            S.SCHEMA_NAME,
            S.TABLE_NAME,
            S.COLUMN_NAME,
            S.ORDINAL_POSITION,
            S.DATA_TYPE,
            S.IS_NULLABLE,
            S.COLUMN_DEFAULT,
            S.COMMENT,
            S.SOURCE_METADATA,
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );



    /* ========================================================================
       STEP 3
       REMOVE STALE COLUMN METADATA

       If a physical column has been dropped, do not leave it indefinitely
       in the current governance catalog.
    ======================================================================== */

    DELETE
    FROM GOVERNANCE.CATALOG.COLUMN_CATALOG T

    WHERE

        (
            (
                T.DATABASE_NAME = 'RAW'
                AND T.SCHEMA_NAME = 'BANKING'
            )

            OR

            (
                T.DATABASE_NAME = 'ANALYTICS'
                AND T.SCHEMA_NAME IN
                (
                    'STAGING',
                    'MARTS'
                )
            )
        )

        AND NOT EXISTS
        (

            SELECT 1

            FROM
            (

                SELECT

                    TABLE_CATALOG,
                    TABLE_SCHEMA,
                    TABLE_NAME,
                    COLUMN_NAME

                FROM RAW.INFORMATION_SCHEMA.COLUMNS

                WHERE TABLE_SCHEMA = 'BANKING'


                UNION ALL


                SELECT

                    TABLE_CATALOG,
                    TABLE_SCHEMA,
                    TABLE_NAME,
                    COLUMN_NAME

                FROM ANALYTICS.INFORMATION_SCHEMA.COLUMNS

                WHERE TABLE_SCHEMA IN
                (
                    'STAGING',
                    'MARTS'
                )

            ) S

            WHERE S.TABLE_CATALOG = T.DATABASE_NAME
              AND S.TABLE_SCHEMA  = T.SCHEMA_NAME
              AND S.TABLE_NAME    = T.TABLE_NAME
              AND S.COLUMN_NAME   = T.COLUMN_NAME

        );



    /* ========================================================================
       STEP 4
       REMOVE STALE OBJECT METADATA
    ======================================================================== */

    DELETE
    FROM GOVERNANCE.CATALOG.OBJECT_CATALOG T

    WHERE

        (
            (
                T.DATABASE_NAME = 'RAW'
                AND T.SCHEMA_NAME = 'BANKING'
            )

            OR

            (
                T.DATABASE_NAME = 'ANALYTICS'
                AND T.SCHEMA_NAME IN
                (
                    'STAGING',
                    'MARTS'
                )
            )
        )

        AND NOT EXISTS
        (

            SELECT 1

            FROM
            (

                SELECT

                    TABLE_CATALOG,
                    TABLE_SCHEMA,
                    TABLE_NAME

                FROM RAW.INFORMATION_SCHEMA.TABLES

                WHERE TABLE_SCHEMA = 'BANKING'


                UNION ALL


                SELECT

                    TABLE_CATALOG,
                    TABLE_SCHEMA,
                    TABLE_NAME

                FROM ANALYTICS.INFORMATION_SCHEMA.TABLES

                WHERE TABLE_SCHEMA IN
                (
                    'STAGING',
                    'MARTS'
                )

            ) S

            WHERE S.TABLE_CATALOG = T.DATABASE_NAME
              AND S.TABLE_SCHEMA  = T.SCHEMA_NAME
              AND S.TABLE_NAME    = T.OBJECT_NAME

        );



    /* ========================================================================
       STEP 5
       CAPTURE RESULT COUNTS
    ======================================================================== */

    SELECT COUNT(*)
    INTO :V_OBJECT_COUNT
    FROM GOVERNANCE.CATALOG.OBJECT_CATALOG

    WHERE
        (
            DATABASE_NAME = 'RAW'
            AND SCHEMA_NAME = 'BANKING'
        )

        OR

        (
            DATABASE_NAME = 'ANALYTICS'
            AND SCHEMA_NAME IN
            (
                'STAGING',
                'MARTS'
            )
        );


    SELECT COUNT(*)
    INTO :V_COLUMN_COUNT
    FROM GOVERNANCE.CATALOG.COLUMN_CATALOG

    WHERE
        (
            DATABASE_NAME = 'RAW'
            AND SCHEMA_NAME = 'BANKING'
        )

        OR

        (
            DATABASE_NAME = 'ANALYTICS'
            AND SCHEMA_NAME IN
            (
                'STAGING',
                'MARTS'
            )
        );



    /* ========================================================================
       STEP 6
       RETURN EXECUTION SUMMARY
    ======================================================================== */

    RETURN
          'METADATA HARVEST COMPLETED SUCCESSFULLY'
       || ' | OBJECTS='
       || V_OBJECT_COUNT
       || ' | COLUMNS='
       || V_COLUMN_COUNT
       || ' | HARVESTED_AT='
       || CURRENT_TIMESTAMP();


END;
$$;