/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/20_validate_banking_glossary.sql

  Purpose:
      Validate the governed 10-term banking glossary and its physical
      column mappings.
==============================================================================*/


USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;



-- ============================================================================
-- 1. VERIFY THE TEN REQUIRED SEEDED TERMS
--
-- Expected:
--      SEEDED_TERM_COUNT = 10
--      APPROVED_TERM_COUNT = 10
-- ============================================================================

SELECT

    COUNT(*) AS SEEDED_TERM_COUNT,

    COUNT_IF(STATUS = 'APPROVED')
        AS APPROVED_TERM_COUNT

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM

WHERE TERM_ID IN
(
    'CUSTOMER',
    'DEPOSIT_ACCOUNT',
    'ACCOUNT_BALANCE',
    'TRANSACTION_POSTING',
    'TRANSACTION_AMOUNT',
    'LOAN',
    'CREDIT_GRADE',
    'COLLATERAL',
    'BRANCH',
    'GL_CONTROL_TOTAL'
);



-- ============================================================================
-- 2. DISPLAY GOVERNED GLOSSARY
-- ============================================================================

SELECT

    TERM_ID,
    TERM_NAME,
    DEFINITION,
    DOMAIN,
    DATA_OWNER,
    DATA_STEWARD,
    STATUS,
    VERSION

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM

WHERE TERM_ID IN
(
    'CUSTOMER',
    'DEPOSIT_ACCOUNT',
    'ACCOUNT_BALANCE',
    'TRANSACTION_POSTING',
    'TRANSACTION_AMOUNT',
    'LOAN',
    'CREDIT_GRADE',
    'COLLATERAL',
    'BRANCH',
    'GL_CONTROL_TOTAL'
)

ORDER BY DOMAIN, TERM_NAME;



-- ============================================================================
-- 3. DUPLICATE TERM NAMES
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    TERM_NAME,

    COUNT(*) AS RECORD_COUNT

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM

GROUP BY TERM_NAME

HAVING COUNT(*) > 1;



-- ============================================================================
-- 4. SEEDED TERMS WITHOUT ANY ACTIVE PHYSICAL COLUMN LINK
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    G.TERM_ID,
    G.TERM_NAME

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM G

LEFT JOIN GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK L

       ON L.TERM_ID = G.TERM_ID
      AND L.ACTIVE_FLAG = TRUE

WHERE G.TERM_ID IN
(
    'CUSTOMER',
    'DEPOSIT_ACCOUNT',
    'ACCOUNT_BALANCE',
    'TRANSACTION_POSTING',
    'TRANSACTION_AMOUNT',
    'LOAN',
    'CREDIT_GRADE',
    'COLLATERAL',
    'BRANCH',
    'GL_CONTROL_TOTAL'
)

AND L.TERM_ID IS NULL

ORDER BY G.TERM_ID;



-- ============================================================================
-- 5. ORPHAN GLOSSARY LINKS
--
-- Link refers to a TERM_ID not present in GLOSSARY_TERM.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    L.TERM_ID,
    L.TABLE_NAME,
    L.COLUMN_NAME

FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK L

LEFT JOIN GOVERNANCE.CATALOG.GLOSSARY_TERM G
       ON G.TERM_ID = L.TERM_ID

WHERE L.ACTIVE_FLAG = TRUE

  AND G.TERM_ID IS NULL;



-- ============================================================================
-- 6. LINKS TO PHYSICAL COLUMNS THAT DO NOT EXIST
--
-- COLUMN_CATALOG contains harvested Snowflake physical metadata.
--
-- Expected:
--      0 rows
-- ============================================================================

SELECT

    L.TERM_ID,
    L.DATABASE_NAME,
    L.SCHEMA_NAME,
    L.TABLE_NAME,
    L.COLUMN_NAME,
    L.RELATIONSHIP_TYPE

FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK L

LEFT JOIN GOVERNANCE.CATALOG.COLUMN_CATALOG C

       ON C.DATABASE_NAME = L.DATABASE_NAME
      AND C.SCHEMA_NAME   = L.SCHEMA_NAME
      AND C.TABLE_NAME    = L.TABLE_NAME
      AND C.COLUMN_NAME   = L.COLUMN_NAME

WHERE L.ACTIVE_FLAG = TRUE

  AND C.COLUMN_NAME IS NULL

ORDER BY
    L.TERM_ID,
    L.TABLE_NAME,
    L.COLUMN_NAME;



-- ============================================================================
-- 7. LINK COVERAGE SUMMARY
--
-- Expected for the seed supplied above:
--
--      LINKED_TERMS = 10
--      ACTIVE_LINKS = 27
-- ============================================================================

SELECT

    COUNT(DISTINCT TERM_ID)
        AS LINKED_TERMS,

    COUNT(*)
        AS ACTIVE_LINKS,

    COUNT_IF(RELATIONSHIP_TYPE = 'DIRECT')
        AS DIRECT_LINKS,

    COUNT_IF(RELATIONSHIP_TYPE = 'REFERENCE')
        AS REFERENCE_LINKS,

    COUNT_IF(RELATIONSHIP_TYPE = 'DERIVED')
        AS DERIVED_LINKS

FROM GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK

WHERE ACTIVE_FLAG = TRUE;



-- ============================================================================
-- 8. FINAL BUSINESS-FRIENDLY GLOSSARY VIEW
--
-- Useful evidence query.
-- ============================================================================

SELECT

    G.TERM_NAME,
    G.DEFINITION,
    G.DOMAIN,
    G.DATA_OWNER,
    G.DATA_STEWARD,

    L.DATABASE_NAME
        || '.'
        || L.SCHEMA_NAME
        || '.'
        || L.TABLE_NAME
        || '.'
        || L.COLUMN_NAME
            AS PHYSICAL_COLUMN,

    L.RELATIONSHIP_TYPE

FROM GOVERNANCE.CATALOG.GLOSSARY_TERM G

INNER JOIN GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK L
        ON L.TERM_ID = G.TERM_ID

WHERE G.STATUS = 'APPROVED'
  AND L.ACTIVE_FLAG = TRUE

ORDER BY
    G.TERM_NAME,
    PHYSICAL_COLUMN;