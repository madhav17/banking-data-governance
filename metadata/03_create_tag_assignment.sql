/*==============================================================================
 AVIDIA
 Phase 2 - Metadata Driven Tag Assignment
==============================================================================*/

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


CREATE TABLE IF NOT EXISTS GOVERNANCE.CATALOG.TAG_ASSIGNMENT
(
    DATABASE_NAME       VARCHAR(255) NOT NULL,

    SCHEMA_NAME         VARCHAR(255),

    OBJECT_NAME         VARCHAR(255),

    COLUMN_NAME         VARCHAR(255),

    /*
       DATABASE
       SCHEMA
       TABLE
       VIEW
       COLUMN
    */
    OBJECT_LEVEL        VARCHAR(50) NOT NULL,

    /*
       Required especially when OBJECT_LEVEL = COLUMN,
       because the parent might be TABLE or VIEW.
    */
    OBJECT_TYPE         VARCHAR(50),

    /*
       Tag name only.

       Examples:
           LAYER
           DOMAIN
           CDE
           DATA_OWNER

       Procedure will resolve this to:
           GOVERNANCE.TAGS.<TAG_NAME>
    */
    TAG_NAME            VARCHAR(255) NOT NULL,

    TAG_VALUE           VARCHAR(256) NOT NULL,

    /*
       Where the decision came from.

       BASELINE
       CDE_REGISTRY
       CLASSIFICATION_REVIEW
       CERTIFICATION
    */
    SOURCE_TYPE         VARCHAR(100),

    SOURCE_REFERENCE    VARCHAR(500),

    ASSIGNMENT_REASON   VARCHAR(5000),

    /*
       Parent/baseline assignments execute first,
       specific overrides afterwards.
    */
    APPLY_ORDER         NUMBER DEFAULT 100,

    ACTIVE_FLAG         BOOLEAN DEFAULT TRUE,

    CREATED_BY          VARCHAR(255)
                            DEFAULT CURRENT_USER(),

    CREATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP(),

    UPDATED_AT          TIMESTAMP_LTZ
                            DEFAULT CURRENT_TIMESTAMP()
)
COMMENT =
'Metadata-driven configuration used to deploy Snowflake governance tags';