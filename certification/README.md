# Block 5 - Certification

`GOVERNANCE.EVIDENCE.CERTIFY(object)` is the minimal certification control for
the take-home. It reuses evidence from the previous blocks rather than creating a
new rule framework.

## Candidate

`ANALYTICS.MARTS.DEPOSITS_DAILY` is the primary certification candidate because
it is the deposit mart with completed DQ evidence and GL reconciliation.

## Gates

CERTIFY evaluates exactly seven gates:

1. `DATA_OWNER` metadata exists.
2. `DATA_STEWARD` metadata exists.
3. Native object and column description coverage is 100%.
4. Relevant registered CDEs are tagged with `GOVERNANCE.TAGS.CDE`.
5. Steward-confirmed classification tags are present where required.
6. Sensitive classified columns have active policy coverage.
7. The latest DQ run has exactly six dimensions and all six checks pass.

Lineage is intentionally not a certification gate. Block 4 proves traceability,
but the specification lists the seven gates above for `CERTIFY(object)`.

## Evidence Sources

- Ownership/stewardship: native tags from `GOVERNANCE.TAGS.DATA_OWNER` and
  `GOVERNANCE.TAGS.DATA_STEWARD`.
- Descriptions: `ANALYTICS.INFORMATION_SCHEMA.TABLES` and
  `ANALYTICS.INFORMATION_SCHEMA.COLUMNS`.
- CDEs: `GOVERNANCE.CATALOG.CDE_REGISTRY` plus native `CDE` column tags.
- Classification: steward-approved `GOVERNANCE.CATALOG.TAG_ASSIGNMENT` rows
  where `SOURCE_TYPE = 'CLASSIFICATION_REVIEW'`.
- Policy coverage: `ANALYTICS.INFORMATION_SCHEMA.POLICY_REFERENCES`.
- DQ: latest `GOVERNANCE.DQ.DQ_RESULT` run for the object.

## Behavior

If every gate passes, CERTIFY applies:

```sql
GOVERNANCE.TAGS.CERTIFICATION = 'CERTIFIED'
```

to the target object and writes one `CERTIFIED` row to
`GOVERNANCE.EVIDENCE.CERTIFICATION_LOG`.

If any gate fails, CERTIFY does not modify the certification tag. It writes one
`REFUSED` row with failure reasons and returns the same reasons to the caller.
Refusal is a business outcome, not a technical exception.

## Demonstration

`03_demonstrate_certification.sql` prepares missing current-state MART evidence
for `DEPOSITS_DAILY` by applying native comments and CDE tags, then calls
`CERTIFY`.

It then calls `CERTIFY` for `ANALYTICS.MARTS.CUSTOMER_360`. That object
naturally lacks DQ evidence, so it demonstrates a refused outcome without
damaging the successful certified mart.

## Execution Order

```bash
snow sql -c avidia -f certification/00_permissions.sql
snow sql -c avidia -f certification/01_create_certification_log.sql
snow sql -c avidia -f certification/02_create_certify_procedure.sql
snow sql -c avidia -f certification/03_demonstrate_certification.sql
snow sql -c avidia -f certification/04_validate_certification.sql
```
