# Avidia Banking dbt Project

This directory contains the dbt project used for the Avidia Bank STAGING -> MARTS transformation.

The physical Snowflake flow is:

```text
ANALYTICS.STAGING
  -> dbt
  -> ANALYTICS.MARTS
```

The native Snowflake dbt Project deployment target is:

```text
ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT
```

## Project Contents

```text
dbt/
├── dbt_project.yml
├── profiles.yml
├── dbt_projects_profiles.yml
├── dbt_projects_profiles_backup.yml
├── packages.yml
├── requirements-ci.txt
├── .sqlfluff
├── .sqlfluffignore
├── models/
│   └── marts/
│       ├── _sources.yml
│       ├── schema.yml
│       ├── customer_360.sql
│       ├── deposits_daily.sql
│       ├── loan_portfolio.sql
│       └── README.md
├── tests/
│   └── assert_deposits_daily_unique_account_date.sql
├── analyses/
├── macros/
├── seeds/
└── snapshots/
```

The `analyses`, `macros`, `seeds` and `snapshots` folders are intentionally present for future dbt growth, but the current take-home MART implementation does not depend on custom macros, seeds or snapshots.

## MART Models

Exactly three business MART models are implemented:

| Model | Target object | Grain | Purpose |
| --- | --- | --- | --- |
| `customer_360` | `ANALYTICS.MARTS.CUSTOMER_360` | one row per `CUSTOMER_ID` | Customer profile with sensitive fields needed for masking/classification proof. |
| `deposits_daily` | `ANALYTICS.MARTS.DEPOSITS_DAILY` | one row per `ACCOUNT_ID + BUSINESS_DATE` | Primary certified data product, DQ target and GL reconciliation anchor. |
| `loan_portfolio` | `ANALYTICS.MARTS.LOAN_PORTFOLIO` | one row per `LOAN_ID` | Lending exposure and collateral/credit-grade data product. |

The MART source tables are declared in `models/marts/_sources.yml` and point to existing tables in `ANALYTICS.STAGING`. dbt does not create STAGING objects.

## Materialization Strategy

All three MART models use:

```sql
materialized = 'incremental'
incremental_strategy = 'insert_overwrite'
```

The model queries return the complete desired dataset on each run. There are no `is_incremental()` date filters, manual truncates or manual deletes. This gives full-refresh-like business behavior while preserving the Snowflake relation object for future tags, policies and governance evidence.

## Tests And Documentation

`models/marts/schema.yml` documents the models, important columns and basic engineering tests:

- `CUSTOMER_360.CUSTOMER_ID` is not null and unique.
- `DEPOSITS_DAILY.ACCOUNT_ID` and `BUSINESS_DATE` are not null.
- `LOAN_PORTFOLIO.LOAN_ID` is not null and unique.

`tests/assert_deposits_daily_unique_account_date.sql` checks the composite grain of `DEPOSITS_DAILY` without requiring an external package such as `dbt-utils`.

## Local Environment Variables

The dbt profiles use environment variables. Do not commit credentials.

Required for local dbt Core execution:

```sh
export DBT_SNOWFLAKE_ACCOUNT="<account_identifier>"
export DBT_SNOWFLAKE_USER="<user_or_service_user>"
export DBT_SNOWFLAKE_PRIVATE_KEY_PATH="<path_to_private_key_file>"
export DBT_SNOWFLAKE_ROLE="<role>"
export DBT_SNOWFLAKE_WAREHOUSE="<warehouse>"
export DBT_SNOWFLAKE_DATABASE="ANALYTICS"
export DBT_TARGET="dev"
```

Optional:

```sh
export DBT_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE="<optional_passphrase>"
export DBT_DEV_SCHEMA="MARTS_DEV"
export DBT_CI_SCHEMA="MARTS_CI"
export DBT_PROD_SCHEMA="MARTS"
export DBT_THREADS="4"
export ANALYTICS_DATABASE="ANALYTICS"
export STAGING_SCHEMA="STAGING"
export MARTS_SCHEMA="MARTS"
```

## Local Validation

From the repository root:

```sh
dbt --project-dir dbt --profiles-dir dbt deps
dbt --project-dir dbt --profiles-dir dbt debug
dbt --project-dir dbt --profiles-dir dbt parse
dbt --project-dir dbt --profiles-dir dbt compile --target dev
dbt --project-dir dbt --profiles-dir dbt build --target dev
```

SQLFluff:

```sh
cd dbt
sqlfluff lint .
```

## GitHub Actions dbt CI

The CI workflow is:

```text
.github/workflows/dbt_ci.yml
```

It is manual-only:

```yaml
on:
  workflow_dispatch:
```

The workflow:

1. checks out the repository;
2. installs dbt, SQLFluff and Snowflake CLI;
3. writes the service-user private key to a temporary runner file;
4. validates SQLFluff;
5. runs `dbt deps`, `dbt parse` and `dbt compile --target ci`;
6. creates a unique Snowflake zero-copy clone database;
7. runs `dbt build --target ci` against the clone;
8. drops the clone in an `always()` cleanup step.

The workflow does not deploy to production and does not execute the native Snowflake dbt Project.

## GitHub Actions dbt Deploy

The deployment workflow is:

```text
.github/workflows/dbt_deploy.yml
```

It is also manual-only. It deploys the current selected branch as:

```text
ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT
```

The workflow uses:

```text
role:      SVC_PIPELINE_ROLE
warehouse: WH_GOVERNANCE_XS
database:  ANALYTICS
schema:    DBT_PROJECTS
target:    prod
```

It runs `snow dbt deploy` with `--auto-compile`, then verifies the deployed project with `snow dbt describe`. It does not run `EXECUTE DBT PROJECT` and does not create a Snowflake Task.

## Required GitHub Secrets And Variables

Secrets:

```text
SNOWFLAKE_USER
SNOWFLAKE_PRIVATE_KEY
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE   # optional
```

Variables used by CI:

```text
SNOWFLAKE_ACCOUNT
SNOWFLAKE_ROLE
SNOWFLAKE_WAREHOUSE
SNOWFLAKE_BASE_DATABASE
SNOWFLAKE_CI_DB_PREFIX
DBT_CI_SCHEMA
DBT_THREADS
```

## Native Snowflake dbt Project Commands

Verify connection:

```sh
snow connection test -c avidia_pipeline
```

Deploy:

```sh
snow dbt deploy AVIDIA_BANK_DBT \
  --source dbt \
  --profiles-dir dbt \
  --default-target prod \
  --auto-compile \
  -c avidia_pipeline \
  --database ANALYTICS \
  --schema DBT_PROJECTS \
  --role SVC_PIPELINE_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Verify:

```sh
snow dbt list -c avidia_pipeline --database ANALYTICS --schema DBT_PROJECTS
snow dbt describe AVIDIA_BANK_DBT -c avidia_pipeline --database ANALYTICS --schema DBT_PROJECTS
```

Execute later, when you intentionally want Snowflake to run the deployed project:

```sql
EXECUTE DBT PROJECT ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT;
```

Execution is intentionally separate from deployment so CI/CD can validate and publish code without unexpectedly refreshing production MART data.
