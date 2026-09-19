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

## Native Snowflake dbt Project Deployment

This section deploys the dbt code to a native Snowflake DBT PROJECT object. It does not schedule the project or automatically update MARTS data.

The deployed object location is:

```text
ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT
```

The dbt production target writes models to:

```text
ANALYTICS.MARTS
```

`ANALYTICS.STAGING` remains the source layer, and `ANALYTICS.DBT_PROJECTS` stores Snowflake DBT PROJECT objects only.

### GitHub Actions Deployment

The deployment workflow lives at:

```text
.github/workflows/dbt_deploy.yml
```

It is manual-only:

```yaml
on:
  workflow_dispatch:
```

The workflow deploys the current selected branch to:

```text
ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT
```

It uses Snowflake key-pair authentication with the same service user pattern as CI. It does not use `ACCOUNTADMIN`, does not run `EXECUTE DBT PROJECT`, and does not create Snowflake Tasks.

Required GitHub repository variable:

```text
SNOWFLAKE_ACCOUNT
```

Required GitHub repository secrets:

```text
SNOWFLAKE_USER
SNOWFLAKE_PRIVATE_KEY
```

Optional GitHub repository secret:

```text
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
```

To deploy from GitHub:

1. Go to the repository in GitHub.
2. Open **Actions**.
3. Select **dbt Deploy**.
4. Click **Run workflow**.
5. Select the branch to deploy.
6. Click **Run workflow**.

Expected result: the workflow installs Snowflake CLI, verifies the Snowflake connection, runs `snow dbt deploy`, and verifies the deployed DBT PROJECT object with `snow dbt describe`.

### Snowflake CLI Prerequisite

Install Snowflake CLI and verify it is available:

```sh
snow --version
```

Snowflake CLI must support `snow dbt` commands. Snowflake documents `snow dbt deploy` as the command that uploads local dbt project files and creates or updates a Snowflake DBT PROJECT object.

### Local Connection

Create a local Snowflake CLI connection named `avidia_pipeline` for the service user.
The connection should conceptually use:

```text
connection name: avida_pipeline
user: SVC_PIPELINE
authenticator: SNOWFLAKE_JWT
role: SVC_PIPELINE_ROLE
warehouse: WH_GOVERNANCE_XS
database: ANALYTICS
schema: DBT_PROJECTS
private key file: ~/.snowflake/keys/svc_pipeline_key.p8
```

Add it interactively:

```sh
snow connection add
```

When prompted, provide the Snowflake account identifier locally. Never copy the private key, passphrase, or generated Snowflake CLI config into this repository.

Verify the connection:

```sh
snow connection test -c avida_pipeline
```

Expected result: `Status` is `OK`, with user `SVC_PIPELINE`, role `SVC_PIPELINE_ROLE`, warehouse `WH_GOVERNANCE_XS`, database `ANALYTICS`, and schema `DBT_PROJECTS`.

Confirm the active Snowflake context:

```sh
snow sql \
  -c avida_pipeline \
  --role SVC_PIPELINE_ROLE \
  --warehouse WH_GOVERNANCE_XS \
  --database ANALYTICS \
  --schema DBT_PROJECTS \
  -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();"
```

Expected result: current user is `SVC_PIPELINE`, current role is `SVC_PIPELINE_ROLE`, database is `ANALYTICS`, schema is `DBT_PROJECTS`, and warehouse is `WH_GOVERNANCE_XS`.

### Deploy

Run from the repository root:

```sh
snow dbt deploy AVIDIA_BANK_DBT \
  --source dbt \
  --profiles-dir dbt \
  --default-target prod \
  --auto-compile \
  -c avida_pipeline \
  --database ANALYTICS \
  --schema DBT_PROJECTS \
  --role SVC_PIPELINE_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Do not use `--force` for normal deployment because it recreates the DBT PROJECT object and can remove run history.

Expected result: Snowflake creates or updates `ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT` and compiles the project during deployment. This does not run MART transformations.

### Verify Deployment

List DBT PROJECT objects:

```sh
snow dbt list \
  -c avida_pipeline \
  --database ANALYTICS \
  --schema DBT_PROJECTS \
  --role SVC_PIPELINE_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Expected result: `AVIDIA_BANK_DBT` appears in the list.

Describe the deployed project:

```sh
snow dbt describe AVIDIA_BANK_DBT \
  -c avida_pipeline \
  --database ANALYTICS \
  --schema DBT_PROJECTS \
  --role SVC_PIPELINE_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Expected result: Snowflake returns details for `AVIDIA_BANK_DBT`, including owner, dbt version, and deployment metadata.

Verify from SQL:

```sh
snow sql \
  -c avida_pipeline \
  --role SVC_PIPELINE_ROLE \
  --warehouse WH_GOVERNANCE_XS \
  --database ANALYTICS \
  --schema DBT_PROJECTS \
  -q "SHOW DBT PROJECTS IN SCHEMA ANALYTICS.DBT_PROJECTS;"
```

Expected result: `AVIDIA_BANK_DBT` appears in `ANALYTICS.DBT_PROJECTS`.

### Run After Deployment

Deployment only pushes dbt code into Snowflake. To run the deployed project manually from Snowflake, execute:

```sql
EXECUTE DBT PROJECT ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT
  ARGS = 'build --target prod';
```

Expected result: Snowflake runs dbt using the deployed project object. Models build into the configured production target:

```text
ANALYTICS.MARTS
```

For the current skeleton, there may be little or nothing to create until real MART models are added. Later models such as `CUSTOMER_360` or `DEPOSITS_DAILY` should be added under `dbt/models/marts/` before this command becomes the MART refresh path.

Validate the run result in Snowflake query history and with:

```sql
SHOW TABLES IN SCHEMA ANALYTICS.MARTS;
SHOW VIEWS IN SCHEMA ANALYTICS.MARTS;
```

### Native Profile

`dbt_projects_profiles.yml` is used by Snowflake dbt Projects. It intentionally contains only the native execution target:

```text
profile: avidia_banking_governance
target: prod
database: ANALYTICS
schema: MARTS
warehouse: WH_GOVERNANCE_XS
role: SVC_PIPELINE_ROLE
```

It does not contain account, user, password, private key, passphrase, or GitHub secret references. Authentication belongs to Snowflake CLI and the `avidia_pipeline` connection.

### Dependencies

`packages.yml` currently contains:

```yaml
packages: []
```

There are no external dbt packages for Snowflake to download during deployment. Keep it this way until a real transformation needs a package.

### Troubleshooting

If `snow connection test -c avida_pipeline` fails, fix the local Snowflake CLI connection first. Check account, user, private key path, role, warehouse, database, and schema.

If deployment fails with a privilege error, confirm `SVC_PIPELINE_ROLE` has `USAGE` on `ANALYTICS`, `USAGE` on `ANALYTICS.DBT_PROJECTS`, `CREATE DBT PROJECT` on `ANALYTICS.DBT_PROJECTS`, and `USAGE` on `WH_GOVERNANCE_XS`.

If deployment fails during compilation, run local dbt checks again:

```sh
dbt --project-dir dbt --profiles-dir dbt parse
dbt --project-dir dbt --profiles-dir dbt compile --target prod
```

If the DBT PROJECT is created in the wrong schema, confirm the deploy command includes `--database ANALYTICS --schema DBT_PROJECTS`. The MART target schema belongs in `dbt_projects_profiles.yml`; the DBT PROJECT object schema belongs in the Snowflake CLI deploy command.
