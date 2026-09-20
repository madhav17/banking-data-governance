# Block 3 - Trust / Data Quality

This block implements the six required data-quality checks for the selected certified MART candidate:

```text
ANALYTICS.MARTS.DEPOSITS_DAILY
```

The implementation intentionally does not create a DQ rule registry or generic configuration framework. The rule definitions are code-driven through Snowflake Data Metric Function associations and expectations.

## Architecture

```text
ANALYTICS.MARTS.DEPOSITS_DAILY
  -> Snowflake Data Metric Functions
  -> expectations where VALUE = 0
  -> native Snowflake DQ result persistence
  -> GOVERNANCE.DQ.DQ_RESULT
  -> CERTIFY(object), scorecard and Streamlit catalog
```

`GOVERNANCE.DQ.DQ_RESULT` is the only persistent project-level DQ result table for this block.

## Why DEPOSITS_DAILY

`DEPOSITS_DAILY` is the strongest DQ target because its grain and source context naturally support the required checks.

Business grain:

```text
ACCOUNT_ID + BUSINESS_DATE
```

This grain allows the project to prove:

- one CDE completeness check;
- one business-key uniqueness check;
- one status-code validity check;
- one account/customer relationship consistency check;
- one upstream-versus-mart latest-date timeliness check;
- one deposit balance to GL control total accuracy check.

## Six Checks

| Dimension | Expectation name | Metric | Passing result |
| --- | --- | --- | --- |
| Completeness | `COMPLETENESS_CDE_NOT_NULL` | `SNOWFLAKE.CORE.NULL_COUNT` on `ACCOUNT_ID` | `0` nulls |
| Uniqueness | `UNIQUENESS_BUSINESS_KEY` | `SNOWFLAKE.CORE.DUPLICATE_COUNT` on `ACCOUNT_ID, BUSINESS_DATE` | `0` duplicate keys |
| Validity | `VALIDITY_ACCOUNT_STATUS` | `SNOWFLAKE.CORE.ACCEPTED_VALUES` on `ACCOUNT_STATUS` | `0` invalid statuses |
| Consistency | `CONSISTENCY_ACCOUNT_CUSTOMER` | `SNOWFLAKE.CORE.REFERENTIAL_INTEGRITY_COUNT` from MART customer to staging customer | `0` orphan relationships |
| Timeliness | `TIMELINESS_LATEST_BUSINESS_DATE` | `GOVERNANCE.DQ.DMF_LATEST_BUSINESS_DATE_MATCH` | `0` mismatch |
| Accuracy | `ACCURACY_GL_RECONCILIATION` | `GOVERNANCE.DQ.DMF_GL_DEPOSIT_RECONCILIATION` | `0` business-date reconciliation failures |

All checks return a numeric violation count where `0 = PASS`.

## Custom DMFs

Two custom Data Metric Functions are required because the system DMFs do not express the banking-specific logic exactly.

### `GOVERNANCE.DQ.DMF_LATEST_BUSINESS_DATE_MATCH`

Compares the latest `BUSINESS_DATE` in `ANALYTICS.MARTS.DEPOSITS_DAILY` with the latest upstream account daily balance date. It returns:

- `0` when the dates match;
- `1` when they differ.

This avoids a weak freshness check such as `CURRENT_DATE - MAX(BUSINESS_DATE)`.

### `GOVERNANCE.DQ.DMF_GL_DEPOSIT_RECONCILIATION`

Aggregates MART deposit balances by business date and compares them with the authoritative GL deposit control total. It returns the number of business dates where:

```text
ABS(MART_DEPOSIT_TOTAL - GL_CONTROL_TOTAL) > 1
```

Missing dates on either side are treated as failures.

## Files

```text
dq/
├── 00_permissions.sql
├── 01_create_dq_result.sql
├── 02_create_custom_dmfs.sql
├── 03_attach_dq_checks.sql
├── 04_run_and_persist_dq.sql
├── 05_validate_dq_results.sql
├── execution_order.txt
└── README.md
```

## Execution Order

Run from the repository root:

```sh
snow sql -c avidia -f dq/00_permissions.sql
snow sql -c avidia -f dq/01_create_dq_result.sql
snow sql -c avidia -f dq/02_create_custom_dmfs.sql
snow sql -c avidia -f dq/03_attach_dq_checks.sql
snow sql -c avidia -f dq/04_run_and_persist_dq.sql
snow sql -c avidia -f dq/05_validate_dq_results.sql
```

## Permission Model

The block reuses existing project roles:

- `DATA_GOVERNANCE_ADMIN` creates governance DQ objects and writes `DQ_RESULT`.
- `SVC_PIPELINE_ROLE` owns or controls the MART object for DMF association where required.

The runtime/pipeline role is not `ACCOUNTADMIN`.

## Result Table

`GOVERNANCE.DQ.DQ_RESULT` stores historical execution results. Each run should produce exactly six rows for `ANALYTICS.MARTS.DEPOSITS_DAILY`.

Important fields include:

- `RUN_ID`
- `CHECK_NAME`
- `QUALITY_DIMENSION`
- `OBJECT_FQN`
- `METRIC_NAME`
- `METRIC_VALUE`
- `THRESHOLD_VALUE`
- `STATUS`
- `MEASURED_AT`
- `RECORDED_AT`

`STATUS` is `PASS` when the expectation is not violated and `FAIL` when the expectation is violated.

## Expected Healthy Output

`dq/05_validate_dq_results.sql` should show:

```text
TOTAL_CHECKS   = 6
PASSED_CHECKS  = 6
FAILED_CHECKS  = 0
OVERALL_STATUS = PASS
```

It should also show each required dimension:

```text
COMPLETENESS
UNIQUENESS
VALIDITY
CONSISTENCY
TIMELINESS
ACCURACY
```

## Downstream Consumers

The DQ results are reused by:

- `GOVERNANCE.EVIDENCE.CERTIFY(object)` for certification gating;
- `GOVERNANCE.CATALOG.CATALOG_SCORECARD` for `TRUSTED` and `RECONCILED`;
- `GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG` for catalog quality status.
