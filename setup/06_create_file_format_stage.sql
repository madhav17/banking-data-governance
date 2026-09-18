-- ============================================================
-- Avidia Bank
-- Common CSV File Format + Internal Stage
-- ============================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_GOVERNANCE_XS;


-- ============================================================
-- 1. COMMON CSV FILE FORMAT
-- ============================================================

CREATE FILE FORMAT IF NOT EXISTS RAW.BANKING.FF_BANKING_CSV
    TYPE = CSV

    -- Read CSV header names.
    PARSE_HEADER = TRUE

    FIELD_DELIMITER = ','

    -- Required for values such as:
    -- "78 MG Road, Block B"
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'

    TRIM_SPACE = TRUE

    -- Convert empty CSV values into NULL.
    EMPTY_FIELD_AS_NULL = TRUE

    NULL_IF = ('NULL', 'null')

    DATE_FORMAT = 'AUTO'
    TIMESTAMP_FORMAT = 'AUTO'

    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE

    COMMENT = 'Common CSV file format for Avidia RAW banking data';


-- ============================================================
-- 2. NAMED INTERNAL STAGE
-- ============================================================

CREATE STAGE IF NOT EXISTS RAW.BANKING.STG_BANKING_CSV
    FILE_FORMAT = RAW.BANKING.FF_BANKING_CSV
    COMMENT = 'Internal stage for Avidia synthetic banking CSV files';


-- ============================================================
-- 3. VERIFICATION
-- ============================================================

SHOW FILE FORMATS LIKE 'FF_BANKING_CSV'
    IN SCHEMA RAW.BANKING;

SHOW STAGES LIKE 'STG_BANKING_CSV'
    IN SCHEMA RAW.BANKING;