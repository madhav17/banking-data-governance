# Banking Data Governance

Snowflake-based data governance implementation for the Avidia Bank take-home project.

This repository builds a governed synthetic banking data platform end to end:

```text
Synthetic CSV data
  -> RAW
  -> STAGING
  -> dbt MARTS
  -> metadata, tags, classification, protection, DQ, lineage, certification
  -> scorecard and Streamlit catalog
```

The implementation is intentionally code-driven. Snowflake objects are created from SQL files, dbt models are versioned under `dbt/`, and Streamlit is deployed from `catalog_app/`.

## Current Status

Implemented:

- Snowflake roles, warehouse, databases, schemas, stages and RAW tables.
- RAW loading from generated CSV files.
- STAGING table creation and merge/load scripts.
- dbt MARTS for `CUSTOMER_360`, `DEPOSITS_DAILY` and `LOAN_PORTFOLIO`.
- GitHub Actions for manual dbt CI, native Snowflake dbt Project deployment and Streamlit deployment.
- Metadata foundation with tags, dictionary, glossary, CDE registry and metadata harvest support.
- Classification and protection with review workflow, tag synchronization, masking, branch row access and policy gap reporting.
- DQ / trust block for `ANALYTICS.MARTS.DEPOSITS_DAILY`.
- Lineage block for the certified deposit mart, including native lineage snapshots and two metadata-only external endpoint rows.
- `CERTIFY(object)` procedure and certification evidence log.
- Streamlit data catalog backed by `GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG`.
- Seven-dimension catalog scorecard backed by `GOVERNANCE.CATALOG.CATALOG_SCORECARD`.

## Repository Structure

```text
.
├── setup/                         # Core Snowflake setup, RAW DDL, stages and RAW validation
├── scripts/                       # Local/SnowSQL helper upload scripts for CSV files
├── transformations/staging/       # STAGING schema/table DDL and RAW -> STAGING merge scripts
├── dbt/                           # dbt Core / Snowflake dbt Project for MARTS
│   ├── models/marts/              # CUSTOMER_360, DEPOSITS_DAILY, LOAN_PORTFOLIO
│   ├── tests/                     # Singular dbt test for DEPOSITS_DAILY grain
│   ├── profiles.yml               # dbt Core profile using environment variables
│   └── dbt_projects_profiles.yml  # Native Snowflake dbt Project profile
├── dbt_setup/                     # Snowflake privileges for native dbt Project deployment
├── metadata/                      # Governance schemas, tags, dictionary, glossary, CDEs and harvest
├── classification/                # Classification profile, custom classifier, review queue and approvals
├── protection/                    # Masking policies, row access policy and protection validation
├── dq/                            # Six DQ checks and DQ_RESULT persistence
├── lineage/                       # Native lineage, snapshots, external fallback metadata and impact analysis
├── certification/                 # CERTIFY procedure, evidence log and certification validation
├── scorecard/                     # Seven-dimension catalog scorecard view and validation
├── catalog_app/                   # Existing Streamlit catalog application
├── .github/workflows/             # Manual dbt CI, dbt deploy and Streamlit deploy workflows
├── data/                          # Generated banking data and sealed sensitive-column truth set
├── evidence/                      # Final evidence pack and supporting evidence exports
├── roadmap/                       # 12-month governance roadmap PDF
├── start_fresh/                   # Account reset helper for a clean rebuild
├── HOURS.md                       # Candidate time log
└── AI_DISCLOSURE.md               # AI assistance disclosure
```

## Snowflake Logical Layout

```text
RAW
└── BANKING
    └── source-aligned synthetic banking tables

ANALYTICS
├── STAGING
│   └── normalized/typed internal processing tables
├── MARTS
│   ├── CUSTOMER_360
│   ├── DEPOSITS_DAILY
│   └── LOAN_PORTFOLIO
└── DBT_PROJECTS
    └── AVIDIA_BANK_DBT

GOVERNANCE
├── CATALOG
│   ├── metadata, review, lineage and Streamlit catalog objects
│   ├── V_STREAMLIT_CATALOG
│   └── CATALOG_SCORECARD
├── TAGS
│   └── governed tag taxonomy
├── DQ
│   └── DQ_RESULT and custom DMFs
└── EVIDENCE
    └── CERTIFICATION_LOG and CERTIFY procedure
```

## Principal Roles

The repository uses separate roles to keep administrative, pipeline and consumer behavior understandable:

- `DATA_PLATFORM_ADMIN`: platform/bootstrap setup.
- `DATA_ENGINEER`: data loading and transformation execution.
- `DATA_GOVERNANCE_ADMIN`: metadata, tags, classification, protection, DQ, lineage, certification and scorecard setup.
- `SVC_PIPELINE` / `SVC_PIPELINE_ROLE`: service-user automation for GitHub Actions and dbt deployment.
- `CATALOG_APP_ROLE`: Streamlit deployment/runtime role.
- `DATA_OWNER`: clear sensitive-data visibility and certification review persona.
- `DATA_STEWARD`: partial sensitive-data visibility and classification/certification review persona.
- `DEPOSITS_ANALYST`: masked consumer persona.
- `BRANCH_HUDSON`: branch-scoped consumer persona.

Do not use `ACCOUNTADMIN` as the runtime role for pipelines or demonstrations. Some bootstrap grants may still require a high-privilege setup role depending on the Snowflake account.

## Data Flow

### 1. RAW Setup And Load

Core platform setup:

```sh
snow sql -c avidia -f setup/00_run_setup.sql
```

`setup/00_run_setup.sql` sources:

- `setup/01_roles.sql`
- `setup/02_warehouse.sql`
- `setup/03_databases_schemas.sql`
- `setup/04_base_grants.sql`
- `setup/05_raw_tables.sql`
- `setup/06_create_file_format_stage.sql`
- `setup/07_prepare_full_reload.sql`

Upload generated CSV files to the RAW stage:

```sh
./scripts/upload_raw_to_stage.sh
```

Load and validate RAW:

```sh
snow sql -c avidia -f setup/08_load_raw.sql
snow sql -c avidia -f setup/09_validate_raw.sql
```

Shortcut after the upload script has finished:

```sh
snow sql -c avidia -f setup/01_run_setup.sql
```

### 2. STAGING Layer

Build STAGING objects and merge RAW data:

```sh
snow sql -c avidia -f transformations/staging/00_run_staging.sql
```

The STAGING driver creates the schema/tables, validates RAW prerequisites, runs each domain merge and validates final STAGING row counts.

### 3. dbt MARTS

The dbt project transforms `ANALYTICS.STAGING` into three business-oriented MARTS:

| MART | Grain | Purpose |
| --- | --- | --- |
| `CUSTOMER_360` | one row per `CUSTOMER_ID` | Customer-centric governed profile for masking/classification proof. |
| `DEPOSITS_DAILY` | one row per `ACCOUNT_ID + BUSINESS_DATE` | Primary certified deposit data product, DQ target and GL reconciliation anchor. |
| `LOAN_PORTFOLIO` | one row per `LOAN_ID` | Lending exposure and collateral/credit-grade data product. |

Local dbt validation:

```sh
dbt --project-dir dbt --profiles-dir dbt deps
dbt --project-dir dbt --profiles-dir dbt parse
dbt --project-dir dbt --profiles-dir dbt compile --target dev
dbt --project-dir dbt --profiles-dir dbt build --target dev
```

Native Snowflake dbt Project deployment:

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

The deployment creates or updates `ANALYTICS.DBT_PROJECTS.AVIDIA_BANK_DBT`. It does not automatically execute the project or schedule it.

### 4. Metadata Foundation

Run the metadata foundation after RAW, STAGING and the dbt MARTS exist:

```sh
snow sql -c avidia -f metadata/00_run_setup.sql
```

This block creates and populates:

- `GOVERNANCE.CATALOG.TAG_ASSIGNMENT`
- `GOVERNANCE.TAGS` taxonomy
- `GOVERNANCE.CATALOG.APPLY_TAG_ASSIGNMENTS()`
- metadata harvest procedure/task support
- data dictionary comments
- banking glossary and glossary links
- CDE registry and CDE tag synchronization
- MART owner, steward, CDE and certification-support metadata

### 5. Classification And Protection

Classification is centered on STAGING as the internal processing boundary. Machine-detected results become candidates, steward decisions become confirmed governance tag assignments, and confirmed tags drive protection on RAW/MART targets.

Execution order:

```sh
snow sql -c avidia -f classification/01_permissions.sql
snow sql -c avidia -f classification/02_create_classification_profile.sql
snow sql -c avidia -f classification/03_create_custom_classifier.sql
snow sql -c avidia -f classification/04_prepare_classification_tables.sql
snow sql -c avidia -f classification/05_load_sealed_sensitive_list.sql
snow sql -c avidia -f classification/06_run_staging_classification.sql
snow sql -c avidia -f classification/07_capture_classification_results.sql
snow sql -c avidia -f classification/08_precision_recall.sql
snow sql -c avidia -f classification/09_create_review_procedures.sql
snow sql -c avidia -f classification/10_sync_confirmed_classification_tags.sql
snow sql -c avidia -f classification/11_validate_classification.sql
```

Protection execution order:

```sh
snow sql -c avidia -f protection/01_permissions.sql
snow sql -c avidia -f protection/02_create_masking_policies.sql
snow sql -c avidia -f protection/03_bind_masking_policies.sql
snow sql -c avidia -f protection/04_create_branch_entitlements.sql
snow sql -c avidia -f protection/05_create_row_access_policy.sql
snow sql -c avidia -f protection/06_apply_row_access_policy.sql
snow sql -c avidia -f protection/07_validate_masking_by_role.sql
snow sql -c avidia -f protection/08_validate_branch_access.sql
snow sql -c avidia -f protection/09_sensitive_policy_gap_report.sql
```

Expected protection evidence:

- `DATA_OWNER` sees clear sensitive values.
- `DATA_STEWARD` sees partially masked sensitive values.
- `DEPOSITS_ANALYST` sees strongly masked sensitive values.
- `BRANCH_HUDSON` sees only entitled branch rows.
- Sensitive policy gap report returns zero rows when protection is complete.

### 6. Data Quality / Trust

The DQ target is `ANALYTICS.MARTS.DEPOSITS_DAILY`.

Exactly six checks are implemented:

| Dimension | Implementation |
| --- | --- |
| Completeness | `SNOWFLAKE.CORE.NULL_COUNT` on `ACCOUNT_ID`. |
| Uniqueness | `SNOWFLAKE.CORE.DUPLICATE_COUNT` for `ACCOUNT_ID + BUSINESS_DATE`. |
| Validity | `SNOWFLAKE.CORE.ACCEPTED_VALUES` for `ACCOUNT_STATUS`. |
| Consistency | `SNOWFLAKE.CORE.REFERENTIAL_INTEGRITY_COUNT` for `CUSTOMER_ID`. |
| Timeliness | custom DMF comparing latest MART date to latest upstream balance date. |
| Accuracy | custom DMF reconciling deposit balances to GL totals within `$1`. |

Run:

```sh
snow sql -c avidia -f dq/00_run_setup.sql
```

`dq/00_run_setup.sql` sources the permission, `DQ_RESULT`, custom DMF, attachment, execution/persistence and validation scripts in order.

Results are persisted historically in `GOVERNANCE.DQ.DQ_RESULT`.

### 7. Lineage

Lineage is focused on the certified mart `ANALYTICS.MARTS.DEPOSITS_DAILY`.

Native chain:

```text
RAW.BANKING.ACCOUNT_DAILY_BALANCE
  -> ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE
  -> ANALYTICS.MARTS.DEPOSITS_DAILY
```

Supporting sources include `ACCOUNT`, `CUSTOMER`, `PRODUCT` and `BRANCH`.

Run:

```sh
snow sql -c avidia -f lineage/00_run_setup.sql
```

`lineage/00_run_setup.sql` sources native lineage, external fallback metadata, task/snapshot, worked trace, impact-analysis and validation scripts.

`GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL` contains exactly two metadata-only rows:

```text
LEGACY_TALEND_DEPOSIT_LOAD -> RAW.BANKING.ACCOUNT_DAILY_BALANCE
ANALYTICS.MARTS.DEPOSITS_DAILY -> POWER_BI_DEPOSITS_MODEL
```

No Talend or Power BI objects are created.

### 8. Certification

`GOVERNANCE.EVIDENCE.CERTIFY(object)` validates existing evidence and either certifies or refuses a MART.

Gates:

1. owner exists
2. steward exists
3. description coverage is 100%
4. registered CDEs are tagged
5. confirmed classification exists where required
6. sensitive policy coverage has no gaps
7. latest DQ run has all six dimensions passing

Run:

```sh
snow sql -c avidia -f certification/00_run_setup.sql
```

`certification/00_run_setup.sql` sources permissions, log creation, procedure creation, demonstration and validation helpers.

Expected demonstration:

- `ANALYTICS.MARTS.DEPOSITS_DAILY` is certified.
- `ANALYTICS.MARTS.CUSTOMER_360` is refused because it does not have the full DQ evidence required for certification.

### 9. Scorecard

The scorecard view returns the seven required dimensions:

```text
OWNED, DEFINED, TRACEABLE, TRUSTED, SECURE, ADOPTED, RECONCILED
```

Run:

```sh
snow sql -c avidia -f scorecard/00_run_setup.sql
```

The scorecard is exposed to Streamlit through `GOVERNANCE.CATALOG.CATALOG_SCORECARD`.

### 10. Streamlit Catalog

The existing Streamlit app lives under `catalog_app/` and deploys to:

```text
GOVERNANCE.CATALOG.AVIDIA_DATA_CATALOG
```

Prepare the backing view and validate it:

```sh
snow sql -c avidia -f catalog_app/sql/00_run_setup.sql
```

Deploy:

```sh
cd catalog_app
snow streamlit deploy avida_data_catalog --replace -c avidia
```

The app reads:

- `GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG`
- `GOVERNANCE.CATALOG.CATALOG_SCORECARD`

It does not execute DQ, lineage, certification or classification workflows.

## Clean Rebuild Order

For a fresh demo account, the safest rebuild order is:

```text
setup/00_run_setup.sql
scripts/upload_raw_to_stage.sh
setup/01_run_setup.sql
transformations/staging/00_run_staging.sql
dbt build or native dbt project execution
metadata/00_run_setup.sql
classification scripts
protection scripts
dq/00_run_setup.sql
lineage/00_run_setup.sql
certification/00_run_setup.sql
catalog_app/sql/00_run_setup.sql
scorecard/00_run_setup.sql
Streamlit deploy
```

`start_fresh/clean.sql` can be used to drop `RAW`, `ANALYTICS` and `GOVERNANCE` when you intentionally want to reset the Snowflake account and rebuild from zero. It should not be part of normal CI/CD.

## GitHub Actions

The workflows are manual-only.

| Workflow | File | Purpose |
| --- | --- | --- |
| dbt CI | `.github/workflows/dbt_ci.yml` | SQLFluff, dbt parse/compile, zero-copy clone, dbt build. |
| dbt Deploy | `.github/workflows/dbt_deploy.yml` | Deploys `AVIDIA_BANK_DBT` to `ANALYTICS.DBT_PROJECTS`. |
| Streamlit CI/CD | `.github/workflows/streamlit_ci_cd.yml` | Validates and deploys `AVIDIA_DATA_CATALOG`. |

Core GitHub secrets:

```text
SNOWFLAKE_USER
SNOWFLAKE_PRIVATE_KEY
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE   # optional when the key has no passphrase
```

Core GitHub variables:

```text
SNOWFLAKE_ACCOUNT
SNOWFLAKE_ROLE
SNOWFLAKE_WAREHOUSE
SNOWFLAKE_BASE_DATABASE
SNOWFLAKE_CI_DB_PREFIX
DBT_CI_SCHEMA
DBT_THREADS
```

## Interview Walkthrough

Suggested live flow:

1. Show the repository structure and explain RAW -> STAGING -> MARTS.
2. Open `dbt/models/marts/` and explain the three MART grains.
3. Show `DEPOSITS_DAILY` as the primary certified data product.
4. Show metadata tags and CDE setup in `metadata/`.
5. Explain classification detection versus steward-confirmed classification.
6. Demonstrate masking and branch row access validation scripts.
7. Show the six DQ dimensions and the latest `DQ_RESULT`.
8. Show lineage for `DEPOSITS_DAILY`, including the worked `CLOSING_BALANCE` trace.
9. Run or show `CERTIFY('ANALYTICS.MARTS.DEPOSITS_DAILY')` output and log.
10. Open the Streamlit catalog and search for `deposits`.
11. Open the scorecard tab and explain each dimension.

## Notes And Limitations

- Account Usage views can lag, so ACCESS_HISTORY, QUERY_HISTORY and OBJECT_DEPENDENCIES evidence may not appear immediately after scripts run.
- Native lineage visibility depends on Snowflake lineage support and query history in the trial account.
- The Streamlit app is read-only and metadata-only; it does not expose sensitive banking records.
- `evidence/Avidia_Evidence_Pack_Formatted.pdf` contains the formatted evidence pack.
- `roadmap/Avidia_Snowflake_12_Month_Governance_Roadmap.pdf` contains the roadmap deliverable.
- `start_fresh/clean.sql` drops the project databases for a clean rebuild. It uses `ACCOUNTADMIN` and should be run only when you intentionally want to reset the demo account.
