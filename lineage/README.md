# Block 4 - Lineage

`ANALYTICS.MARTS.DEPOSITS_DAILY` is the lineage anchor because it is the
deposit mart selected for DQ and future certification.

## Native Scope

Native Snowflake lineage covers the internal chain:

```text
RAW.BANKING.ACCOUNT_DAILY_BALANCE
  -> ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
  -> ANALYTICS.MARTS.DEPOSITS_DAILY
```

`DEPOSITS_DAILY` also uses:

```text
RAW.BANKING.ACCOUNT  -> ANALYTICS.STAGING.STG_ACCOUNT
RAW.BANKING.CUSTOMER -> ANALYTICS.STAGING.STG_CUSTOMER
RAW.BANKING.PRODUCT  -> ANALYTICS.STAGING.STG_PRODUCT
RAW.BANKING.BRANCH   -> ANALYTICS.STAGING.STG_BRANCH
```

## Primary Lineage Source

`SNOWFLAKE.CORE.GET_LINEAGE` is the source of truth for native lineage.
`OBJECT_DEPENDENCIES` and `ACCESS_HISTORY` are supporting evidence because
Account Usage can lag and object dependencies do not fully describe data-copy
lineage.

## Snapshot Table

`GOVERNANCE.CATALOG.LINEAGE_EDGE` stores historical snapshots of native
`GET_LINEAGE` output. The snapshot is evidence for review and scorecards; it
is not the lineage source of truth.

The task `GOVERNANCE.CATALOG.SNAPSHOT_DEPOSITS_DAILY_LINEAGE_TASK` refreshes
the snapshot daily and can be run manually for the live demo.

## Worked Column Trace

The deposit measure is:

```text
ANALYTICS.MARTS.DEPOSITS_DAILY.CLOSING_BALANCE
```

Native column lineage traces it back to:

```text
ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE.CLOSING_BALANCE
RAW.BANKING.ACCOUNT_DAILY_BALANCE.CLOSING_BALANCE
```

## External Fallback

We do not create, deploy, configure, or simulate Talend, Power BI, or the
External Lineage API for this take-home. Instead, the approved fallback table
`GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL` contains exactly two metadata-only
endpoint rows:

```text
LEGACY_TALEND_DEPOSIT_LOAD
  -> RAW.BANKING.ACCOUNT_DAILY_BALANCE

ANALYTICS.MARTS.DEPOSITS_DAILY
  -> POWER_BI_DEPOSITS_MODEL
```

`LEGACY_TALEND_DEPOSIT_LOAD` and `POWER_BI_DEPOSITS_MODEL` are string
identifiers only. They are not Snowflake objects and no Talend or Power BI
resource is created by this implementation.

## Execution Order

```bash
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

Run as `DATA_GOVERNANCE_ADMIN` using `WH_GOVERNANCE_XS`.

## Known Latency

`SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES` and
`SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY` can lag. Lack of immediate rows in
those views is documented as evidence latency, not failure of native
`GET_LINEAGE`.
