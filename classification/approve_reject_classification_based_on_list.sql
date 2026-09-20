-- ============================================================
-- REJECT FALSE POSITIVES
-- These columns were detected by Snowflake classification,
-- but are NOT present in the sealed sensitive list.
-- ============================================================

CALL GOVERNANCE.CATALOG.REJECT_CLASSIFICATION(
    1,
    'Rejected: STG_CUSTOMER.ADDRESS_LINE1 is not present in the sealed sensitive list.'
);

CALL GOVERNANCE.CATALOG.REJECT_CLASSIFICATION(
    2,
    'Rejected: STG_CUSTOMER.COUNTRY is not present in the sealed sensitive list.'
);

CALL GOVERNANCE.CATALOG.REJECT_CLASSIFICATION(
    5,
    'Rejected: STG_CUSTOMER.FIRST_NAME is not present in the sealed sensitive list.'
);

CALL GOVERNANCE.CATALOG.REJECT_CLASSIFICATION(
    6,
    'Rejected: STG_CUSTOMER.LAST_NAME is not present in the sealed sensitive list.'
);


-- ============================================================
-- APPROVE TRUE POSITIVES
-- These columns exist in the sealed sensitive list.
-- ============================================================

CALL GOVERNANCE.CATALOG.APPROVE_CLASSIFICATION(
    3,
    'CONFIDENTIAL',
    'Approved: STG_CUSTOMER.DATE_OF_BIRTH matches the sealed sensitive list.'
);

CALL GOVERNANCE.CATALOG.APPROVE_CLASSIFICATION(
    4,
    'RESTRICTED',
    'Approved: STG_CUSTOMER.EMAIL matches the sealed sensitive list.'
);

CALL GOVERNANCE.CATALOG.APPROVE_CLASSIFICATION(
    7,
    'RESTRICTED',
    'Approved: STG_CUSTOMER.NOTES contains expected sensitive EMAIL content. This is a deliberately mislabeled sensitive column.'
);

CALL GOVERNANCE.CATALOG.APPROVE_CLASSIFICATION(
    8,
    'RESTRICTED',
    'Approved: STG_CUSTOMER.TAX_ID matches the sealed sensitive list despite LOW classification confidence.'
);

CALL GOVERNANCE.CATALOG.APPROVE_CLASSIFICATION(
    9,
    'RESTRICTED',
    'Approved: STG_ACCOUNT.ACCOUNT_NUMBER matches the sealed sensitive list.'
);