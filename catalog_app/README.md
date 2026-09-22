# Avidia Data Catalog

This directory contains the existing one-page Streamlit in Snowflake application for the Avidia Bank governance catalog.

The deployed Streamlit object is:

```text
GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG
```

The application reads live Snowflake governance metadata through:

```text
GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG
GOVERNANCE.CATALOG.CATALOG_SCORECARD
```

It no longer uses hardcoded catalog rows for the Snowflake deployment.

## Purpose

The app is the Block 5 data-dictionary experience. It lets a reviewer search and inspect governed MART objects with the fields required by the specification:

- owner;
- steward;
- certification;
- CDE flag;
- confirmed classification;
- description;
- upstream sources;
- last refresh;
- latest quality result;
- usage since creation;
- query count;
- distinct roles.

It also exposes the seven-dimension governance scorecard in a simple `Governance Scorecard` tab.

The app is intentionally read-only. It does not:

- run DQ;
- execute lineage;
- call `CERTIFY`;
- approve/reject classification;
- generate Cortex descriptions;
- expose sensitive banking row data.

## Directory Structure

```text
catalog_app/
├── streamlit_app.py
├── snowflake.yml
├── environment.yml
├── components/
│   ├── header.py
│   ├── object_summary.py
│   ├── column_table.py
│   └── status_cards.py
├── services/
│   ├── catalog_service.py
│   └── mock_catalog_service.py
├── sql/
│   ├── 00_run_setup.sql
│   ├── 00_permissions.sql
│   ├── 01_create_catalog_view.sql
│   └── 02_validate_catalog_view.sql
└── README.md
```

`mock_catalog_service.py` remains as a development fallback pattern, but the production app reads Snowflake through `services/catalog_service.py`.

## Architecture

```text
Existing governance metadata
  -> GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG
  -> GOVERNANCE.CATALOG.CATALOG_SCORECARD
  -> SnowflakeCatalogService
  -> Streamlit UI
```

Large governance joins are kept in Snowflake SQL views rather than embedded in Python. This keeps the UI small and easy to explain.

## Existing Deployment Configuration

`snowflake.yml` defines one Streamlit entity:

```text
entity id:       avida_data_catalog
object:          GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG
stage:           AVIDIA_DATA_CATALOG_STAGE
query warehouse: WH_GOVERNANCE_XS
main file:       streamlit_app.py
artifacts:       streamlit_app.py, environment.yml, components/, services/
```

The deployment/runtime role is:

```text
CATALOG_APP_ROLE
```

The app uses Snowflake warehouse runtime and does not require Snowpark Container Services or a compute pool.

## Field Sources

| App field | Source |
| --- | --- |
| database, schema, object and column | `ANALYTICS.INFORMATION_SCHEMA.TABLES/COLUMNS` for `ANALYTICS.MARTS` |
| object and column descriptions | Snowflake comments |
| owner | effective `GOVERNANCE.TAGS.DATA_OWNER` tag |
| steward | effective `GOVERNANCE.TAGS.DATA_STEWARD` tag |
| certification | effective `GOVERNANCE.TAGS.CERTIFICATION` tag |
| CDE flag | effective `GOVERNANCE.TAGS.CDE` column tag |
| classification | confirmed/effective `GOVERNANCE.TAGS.CLASSIFICATION` column tag |
| upstream sources | latest `GOVERNANCE.CATALOG.LINEAGE_EDGE` snapshot |
| last refresh | `ANALYTICS.INFORMATION_SCHEMA.TABLES.LAST_ALTERED` |
| quality result | latest `GOVERNANCE.DQ.DQ_RESULT` run |
| query count | `SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY` |
| distinct roles | `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` joined by query ID |
| scorecard | `GOVERNANCE.CATALOG.CATALOG_SCORECARD` |

`LAST_REFRESH` is interpreted as Snowflake object last-altered time for the MART object. It is not a business SLA timestamp.

`ACCOUNT_USAGE` can lag, so usage counts are not real-time.

## SQL Setup Order

Run from the repository root:

```sh
snow sql -c avidia -f catalog_app/sql/00_run_setup.sql
snow sql -c avidia -f scorecard/00_run_setup.sql
```

Expected result:

- `GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG` exists and returns MART column rows;
- `ANALYTICS.MARTS.DEPOSITS_DAILY` appears in the catalog;
- owner, steward, certification, CDE, classification, lineage, DQ and usage fields populate when prior blocks have been executed;
- `GOVERNANCE.CATALOG.CATALOG_SCORECARD` returns seven rows.

## Local UI Check

For a local syntax/UI check:

```sh
cd catalog_app
streamlit run streamlit_app.py
```

Local rendering still requires the service layer to handle the environment you are using. The intended deployment target is Streamlit in Snowflake with an active Snowflake session.

## Deploy To Snowflake

From the repository root:

```sh
cd catalog_app
snow streamlit deploy avida_data_catalog \
  --replace \
  -c avidia
```

If your local service-user connection is named `avida_pipeline`, use:

```sh
snow streamlit deploy avida_data_catalog \
  --replace \
  -c avida_pipeline
```

The GitHub workflow `.github/workflows/streamlit_ci_cd.yml` deploys the same entity manually and does not use `--open`.

## Open The App

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
4. Show owner, steward, certification, quality result, usage count and distinct-role count.
5. Show the column table with CDE and classification values.
6. Show upstream sources from the latest lineage snapshot.
7. Open `Governance Scorecard`.
8. Explain each of the seven dimensions and why `DEFINED` may show a gap if not all MART columns have comments.

## Troubleshooting

Insufficient privileges:
Run `catalog_app/sql/00_permissions.sql` with the appropriate setup/admin connection, then rerun the catalog view and scorecard scripts.

Missing catalog view:
Run `catalog_app/sql/01_create_catalog_view.sql`, then validate with `catalog_app/sql/02_validate_catalog_view.sql`.

Missing scorecard:
Run `scorecard/00_create_catalog_scorecard_view.sql`, then validate with `scorecard/01_validate_scorecard.sql`.

Missing imports:
Confirm `snowflake.yml` includes `components/` and `services/` under `artifacts`, then redeploy with `--replace`.

Dependency errors:
Confirm `environment.yml` contains only the required Streamlit/Snowpark packages for Streamlit in Snowflake.

Usage counts are zero:
`ACCOUNT_USAGE.ACCESS_HISTORY` and `QUERY_HISTORY` can lag. Also confirm the view owner role has Account Usage visibility from the lineage setup.

Quality result is `NO_DQ`:
Run the DQ block and confirm `GOVERNANCE.DQ.DQ_RESULT` has a latest run for the selected object.

Upstream sources are unavailable:
Run the lineage snapshot scripts for `DEPOSITS_DAILY`. Formal lineage evidence is focused on that certified mart.
