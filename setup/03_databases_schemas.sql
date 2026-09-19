-- ============================================================
-- Avidia Bank Take-Home
-- Database and Schema Foundation
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;


-- ============================================================
-- DATABASES
-- ============================================================

CREATE DATABASE IF NOT EXISTS RAW
    COMMENT = 'Source-aligned synthetic banking data';

CREATE DATABASE IF NOT EXISTS ANALYTICS
    COMMENT = 'Standardized and business-ready banking data';

CREATE DATABASE IF NOT EXISTS GOVERNANCE
    COMMENT = 'Metadata, governance, data quality, certification and evidence';


-- ============================================================
-- RAW
-- ============================================================

CREATE SCHEMA IF NOT EXISTS RAW.BANKING
    COMMENT = 'Raw source-aligned synthetic banking data';


-- ============================================================
-- ANALYTICS
-- ============================================================

CREATE SCHEMA IF NOT EXISTS ANALYTICS.STAGING
    COMMENT = 'Standardized banking data derived from RAW';

CREATE SCHEMA IF NOT EXISTS ANALYTICS.MARTS
    COMMENT = 'Business-ready governed banking data products';


-- ============================================================
-- GOVERNANCE
-- ============================================================

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.CATALOG
    COMMENT = 'Technical and business metadata, glossary and CDE registry';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.TAGS
    COMMENT = 'Governance tags and data protection policies';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.EVIDENCE
    COMMENT = 'Certification, lineage, scorecard and governance evidence';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.DQ
    COMMENT = 'Data quality definitions, measurements and results';