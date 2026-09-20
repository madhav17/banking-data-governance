/*==============================================================================
 AVIDIA BANK - BLOCK 2 CUSTOM CLASSIFIER

 Purpose:
   Create one custom classifier for synthetic Avidia account numbers.

 Actual generated format:
   data/generator/generate.py creates:
       six random digits || eight digit sequence

 Example:
   70154600000001

 Classifier:
   Semantic category : AVIDIA_BANK_ACCOUNT_NUMBER
   Privacy category  : IDENTIFIER
   Value regex       : ^[0-9]{14}$
   Column-name regex : .*ACCOUNT.*NUMBER.*

 Why:
   Card/PAN-like values are 16 digits formatted as ####-####-####-####.
   The account-number classifier is restricted to ACCOUNT_NUMBER-like column
   names to avoid broad numeric false positives.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA CATALOG;

CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CUSTOM_CLASSIFIER
    GOVERNANCE.CATALOG.AVIDIA_ACCOUNT_NUMBER_CLASSIFIER();

CALL GOVERNANCE.CATALOG.AVIDIA_ACCOUNT_NUMBER_CLASSIFIER!ADD_REGEX(
    SEMANTIC_CATEGORY => 'AVIDIA_BANK_ACCOUNT_NUMBER',
    PRIVACY_CATEGORY => 'IDENTIFIER',
    VALUE_REGEX => '^[0-9]{14}$',
    COL_NAME_REGEX => '.*ACCOUNT.*NUMBER.*',
    DESCRIPTION => 'Synthetic Avidia account number: six random digits followed by an eight digit sequence.',
    THRESHOLD => 0.8
);

CALL GOVERNANCE.CATALOG.STAGING_CLASSIFICATION_PROFILE!SET_CUSTOM_CLASSIFIERS(
    {
        'avida_account_number':
            GOVERNANCE.CATALOG.AVIDIA_ACCOUNT_NUMBER_CLASSIFIER!LIST()
    }
);

SELECT
    GOVERNANCE.CATALOG.AVIDIA_ACCOUNT_NUMBER_CLASSIFIER!LIST()
        AS CUSTOM_CLASSIFIER_CONFIGURATION;

SELECT
    GOVERNANCE.CATALOG.STAGING_CLASSIFICATION_PROFILE!DESCRIBE()
        AS CLASSIFICATION_PROFILE_CONFIGURATION;
