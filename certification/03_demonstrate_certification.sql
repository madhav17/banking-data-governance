/*==============================================================================
 AVIDIA BANK - DEMONSTRATE CERTIFICATION

 Purpose:
   Demonstrate one CERTIFIED and one REFUSED outcome.

 Notes:
   DEPOSITS_DAILY already has owner/steward, classification, policy and DQ
   evidence. This script prepares the missing current-state MART comments and
   CDE tags so CERTIFY can validate real evidence rather than hardcoded PASS.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;

/* ---------------------------------------------------------------------------
   Prepare real description evidence for the success candidate.
--------------------------------------------------------------------------- */
COMMENT ON TABLE ANALYTICS.MARTS.DEPOSITS_DAILY IS
    'Certified-candidate daily deposit account mart at one row per account and business date.';

COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_ID IS 'Account business key and first component of the DEPOSITS_DAILY grain.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.BUSINESS_DATE IS 'Balance business date and second component of the DEPOSITS_DAILY grain.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_NUMBER IS 'Customer-facing banking account number retained for masking and classification evidence.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.CUSTOMER_ID IS 'Customer associated with the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.CUSTOMER_TYPE IS 'Customer type associated with the account owner.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.CUSTOMER_DISPLAY_NAME IS 'Business or person display name for the account owner.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.CUSTOMER_STATUS IS 'Lifecycle status of the customer associated with the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.PRODUCT_ID IS 'Banking product identifier linked to the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.PRODUCT_CODE IS 'Banking product code linked to the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.PRODUCT_NAME IS 'Banking product name linked to the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.PRODUCT_TYPE IS 'Banking product type from the product reference table.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.BRANCH_ID IS 'Branch identifier associated with the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.BRANCH_CODE IS 'Branch code associated with the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.BRANCH_NAME IS 'Branch name associated with the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.BRANCH_REGION IS 'Branch region associated with the account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_OPEN_DATE IS 'Date the account was opened.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_CLOSE_DATE IS 'Date the account was closed, when applicable.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_STATUS IS 'Current lifecycle status of the deposit account.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_TYPE IS 'Deposit account type from the source account record.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.CURRENCY IS 'Currency used for the account balance amounts.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.OPENING_BALANCE IS 'Opening account balance for the business date.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.CLOSING_BALANCE IS 'Closing account balance for the business date.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.AVAILABLE_BALANCE IS 'Available account balance for the business date.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.ACCOUNT_CURRENT_BALANCE IS 'Current account balance from the latest source account record.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.SOURCE_SYSTEM IS 'Source system supplied by the daily balance feed.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.LOAD_TIMESTAMP IS 'Timestamp from the source daily balance load.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.STG_LOADED_AT IS 'Timestamp when the staging record was loaded.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.STG_UPDATED_AT IS 'Timestamp when the staging record was last updated.';
COMMENT ON COLUMN ANALYTICS.MARTS.DEPOSITS_DAILY.IS_ACTIVE_ACCOUNT IS 'Boolean flag indicating whether ACCOUNT_STATUS is ACTIVE.';

/* ---------------------------------------------------------------------------
   Prepare real CDE tag evidence from the existing CDE_REGISTRY mappings.
--------------------------------------------------------------------------- */
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN ACCOUNT_ID SET TAG GOVERNANCE.TAGS.CDE = 'TIER_1';
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN ACCOUNT_NUMBER SET TAG GOVERNANCE.TAGS.CDE = 'TIER_1';
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN CUSTOMER_ID SET TAG GOVERNANCE.TAGS.CDE = 'TIER_1';
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN BRANCH_ID SET TAG GOVERNANCE.TAGS.CDE = 'TIER_2';
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN ACCOUNT_STATUS SET TAG GOVERNANCE.TAGS.CDE = 'TIER_2';
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN BUSINESS_DATE SET TAG GOVERNANCE.TAGS.CDE = 'TIER_1';
ALTER TABLE ANALYTICS.MARTS.DEPOSITS_DAILY
    MODIFY COLUMN CLOSING_BALANCE SET TAG GOVERNANCE.TAGS.CDE = 'TIER_1';

/* ---------------------------------------------------------------------------
   SUCCESS CASE
--------------------------------------------------------------------------- */
CALL GOVERNANCE.EVIDENCE.CERTIFY('ANALYTICS.MARTS.DEPOSITS_DAILY');

SELECT
    TAG_NAME,
    TAG_VALUE,
    LEVEL,
    APPLY_METHOD
FROM TABLE
(
    ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES
    (
        'ANALYTICS.MARTS.DEPOSITS_DAILY',
        'TABLE'
    )
)
WHERE TAG_DATABASE = 'GOVERNANCE'
  AND TAG_SCHEMA = 'TAGS'
  AND TAG_NAME = 'CERTIFICATION';

SELECT *
FROM GOVERNANCE.EVIDENCE.CERTIFICATION_LOG
WHERE OBJECT_FQN = 'ANALYTICS.MARTS.DEPOSITS_DAILY'
QUALIFY ROW_NUMBER() OVER
(
    ORDER BY REQUESTED_AT DESC, CERTIFICATION_RUN_ID DESC
) = 1;

/* ---------------------------------------------------------------------------
   REFUSAL CASE
   CUSTOMER_360 naturally lacks DQ evidence, so it should be refused.
--------------------------------------------------------------------------- */
CALL GOVERNANCE.EVIDENCE.CERTIFY('ANALYTICS.MARTS.CUSTOMER_360');

SELECT *
FROM GOVERNANCE.EVIDENCE.CERTIFICATION_LOG
WHERE OBJECT_FQN = 'ANALYTICS.MARTS.CUSTOMER_360'
QUALIFY ROW_NUMBER() OVER
(
    ORDER BY REQUESTED_AT DESC, CERTIFICATION_RUN_ID DESC
) = 1;
