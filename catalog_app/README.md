# Avidia Data Catalog

Single-page Streamlit framework for the Avidia Bank Snowflake data dictionary.

This phase creates the UI shell only. It uses mock catalog data so the page can
be developed and reviewed locally without Snowflake credentials.

## Purpose

The final app will help users inspect governed banking data assets with:

- search
- owner
- steward
- certification
- CDE flag
- classification
- description
- upstream sources
- last refresh
- quality result
- usage since creation

Today, those values are static mock data. The UI is intentionally simple so it
can be explained during a live walkthrough.

## Architecture

Current:

```text
Streamlit UI
  -> CatalogService
  -> MockCatalogService
```

Future:

```text
Streamlit UI
  -> CatalogService
  -> SnowflakeCatalogService
  -> GOVERNANCE / ANALYTICS / ACCOUNT_USAGE
```

The UI does not contain hard-coded SQL. Data retrieval is separated behind the
`CatalogService` interface so mock data can later be replaced by Snowpark
queries.

## Files

```text
catalog_app/
  streamlit_app.py
  snowflake.yml
  environment.yml
  README.md
  components/
    header.py
    object_summary.py
    column_table.py
    status_cards.py
  services/
    catalog_service.py
    mock_catalog_service.py
```

## Run Locally

From the repository root:

```sh
cd catalog_app
streamlit run streamlit_app.py
```

If Streamlit is not installed locally:

```sh
pip install streamlit
cd catalog_app
streamlit run streamlit_app.py
```

Local execution uses mock data only. It does not require Snowflake credentials.

## Current Mock Data

The mock service includes example STAGING objects:

- `ANALYTICS.STAGING.STG_CUSTOMER`
- `ANALYTICS.STAGING.STG_ACCOUNT`
- `ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE`

Mocked sections today:

- object descriptions
- owner and steward
- certification status
- CDE status
- classification
- last refresh
- data-quality status
- usage/query count
- distinct roles
- upstream sources
- column metadata

Placeholder values such as `NOT EVALUATED`, `NOT CERTIFIED`, and `NOT AVAILABLE`
are used where governance features are not integrated yet.

## Future Snowflake Integration

A later `SnowflakeCatalogService` will use Snowpark and the active Streamlit in
Snowflake session:

```python
from snowflake.snowpark.context import get_active_session
```

It will query curated metadata from:

- `GOVERNANCE`
- `ANALYTICS`
- `SNOWFLAKE.ACCOUNT_USAGE`

Do not add real metadata, lineage, DQ, certification, ACCESS_HISTORY, or Cortex
queries in this phase.

## Snowflake Deployment

This phase deploys the mock UI framework only. It does not query real governance
metadata, account usage, lineage, DQ results, certifications, or marts.

The target Snowflake object is:

```text
GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG
```

The deployment uses:

```text
connection: avida_pipeline
user: SVC_PIPELINE
role: CATALOG_APP_ROLE
warehouse: WH_GOVERNANCE_XS
database: GOVERNANCE
schema: CATALOG
```

The app uses the Snowflake warehouse runtime. The `snowflake.yml` file does not
set `compute_pool` or a container `runtime_name`.

### 1. Verify Snowflake CLI

```sh
snow --version
snow streamlit deploy --help
```

Expected result: Snowflake CLI is available and supports `snow streamlit deploy`.

### 2. Prepare Snowflake Privileges

From the repository root, run this with a setup/admin Snowflake connection that
can use `SECURITYADMIN`:

```sh
snow sql \
  -c <admin_setup_connection> \
  -f setup/08_prepare_streamlit_deployment.sql
```

Expected result: `CATALOG_APP_ROLE` exists, is granted to `SVC_PIPELINE`, and has
only the current dummy deployment privileges:

- `USAGE` on `GOVERNANCE`
- `USAGE` on `GOVERNANCE.CATALOG`
- `CREATE STREAMLIT` on `GOVERNANCE.CATALOG`
- `CREATE STAGE` on `GOVERNANCE.CATALOG`
- `USAGE` on `WH_GOVERNANCE_XS`

No `ACCOUNTADMIN`, account-level grants, `ACCOUNT_USAGE`, DQ, MARTS,
classification, or lineage privileges are granted in this phase.

### 3. Verify Service Role Context

```sh
snow sql \
  -c avida_pipeline \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS \
  --database GOVERNANCE \
  --schema CATALOG \
  -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();"
```

Expected result: current user is `SVC_PIPELINE`, role is `CATALOG_APP_ROLE`,
database is `GOVERNANCE`, schema is `CATALOG`, and warehouse is
`WH_GOVERNANCE_XS`.

### 4. Deploy

From the repository root:

```sh
cd catalog_app
snow streamlit deploy avida_data_catalog \
  --replace \
  --open \
  --connection avida_pipeline \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Expected result: Snowflake CLI uploads `streamlit_app.py`, `environment.yml`,
`components/`, and `services/` to the deployment stage and creates or replaces
`GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG`.

### 5. Verify Deployment

```sh
snow sql \
  -c avida_pipeline \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS \
  --database GOVERNANCE \
  --schema CATALOG \
  -q "SHOW STREAMLITS IN SCHEMA GOVERNANCE.CATALOG;"
```

Expected result: `AVIDIA_DATA_CATALOG` appears.

```sh
snow streamlit list \
  -c avida_pipeline \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Expected result: `AVIDIA_DATA_CATALOG` appears in the list.

```sh
snow streamlit describe AVIDIA_DATA_CATALOG \
  -c avida_pipeline \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Expected result: app metadata is returned, including `QUERY_WAREHOUSE`.

### 6. Get or Open the App URL

```sh
snow streamlit get-url AVIDIA_DATA_CATALOG \
  --open \
  -c avida_pipeline \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

You can also open the app from Snowsight:

```text
Snowsight -> Projects -> Streamlit -> AVIDIA_DATA_CATALOG
```

For now, only the deployment/owner role is prepared. Viewer grants for
`DATA_OWNER`, `DATA_STEWARD`, and analyst roles will be added later when the app
uses real governed metadata.

### 7. Verify Runtime and Warehouse

Use `DESCRIBE STREAMLIT` to confirm the app is using the expected warehouse and
does not reference a compute pool:

```sh
snow sql \
  -c avida_pipeline \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS \
  --database GOVERNANCE \
  --schema CATALOG \
  -q "DESCRIBE STREAMLIT GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG;"
```

Expected result: `QUERY_WAREHOUSE` is `WH_GOVERNANCE_XS`. There should be no
compute pool for this warehouse-runtime app.

### 8. Redeploy After Code Changes

```sh
cd catalog_app
snow streamlit deploy avida_data_catalog \
  --replace \
  --prune \
  --open \
  -c avida_pipeline \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

Use `--prune` when you remove or rename local files so old files are removed
from the deployment stage.

## Troubleshooting

### Insufficient Privileges

Symptoms include failures creating the Streamlit object, creating the stage, or
using the warehouse.

Re-run:

```sh
snow sql -c <admin_setup_connection> -f ../setup/08_prepare_streamlit_deployment.sql
```

If you are already in `catalog_app/`, use `../setup/...`; from the repository
root, use `setup/...`.

### Missing Stage

The project definition uses:

```text
AVIDIA_DATA_CATALOG_STAGE
```

Snowflake CLI can create the stage if `CATALOG_APP_ROLE` has `CREATE STAGE` on
`GOVERNANCE.CATALOG`. Verify with:

```sql
SHOW STAGES IN SCHEMA GOVERNANCE.CATALOG;
```

### Missing Python Files or Modules

If the deployed app cannot import `components` or `services`, verify
`catalog_app/snowflake.yml` includes:

```yaml
artifacts:
  - streamlit_app.py
  - environment.yml
  - components/
  - services/
```

Redeploy with `--prune` after fixing the artifact list.

### Package or Dependency Errors

The dummy app currently requires only Streamlit. If package errors occur, verify
`environment.yml` contains no unnecessary packages and redeploy.

### Wrong Runtime

This app should use the warehouse runtime. The project definition intentionally
omits `compute_pool` and container `runtime_name`. Verify with:

```sql
DESCRIBE STREAMLIT GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG;
```

If a compute pool appears, drop/recreate the app from this project definition
without adding container runtime fields.

### Warehouse Access

If the app opens but cannot run, verify:

```sql
SHOW GRANTS TO ROLE CATALOG_APP_ROLE;
```

The role must have `USAGE` on `WH_GOVERNANCE_XS`.

### App URL or Access Errors

Use:

```sh
snow streamlit get-url AVIDIA_DATA_CATALOG \
  -c avida_pipeline \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

If the URL opens but access is denied, confirm you are using a user that can
assume `CATALOG_APP_ROLE`. Broader viewer access will be granted in a later
phase.
