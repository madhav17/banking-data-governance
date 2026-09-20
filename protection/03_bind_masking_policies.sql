/*==============================================================================
 AVIDIA BANK - BIND MASKING POLICIES TO GOVERNANCE CLASSIFICATION TAG

 Purpose:
   Attach masking policies to GOVERNANCE.TAGS.CLASSIFICATION using Snowflake
   tag-based masking.

 Important:
   ALTER TAG requires the tag owner plus APPLY MASKING POLICY. The tag was
   created by metadata/02_create_tag_taxonomy.sql under SYSADMIN, so this script
   intentionally uses SYSADMIN and does not transfer ownership.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;

SHOW TAGS LIKE 'CLASSIFICATION' IN SCHEMA GOVERNANCE.TAGS;

ALTER TAG GOVERNANCE.TAGS.CLASSIFICATION SET
    MASKING POLICY GOVERNANCE.CATALOG.CLASSIFICATION_STRING_MASK,
    MASKING POLICY GOVERNANCE.CATALOG.CLASSIFICATION_DATE_MASK
    FORCE;

SELECT
    POLICY_DB,
    POLICY_SCHEMA,
    POLICY_NAME,
    POLICY_KIND,
    TAG_DATABASE,
    TAG_SCHEMA,
    TAG_NAME,
    POLICY_STATUS
FROM TABLE
(
    GOVERNANCE.INFORMATION_SCHEMA.POLICY_REFERENCES
    (
        REF_ENTITY_NAME => 'GOVERNANCE.TAGS.CLASSIFICATION',
        REF_ENTITY_DOMAIN => 'TAG'
    )
)
ORDER BY POLICY_NAME;
