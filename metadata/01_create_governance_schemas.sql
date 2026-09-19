/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE
  Phase 1 - Core Governance Catalog Tables

  Purpose:
    Creates the central governance metadata repository used for:

      - Object inventory
      - Column inventory
      - Data dictionary
      - Business glossary
      - Glossary-to-column mapping
      - Critical Data Element (CDE) registry

  Database  : GOVERNANCE
  Schema    : CATALOG
  Warehouse : WH_GOVERNANCE_XS

==============================================================================*/


-- ============================================================================
-- 1. SET EXECUTION CONTEXT
-- ============================================================================

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

CREATE DATABASE IF NOT EXISTS GOVERNANCE
    COMMENT = 'Central governance, metadata, catalog and data quality database';

USE DATABASE GOVERNANCE;


CREATE SCHEMA IF NOT EXISTS CATALOG
    COMMENT = 'Enterprise metadata catalog, glossary and CDE registry';

USE SCHEMA CATALOG;



-- ============================================================================
-- 2. OBJECT CATALOG
-- ============================================================================
--
-- Stores metadata for Snowflake objects discovered during metadata harvesting.
--
-- Typical sources:
--   SNOWFLAKE.ACCOUNT_USAGE.TABLES
--   INFORMATION_SCHEMA.TABLES
--   INFORMATION_SCHEMA.VIEWS
--
-- Examples:
--   AVIDIA_RAW.RAW.CUSTOMER
--   AVIDIA_STAGING.STAGING.CUSTOMER
--   AVIDIA_MART.MART.CUSTOMER_360
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS OBJECT_CATALOG
(
    DATABASE_NAME       VARCHAR(255) NOT NULL,
    SCHEMA_NAME         VARCHAR(255) NOT NULL,
    OBJECT_NAME         VARCHAR(255) NOT NULL,

    OBJECT_TYPE         VARCHAR(50) NOT NULL,

    OBJECT_OWNER        VARCHAR(255),

    OBJECT_COMMENT      VARCHAR(5000),

    CREATED_AT          TIMESTAMP_LTZ,
    LAST_ALTERED_AT     TIMESTAMP_LTZ,

    ROW_COUNT           NUMBER,

    SOURCE_METADATA     VARCHAR(255),

    HARVESTED_AT        TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_OBJECT_CATALOG
        PRIMARY KEY
        (
            DATABASE_NAME,
            SCHEMA_NAME,
            OBJECT_NAME
        )
)
COMMENT =
'Central inventory of governed Snowflake objects harvested from Snowflake metadata';



-- ============================================================================
-- 3. COLUMN CATALOG
-- ============================================================================
--
-- Stores technical metadata for every governed column.
--
-- This table later becomes important for:
--
--   Classification
--   Sensitive data detection
--   CDE mapping
--   Business glossary mapping
--   Data quality rules
--   Masking policy visibility
--   Streamlit Data Catalog
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS COLUMN_CATALOG
(
    DATABASE_NAME       VARCHAR(255) NOT NULL,
    SCHEMA_NAME         VARCHAR(255) NOT NULL,
    TABLE_NAME          VARCHAR(255) NOT NULL,
    COLUMN_NAME         VARCHAR(255) NOT NULL,

    ORDINAL_POSITION    NUMBER,

    DATA_TYPE           VARCHAR(255),

    IS_NULLABLE         VARCHAR(10),

    COLUMN_DEFAULT      VARCHAR(5000),

    COMMENT             VARCHAR(5000),

    SOURCE_METADATA     VARCHAR(255),

    HARVESTED_AT        TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_COLUMN_CATALOG
        PRIMARY KEY
        (
            DATABASE_NAME,
            SCHEMA_NAME,
            TABLE_NAME,
            COLUMN_NAME
        )
)
COMMENT =
'Technical metadata inventory for governed Snowflake table columns';



-- ============================================================================
-- 4. DATA DICTIONARY
-- ============================================================================
--
-- Represents expected/business metadata coming from the specification,
-- source documentation, CSV definitions or manually curated definitions.
--
-- This is intentionally separate from COLUMN_CATALOG.
--
-- COLUMN_CATALOG:
--      What Snowflake physically contains.
--
-- DATA_DICTIONARY:
--      What the business/specification says the column means.
--
-- Later we can reconcile the two.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS DATA_DICTIONARY
(
    DATABASE_NAME       VARCHAR(255),

    SCHEMA_NAME         VARCHAR(255),

    TABLE_NAME          VARCHAR(255) NOT NULL,

    COLUMN_NAME         VARCHAR(255) NOT NULL,

    BUSINESS_NAME       VARCHAR(500),

    DESCRIPTION         VARCHAR(5000),

    EXPECTED_DATA_TYPE  VARCHAR(255),

    SENSITIVITY_HINT    VARCHAR(255),

    DATA_DOMAIN         VARCHAR(255),

    SOURCE_SYSTEM       VARCHAR(255),

    SOURCE_FILE         VARCHAR(1000),

    LOADED_AT           TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_DATA_DICTIONARY
        PRIMARY KEY
        (
            TABLE_NAME,
            COLUMN_NAME
        )
)
COMMENT =
'Curated business and source metadata describing expected data semantics';



-- ============================================================================
-- 5. BUSINESS GLOSSARY
-- ============================================================================
--
-- Stores business concepts independently of physical database columns.
--
-- Examples:
--
--   Customer
--   Account
--   Account Balance
--   Transaction Amount
--   Customer Identifier
--   Account Status
--
-- One glossary term can be linked to multiple physical columns.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS GLOSSARY_TERM
(
    TERM_ID             VARCHAR(100) NOT NULL,

    TERM_NAME           VARCHAR(500) NOT NULL,

    DEFINITION          VARCHAR(5000),

    DOMAIN              VARCHAR(255),

    DATA_OWNER          VARCHAR(255),

    DATA_STEWARD        VARCHAR(255),

    STATUS              VARCHAR(50)
                            DEFAULT 'DRAFT',

    VERSION             NUMBER
                            DEFAULT 1,

    CREATED_BY          VARCHAR(255)
                            DEFAULT CURRENT_USER(),

    CREATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_GLOSSARY_TERM
        PRIMARY KEY (TERM_ID),

    CONSTRAINT UQ_GLOSSARY_TERM_NAME
        UNIQUE (TERM_NAME),

    CONSTRAINT CK_GLOSSARY_TERM_STATUS
        CHECK
        (
            STATUS IN
            (
                'DRAFT',
                'PENDING_APPROVAL',
                'APPROVED',
                'RETIRED'
            )
        )
)
COMMENT =
'Enterprise business glossary containing governed business terminology';



-- ============================================================================
-- 6. GLOSSARY TO COLUMN LINK
-- ============================================================================
--
-- Provides mapping between:
--
--      Business glossary
--
--            and
--
--      Physical Snowflake columns
--
-- Example:
--
--   TERM:
--      ACCOUNT_BALANCE
--
--          ↓
--
--   RAW.ACCOUNT.CURRENT_BALANCE
--   STAGING.ACCOUNT.CURRENT_BALANCE
--   MART.ACCOUNT_SUMMARY.ACCOUNT_BALANCE
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS GLOSSARY_COLUMN_LINK
(
    TERM_ID             VARCHAR(100) NOT NULL,

    DATABASE_NAME       VARCHAR(255) NOT NULL,
    SCHEMA_NAME         VARCHAR(255) NOT NULL,
    TABLE_NAME          VARCHAR(255) NOT NULL,
    COLUMN_NAME         VARCHAR(255) NOT NULL,

    RELATIONSHIP_TYPE   VARCHAR(50)
                            DEFAULT 'DIRECT',

    ACTIVE_FLAG         BOOLEAN
                            DEFAULT TRUE,

    CREATED_BY          VARCHAR(255)
                            DEFAULT CURRENT_USER(),

    CREATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_GLOSSARY_COLUMN_LINK
        PRIMARY KEY
        (
            TERM_ID,
            DATABASE_NAME,
            SCHEMA_NAME,
            TABLE_NAME,
            COLUMN_NAME
        ),

    CONSTRAINT CK_GLOSSARY_RELATIONSHIP_TYPE
        CHECK
        (
            RELATIONSHIP_TYPE IN
            (
                'DIRECT',
                'DERIVED',
                'REFERENCE'
            )
        )
)
COMMENT =
'Maps enterprise business glossary terms to physical Snowflake columns';



-- ============================================================================
-- 7. CRITICAL DATA ELEMENT REGISTRY
-- ============================================================================
--
-- Registry for business-critical columns.
--
-- A CDE is a data element whose quality, integrity or availability can have
-- significant business, financial, customer or regulatory impact.
--
-- Typical banking examples:
--
--   CUSTOMER_ID
--   ACCOUNT_ID
--   ACCOUNT_NUMBER
--   CURRENT_BALANCE
--   TRANSACTION_AMOUNT
--   TRANSACTION_DATE
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS CDE_REGISTRY
(
    DATABASE_NAME       VARCHAR(255) NOT NULL,
    SCHEMA_NAME         VARCHAR(255) NOT NULL,
    TABLE_NAME          VARCHAR(255) NOT NULL,
    COLUMN_NAME         VARCHAR(255) NOT NULL,

    CDE_TIER            VARCHAR(50) NOT NULL,

    BUSINESS_NAME       VARCHAR(500),

    BUSINESS_DEFINITION VARCHAR(5000),

    BUSINESS_REASON     VARCHAR(5000),

    DATA_DOMAIN         VARCHAR(255),

    DATA_OWNER          VARCHAR(255),

    DATA_STEWARD        VARCHAR(255),

    REGULATORY_RELEVANCE VARCHAR(1000),

    DQ_REQUIRED         BOOLEAN
                            DEFAULT TRUE,

    ACTIVE_FLAG         BOOLEAN
                            DEFAULT TRUE,

    CREATED_BY          VARCHAR(255)
                            DEFAULT CURRENT_USER(),

    CREATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_CDE_REGISTRY
        PRIMARY KEY
        (
            DATABASE_NAME,
            SCHEMA_NAME,
            TABLE_NAME,
            COLUMN_NAME
        ),

    CONSTRAINT CK_CDE_TIER
        CHECK
        (
            CDE_TIER IN
            (
                'TIER_1',
                'TIER_2',
                'TIER_3'
            )
        )
)
COMMENT =
'Registry of Critical Data Elements requiring enhanced governance and data quality controls';



-- ============================================================================
-- 8. TABLE COMMENTS / DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE OBJECT_CATALOG IS
'Inventory of governed Snowflake objects collected by metadata harvesting';

COMMENT ON TABLE COLUMN_CATALOG IS
'Inventory of governed Snowflake columns and their technical metadata';

COMMENT ON TABLE DATA_DICTIONARY IS
'Business and source-level description of expected tables and columns';

COMMENT ON TABLE GLOSSARY_TERM IS
'Central registry of approved enterprise business terminology';

COMMENT ON TABLE GLOSSARY_COLUMN_LINK IS
'Maps business glossary terms to physical Snowflake columns';

COMMENT ON TABLE CDE_REGISTRY IS
'Registry identifying Critical Data Elements and governance accountability';



-- ============================================================================
-- 9. VALIDATION
-- ============================================================================

SHOW TABLES IN SCHEMA GOVERNANCE.CATALOG;


SELECT
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM GOVERNANCE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CATALOG'
ORDER BY TABLE_NAME;



-- ============================================================================
-- EXPECTED TABLES
-- ============================================================================
--
-- GOVERNANCE.CATALOG.OBJECT_CATALOG
-- GOVERNANCE.CATALOG.COLUMN_CATALOG
-- GOVERNANCE.CATALOG.DATA_DICTIONARY
-- GOVERNANCE.CATALOG.GLOSSARY_TERM
-- GOVERNANCE.CATALOG.GLOSSARY_COLUMN_LINK
-- GOVERNANCE.CATALOG.CDE_REGISTRY
--
-- ============================================================================