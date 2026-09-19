/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/15_create_apply_dictionary_comments_procedure.sql

  Purpose:
      Create a metadata-driven stored procedure that applies business
      descriptions from DATA_DICTIONARY as native Snowflake table and
      column comments.

  Design:
      - EXECUTE AS CALLER
      - Called later as DATA_ENGINEER
      - DATA_ENGINEER owns RAW.BANKING tables
      - Only comments that are missing/different are updated
      - Dynamic COMMENT statements are executed using EXECUTE IMMEDIATE
==============================================================================*/


-- ============================================================================
-- 1. EXECUTION CONTEXT
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. CREATE PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE
    GOVERNANCE.CATALOG.APPLY_DICTIONARY_COMMENTS()

RETURNS VARCHAR

LANGUAGE SQL

EXECUTE AS CALLER

AS
$$

DECLARE

    V_SQL VARCHAR;

    V_TABLE_COMMENTS_APPLIED  NUMBER DEFAULT 0;

    V_COLUMN_COMMENTS_APPLIED NUMBER DEFAULT 0;



    /* ========================================================================
       TABLE COMMENT CURSOR

       DATA_DICTIONARY is column-grain, so table descriptions are maintained
       here as committed metadata definitions.

       Only physical RAW.BANKING tables represented in DATA_DICTIONARY
       are considered.
    ======================================================================== */

    C_TABLE_COMMENTS CURSOR FOR

        WITH TABLE_DESCRIPTIONS AS
        (

            SELECT
                COLUMN1::VARCHAR AS TABLE_NAME,
                COLUMN2::VARCHAR AS TABLE_DESCRIPTION

            FROM VALUES

                (
                    'BRANCH',
                    'Reference table for bank branches.'
                ),

                (
                    'OFFICER',
                    'Bank officer reference linked to a branch.'
                ),

                (
                    'PRODUCT',
                    'Reference table for banking deposit and loan products.'
                ),

                (
                    'CUSTOMER',
                    'Bank customer master containing persons and businesses.'
                ),

                (
                    'ACCOUNT',
                    'Deposit account master containing customer banking accounts.'
                ),

                (
                    'ACCOUNT_DAILY_BALANCE',
                    'Daily end-of-day balance for each deposit account.'
                ),

                (
                    'CARD',
                    'Synthetic payment cards linked to customer deposit accounts.'
                ),

                (
                    'LOAN',
                    'Loan master containing customer lending exposure and credit grade.'
                ),

                (
                    'LOAN_COLLATERAL',
                    'Collateral associated with customer loans.'
                ),

                (
                    'GL_CONTROL_TOTAL',
                    'General ledger control totals used for reconciliation.'
                ),

                (
                    'TRANSACTIONS',
                    'Account transaction postings where one row represents one account posting.'
                )

        ),

        DICTIONARY_TABLES AS
        (

            SELECT DISTINCT
                TABLE_NAME

            FROM GOVERNANCE.CATALOG.DATA_DICTIONARY

            WHERE DATABASE_NAME = 'RAW'
              AND SCHEMA_NAME   = 'BANKING'

        )

        SELECT

            'RAW' AS DATABASE_NAME,

            'BANKING' AS SCHEMA_NAME,

            D.TABLE_NAME,

            D.TABLE_DESCRIPTION

        FROM TABLE_DESCRIPTIONS D

        INNER JOIN DICTIONARY_TABLES X

            ON X.TABLE_NAME = D.TABLE_NAME

        INNER JOIN RAW.INFORMATION_SCHEMA.TABLES T

            ON T.TABLE_CATALOG = 'RAW'
           AND T.TABLE_SCHEMA  = 'BANKING'
           AND T.TABLE_NAME    = D.TABLE_NAME

        WHERE COALESCE(TRIM(T.COMMENT), '')
              <> TRIM(D.TABLE_DESCRIPTION);



    /* ========================================================================
       COLUMN COMMENT CURSOR

       DATA_DICTIONARY.DESCRIPTION is the expected business description.

       Only:
         - existing physical columns
         - non-empty dictionary descriptions
         - comments that differ

       are selected.
    ======================================================================== */

    C_COLUMN_COMMENTS CURSOR FOR

        SELECT

            D.DATABASE_NAME,

            D.SCHEMA_NAME,

            D.TABLE_NAME,

            D.COLUMN_NAME,

            TRIM(D.DESCRIPTION)
                AS DESCRIPTION

        FROM GOVERNANCE.CATALOG.DATA_DICTIONARY D

        INNER JOIN RAW.INFORMATION_SCHEMA.COLUMNS C

             ON C.TABLE_CATALOG = D.DATABASE_NAME
            AND C.TABLE_SCHEMA  = D.SCHEMA_NAME
            AND C.TABLE_NAME    = D.TABLE_NAME
            AND C.COLUMN_NAME   = D.COLUMN_NAME

        WHERE D.DATABASE_NAME = 'RAW'

          AND D.SCHEMA_NAME = 'BANKING'

          AND D.DESCRIPTION IS NOT NULL

          AND TRIM(D.DESCRIPTION) <> ''

          AND COALESCE(TRIM(C.COMMENT), '')
              <> TRIM(D.DESCRIPTION);



BEGIN


    /* ========================================================================
       APPLY TABLE COMMENTS
    ======================================================================== */

    FOR REC IN C_TABLE_COMMENTS DO


        V_SQL :=

              'COMMENT ON TABLE "'
           || REPLACE(REC.DATABASE_NAME, '"', '""')
           || '"."'
           || REPLACE(REC.SCHEMA_NAME, '"', '""')
           || '"."'
           || REPLACE(REC.TABLE_NAME, '"', '""')
           || '" IS '''
           || REPLACE
              (
                  REC.TABLE_DESCRIPTION,
                  '''',
                  ''''''
              )
           || '''';


        EXECUTE IMMEDIATE V_SQL;


        V_TABLE_COMMENTS_APPLIED :=
            V_TABLE_COMMENTS_APPLIED + 1;


    END FOR;



    /* ========================================================================
       APPLY COLUMN COMMENTS
    ======================================================================== */

    FOR REC IN C_COLUMN_COMMENTS DO


        V_SQL :=

              'COMMENT ON COLUMN "'
           || REPLACE(REC.DATABASE_NAME, '"', '""')
           || '"."'
           || REPLACE(REC.SCHEMA_NAME, '"', '""')
           || '"."'
           || REPLACE(REC.TABLE_NAME, '"', '""')
           || '"."'
           || REPLACE(REC.COLUMN_NAME, '"', '""')
           || '" IS '''
           || REPLACE
              (
                  REC.DESCRIPTION,
                  '''',
                  ''''''
              )
           || '''';


        EXECUTE IMMEDIATE V_SQL;


        V_COLUMN_COMMENTS_APPLIED :=
            V_COLUMN_COMMENTS_APPLIED + 1;


    END FOR;



    RETURN

          'DICTIONARY COMMENTS APPLIED'
       || ' | TABLE_COMMENTS='
       || V_TABLE_COMMENTS_APPLIED
       || ' | COLUMN_COMMENTS='
       || V_COLUMN_COMMENTS_APPLIED;


END;
$$;



-- ============================================================================
-- 3. ALLOW DATA_ENGINEER TO CALL THE PROCEDURE
-- ============================================================================

GRANT USAGE
ON PROCEDURE GOVERNANCE.CATALOG.APPLY_DICTIONARY_COMMENTS()
TO ROLE DATA_ENGINEER;



-- ============================================================================
-- 4. VERIFY PROCEDURE
-- ============================================================================

SHOW PROCEDURES
LIKE 'APPLY_DICTIONARY_COMMENTS'
IN SCHEMA GOVERNANCE.CATALOG;