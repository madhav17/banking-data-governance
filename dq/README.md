# Block 3 - Trust / Data Quality

This block implements the six required data-quality checks on one mart:

`ANALYTICS.MARTS.DEPOSITS_DAILY`

## Why DEPOSITS_DAILY

`DEPOSITS_DAILY` is the deposit data product with the business grain:

`ACCOUNT_ID + BUSINESS_DATE`

It naturally supports account/day uniqueness, customer relationship checks,
latest business-date checks, and GL deposit reconciliation.

## Checks

| Dimension | Check | DMF |
| --- | --- | --- |
| Completeness | `ACCOUNT_ID` CDE is not null | `SNOWFLAKE.CORE.NULL_COUNT` |
| Uniqueness | `ACCOUNT_ID + BUSINESS_DATE` has no duplicates | `SNOWFLAKE.CORE.DUPLICATE_COUNT` |
| Validity | `ACCOUNT_STATUS` is `ACTIVE`, `CLOSED`, or `DORMANT` | `SNOWFLAKE.CORE.ACCEPTED_VALUES` |
| Consistency | `CUSTOMER_ID` resolves to `STG_CUSTOMER` | `SNOWFLAKE.CORE.REFERENTIAL_INTEGRITY_COUNT` |
| Timeliness | latest mart date equals latest upstream balance date | `GOVERNANCE.DQ.DMF_LATEST_BUSINESS_DATE_MATCH` |
| Accuracy | mart closing balances tie to deposit GL totals within $1 | `GOVERNANCE.DQ.DMF_GL_DEPOSIT_RECONCILIATION` |

All six DMFs return a numeric violation count. `0` means the check passes.
Every association uses an expectation of `VALUE = 0`.

## Why DQ_RESULT Exists

Snowflake persists native DQ history when
`SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS_PERSIST_RESULT` runs. The project
also keeps `GOVERNANCE.DQ.DQ_RESULT` as a compact governed result table for
later certification, scorecards and Streamlit catalog evidence.

## Execution Order

```bash
snow sql -c avidia -f dq/00_permissions.sql
snow sql -c avidia -f dq/01_create_dq_result.sql
snow sql -c avidia -f dq/02_create_custom_dmfs.sql
snow sql -c avidia -f dq/03_attach_dq_checks.sql
snow sql -c avidia -f dq/04_run_and_persist_dq.sql
snow sql -c avidia -f dq/05_validate_dq_results.sql
```

## Required Roles

- `DATA_GOVERNANCE_ADMIN` creates custom DMFs and writes `DQ_RESULT`.
- `SVC_PIPELINE_ROLE` owns `ANALYTICS.MARTS.DEPOSITS_DAILY`, so it attaches
  the DMF associations to the mart.

## Expected Healthy Result

`dq/05_validate_dq_results.sql` should show:

- `TOTAL_CHECKS = 6`
- `PASSED_CHECKS = 6`
- `FAILED_CHECKS = 0`
- `OVERALL_STATUS = PASS`

## Later Certification

A future `CERTIFY(object)` procedure can read the latest six rows in
`GOVERNANCE.DQ.DQ_RESULT`. The mart should only become certified when all six
dimensions pass for the latest run.
