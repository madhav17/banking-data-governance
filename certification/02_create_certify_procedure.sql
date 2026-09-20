/*==============================================================================
 AVIDIA BANK - CERTIFY PROCEDURE

 Purpose:
   Reuse existing governance evidence and certify a MART object only when all
   seven required Block 5 gates pass.
==============================================================================*/

USE ROLE DATA_GOVERNANCE_ADMIN;
USE WAREHOUSE WH_GOVERNANCE_XS;
USE DATABASE GOVERNANCE;
USE SCHEMA EVIDENCE;

CREATE OR REPLACE PROCEDURE GOVERNANCE.EVIDENCE.CERTIFY(OBJECT_FQN VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_INPUT_OBJECT_FQN VARCHAR DEFAULT UPPER(TRIM(:OBJECT_FQN));
    V_DATABASE_NAME VARCHAR;
    V_SCHEMA_NAME VARCHAR;
    V_OBJECT_NAME VARCHAR;
    V_OBJECT_DOMAIN VARCHAR DEFAULT 'TABLE';
    V_TABLE_TYPE VARCHAR;
    V_OBJECT_EXISTS NUMBER DEFAULT 0;

    V_RUN_ID VARCHAR DEFAULT UUID_STRING();
    V_REQUESTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP();
    V_CERTIFIED_AT TIMESTAMP_LTZ;
    V_OUTCOME VARCHAR DEFAULT 'REFUSED';
    V_FAILURE_REASONS VARCHAR DEFAULT '';

    V_OWNER_VALUE VARCHAR;
    V_STEWARD_VALUE VARCHAR;
    V_DOMAIN_VALUE VARCHAR;

    V_OWNER_CHECK BOOLEAN DEFAULT FALSE;
    V_STEWARD_CHECK BOOLEAN DEFAULT FALSE;
    V_DESCRIPTION_CHECK BOOLEAN DEFAULT FALSE;
    V_CDE_CHECK BOOLEAN DEFAULT FALSE;
    V_CLASSIFICATION_CHECK BOOLEAN DEFAULT FALSE;
    V_POLICY_CHECK BOOLEAN DEFAULT FALSE;
    V_DQ_CHECK BOOLEAN DEFAULT FALSE;

    V_TABLE_COMMENT_PRESENT NUMBER DEFAULT 0;
    V_TOTAL_COLUMNS NUMBER DEFAULT 0;
    V_DESCRIBED_COLUMNS NUMBER DEFAULT 0;
    V_DESCRIPTION_COVERAGE NUMBER(10,2) DEFAULT 0;

    V_REQUIRED_CDES NUMBER DEFAULT 0;
    V_MATCHED_CDES NUMBER DEFAULT 0;
    V_CLASSIFICATION_GAPS NUMBER DEFAULT 0;
    V_POLICY_GAPS NUMBER DEFAULT 0;

    V_DQ_TOTAL_CHECKS NUMBER DEFAULT 0;
    V_DQ_DIMENSIONS NUMBER DEFAULT 0;
    V_DQ_PASSED NUMBER DEFAULT 0;
    V_DQ_FAILED NUMBER DEFAULT 0;
    V_DQ_MISSING_DIMENSIONS NUMBER DEFAULT 6;

    V_TAG_SQL VARCHAR;
BEGIN
    /* Validate a simple three-part identifier before any dynamic SQL. */
    IF (V_INPUT_OBJECT_FQN IS NULL
        OR NOT REGEXP_LIKE(V_INPUT_OBJECT_FQN, '^[A-Z0-9_]+[.][A-Z0-9_]+[.][A-Z0-9_]+$')) THEN
        V_FAILURE_REASONS := 'Object must be a valid fully-qualified identifier.';
    ELSE
        V_DATABASE_NAME := SPLIT_PART(V_INPUT_OBJECT_FQN, '.', 1);
        V_SCHEMA_NAME := SPLIT_PART(V_INPUT_OBJECT_FQN, '.', 2);
        V_OBJECT_NAME := SPLIT_PART(V_INPUT_OBJECT_FQN, '.', 3);

        IF (V_DATABASE_NAME <> 'ANALYTICS' OR V_SCHEMA_NAME <> 'MARTS') THEN
            V_FAILURE_REASONS := 'Only ANALYTICS.MARTS objects can be certified.';
        ELSE
            SELECT
                COUNT(*),
                MAX(TABLE_TYPE)
            INTO
                :V_OBJECT_EXISTS,
                :V_TABLE_TYPE
            FROM ANALYTICS.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = :V_SCHEMA_NAME
              AND TABLE_NAME = :V_OBJECT_NAME
              AND TABLE_TYPE IN ('BASE TABLE', 'VIEW');

            IF (V_OBJECT_EXISTS = 0) THEN
                V_FAILURE_REASONS := 'Object does not exist or is not a table/view.';
            ELSE
                IF (V_TABLE_TYPE = 'VIEW') THEN
                    V_OBJECT_DOMAIN := 'VIEW';
                ELSE
                    V_OBJECT_DOMAIN := 'TABLE';
                END IF;

                /* Gate 1 and 2: owner and steward tags. */
                SELECT MAX(IFF(TAG_NAME = 'DATA_OWNER', TAG_VALUE, NULL))
                INTO :V_OWNER_VALUE
                FROM TABLE
                (
                    ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES
                    (
                        :V_INPUT_OBJECT_FQN,
                        :V_OBJECT_DOMAIN
                    )
                )
                WHERE TAG_DATABASE = 'GOVERNANCE'
                  AND TAG_SCHEMA = 'TAGS';

                SELECT MAX(IFF(TAG_NAME = 'DATA_STEWARD', TAG_VALUE, NULL))
                INTO :V_STEWARD_VALUE
                FROM TABLE
                (
                    ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES
                    (
                        :V_INPUT_OBJECT_FQN,
                        :V_OBJECT_DOMAIN
                    )
                )
                WHERE TAG_DATABASE = 'GOVERNANCE'
                  AND TAG_SCHEMA = 'TAGS';

                SELECT MAX(IFF(TAG_NAME = 'DOMAIN', TAG_VALUE, NULL))
                INTO :V_DOMAIN_VALUE
                FROM TABLE
                (
                    ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES
                    (
                        :V_INPUT_OBJECT_FQN,
                        :V_OBJECT_DOMAIN
                    )
                )
                WHERE TAG_DATABASE = 'GOVERNANCE'
                  AND TAG_SCHEMA = 'TAGS';

                V_OWNER_CHECK := COALESCE(TRIM(V_OWNER_VALUE), '') <> '';
                V_STEWARD_CHECK := COALESCE(TRIM(V_STEWARD_VALUE), '') <> '';

                /* Gate 3: table/view and every exposed column must be described. */
                SELECT COUNT_IF(COMMENT IS NOT NULL AND TRIM(COMMENT) <> '')
                INTO :V_TABLE_COMMENT_PRESENT
                FROM ANALYTICS.INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = :V_SCHEMA_NAME
                  AND TABLE_NAME = :V_OBJECT_NAME;

                SELECT
                    COUNT(*),
                    COUNT_IF(COMMENT IS NOT NULL AND TRIM(COMMENT) <> '')
                INTO
                    :V_TOTAL_COLUMNS,
                    :V_DESCRIBED_COLUMNS
                FROM ANALYTICS.INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :V_SCHEMA_NAME
                  AND TABLE_NAME = :V_OBJECT_NAME;

                V_DESCRIPTION_COVERAGE :=
                    IFF(V_TOTAL_COLUMNS = 0, 0,
                        ROUND(100.0 * V_DESCRIBED_COLUMNS / V_TOTAL_COLUMNS, 2));

                V_DESCRIPTION_CHECK :=
                    V_TABLE_COMMENT_PRESENT = 1
                    AND V_TOTAL_COLUMNS > 0
                    AND V_DESCRIBED_COLUMNS = V_TOTAL_COLUMNS;

                /* Gate 4: relevant CDEs from the existing registry must be tagged. */
                WITH TARGET_COLUMNS AS
                (
                    SELECT COLUMN_NAME
                    FROM ANALYTICS.INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = :V_SCHEMA_NAME
                      AND TABLE_NAME = :V_OBJECT_NAME
                ),
                REQUIRED_CDES AS
                (
                    SELECT DISTINCT
                        R.COLUMN_NAME,
                        R.CDE_TIER
                    FROM GOVERNANCE.CATALOG.CDE_REGISTRY R
                    INNER JOIN TARGET_COLUMNS C
                        ON C.COLUMN_NAME = R.COLUMN_NAME
                    WHERE R.ACTIVE_FLAG = TRUE
                      AND R.DATA_DOMAIN = :V_DOMAIN_VALUE
                ),
                ACTUAL_CDE_TAGS AS
                (
                    SELECT
                        COLUMN_NAME,
                        TAG_VALUE
                    FROM TABLE
                    (
                        ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
                        (
                            :V_INPUT_OBJECT_FQN,
                            :V_OBJECT_DOMAIN
                        )
                    )
                    WHERE TAG_DATABASE = 'GOVERNANCE'
                      AND TAG_SCHEMA = 'TAGS'
                      AND TAG_NAME = 'CDE'
                )
                SELECT
                    COUNT(*),
                    COUNT_IF(A.TAG_VALUE = R.CDE_TIER)
                INTO
                    :V_REQUIRED_CDES,
                    :V_MATCHED_CDES
                FROM REQUIRED_CDES R
                LEFT JOIN ACTUAL_CDE_TAGS A
                    ON A.COLUMN_NAME = R.COLUMN_NAME;

                V_CDE_CHECK :=
                    V_REQUIRED_CDES > 0
                    AND V_MATCHED_CDES = V_REQUIRED_CDES;

                /* Gate 5: steward-confirmed MART classification has no gaps. */
                WITH APPROVED_TARGETS AS
                (
                    SELECT
                        COLUMN_NAME,
                        TAG_VALUE
                    FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT
                    WHERE DATABASE_NAME = :V_DATABASE_NAME
                      AND SCHEMA_NAME = :V_SCHEMA_NAME
                      AND OBJECT_NAME = :V_OBJECT_NAME
                      AND TAG_NAME = 'CLASSIFICATION'
                      AND SOURCE_TYPE = 'CLASSIFICATION_REVIEW'
                      AND ACTIVE_FLAG = TRUE
                ),
                ACTUAL_TAGS AS
                (
                    SELECT
                        COLUMN_NAME,
                        TAG_VALUE
                    FROM TABLE
                    (
                        ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
                        (
                            :V_INPUT_OBJECT_FQN,
                            :V_OBJECT_DOMAIN
                        )
                    )
                    WHERE TAG_DATABASE = 'GOVERNANCE'
                      AND TAG_SCHEMA = 'TAGS'
                      AND TAG_NAME = 'CLASSIFICATION'
                )
                SELECT COUNT_IF(A.COLUMN_NAME IS NULL OR A.TAG_VALUE <> T.TAG_VALUE)
                INTO :V_CLASSIFICATION_GAPS
                FROM APPROVED_TARGETS T
                LEFT JOIN ACTUAL_TAGS A
                    ON A.COLUMN_NAME = T.COLUMN_NAME;

                V_CLASSIFICATION_CHECK := V_CLASSIFICATION_GAPS = 0;

                /* Gate 6: sensitive columns requiring policy have no active gaps. */
                WITH APPROVED_TARGETS AS
                (
                    SELECT
                        COLUMN_NAME,
                        TAG_VALUE
                    FROM GOVERNANCE.CATALOG.TAG_ASSIGNMENT
                    WHERE DATABASE_NAME = :V_DATABASE_NAME
                      AND SCHEMA_NAME = :V_SCHEMA_NAME
                      AND OBJECT_NAME = :V_OBJECT_NAME
                      AND TAG_NAME = 'CLASSIFICATION'
                      AND SOURCE_TYPE = 'CLASSIFICATION_REVIEW'
                      AND ACTIVE_FLAG = TRUE
                ),
                ACTUAL_TAGS AS
                (
                    SELECT
                        COLUMN_NAME,
                        TAG_VALUE
                    FROM TABLE
                    (
                        ANALYTICS.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS
                        (
                            :V_INPUT_OBJECT_FQN,
                            :V_OBJECT_DOMAIN
                        )
                    )
                    WHERE TAG_DATABASE = 'GOVERNANCE'
                      AND TAG_SCHEMA = 'TAGS'
                      AND TAG_NAME = 'CLASSIFICATION'
                ),
                POLICY_REFS AS
                (
                    SELECT
                        REF_COLUMN_NAME AS COLUMN_NAME,
                        POLICY_STATUS
                    FROM TABLE
                    (
                        ANALYTICS.INFORMATION_SCHEMA.POLICY_REFERENCES
                        (
                            REF_ENTITY_NAME => :V_INPUT_OBJECT_FQN,
                            REF_ENTITY_DOMAIN => :V_OBJECT_DOMAIN
                        )
                    )
                    WHERE TAG_DATABASE = 'GOVERNANCE'
                      AND TAG_SCHEMA = 'TAGS'
                      AND TAG_NAME = 'CLASSIFICATION'
                )
                SELECT COUNT_IF(
                    A.COLUMN_NAME IS NULL
                    OR P.COLUMN_NAME IS NULL
                    OR P.POLICY_STATUS <> 'ACTIVE'
                )
                INTO :V_POLICY_GAPS
                FROM APPROVED_TARGETS T
                LEFT JOIN ACTUAL_TAGS A
                    ON A.COLUMN_NAME = T.COLUMN_NAME
                LEFT JOIN POLICY_REFS P
                    ON P.COLUMN_NAME = T.COLUMN_NAME
                   AND P.POLICY_STATUS = 'ACTIVE';

                V_POLICY_CHECK := V_POLICY_GAPS = 0;

                /* Gate 7: latest DQ run must have six dimensions and all PASS. */
                WITH LATEST_DQ AS
                (
                    SELECT *
                    FROM GOVERNANCE.DQ.DQ_RESULT
                    WHERE OBJECT_FQN = :V_INPUT_OBJECT_FQN
                    QUALIFY DENSE_RANK() OVER
                    (
                        ORDER BY MEASURED_AT DESC, RUN_ID DESC
                    ) = 1
                ),
                REQUIRED_DIMENSIONS AS
                (
                    SELECT COLUMN1::VARCHAR AS QUALITY_DIMENSION
                    FROM VALUES
                        ('COMPLETENESS'),
                        ('UNIQUENESS'),
                        ('VALIDITY'),
                        ('CONSISTENCY'),
                        ('TIMELINESS'),
                        ('ACCURACY')
                )
                SELECT
                    COUNT(L.QUALITY_DIMENSION),
                    COUNT(DISTINCT L.QUALITY_DIMENSION),
                    COUNT_IF(L.STATUS = 'PASS'),
                    COUNT_IF(L.STATUS = 'FAIL'),
                    COUNT_IF(L.QUALITY_DIMENSION IS NULL)
                INTO
                    :V_DQ_TOTAL_CHECKS,
                    :V_DQ_DIMENSIONS,
                    :V_DQ_PASSED,
                    :V_DQ_FAILED,
                    :V_DQ_MISSING_DIMENSIONS
                FROM REQUIRED_DIMENSIONS R
                LEFT JOIN LATEST_DQ L
                    ON L.QUALITY_DIMENSION = R.QUALITY_DIMENSION;

                V_DQ_CHECK :=
                    V_DQ_TOTAL_CHECKS = 6
                    AND V_DQ_DIMENSIONS = 6
                    AND V_DQ_PASSED = 6
                    AND V_DQ_FAILED = 0
                    AND V_DQ_MISSING_DIMENSIONS = 0;

                /* Collect refusal reasons without raising a business exception. */
                IF (NOT V_OWNER_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS || 'Missing DATA_OWNER metadata. ';
                END IF;
                IF (NOT V_STEWARD_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS || 'Missing DATA_STEWARD metadata. ';
                END IF;
                IF (NOT V_DESCRIPTION_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS
                        || 'Description coverage is '
                        || V_DESCRIPTION_COVERAGE
                        || '%; certification requires 100%. ';
                END IF;
                IF (NOT V_CDE_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS
                        || 'CDE tagging incomplete: '
                        || V_MATCHED_CDES
                        || '/'
                        || V_REQUIRED_CDES
                        || ' relevant CDE tags match. ';
                END IF;
                IF (NOT V_CLASSIFICATION_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS
                        || 'Confirmed classification gaps exist: '
                        || V_CLASSIFICATION_GAPS
                        || '. ';
                END IF;
                IF (NOT V_POLICY_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS
                        || 'Policy coverage gaps exist: '
                        || V_POLICY_GAPS
                        || '. ';
                END IF;
                IF (NOT V_DQ_CHECK) THEN
                    V_FAILURE_REASONS := V_FAILURE_REASONS
                        || 'Six required DQ checks are not available or not all passing. ';
                END IF;

                IF (
                    V_OWNER_CHECK
                    AND V_STEWARD_CHECK
                    AND V_DESCRIPTION_CHECK
                    AND V_CDE_CHECK
                    AND V_CLASSIFICATION_CHECK
                    AND V_POLICY_CHECK
                    AND V_DQ_CHECK
                ) THEN
                    V_OUTCOME := 'CERTIFIED';
                    V_CERTIFIED_AT := CURRENT_TIMESTAMP();

                    V_TAG_SQL :=
                        'ALTER '
                        || IFF(V_OBJECT_DOMAIN = 'VIEW', 'VIEW ', 'TABLE ')
                        || V_INPUT_OBJECT_FQN
                        || ' SET TAG GOVERNANCE.TAGS.CERTIFICATION = ''CERTIFIED''';

                    EXECUTE IMMEDIATE :V_TAG_SQL;
                END IF;
            END IF;
        END IF;
    END IF;

    INSERT INTO GOVERNANCE.EVIDENCE.CERTIFICATION_LOG
    (
        CERTIFICATION_RUN_ID,
        OBJECT_FQN,
        REQUESTED_AT,
        REQUESTED_BY,
        OWNER_CHECK,
        STEWARD_CHECK,
        DESCRIPTION_CHECK,
        CDE_CHECK,
        CLASSIFICATION_CHECK,
        POLICY_CHECK,
        DQ_CHECK,
        OUTCOME,
        FAILURE_REASONS,
        CERTIFIED_AT
    )
    SELECT
        :V_RUN_ID,
        COALESCE(:V_INPUT_OBJECT_FQN, :OBJECT_FQN),
        :V_REQUESTED_AT,
        CURRENT_USER(),
        :V_OWNER_CHECK,
        :V_STEWARD_CHECK,
        :V_DESCRIPTION_CHECK,
        :V_CDE_CHECK,
        :V_CLASSIFICATION_CHECK,
        :V_POLICY_CHECK,
        :V_DQ_CHECK,
        :V_OUTCOME,
        NULLIF(TRIM(:V_FAILURE_REASONS), ''),
        :V_CERTIFIED_AT
    ;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL
    (
        'object', V_INPUT_OBJECT_FQN,
        'outcome', V_OUTCOME,
        'owner', IFF(V_OWNER_CHECK, 'PASS', 'FAIL'),
        'steward', IFF(V_STEWARD_CHECK, 'PASS', 'FAIL'),
        'description', IFF(V_DESCRIPTION_CHECK, 'PASS', 'FAIL'),
        'description_coverage_pct', V_DESCRIPTION_COVERAGE,
        'cde', IFF(V_CDE_CHECK, 'PASS', 'FAIL'),
        'cde_matched', V_MATCHED_CDES,
        'cde_required', V_REQUIRED_CDES,
        'classification', IFF(V_CLASSIFICATION_CHECK, 'PASS', 'FAIL'),
        'policy', IFF(V_POLICY_CHECK, 'PASS', 'FAIL'),
        'dq', IFF(V_DQ_CHECK, 'PASS', 'FAIL'),
        'dq_total_checks', V_DQ_TOTAL_CHECKS,
        'dq_passed_checks', V_DQ_PASSED,
        'reasons', IFF(TRIM(V_FAILURE_REASONS) = '', ARRAY_CONSTRUCT(), ARRAY_CONSTRUCT(TRIM(V_FAILURE_REASONS))),
        'certification_run_id', V_RUN_ID
    );
END;
$$;

GRANT USAGE ON PROCEDURE GOVERNANCE.EVIDENCE.CERTIFY(VARCHAR)
TO ROLE DATA_GOVERNANCE_ADMIN;

SHOW PROCEDURES LIKE 'CERTIFY' IN SCHEMA GOVERNANCE.EVIDENCE;
