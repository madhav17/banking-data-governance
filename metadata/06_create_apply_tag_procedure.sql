/*==============================================================================
 AVIDIA
 Phase 2 - Metadata Driven Tag Deployment
==============================================================================*/

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


CREATE OR REPLACE PROCEDURE
GOVERNANCE.CATALOG.APPLY_TAG_ASSIGNMENTS()

RETURNS VARCHAR

LANGUAGE SQL

EXECUTE AS OWNER

AS
$$

DECLARE

    V_SQL       VARCHAR;

    V_COUNT     NUMBER DEFAULT 0;


    C_ASSIGNMENTS CURSOR FOR

        SELECT
            DATABASE_NAME,
            SCHEMA_NAME,
            OBJECT_NAME,
            COLUMN_NAME,

            OBJECT_LEVEL,
            OBJECT_TYPE,

            TAG_NAME,
            TAG_VALUE

        FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT

        WHERE ACTIVE_FLAG = TRUE

        ORDER BY
            APPLY_ORDER,
            DATABASE_NAME,
            SCHEMA_NAME,
            OBJECT_NAME,
            COLUMN_NAME,
            TAG_NAME;


BEGIN

    FOR REC IN C_ASSIGNMENTS DO


        /* ================================================================
           SCHEMA
        ================================================================ */

        IF (REC.OBJECT_LEVEL = 'SCHEMA') THEN

            V_SQL :=

                'ALTER SCHEMA "' ||

                REPLACE(REC.DATABASE_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.SCHEMA_NAME, '"', '""') ||

                '" SET TAG "GOVERNANCE"."TAGS"."' ||

                REPLACE(REC.TAG_NAME, '"', '""') ||

                '" = ''' ||

                REPLACE(REC.TAG_VALUE, '''', '''''') ||

                '''';


        /* ================================================================
           TABLE
        ================================================================ */

        ELSEIF (REC.OBJECT_LEVEL = 'TABLE') THEN

            V_SQL :=

                'ALTER TABLE "' ||

                REPLACE(REC.DATABASE_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.SCHEMA_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.OBJECT_NAME, '"', '""') ||

                '" SET TAG "GOVERNANCE"."TAGS"."' ||

                REPLACE(REC.TAG_NAME, '"', '""') ||

                '" = ''' ||

                REPLACE(REC.TAG_VALUE, '''', '''''') ||

                '''';


        /* ================================================================
           VIEW
        ================================================================ */

        ELSEIF (REC.OBJECT_LEVEL = 'VIEW') THEN

            V_SQL :=

                'ALTER VIEW "' ||

                REPLACE(REC.DATABASE_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.SCHEMA_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.OBJECT_NAME, '"', '""') ||

                '" SET TAG "GOVERNANCE"."TAGS"."' ||

                REPLACE(REC.TAG_NAME, '"', '""') ||

                '" = ''' ||

                REPLACE(REC.TAG_VALUE, '''', '''''') ||

                '''';


        /* ================================================================
           COLUMN ON TABLE
        ================================================================ */

        ELSEIF (
            REC.OBJECT_LEVEL = 'COLUMN'
            AND COALESCE(REC.OBJECT_TYPE, 'TABLE') = 'TABLE'
        ) THEN

            V_SQL :=

                'ALTER TABLE "' ||

                REPLACE(REC.DATABASE_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.SCHEMA_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.OBJECT_NAME, '"', '""') ||

                '" MODIFY COLUMN "' ||

                REPLACE(REC.COLUMN_NAME, '"', '""') ||

                '" SET TAG "GOVERNANCE"."TAGS"."' ||

                REPLACE(REC.TAG_NAME, '"', '""') ||

                '" = ''' ||

                REPLACE(REC.TAG_VALUE, '''', '''''') ||

                '''';


        /* ================================================================
           COLUMN ON VIEW
        ================================================================ */

        ELSEIF (
            REC.OBJECT_LEVEL = 'COLUMN'
            AND REC.OBJECT_TYPE = 'VIEW'
        ) THEN

            V_SQL :=

                'ALTER VIEW "' ||

                REPLACE(REC.DATABASE_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.SCHEMA_NAME, '"', '""') ||

                '"."' ||

                REPLACE(REC.OBJECT_NAME, '"', '""') ||

                '" MODIFY COLUMN "' ||

                REPLACE(REC.COLUMN_NAME, '"', '""') ||

                '" SET TAG "GOVERNANCE"."TAGS"."' ||

                REPLACE(REC.TAG_NAME, '"', '""') ||

                '" = ''' ||

                REPLACE(REC.TAG_VALUE, '''', '''''') ||

                '''';

        ELSE

            V_SQL := NULL;

        END IF;


        IF (V_SQL IS NOT NULL) THEN

            EXECUTE IMMEDIATE :V_SQL;

            V_COUNT := V_COUNT + 1;

        END IF;


    END FOR;


    RETURN
        'Successfully applied ' ||
        V_COUNT ||
        ' governance tag assignments.';

END;

$$;