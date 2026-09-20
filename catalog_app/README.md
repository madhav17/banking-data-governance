# Avidia Data Catalog

One-page Streamlit in Snowflake data dictionary for the Avidia Bank governance
take-home project.

The app reads live metadata from:

```text
GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG
```

It no longer uses hardcoded catalog data for the production Snowflake
deployment.

## Purpose

The catalog lets reviewers search governed MART objects and inspect the Block 5
data-dictionary fields:

- owner
- steward
- certification
- CDE flag
- confirmed classification
- descriptions
- upstream sources
- last refresh
- latest quality result
- usage since creation

The app is intentionally one page and read-only. It does not run DQ, lineage,
classification, certification, Cortex, or metadata-edit workflows.

## Architecture

```text
Existing governance metadata
  -> GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG
  -> catalog_app/services/SnowflakeCatalogService
  -> Streamlit UI
```

The Streamlit code does not contain the governance joins. Those joins live in
`sql/01_create_catalog_view.sql` so the UI stays easy to explain.

## Source Mapping

| Display field | Source |
| --- | --- |
| object and column inventory | `ANALYTICS.INFORMATION_SCHEMA.TABLES/COLUMNS` for `ANALYTICS.MARTS` |
| description | Snowflake object and column comments |
| owner | `GOVERNANCE.TAGS.DATA_OWNER` effective tag |
| steward | `GOVERNANCE.TAGS.DATA_STEWARD` effective tag |
| certification | `GOVERNANCE.TAGS.CERTIFICATION` effective tag |
| CDE flag | `GOVERNANCE.TAGS.CDE` effective column tag |
| classification | confirmed `GOVERNANCE.TAGS.CLASSIFICATION` column tag |
| upstream sources | latest `GOVERNANCE.CATALOG.LINEAGE_EDGE` snapshot |
| last refresh | `ANALYTICS.INFORMATION_SCHEMA.TABLES.LAST_ALTERED` |
| quality result | latest `GOVERNANCE.DQ.DQ_RESULT` run |
| query count | `SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY` |
| distinct roles | `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` joined by query ID |

`LAST_REFRESH` is interpreted as the latest Snowflake object alteration time
available from `INFORMATION_SCHEMA`, not a business SLA timestamp.

`ACCOUNT_USAGE` data can lag, so usage counts are evidence for review rather
than real-time telemetry.

## Existing Deployment Configuration

The existing Snowflake Streamlit object is preserved:

```text
entity id:  avida_data_catalog
object:     GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG
role:       CATALOG_APP_ROLE
warehouse:  WH_GOVERNANCE_XS
stage:      AVIDIA_DATA_CATALOG_STAGE
runtime:    warehouse runtime
```

The project definition remains in `snowflake.yml`.

## SQL Setup Order

From the repository root:

```sh
snow sql -c avidia -f catalog_app/sql/00_permissions.sql
snow sql -c avidia -f catalog_app/sql/01_create_catalog_view.sql
snow sql -c avidia -f catalog_app/sql/02_validate_catalog_view.sql
snow sql -c avidia -f scorecard/00_create_catalog_scorecard_view.sql
snow sql -c avidia -f scorecard/01_validate_scorecard.sql
```

Expected result:

- `V_STREAMLIT_CATALOG` exists
- it returns MART column rows
- `ANALYTICS.MARTS.DEPOSITS_DAILY` is present
- certification, DQ, lineage, CDE, classification and usage evidence are visible
  when those prior blocks have been executed
- `CATALOG_SCORECARD` returns the seven governance dimensions:
  `OWNED`, `DEFINED`, `TRACEABLE`, `TRUSTED`, `SECURE`, `ADOPTED`,
  `RECONCILED`

## Deploy

From the repository root:

```sh
cd catalog_app
snow streamlit deploy avida_data_catalog \
  --replace \
  -c avidia
```

Use the existing connection configured for the Avidia project. If your local
connection is named `avida_pipeline`, replace `-c avidia` with
`-c avida_pipeline`.

The CI/CD workflow should also deploy the same existing entity and should not
use `--open`.

## Open the App

Use one of:

```sh
snow streamlit get-url AVIDIA_DATA_CATALOG \
  -c avidia \
  --database GOVERNANCE \
  --schema CATALOG \
  --role CATALOG_APP_ROLE \
  --warehouse WH_GOVERNANCE_XS
```

or:

```text
Snowsight -> Projects -> Streamlit -> AVIDIA_DATA_CATALOG
```

## Interview Demo

1. Open `Avidia Data Catalog`.
2. Search for `deposits`.
3. Select `ANALYTICS.MARTS.DEPOSITS_DAILY`.
4. Point out owner, steward, certification, quality result and usage metrics.
5. Show the column table with CDE and classification values.
6. Show upstream sources from the latest lineage snapshot.
7. Open the `Governance Scorecard` tab and show the seven scorecard rows.

## Troubleshooting

Insufficient privileges:
Run `catalog_app/sql/00_permissions.sql` with an admin/setup connection, then
rerun the view creation script.

Missing catalog view:
Run `catalog_app/sql/01_create_catalog_view.sql`, then validate with
`catalog_app/sql/02_validate_catalog_view.sql`.

Missing Python module:
Confirm `environment.yml` includes `streamlit` and
`snowflake-snowpark-python`, then redeploy.

Missing `components` or `services` imports:
Confirm `snowflake.yml` still includes `components/` and `services/` under
`artifacts`, then redeploy with `--replace`.

Usage counts are zero:
`ACCOUNT_USAGE.ACCESS_HISTORY` and `QUERY_HISTORY` can lag. Also confirm the
view owner role has the governance visibility granted in the lineage block.

Quality result is `NO_DQ`:
Run the DQ block for the target object and rerun the catalog validation query.

Upstream sources are `NOT AVAILABLE`:
Run the lineage snapshot task/script for the target object. Current formal
lineage evidence is focused on `ANALYTICS.MARTS.DEPOSITS_DAILY`.
