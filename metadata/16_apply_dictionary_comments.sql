/*==============================================================================
  AVIDIA BANKING DATA GOVERNANCE

  File:
      metadata/16_apply_dictionary_comments.sql

  Purpose:
      Execute the metadata-driven dictionary comment procedure and then
      refresh the custom governance metadata catalog so the newly applied
      native Snowflake comments are reflected in OBJECT_CATALOG and
      COLUMN_CATALOG.

  Prerequisites:
      - GOVERNANCE.CATALOG.DATA_DICTIONARY has been loaded and validated.
      - GOVERNANCE.CATALOG.APPLY_DICTIONARY_COMMENTS() already exists.
      - RAW.BANKING tables are owned by DATA_ENGINEER.
      - DATA_ENGINEER has SELECT access to GOVERNANCE.CATALOG.DATA_DICTIONARY.
      - DATA_ENGINEER has USAGE on GOVERNANCE and GOVERNANCE.CATALOG.
      - DATA_ENGINEER has USAGE on WH_GOVERNANCE_XS.
      - DATA_GOVERNANCE_ADMIN can execute HARVEST_METADATA().

  Design:
      1. Run comment application as DATA_ENGINEER because RAW tables are
         owned by DATA_ENGINEER and the procedure executes as caller.
      2. Re-run metadata harvest as DATA_GOVERNANCE_ADMIN.
      3. The next validation file verifies native and harvested coverage.
==============================================================================*/


-- ============================================================================
-- 1. APPLY NATIVE SNOWFLAKE COMMENTS
-- ============================================================================

USE ROLE DATA_ENGINEER;

USE WAREHOUSE WH_GOVERNANCE_XS;


CALL GOVERNANCE.CATALOG.APPLY_DICTIONARY_COMMENTS();



-- ============================================================================
-- 2. REFRESH THE CUSTOM GOVERNANCE METADATA CATALOG
--
-- COMMENT ON TABLE / COMMENT ON COLUMN changes native Snowflake metadata.
-- Re-harvesting synchronizes those comments back into:
--
--      GOVERNANCE.CATALOG.OBJECT_CATALOG
--      GOVERNANCE.CATALOG.COLUMN_CATALOG
-- ============================================================================

USE ROLE DATA_GOVERNANCE_ADMIN;

USE WAREHOUSE WH_GOVERNANCE_XS;


CALL GOVERNANCE.CATALOG.HARVEST_METADATA();



-- ============================================================================
-- 3. QUICK EXECUTION CHECK
--
-- These are only quick checks.
-- Full coverage validation is performed in:
--      metadata/17_validate_description_coverage.sql
-- ============================================================================

SELECT

    COUNT(*) AS RAW_OBJECT_COUNT,

    COUNT_IF
    (
        OBJECT_COMMENT IS NOT NULL
        AND TRIM(OBJECT_COMMENT) <> ''
    )
        AS RAW_OBJECTS_WITH_COMMENTS

FROM GOVERNANCE.CATALOG.OBJECT_CATALOG

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING';


SELECT

    COUNT(*) AS RAW_COLUMN_COUNT,

    COUNT_IF
    (
        COMMENT IS NOT NULL
        AND TRIM(COMMENT) <> ''
    )
        AS RAW_COLUMNS_WITH_COMMENTS

FROM GOVERNANCE.CATALOG.COLUMN_CATALOG

WHERE DATABASE_NAME = 'RAW'
  AND SCHEMA_NAME   = 'BANKING';
