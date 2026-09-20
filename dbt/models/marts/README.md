# MART Design Notes

This folder contains the three business-oriented MART models for the Avidia Bank
take-home project:

- `CUSTOMER_360`: one row per `CUSTOMER_ID`
- `DEPOSITS_DAILY`: one row per `ACCOUNT_ID` and `BUSINESS_DATE`
- `LOAN_PORTFOLIO`: one row per `LOAN_ID`

All three models use dbt incremental materialization with
`incremental_strategy='insert_overwrite'`. The model queries intentionally return
the complete desired dataset on every run. They do not use `is_incremental()`
filters, manual deletes, or manual truncates.

`DEPOSITS_DAILY` is the future primary certified data product. The synthetic
dataset is small, so no Snowflake clustering is configured yet. In a production
volume scenario, clustering on `BUSINESS_DATE`, `BRANCH_ID`, or both could be
evaluated using query history and table size evidence.
