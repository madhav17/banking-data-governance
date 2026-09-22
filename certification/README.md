# Block 5 - Certification

This block implements the minimal `CERTIFY(object)` functionality required by the take-home.

The procedure reuses evidence already produced by metadata, classification, protection and DQ. It does not rebuild those systems and it does not introduce a certification rules framework.

## Objects Created

```text
GOVERNANCE.EVIDENCE.CERTIFICATION_LOG
GOVERNANCE.EVIDENCE.CERTIFY(OBJECT_FQN VARCHAR)
```

The existing tag used for successful certification is:

```text
GOVERNANCE.TAGS.CERTIFICATION
```

No duplicate certification tag or certification registry table is created.

## Primary Candidate

The success candidate is:

```text
ANALYTICS.MARTS.DEPOSITS_DAILY
```

It is the primary certified data product because it has:

- owner/steward metadata;
- MART comments and column descriptions;
- CDE tags;
- confirmed classification where required;
- policy coverage for sensitive columns;
- six DQ checks;
- GL reconciliation evidence.

## Seven Gates

`CERTIFY(object)` evaluates exactly these seven gates:

| Gate | Requirement | Evidence source |
| --- | --- | --- |
| Owner | target object has `DATA_OWNER` metadata | effective `GOVERNANCE.TAGS.DATA_OWNER` tag |
| Steward | target object has `DATA_STEWARD` metadata | effective `GOVERNANCE.TAGS.DATA_STEWARD` tag |
| Description | object and all exposed columns have descriptions | Snowflake `INFORMATION_SCHEMA` comments |
| CDE | relevant registered CDEs are tagged | `GOVERNANCE.CATALOG.CDE_REGISTRY` plus `GOVERNANCE.TAGS.CDE` |
| Classification | required sensitive MART columns have confirmed classification | approved classification review / desired tag state |
| Policy | required sensitive columns have masking policy coverage | existing protection policy-reference evidence |
| DQ | latest run has exactly six dimensions and all six pass | `GOVERNANCE.DQ.DQ_RESULT` |

Lineage is intentionally not a certification gate. Lineage is implemented separately in Block 4 and is visible in the catalog/scorecard, but the certification procedure follows the explicit gate list above.

## PASS Behavior

When all gates pass, the procedure:

1. applies `GOVERNANCE.TAGS.CERTIFICATION = 'CERTIFIED'` to the target object;
2. inserts one `CERTIFIED` row into `GOVERNANCE.EVIDENCE.CERTIFICATION_LOG`;
3. returns a structured VARIANT response containing each gate status.

Example call:

```sql
CALL GOVERNANCE.EVIDENCE.CERTIFY('ANALYTICS.MARTS.DEPOSITS_DAILY');
```

Expected outcome:

```text
CERTIFIED
```

## REFUSED Behavior

When any gate fails, the procedure:

1. does not set `CERTIFICATION = CERTIFIED`;
2. inserts one `REFUSED` row into `GOVERNANCE.EVIDENCE.CERTIFICATION_LOG`;
3. returns all failure reasons to the caller.

Refusal is a valid business outcome, not a technical error.

The current refusal demonstration uses:

```text
ANALYTICS.MARTS.CUSTOMER_360
```

This object naturally lacks the complete six-dimension DQ evidence required for certification.

## Files

```text
certification/
├── 00_run_setup.sql
├── 00_permissions.sql
├── 01_create_certification_log.sql
├── 02_create_certify_procedure.sql
├── 03_demonstrate_certification.sql
├── 04_validate_certification.sql
├── 05_validations.sql
└── README.md
```

`05_validations.sql` is an additional validation helper and is included by `00_run_setup.sql`.

## Execution Order

Run from the repository root:

```sh
snow sql -c avidia -f certification/00_run_setup.sql
```

`00_run_setup.sql` sources permissions, log creation, procedure creation, demonstration and both validation scripts. Run individual files only when debugging a specific certification step.

## Demonstration Script

`03_demonstrate_certification.sql` demonstrates both required outcomes:

1. certifies `ANALYTICS.MARTS.DEPOSITS_DAILY`;
2. refuses `ANALYTICS.MARTS.CUSTOMER_360`.

The script does not damage or modify `DEPOSITS_DAILY` to force a refusal.

## Validation Evidence

`04_validate_certification.sql` proves:

- the procedure exists;
- the log table exists;
- `DEPOSITS_DAILY` has owner and steward metadata;
- description coverage is complete;
- CDE evidence is present;
- confirmed classification evidence exists where required;
- policy gap count is zero;
- the latest DQ run has six dimensions and all pass;
- `DEPOSITS_DAILY` has `CERTIFICATION = CERTIFIED`;
- at least one refused outcome exists;
- refused outcomes include non-empty failure reasons.

## Downstream Consumers

Certification evidence is reused by:

- `GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG`;
- `GOVERNANCE.CATALOG.CATALOG_SCORECARD`;
- the Streamlit catalog object details and scorecard tab.
