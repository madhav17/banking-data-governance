# Block 4 - Lineage

This block implements lineage evidence for the certified data product:

```text
ANALYTICS.MARTS.DEPOSITS_DAILY
```

The implementation uses Snowflake native lineage where available and a small fallback table for the two required external endpoints. It does not create Talend or Power BI resources.

## Scope

Lineage is focused on `DEPOSITS_DAILY`, not every MART.

Native internal chain:

```text
RAW.BANKING.ACCOUNT_DAILY_BALANCE
  -> ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
  -> ANALYTICS.MARTS.DEPOSITS_DAILY
```

Additional upstream sources for the MART include:

```text
RAW.BANKING.ACCOUNT  -> ANALYTICS.STAGING.STG_ACCOUNT
RAW.BANKING.CUSTOMER -> ANALYTICS.STAGING.STG_CUSTOMER
RAW.BANKING.PRODUCT  -> ANALYTICS.STAGING.STG_PRODUCT
RAW.BANKING.BRANCH   -> ANALYTICS.STAGING.STG_BRANCH
```

`CUSTOMER_360` and `LOAN_PORTFOLIO` are valid dbt MARTS, but the formal Block 4 lineage evidence, snapshots, external endpoint metadata and worked trace are built around the certified deposit data product.

## Primary Source

`SNOWFLAKE.CORE.GET_LINEAGE` is the primary lineage source.

Supporting evidence is included from:

- `SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES`
- `SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY`

Account Usage views can lag, so a temporary lack of rows in those views is treated as metadata latency, not a failure of native lineage.

## Snapshot Tables

### `GOVERNANCE.CATALOG.LINEAGE_EDGE`

Stores historical snapshots of native `GET_LINEAGE` output.

The table retains history and is populated by:

```text
GOVERNANCE.CATALOG.SNAPSHOT_DEPOSITS_DAILY_LINEAGE_TASK
```

The snapshot supports reproducible demos, impact analysis and scorecard evidence. It is not intended to replace Snowflake native lineage as the source of truth.

### `GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL`

Stores exactly two metadata-only external endpoint rows:

```text
LEGACY_TALEND_DEPOSIT_LOAD
  -> RAW.BANKING.ACCOUNT_DAILY_BALANCE

ANALYTICS.MARTS.DEPOSITS_DAILY
  -> POWER_BI_DEPOSITS_MODEL
```

Important:

- `LEGACY_TALEND_DEPOSIT_LOAD` is only a string identifier.
- `POWER_BI_DEPOSITS_MODEL` is only a string identifier.
- No Talend job, Power BI workspace, Power BI semantic model, REST API payload or mock BI schema is created.

## Worked Column Trace

The worked measure is:

```text
ANALYTICS.MARTS.DEPOSITS_DAILY.CLOSING_BALANCE
```

The intended trace is:

```text
RAW.BANKING.ACCOUNT_DAILY_BALANCE.CLOSING_BALANCE
  -> ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE.CLOSING_BALANCE
  -> ANALYTICS.MARTS.DEPOSITS_DAILY.CLOSING_BALANCE
```

If Snowflake cannot materialize a specific column edge in a trial account, the validation scripts leave the gap visible rather than inventing a lineage edge.

## Impact Analysis

`07_impact_analysis.sql` answers:

```text
If a source column changes, what is affected and who owns it?
```

The native portion uses `GET_LINEAGE` downstream from the RAW source column. The external consumer is shown separately from `LINEAGE_EDGE_EXTERNAL` so the output clearly distinguishes:

```text
NATIVE SNOWFLAKE LINEAGE:
RAW -> STAGING -> DEPOSITS_DAILY

EXTERNAL FALLBACK METADATA:
Talend endpoint -> RAW
DEPOSITS_DAILY -> Power BI endpoint
```

## Files

```text
lineage/
├── 00_permissions.sql
├── 01_create_lineage_tables.sql
├── 02_native_lineage_queries.sql
├── 03_seed_external_lineage_fallback.sql
├── 04_create_lineage_snapshot_task.sql
├── 05_run_lineage_snapshot.sql
├── 06_worked_column_trace.sql
├── 07_impact_analysis.sql
├── 08_validate_lineage.sql
├── 09_validations.sql
├── execution_order.txt
└── README.md
```

`09_validations.sql` is an additional validation helper. The core execution order ends at `08_validate_lineage.sql`.

## Execution Order

Run from the repository root:

```sh
snow sql -c avidia -f lineage/00_permissions.sql
snow sql -c avidia -f lineage/01_create_lineage_tables.sql
snow sql -c avidia -f lineage/02_native_lineage_queries.sql
snow sql -c avidia -f lineage/03_seed_external_lineage_fallback.sql
snow sql -c avidia -f lineage/04_create_lineage_snapshot_task.sql
snow sql -c avidia -f lineage/05_run_lineage_snapshot.sql
snow sql -c avidia -f lineage/06_worked_column_trace.sql
snow sql -c avidia -f lineage/07_impact_analysis.sql
snow sql -c avidia -f lineage/08_validate_lineage.sql
```

## Required Role

Run as the existing governance role:

```text
DATA_GOVERNANCE_ADMIN
```

using:

```text
WH_GOVERNANCE_XS
```

The permissions script grants the lineage visibility, Account Usage visibility and task privileges required for the block.

## Expected Evidence

The validation scripts prove:

- native upstream lineage exists for `DEPOSITS_DAILY`;
- table-level lineage can be queried;
- column-level lineage for `CLOSING_BALANCE` can be queried where Snowflake exposes it;
- `LINEAGE_EDGE` contains snapshots populated through a task;
- `LINEAGE_EDGE_EXTERNAL` contains exactly two rows;
- the Talend and Power BI endpoint labels are metadata strings only;
- impact analysis can attach owner/steward/certification context where governance metadata exists.
