# MART Design Notes

This folder contains the business MART layer for the Avidia Bank take-home project.

The MART layer is deliberately small and business-oriented. It does not create one-to-one copies of every STAGING table. Instead it creates three useful governed data products:

| dbt model | Snowflake object | Grain | Business purpose |
| --- | --- | --- | --- |
| `customer_360.sql` | `ANALYTICS.MARTS.CUSTOMER_360` | one row per `CUSTOMER_ID` | Customer profile used to demonstrate governed customer attributes, sensitive-data classification and masking. |
| `deposits_daily.sql` | `ANALYTICS.MARTS.DEPOSITS_DAILY` | one row per `ACCOUNT_ID + BUSINESS_DATE` | Primary certified deposit data product. It drives DQ, GL reconciliation, lineage, certification and the catalog demo. |
| `loan_portfolio.sql` | `ANALYTICS.MARTS.LOAN_PORTFOLIO` | one row per `LOAN_ID` | Lending exposure data product with loan, collateral, customer, branch, product and officer context. |

## Source Design

`_sources.yml` declares the existing `ANALYTICS.STAGING` tables used by the MARTS. dbt treats STAGING as an external source layer and does not create or mutate those tables.

The key source domains are:

- `STG_CUSTOMER`
- `STG_ACCOUNT`
- `STG_ACCOUNT_DAILY_BALANCE`
- `STG_TRANSACTION`
- `STG_LOAN`
- `STG_LOAN_COLLATERAL`
- `STG_CARD`
- `STG_BRANCH`
- `STG_PRODUCT`
- `STG_OFFICER`

`STG_GL_CONTROL_TOTAL` is intentionally not joined into every account/day row in `DEPOSITS_DAILY`. It is used later by the DQ accuracy check so the account/day grain remains clean.

## Materialization Strategy

All three MART models use:

```sql
materialized = 'incremental'
incremental_strategy = 'insert_overwrite'
```

This was chosen for a specific governance reason:

```text
First run
  -> dbt creates the MART table
  -> full desired result set is inserted

Normal subsequent run
  -> dbt recalculates the complete desired result set
  -> INSERT OVERWRITE replaces the rows
  -> the physical Snowflake table object is preserved
```

Preserving the physical table matters because later governance tags, masking policies, row-access policies and certification evidence can remain attached to the same object.

The models intentionally do not include:

- `is_incremental()` filters;
- manual `TRUNCATE`;
- manual `DELETE`;
- manual table creation;
- Snowflake clustering keys.

The synthetic data volume is small. Clustering for `DEPOSITS_DAILY` on `BUSINESS_DATE`, `BRANCH_ID`, or both could be evaluated later using real query history and table size evidence.

## Model Summaries

### CUSTOMER_360

`CUSTOMER_360` starts from customer records and joins pre-aggregated child summaries. Child tables are aggregated before joining to avoid one-to-many multiplication.

Typical metrics include account counts, active account counts, deposit balances, transaction activity, loan exposure and card counts where the underlying source columns exist.

This model preserves sensitive customer fields that are required for the protection demonstration, such as tax ID, date of birth, email and phone.

### DEPOSITS_DAILY

`DEPOSITS_DAILY` is built primarily from daily account balances plus account context.

The grain is:

```text
ACCOUNT_ID + BUSINESS_DATE
```

This grain supports:

- completeness checks on critical account identifiers;
- uniqueness checks on account/date;
- account status validity checks;
- account/customer consistency checks;
- latest business-date checks;
- GL reconciliation using aggregated closing balances.

### LOAN_PORTFOLIO

`LOAN_PORTFOLIO` is built from loan data and enriched with customer, product, branch, officer and collateral context.

The grain is:

```text
LOAN_ID
```

Where collateral values are available, derived exposure metrics such as loan-to-value are calculated with null and divide-by-zero protection.

## Tests

`schema.yml` contains basic dbt tests for primary model identifiers. Singular tests in `dbt/tests/` validate:

- the composite `DEPOSITS_DAILY` grain;
- the derived `DEPOSITS_DAILY.IS_ACTIVE_ACCOUNT` flag;
- nonnegative `CUSTOMER_360` activity counts and active-count bounds;
- `LOAN_PORTFOLIO` collateral metric validity;
- `LOAN_PORTFOLIO.LOAN_TO_VALUE_RATIO` calculation consistency.

These avoid adding an external package solely for combination uniqueness or simple business-rule assertions.

## Governance Metadata

Each model carries lightweight dbt `meta` values for later governance integration:

- `domain`
- `layer = MART`

Certification is not hard-coded in dbt. Certification is assigned only by `GOVERNANCE.EVIDENCE.CERTIFY(object)` after all certification gates pass.
