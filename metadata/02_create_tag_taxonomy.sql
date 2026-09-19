
-- snow sql -c avidia -f metadata/02_create_tag_taxonomy.sql

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA TAGS;


--   DOMAIN
--
--   Examples eventually:
--     CUSTOMER
--     DEPOSITS
--     TRANSACTIONS
--     LOANS
--     GL
--     REFERENCE
--
--   Free-form because new domains may be introduced.

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.DOMAIN
    COMMENT =
    'Business/data domain associated with the governed object';



--   LAYER => Strong candidate for inheritance from schema.


CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.LAYER
    ALLOWED_VALUES
        'RAW',
        'STAGING',
        'MARTS'
    COMMENT =
    'Logical data platform layer';



--   CERTIFICATION

--   Create now.
--   Do NOT set CERTIFIED during Phase 2.

--   Later CERTIFY(object) will apply this.


CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CERTIFICATION
    ALLOWED_VALUES
        'CERTIFIED',
        'REVOKED'
    COMMENT =
    'Certification state of a governed consumer-facing data product';



--   DATA OWNER

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.DATA_OWNER
    COMMENT =
    'Business role/team accountable for the governed data';

--   DATA STEWARD

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.DATA_STEWARD
    COMMENT =
    'Role/team responsible for day-to-day governance and stewardship';



--   CDE
--
--   Absence of the tag means NOT a CDE.
--
--   This means:
--
--       WHERE TAG_NAME = 'CDE'
--
--   naturally returns only actual critical data elements.


CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CDE
    ALLOWED_VALUES
        'TIER_1',
        'TIER_2',
        'TIER_3'
    COMMENT =
    'Critical Data Element tier';



--   CLASSIFICATION
--
--   Create now.
--   Do NOT assign during Phase 2.
--
--   Block 2 steward approval will ultimately populate this.

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CLASSIFICATION
    ALLOWED_VALUES
        'PUBLIC',
        'INTERNAL',
        'CONFIDENTIAL',
        'RESTRICTED'
    COMMENT =
    'Confirmed enterprise sensitivity classification';


--   SOURCE SYSTEM
--
--   Free-form because there can be multiple banking source systems.



CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.SOURCE_SYSTEM
    COMMENT =
    'System from which the governed data originated';


--   Validation


SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;