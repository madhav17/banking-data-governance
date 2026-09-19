# Avidia Banking dbt Skeleton

This directory is the initial dbt project shell for future STAGING to MARTS transformations.
It intentionally contains no Avidia business mart logic yet.

## What Exists Now

- `dbt_project.yml` defines the dbt project and model paths.
- `profiles.yml` is for dbt Core and future GitHub Actions execution.
- `dbt_projects_profiles.yml` is the Snowflake dbt Project profile template.
- Empty folders are reserved with `.gitkeep` for future staging, intermediate, marts, tests, macros, seeds, and snapshots.

## Local Validation Commands

Run from the repository root after installing `dbt-snowflake`:

```sh
dbt --project-dir dbt --profiles-dir dbt debug
dbt --project-dir dbt --profiles-dir dbt parse
```

Optional SQLFluff check:

```sh
sqlfluff lint dbt/models
```

## Required Environment Variables

Set these before running dbt locally or in CI:

```sh
export DBT_SNOWFLAKE_ACCOUNT="<account_identifier>"
export DBT_SNOWFLAKE_USER="<pipeline_or_developer_user>"
export DBT_SNOWFLAKE_PRIVATE_KEY_PATH="<path_to_private_key_file>"
export DBT_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE="<optional_key_passphrase>"
export DBT_SNOWFLAKE_ROLE="<PIPELINE_ROLE>"
export DBT_SNOWFLAKE_WAREHOUSE="<WAREHOUSE>"
export DBT_SNOWFLAKE_DATABASE="<ANALYTICS_DATABASE>"
export DBT_TARGET="dev"
```

Optional schema overrides:

```sh
export DBT_DEV_SCHEMA="MARTS_DEV"
export DBT_CI_SCHEMA="MARTS_CI"
export DBT_PROD_SCHEMA="MARTS"
export DBT_THREADS="4"
```

Conceptual future source values:

```sh
export ANALYTICS_DATABASE="<ANALYTICS_DATABASE>"
export STAGING_SCHEMA="STAGING"
export MARTS_SCHEMA="MARTS"
```

Do not commit real credentials.

## GitHub Actions CI

The CI workflow lives at `.github/workflows/dbt_ci.yml`.

It is intentionally manual-only for now:

- `workflow_dispatch`
- no production deployment
- no Snowflake Tasks
- no dbt Project deployment

The workflow validates dbt against a temporary Snowflake zero-copy clone:

1. checkout
2. install Python, dbt, SQLFluff, and Snowflake CLI
3. write the private key from GitHub Secrets to a temporary runner file
4. create a unique CI database name from `SNOWFLAKE_CI_DB_PREFIX` and `GITHUB_RUN_ID`
5. run SQLFluff
6. run `dbt deps`
7. run `dbt parse`
8. run `dbt compile --target ci`
9. create a zero-copy clone of `SNOWFLAKE_BASE_DATABASE`
10. run `dbt build --target ci`
11. drop the CI clone with an `always()` cleanup step

### GitHub Secrets

Store sensitive values as repository or environment secrets:

```text
SNOWFLAKE_USER
SNOWFLAKE_PRIVATE_KEY
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
```

`SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` may be empty if the private key is not encrypted.

### GitHub Variables

Store non-secret CI configuration as repository or environment variables:

```text
SNOWFLAKE_ACCOUNT
SNOWFLAKE_ROLE
SNOWFLAKE_WAREHOUSE
SNOWFLAKE_BASE_DATABASE
SNOWFLAKE_CI_DB_PREFIX
DBT_CI_SCHEMA
DBT_THREADS
```

Use uppercase Snowflake identifiers for:

```text
SNOWFLAKE_BASE_DATABASE
SNOWFLAKE_CI_DB_PREFIX
DBT_CI_SCHEMA
```

### Snowflake Service Role Requirements

The workflow must run with a service user such as `SVC_PIPELINE`, using key-pair authentication.
Do not use `ACCOUNTADMIN`.

The service role needs:

```sql
GRANT USAGE ON WAREHOUSE <WAREHOUSE> TO ROLE <PIPELINE_ROLE>;
GRANT USAGE ON DATABASE <ANALYTICS_DATABASE> TO ROLE <PIPELINE_ROLE>;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE <PIPELINE_ROLE>;
```

It also needs sufficient privileges to clone/read objects from the base analytics database and
to create dbt objects in the cloned CI database/schema. The CI clone is owned by the pipeline role,
so the same role can drop it during cleanup.
