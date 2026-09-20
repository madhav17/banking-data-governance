/*==============================================================================
 AVIDIA BANK - CUSTOM DATA METRIC FUNCTIONS

 Purpose:
   Create only the two banking-specific DMFs that system DMFs cannot express:
     1. latest business date match against upstream daily balances
     2. GL deposit reconciliation within one dollar
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA DQ;

CREATE OR REPLACE DATA METRIC FUNCTION
    GOVERNANCE.DQ.DMF_LATEST_BUSINESS_DATE_MATCH
(
    MART_DAILY TABLE
    (
        BUSINESS_DATE DATE
    ),
    UPSTREAM_DAILY_BALANCE TABLE
    (
        BUSINESS_DATE DATE
    )
)
RETURNS NUMBER
COMMENT = 'Returns 0 when DEPOSITS_DAILY max BUSINESS_DATE equals the authoritative STG_ACCOUNT_DAILY_BALANCE max BUSINESS_DATE; otherwise returns 1.'
AS
$$
    SELECT
        IFF
        (
            EQUAL_NULL
            (
                (SELECT MAX(BUSINESS_DATE) FROM MART_DAILY),
                (SELECT MAX(BUSINESS_DATE) FROM UPSTREAM_DAILY_BALANCE)
            ),
            0,
            1
        )
$$;

CREATE OR REPLACE DATA METRIC FUNCTION
    GOVERNANCE.DQ.DMF_GL_DEPOSIT_RECONCILIATION
(
    MART_DAILY TABLE
    (
        BUSINESS_DATE DATE,
        CLOSING_BALANCE NUMBER
    ),
    GL_CONTROL TABLE
    (
        BUSINESS_DATE DATE,
        PRODUCT_TYPE VARCHAR,
        CONTROL_TOTAL NUMBER
    )
)
RETURNS NUMBER
COMMENT = 'Returns the count of business dates where DEPOSITS_DAILY closing-balance totals differ from deposit GL control totals by more than one dollar, including missing dates on either side.'
AS
$$
    WITH MART_TOTALS AS
    (
        SELECT
            BUSINESS_DATE,
            SUM(CLOSING_BALANCE) AS MART_DEPOSIT_TOTAL
        FROM MART_DAILY
        GROUP BY BUSINESS_DATE
    ),

    GL_TOTALS AS
    (
        SELECT
            BUSINESS_DATE,
            SUM(CONTROL_TOTAL) AS GL_CONTROL_TOTAL
        FROM GL_CONTROL
        WHERE PRODUCT_TYPE = 'DEPOSIT'
        GROUP BY BUSINESS_DATE
    ),

    RECONCILIATION AS
    (
        SELECT
            COALESCE(M.BUSINESS_DATE, G.BUSINESS_DATE) AS BUSINESS_DATE,
            M.MART_DEPOSIT_TOTAL,
            G.GL_CONTROL_TOTAL
        FROM MART_TOTALS AS M
        FULL OUTER JOIN GL_TOTALS AS G
            ON M.BUSINESS_DATE = G.BUSINESS_DATE
    )

    SELECT COUNT(*)
    FROM RECONCILIATION
    WHERE MART_DEPOSIT_TOTAL IS NULL
       OR GL_CONTROL_TOTAL IS NULL
       OR ABS(MART_DEPOSIT_TOTAL - GL_CONTROL_TOTAL) > 1
$$;

GRANT USAGE
ON ALL DATA METRIC FUNCTIONS IN SCHEMA GOVERNANCE.DQ
TO ROLE DATA_GOVERNANCE_ADMIN;

GRANT USAGE
ON ALL DATA METRIC FUNCTIONS IN SCHEMA GOVERNANCE.DQ
TO ROLE SVC_PIPELINE_ROLE;

SHOW DATA METRIC FUNCTIONS LIKE 'DMF_%' IN SCHEMA GOVERNANCE.DQ;
