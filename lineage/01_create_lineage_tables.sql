/*==============================================================================
 AVIDIA BANK - LINEAGE TABLES

 Purpose:
   Create persistent native lineage snapshots and the approved external
   fallback table for metadata-only external endpoint edges.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

CREATE TABLE IF NOT EXISTS GOVERNANCE.CATALOG.LINEAGE_EDGE
(
    SNAPSHOT_ID             VARCHAR(36) NOT NULL,
    SNAPSHOT_AT             TIMESTAMP_LTZ NOT NULL,
    ROOT_OBJECT             VARCHAR(500) NOT NULL,
    DIRECTION               VARCHAR(20) NOT NULL,
    DISTANCE                NUMBER,

    SOURCE_OBJECT           VARCHAR(500),
    SOURCE_OBJECT_DATABASE  VARCHAR(255),
    SOURCE_OBJECT_SCHEMA    VARCHAR(255),
    SOURCE_OBJECT_NAME      VARCHAR(255),
    SOURCE_OBJECT_DOMAIN    VARCHAR(100),
    SOURCE_COLUMN           VARCHAR(255),
    SOURCE_STATUS           VARCHAR(100),
    SOURCE_ORIGIN           VARCHAR(100),

    TARGET_OBJECT           VARCHAR(500),
    TARGET_OBJECT_DATABASE  VARCHAR(255),
    TARGET_OBJECT_SCHEMA    VARCHAR(255),
    TARGET_OBJECT_NAME      VARCHAR(255),
    TARGET_OBJECT_DOMAIN    VARCHAR(100),
    TARGET_COLUMN           VARCHAR(255),
    TARGET_STATUS           VARCHAR(100),
    TARGET_ORIGIN           VARCHAR(100),

    PROCESS                 VARIANT,
    SOURCE_DETAILS          VARIANT,
    TARGET_DETAILS          VARIANT
)
COMMENT = 'Historical snapshots of native Snowflake lineage returned by SNOWFLAKE.CORE.GET_LINEAGE for DEPOSITS_DAILY.';

COMMENT ON TABLE GOVERNANCE.CATALOG.LINEAGE_EDGE IS
    'Historical snapshots of native Snowflake lineage returned by SNOWFLAKE.CORE.GET_LINEAGE for DEPOSITS_DAILY.';

CREATE TABLE IF NOT EXISTS GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL
(
    SOURCE_SYSTEM      VARCHAR(100) NOT NULL,
    SOURCE_OBJECT      VARCHAR(500) NOT NULL,
    SOURCE_OBJECT_TYPE VARCHAR(100) NOT NULL,

    TARGET_SYSTEM      VARCHAR(100) NOT NULL,
    TARGET_OBJECT      VARCHAR(500) NOT NULL,
    TARGET_OBJECT_TYPE VARCHAR(100) NOT NULL,

    EDGE_TYPE          VARCHAR(100) NOT NULL,
    DESCRIPTION        VARCHAR(2000),
    CREATED_AT         TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Small fallback table for exactly two metadata-only external lineage endpoint rows required by the take-home.';

COMMENT ON TABLE GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL IS
    'Small fallback table for exactly two metadata-only external lineage endpoint rows required by the take-home.';

SHOW TABLES LIKE 'LINEAGE_EDGE%' IN SCHEMA GOVERNANCE.CATALOG;
