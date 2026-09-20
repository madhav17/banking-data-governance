# Governance Scorecard

This block implements the seven-dimension catalog scorecard required by the take-home.

The scorecard is a Snowflake view:

```text
GOVERNANCE.CATALOG.CATALOG_SCORECARD
```

It is also displayed in the existing Streamlit catalog app on the `Governance Scorecard` tab.

## Purpose

The scorecard summarizes whether the governed catalog is:

```text
Owned, Defined, Traceable, Trusted, Secure, Adopted and Reconciled
```

Each row reports:

```text
DIMENSION
NUMERATOR
DENOMINATOR
SCORE_PCT
STATUS
DESCRIPTION
```

`SCORE_PCT` is calculated as:

```sql
ROUND(NUMERATOR * 100.0 / NULLIF(DENOMINATOR, 0), 2)
```

`STATUS` is:

- `PASS` when `NUMERATOR = DENOMINATOR` and `DENOMINATOR > 0`;
- `GAP` otherwise.

Scores are not hard-coded. They are derived from existing project metadata and evidence.

## Dimensions

| Dimension | Numerator | Denominator | Evidence source |
| --- | --- | --- | --- |
| `OWNED` | catalog objects with both owner and steward | catalog objects in scope | `V_STREAMLIT_CATALOG` owner/steward fields |
| `DEFINED` | catalog columns with non-empty descriptions | catalog columns in scope | `V_STREAMLIT_CATALOG.DESCRIPTION` |
| `TRACEABLE` | certified MARTS with upstream lineage evidence | certified MARTS in scope | `LINEAGE_EDGE` / catalog lineage fields |
| `TRUSTED` | certified MARTS with all six DQ dimensions passing | certified MARTS evaluated for DQ | `GOVERNANCE.DQ.DQ_RESULT` |
| `SECURE` | confirmed sensitive columns covered by required policy | confirmed sensitive columns in scope | protection gap logic and policy references |
| `ADOPTED` | certified/published objects with observed usage | certified/published objects in scope | ACCESS_HISTORY-derived catalog usage |
| `RECONCILED` | certified MARTS whose accuracy DQ check passes | certified MARTS with accuracy check executed | `DQ_RESULT` accuracy dimension |

## Files

```text
scorecard/
├── 00_create_catalog_scorecard_view.sql
├── 01_validate_scorecard.sql
├── execution_order.txt
└── README.md
```

## Execution Order

Run after DQ, lineage, certification and the Streamlit catalog view have been prepared:

```sh
snow sql -c avidia -f scorecard/00_create_catalog_scorecard_view.sql
snow sql -c avidia -f scorecard/01_validate_scorecard.sql
```

## Expected Output

The validation query should return exactly seven dimensions:

```text
OWNED
DEFINED
TRACEABLE
TRUSTED
SECURE
ADOPTED
RECONCILED
```

The current demo may show `DEFINED` as `GAP` if not every MART column has a description. That is acceptable evidence: the scorecard should surface governance gaps rather than hide them.

## Streamlit Integration

The existing Streamlit app reads:

```sql
SELECT
    DIMENSION,
    NUMERATOR,
    DENOMINATOR,
    SCORE_PCT,
    STATUS,
    DESCRIPTION
FROM GOVERNANCE.CATALOG.CATALOG_SCORECARD
```

The calculation stays in Snowflake SQL; Python only displays the results.

## Troubleshooting

Missing view:
Run `scorecard/00_create_catalog_scorecard_view.sql`.

Missing catalog data:
Run `catalog_app/sql/01_create_catalog_view.sql` before creating the scorecard.

Unexpected `GAP`:
Use `scorecard/01_validate_scorecard.sql` to inspect the underlying evidence sections for `TRUSTED`, `RECONCILED`, `SECURE` and `ADOPTED`.

Zero usage:
ACCESS_HISTORY and QUERY_HISTORY can lag. Verify Account Usage privileges and wait for metadata latency if the app was just queried.
