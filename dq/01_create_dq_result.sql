/*==============================================================================
 AVIDIA BANK - CREATE DQ RESULT TABLE

 Purpose:
   Persist one row per DQ expectation result per execution. Snowflake keeps
   native DQ history too; this table is the project governance result surface
   that later CERTIFY(object), scorecards and catalog UI can consume.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA DQ;

CREATE TABLE IF NOT EXISTS GOVERNANCE.DQ.DQ_RESULT
(
    RUN_ID                 VARCHAR(36) NOT NULL,
    CHECK_NAME             VARCHAR(255) NOT NULL,
    QUALITY_DIMENSION      VARCHAR(50) NOT NULL,
    OBJECT_FQN             VARCHAR(500) NOT NULL,
    METRIC_DATABASE        VARCHAR(255),
    METRIC_SCHEMA          VARCHAR(255),
    METRIC_NAME            VARCHAR(255),
    ARGUMENTS              VARCHAR,
    METRIC_VALUE           NUMBER(38,6),
    THRESHOLD_VALUE        NUMBER(38,6),
    STATUS                 VARCHAR(10) NOT NULL,
    EXPECTATION_EXPRESSION VARCHAR,
    MEASURED_AT            TIMESTAMP_LTZ NOT NULL,
    RECORDED_AT            TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT CK_DQ_RESULT_STATUS
        CHECK (STATUS IN ('PASS', 'FAIL'))
)
COMMENT = 'Persistent governance DQ results for certified-candidate data products. Retains history across runs.';

SHOW TABLES LIKE 'DQ_RESULT' IN SCHEMA GOVERNANCE.DQ;
