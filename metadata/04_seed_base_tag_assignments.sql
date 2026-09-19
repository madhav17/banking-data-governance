/*==============================================================================
 AVIDIA
 Phase 2 - Baseline Tag Configuration
==============================================================================*/

USE ROLE SYSADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;

USE DATABASE GOVERNANCE;

USE SCHEMA CATALOG;


MERGE INTO GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

USING
(
    SELECT
        COLUMN1::VARCHAR AS DATABASE_NAME,
        COLUMN2::VARCHAR AS SCHEMA_NAME,
        COLUMN3::VARCHAR AS OBJECT_NAME,
        COLUMN4::VARCHAR AS COLUMN_NAME,
        COLUMN5::VARCHAR AS OBJECT_LEVEL,
        COLUMN6::VARCHAR AS OBJECT_TYPE,
        COLUMN7::VARCHAR AS TAG_NAME,
        COLUMN8::VARCHAR AS TAG_VALUE,
        COLUMN9::VARCHAR AS SOURCE_TYPE,
        COLUMN10::NUMBER AS APPLY_ORDER,
        COLUMN11::VARCHAR AS ASSIGNMENT_REASON

    FROM VALUES

    /* ========================================================================
       RAW
    ======================================================================== */

    (
        'RAW',
        'BANKING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'LAYER',
        'RAW',
        'BASELINE',
        10,
        'RAW.BANKING is the source-faithful RAW layer'
    ),

    (
        'RAW',
        'BANKING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DOMAIN',
        'BANKING',
        'BASELINE',
        20,
        'Default banking domain'
    ),

    (
        'RAW',
        'BANKING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DATA_OWNER',
        'DATA_OWNER',
        'BASELINE',
        30,
        'Default business owner'
    ),

    (
        'RAW',
        'BANKING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DATA_STEWARD',
        'DATA_STEWARD',
        'BASELINE',
        30,
        'Default data steward'
    ),


    /* ========================================================================
       STAGING
    ======================================================================== */

    (
        'ANALYTICS',
        'STAGING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'LAYER',
        'STAGING',
        'BASELINE',
        10,
        'Standardized STAGING layer'
    ),

    (
        'ANALYTICS',
        'STAGING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DOMAIN',
        'BANKING',
        'BASELINE',
        20,
        'Default banking domain'
    ),

    (
        'ANALYTICS',
        'STAGING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DATA_OWNER',
        'DATA_OWNER',
        'BASELINE',
        30,
        'Default business owner'
    ),

    (
        'ANALYTICS',
        'STAGING',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DATA_STEWARD',
        'DATA_STEWARD',
        'BASELINE',
        30,
        'Default data steward'
    ),


    /* ========================================================================
       MARTS
    ======================================================================== */

    (
        'ANALYTICS',
        'MARTS',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'LAYER',
        'MARTS',
        'BASELINE',
        10,
        'Business consumption MARTS layer'
    ),

    (
        'ANALYTICS',
        'MARTS',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DOMAIN',
        'BANKING',
        'BASELINE',
        20,
        'Default banking business domain'
    ),

    (
        'ANALYTICS',
        'MARTS',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DATA_OWNER',
        'DATA_OWNER',
        'BASELINE',
        30,
        'Default business owner'
    ),

    (
        'ANALYTICS',
        'MARTS',
        NULL,
        NULL,
        'SCHEMA',
        NULL,
        'DATA_STEWARD',
        'DATA_STEWARD',
        'BASELINE',
        30,
        'Default data steward'
    )

) S

ON  T.DATABASE_NAME = S.DATABASE_NAME
AND COALESCE(T.SCHEMA_NAME, '') =
    COALESCE(S.SCHEMA_NAME, '')
AND COALESCE(T.OBJECT_NAME, '') =
    COALESCE(S.OBJECT_NAME, '')
AND COALESCE(T.COLUMN_NAME, '') =
    COALESCE(S.COLUMN_NAME, '')
AND T.OBJECT_LEVEL = S.OBJECT_LEVEL
AND T.TAG_NAME = S.TAG_NAME


WHEN MATCHED THEN

UPDATE SET

    TAG_VALUE =
        S.TAG_VALUE,

    SOURCE_TYPE =
        S.SOURCE_TYPE,

    APPLY_ORDER =
        S.APPLY_ORDER,

    ASSIGNMENT_REASON =
        S.ASSIGNMENT_REASON,

    ACTIVE_FLAG =
        TRUE,

    UPDATED_AT =
        CURRENT_TIMESTAMP()


WHEN NOT MATCHED THEN

INSERT
(
    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,

    OBJECT_LEVEL,
    OBJECT_TYPE,

    TAG_NAME,
    TAG_VALUE,

    SOURCE_TYPE,

    APPLY_ORDER,

    ASSIGNMENT_REASON,

    ACTIVE_FLAG
)

VALUES
(
    S.DATABASE_NAME,
    S.SCHEMA_NAME,
    S.OBJECT_NAME,
    S.COLUMN_NAME,

    S.OBJECT_LEVEL,
    S.OBJECT_TYPE,

    S.TAG_NAME,
    S.TAG_VALUE,

    S.SOURCE_TYPE,

    S.APPLY_ORDER,

    S.ASSIGNMENT_REASON,

    TRUE
);


-- ============================================================================
-- RAW TABLE SOURCE SYSTEM ASSIGNMENTS
-- ============================================================================

MERGE INTO GOVERNANCE.CATALOG.TAG_ASSIGNMENT T

USING
(
    SELECT
        COLUMN1::VARCHAR AS DATABASE_NAME,
        COLUMN2::VARCHAR AS SCHEMA_NAME,
        COLUMN3::VARCHAR AS OBJECT_NAME,
        COLUMN4::VARCHAR AS TAG_VALUE

    FROM VALUES

        ('RAW', 'BANKING', 'BRANCH',                'CORE_BANKING'),
        ('RAW', 'BANKING', 'PRODUCT',               'CORE_BANKING'),
        ('RAW', 'BANKING', 'OFFICER',               'CRM'),
        ('RAW', 'BANKING', 'CUSTOMER',              'CRM'),
        ('RAW', 'BANKING', 'ACCOUNT',               'CORE_BANKING'),
        ('RAW', 'BANKING', 'ACCOUNT_DAILY_BALANCE', 'CORE_BANKING'),
        ('RAW', 'BANKING', 'TRANSACTIONS',          'CORE_BANKING'),
        ('RAW', 'BANKING', 'CARD',                  'CARD_SYSTEM'),
        ('RAW', 'BANKING', 'LOAN',                  'LOAN_SYSTEM'),
        ('RAW', 'BANKING', 'LOAN_COLLATERAL',       'LOAN_SYSTEM'),
        ('RAW', 'BANKING', 'GL_CONTROL_TOTAL',       'GENERAL_LEDGER')

) S

ON  T.DATABASE_NAME = S.DATABASE_NAME
AND T.SCHEMA_NAME   = S.SCHEMA_NAME
AND T.OBJECT_NAME   = S.OBJECT_NAME
AND T.COLUMN_NAME IS NULL
AND T.OBJECT_LEVEL = 'TABLE'
AND T.TAG_NAME = 'SOURCE_SYSTEM'

WHEN MATCHED THEN

UPDATE SET
    T.TAG_VALUE = S.TAG_VALUE,
    T.SOURCE_TYPE = 'BASELINE',
    T.SOURCE_REFERENCE =
        S.DATABASE_NAME || '.' ||
        S.SCHEMA_NAME || '.' ||
        S.OBJECT_NAME,
    T.ASSIGNMENT_REASON =
        'Source system assignment for RAW banking table',
    T.APPLY_ORDER = 30,
    T.ACTIVE_FLAG = TRUE,
    T.UPDATED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN

INSERT
(
    DATABASE_NAME,
    SCHEMA_NAME,
    OBJECT_NAME,
    COLUMN_NAME,
    OBJECT_LEVEL,
    OBJECT_TYPE,
    TAG_NAME,
    TAG_VALUE,
    SOURCE_TYPE,
    SOURCE_REFERENCE,
    ASSIGNMENT_REASON,
    APPLY_ORDER,
    ACTIVE_FLAG
)

VALUES
(
    S.DATABASE_NAME,
    S.SCHEMA_NAME,
    S.OBJECT_NAME,
    NULL,
    'TABLE',
    'TABLE',
    'SOURCE_SYSTEM',
    S.TAG_VALUE,
    'BASELINE',
    S.DATABASE_NAME || '.' ||
    S.SCHEMA_NAME || '.' ||
    S.OBJECT_NAME,
    'Source system assignment for RAW banking table',
    30,
    TRUE
);