# Banking Data Governance

A Snowflake-based data catalog and metadata-governance implementation for synthetic banking data.

This project is designed as a reproducible take-home implementation of a governed banking data product on **Snowflake Horizon**. The solution focuses on proving that a certified data product is:

> **Owned · Defined · Traceable · Trusted · Secure · Adopted · Reconciled**

The implementation uses Snowflake SQL as the primary language, with dbt for STAGING → MARTS transformations and Python/Streamlit where appropriate.

---

## 1. Objectives

The project demonstrates a metadata-driven governance layer around a synthetic banking data platform.

It covers:

- Synthetic banking data generation
- RAW → STAGING → MARTS architecture
- dbt-based transformations and lineage
- Central governance metadata store
- Data dictionary and banking glossary
- Snowflake object tagging and inheritance
- Critical Data Elements (CDEs)
- Sensitive-data classification
- Custom classifier
- Classification steward review workflow
- Tag-based masking
- Row-level security
- Six data-quality dimensions
- GL reconciliation
- Table- and column-level lineage
- External lineage representation
- Streamlit data catalog
- ACCESS_HISTORY-based adoption metrics
- Evidence-based data-product certification
- AI-assisted documentation workflow
- Seven-word governance scorecard
- Assessment of upcoming Snowflake catalog/metadata capabilities

---

## 2. Assignment Alignment

| Block | Area | Primary outcome |
|---|---|---|
| 0 | Setup & Data | Trial, roles, warehouse, synthetic banking data, RAW/STAGING/MARTS |
| 1 | Metadata Foundation | Metadata store, dictionary, tags, glossary, 25 CDEs |
| 2 | Classification & Protection | Classification, custom classifier, review workflow, masking, RLS |
| 3 | Trust | Six DQ checks and reconciliation |
| 4 | Lineage | Native lineage, external lineage representation, impact analysis |
| 5 | Catalog Experience | Streamlit catalog, certification procedure, AI-generated descriptions |
| 6 | What Is Coming | Snowflake catalog/metadata roadmap and architecture implications |
| 7 | Package | README, evidence pack, hours log, AI disclosure and walkthrough |

---

## 3. Architecture

```text
                         SYNTHETIC BANKING DATA
                                  |
                                  v
                           +--------------+
                           |     RAW      |
                           +------+-------+
                                  |
                                  v
                       +----------------------+
                       |       STAGING        |
                       |         dbt          |
                       +----------+-----------+
                                  |
                                  v
                       +----------------------+
                       |        MARTS         |
                       |  Certified Products  |
                       +----------+-----------+
                                  |
              +-------------------+-------------------+
              |                   |                   |
              v                   v                   v
        +-----------+       +-----------+       +-----------+
        | CATALOG / |       | SECURITY  |       | TRUST / DQ|
        | METADATA  |       |           |       |           |
        +-----------+       +-----------+       +-----------+
              |                   |                   |
              |             Classification           |
              |                   |                   |
              |              Masking / RLS            |
              |                   |                   |
              +-------------------+-------------------+
                                  |
                                  v
                            +-----------+
                            | LINEAGE   |
                            +-----+-----+
                                  |
                                  v
                           +--------------+
                           | CERTIFICATION|
                           +------+-------+
                                  |
                                  v
                           +--------------+
                           |  SCORECARD   |
                           +------+-------+
                                  |
                                  v
                           +--------------+
                           |  STREAMLIT   |
                           |   CATALOG    |
                           +--------------+
```

### Snowflake logical layout

```text
RAW
└── source-aligned banking objects

ANALYTICS
├── STAGING
└── MARTS

GOVERNANCE
├── CATALOG
├── TAGS
├── EVIDENCE
└── DQ
```

---

## 4. Roles

The implementation uses separate roles to demonstrate least-privilege access patterns:

- `DATA_OWNER`
- `DATA_STEWARD`
- `DEPOSITS_ANALYST`
- `BRANCH_HUDSON`
- `SVC_PIPELINE`

Automation should use the service identity rather than `ACCOUNTADMIN`.

---

## 5. Banking Data Model

The synthetic source model includes:

- Customers (persons and businesses)
- Customer address/contact information
- Deposit accounts
- Daily account balances
- Transactions
- Cards
- Loans
- Loan collateral
- Loan payments
- General-ledger control totals
- Branch reference
- Product reference
- Officer reference

The implementation targets:

- **3,000+ customers**
- **20+ objects**
- Synthetic data generated from committed code
- Repeatable generation using a fixed seed where applicable

### Primary certified mart

The primary certified product is:

```text
MARTS.DEPOSITS_DAILY
```

This is the main business dataset used to demonstrate ownership, metadata, CDEs, classification, data quality, reconciliation, lineage, certification and adoption.

---

## 6. Sensitive Data Strategy

Sensitive columns are deliberately included in two categories.

### Clearly identifiable sensitive columns

Examples:

```text
TAX_ID
DATE_OF_BIRTH
EMAIL
PHONE
CARD_NUMBER
```

### Deliberately misleading columns

At least four fields contain sensitive values under innocent names, for example:

```text
CUST_REF
MEMO
REFERENCE
NOTES
```

These fields are intended to test whether classification relies only on column names.

A sealed ground-truth file is maintained before classification:

```text
data/sealed_sensitive_columns.json
```

---

## 7. Metadata and Governance Model

The governance layer separates technical metadata from business governance.

### Core metadata

The metadata store captures items such as:

- database
- schema
- object
- column
- data type
- description
- owner
- steward
- certification
- last refresh
- classification
- CDE status
- usage

### Governance tags

The core taxonomy is:

```text
DOMAIN
LAYER
CERTIFICATION
DATA_OWNER
DATA_STEWARD
CDE
CLASSIFICATION
SOURCE_SYSTEM
```

Tags are applied from metadata/configuration rather than manual UI operations. Where appropriate, inheritance is used to reduce repetitive assignment.

---

## 8. Business Glossary

The implementation includes a governed banking glossary with at least 10 terms.

Examples:

- Customer
- Deposit Account
- Available Balance
- Ledger Balance
- Transaction
- Branch
- Loan
- Collateral
- Credit Grade
- Customer Risk

Glossary terms are linked to physical data elements to connect business meaning to implementation.

---

## 9. Critical Data Elements (CDEs)

At least **25 CDEs** are registered.

Each CDE is associated with:

- CDE identifier
- Physical object
- Physical column
- CDE tier
- Owner
- Steward
- Business definition

The design is intended to make CDEs discoverable through Snowflake tag references and related governance metadata.

---

## 10. Sensitive-Data Classification

The classification workflow intentionally separates **detection** from **enforcement**.

```text
Snowflake classification
        |
        v
Detected classification
        |
        v
Steward review queue
        |
        +------> REJECTED
        |
        v
    APPROVED
        |
        v
Enterprise CLASSIFICATION tag
        |
        v
Security policy
```

The implementation distinguishes Snowflake's system classifications:

```text
SNOWFLAKE.CORE.SEMANTIC_CATEGORY
SNOWFLAKE.CORE.PRIVACY_CATEGORY
```

from enterprise governance tags such as:

```text
CLASSIFICATION = CONFIDENTIAL
CLASSIFICATION = RESTRICTED
```

Automatically detected classifications are not treated as confirmed classifications until the review workflow approves them.

---

## 11. Custom Classifier

A banking-specific custom classifier is included for one supported pattern, such as:

- ABA routing number
- account-number format
- card PAN-like format

The custom classifier demonstrates how domain-specific knowledge can complement native classification.

---

## 12. Classification Evaluation

Classification results are compared against:

```text
data/sealed_sensitive_columns.json
```

The evaluation records:

```text
True Positive
False Positive
False Negative
```

and calculates:

```text
Precision = TP / (TP + FP)
Recall    = TP / (TP + FN)
```

Material misses are documented and explained.

This separates classification accuracy from security enforcement.

---

## 13. Protection Model

### Tag-based masking

The enterprise `CLASSIFICATION` tag is used as the governance signal for tag-based masking policies.

Target behavior:

| Role | Sensitive data visibility |
|---|---|
| `DEPOSITS_ANALYST` | Masked |
| `DATA_STEWARD` | Partially masked |
| `DATA_OWNER` | Clear |
| `BRANCH_HUDSON` | Branch-scoped rows |

Sensitive fields include tax ID, date of birth, email, phone and card number.

### Row-level security

A branch-scoped row access policy is used to demonstrate:

```text
BRANCH_HUDSON
       |
       v
Permitted branch
       |
       v
Only authorized rows returned
```

### Policy gap control

A gap query identifies sensitive columns without the required policy.

Expected result:

```text
UNPROTECTED SENSITIVE COLUMNS
0 rows
```

---

## 14. Data Quality and Trust

The certified mart is evaluated across six dimensions:

| Dimension | Example control |
|---|---|
| Completeness | CDE is not null |
| Uniqueness | Business key is unique |
| Validity | Tax-ID / status format is valid |
| Consistency | Account → customer relationship exists |
| Timeliness | Latest business date is present |
| Accuracy | Mart deposits reconcile to GL totals |

Results are written to:

```text
GOVERNANCE.DQ.DQ_RESULT
```

Example fields:

```text
RUN_ID
OBJECT_NAME
CHECK_NAME
DIMENSION
EXPECTED_VALUE
ACTUAL_VALUE
THRESHOLD
STATUS
RUN_TIMESTAMP
```

### Accuracy / reconciliation

```text
MART deposit balances
        =
GL control totals
```

within the required **$1** tolerance.

A reconciliation failure is treated as a certification blocker.

---

## 15. Lineage

Lineage is captured at table and column level.

```text
RAW
  |
  v
STAGING
  |
  v
MART
  |
  v
Downstream consumer
```

The implementation uses Snowflake metadata and lineage capabilities where available, including:

- lineage table function
- `OBJECT_DEPENDENCIES`
- `ACCESS_HISTORY`

A snapshot table is maintained for reproducible impact analysis.

### External lineage metadata

The design covers two metadata-only external endpoint rows:

```text
LEGACY_TALEND_DEPOSIT_LOAD -> RAW
MART -> POWER_BI_DEPOSITS_MODEL
```

The documented fallback table is:

```text
GOVERNANCE.CATALOG.LINEAGE_EDGE_EXTERNAL
```

`LEGACY_TALEND_DEPOSIT_LOAD` and `POWER_BI_DEPOSITS_MODEL` are string
identifiers in that table only. No Talend or Power BI resources are created.

---

## 16. Impact Analysis

The catalog supports questions such as:

> If a source column changes, what downstream data is affected and who owns it?

Example:

```text
RAW.CUSTOMER.EMAIL
        |
        v
STAGING.STG_CUSTOMER.EMAIL
        |
        v
MART.CUSTOMER_360.EMAIL
        |
        v
External BI endpoint metadata
```

The impact query should return affected objects together with owner/steward information.

---

## 17. Certification Framework

The central control is exposed conceptually as:

```text
CERTIFY(<object>)
```

Certification checks include:

1. Owner exists
2. Steward exists
3. Description coverage is sufficient
4. CDE tagging is present where required
5. Classification is confirmed
6. Sensitive columns are policy-covered
7. Six DQ checks pass

### Outcomes

```text
ALL REQUIRED CONTROLS PASS
        |
        v
CERTIFICATION = CERTIFIED
```

or:

```text
ANY CONTROL FAILS
        |
        v
CERTIFICATION = REFUSED
        |
        v
Reasons logged
```

The evidence pack demonstrates both one successful and one refused certification.

---

## 18. Catalog Application

A one-page Streamlit-in-Snowflake catalog provides a searchable view over the governance metadata.

The catalog exposes:

- Search
- Owner
- Steward
- Certification
- CDE flag
- Classification
- Description
- Upstream sources
- Last refresh
- Quality result
- Usage since creation

The UI is intentionally lightweight; the underlying metadata and control queries are the main deliverable.

---

## 19. Usage / Adoption

Adoption is measured using `ACCESS_HISTORY`.

Because a new trial starts without historical project usage, the implementation reports usage since project creation rather than assuming older history.

Representative queries are executed using relevant roles so that usage evidence exists for the walkthrough.

Example metrics:

```text
Query count
Distinct roles
Last access
```

---

## 20. AI-Assisted Documentation

Undocumented columns can receive AI-generated description drafts.

Workflow:

```text
Undocumented column
        |
        v
Snowflake Cortex / approved LLM
        |
        v
Draft description
        |
        v
Approval queue
        |
   +----+----+
   |         |
Approve    Reject
   |
   v
COMMENT ON COLUMN
```

AI-generated text is not written directly into metadata without steward approval.

All AI assistance used during development is disclosed in:

```text
AI_DISCLOSURE.md
```

---

## 21. Seven-Word Governance Scorecard

The final scorecard measures:

```text
Owned
Defined
Traceable
Trusted
Secure
Adopted
Reconciled
```

Each score should have an explicit numerator and denominator.

Example:

```text
Trusted = passed DQ dimensions / required DQ dimensions
```

The scorecard is queryable and evidence-backed rather than manually maintained.

---

## 22. Repository Structure

```text
banking-data-governance/

├── README.md
├── HOURS.md
├── AI_DISCLOSURE.md
│
├── setup/
│   ├── 00_roles.sql
│   ├── 01_databases.sql
│   ├── 02_warehouses.sql
│   └── 03_grants.sql
│
├── data/
│   ├── generator/
│   ├── dictionary.csv
│   ├── sealed_sensitive_columns.json
│   └── seeds/
│
├── metadata/
│   ├── tables.sql
│   ├── harvest.sql
│   ├── dictionary_loader.sql
│   ├── glossary.sql
│   └── cde.sql
│
├── classification/
│   ├── profile.sql
│   ├── custom_classifier.sql
│   ├── tag_map.sql
│   ├── review_queue.sql
│   └── review_procedures.sql
│
├── protection/
│   ├── tags.sql
│   ├── masking_policies.sql
│   ├── row_access.sql
│   └── coverage.sql
│
├── dq/
│   ├── dq_result.sql
│   ├── completeness.sql
│   ├── uniqueness.sql
│   ├── validity.sql
│   ├── consistency.sql
│   ├── timeliness.sql
│   └── accuracy.sql
│
├── lineage/
│   ├── lineage_snapshot.sql
│   ├── external_lineage.sql
│   └── impact_analysis.sql
│
├── certification/
│   └── certify.sql
│
├── catalog_app/
│   └── streamlit_app.py
│
├── scorecard/
│   └── scorecard.sql
│
├── ai/
│   └── description_generation.sql
│
└── evidence/
    ├── block0/
    ├── block1/
    ├── block2/
    ├── block3/
    ├── block4/
    └── block5/
```

---

## 23. Reproducibility

All changes should be executable from code and committed to Git.

Manual metadata changes through the Snowflake UI are intentionally avoided.

Expected rebuild flow:

```text
1. Create Snowflake environment
2. Create roles and grants
3. Create databases / schemas / warehouse
4. Generate synthetic data
5. Load RAW
6. Build STAGING / MARTS
7. Build metadata foundation
8. Configure tags
9. Configure classification
10. Review/confirm classifications
11. Configure masking / RLS
12. Run DQ checks
13. Build lineage snapshot
14. Register external lineage
15. Generate catalog metadata
16. Run certification
17. Generate scorecard
18. Deploy Streamlit
19. Generate evidence
```

The README is intended to remain the single source of truth for the run order.

---

## 24. Known Constraints and Assumptions

- Enterprise edition is required for the requested governance capabilities.
- An Azure Snowflake region is preferred by the assignment.
- Synthetic data only.
- No client/employer account is used.
- `ACCOUNT_USAGE` can lag; use `INFORMATION_SCHEMA` for immediate checks where appropriate.
- Classification depends on data being present and the configured minimum object age.
- Automatically detected classifications are kept separate from confirmed classifications.
- Cortex availability is region-dependent; use the assignment's permitted fallback if unavailable.
- A new trial has no project usage history before creation, so adoption is measured from project creation onward.

---

## 25. Validation Strategy

The project is not considered complete merely because objects exist. Each major capability must have a queryable proof.

```text
Metadata coverage         -> query
CDE coverage              -> TAG_REFERENCES
Classification            -> classification result query
Classification quality    -> precision / recall
Policy coverage           -> gap query
Masking                   -> role-based test queries
RLS                       -> branch-role queries
DQ                        -> DQ_RESULT
Reconciliation            -> GL comparison
Lineage                   -> lineage query
Adoption                  -> ACCESS_HISTORY
Certification             -> CERTIFY() result
Scorecard                 -> seven-word score query
```

A control that cannot be demonstrated through evidence is treated as incomplete.

---

## 26. Live Review Scenario

The architecture is designed to support the expected live exercise: add a new Critical Data Element and demonstrate how it flows through governance controls.

```text
New CDE
  |
  v
Metadata / CDE registration
  |
  v
Tagging
  |
  v
Classification / confirmation
  |
  v
Security policy
  |
  v
DQ coverage
  |
  v
Certification
  |
  v
Scorecard
```

The objective is to demonstrate that the solution is **metadata-driven and reusable**, rather than hard-coded only for the original dataset.

---

## 27. Key Design Principles

### Separate detection from enforcement

```text
Classification
    !=
Governance decision
    !=
Security enforcement
```

### Treat certification as a control

```text
Evidence
   ->
Decision
   ->
Certified / Refused
```

### Prefer metadata-driven automation

New objects and columns should require configuration/metadata changes where possible, rather than repeated manual policy coding.

### Prove controls with queries

A control that cannot be demonstrated through evidence is treated as incomplete.

### Keep the implementation proportionate

The assignment is constrained to approximately 10 hours. The target is a coherent vertical slice rather than a full enterprise platform.

---

## 28. Development Notes

This repository is being built incrementally.

During implementation:

- Validate Snowflake syntax and feature availability against current documentation.
- Review and test generated code before commit.
- Treat AI-generated code as a draft, not an authority.
- Record important design decisions and assumptions.
- Record hours in `HOURS.md`.
- Record AI assistance in `AI_DISCLOSURE.md`.

---

## 29. Evidence Checklist

### Data

- [ ] 3,000+ customers
- [ ] 20+ objects
- [ ] RAW / STAGING / MARTS
- [ ] Vendor-style dictionary
- [ ] Sealed sensitive-column list
- [ ] Four or more deliberately misleading sensitive columns

### Metadata

- [ ] Metadata store
- [ ] Dictionary loader
- [ ] Description coverage
- [ ] Governance taxonomy
- [ ] 10 glossary terms
- [ ] 25 CDEs

### Classification & Security

- [ ] Classification profile
- [ ] Auto-tagging
- [ ] Custom classifier
- [ ] Precision / recall
- [ ] Miss analysis
- [ ] Review queue
- [ ] Approve / reject workflow
- [ ] Masking across three roles
- [ ] Branch RLS
- [ ] Sensitive policy gap report = 0 rows

### Trust

- [ ] Completeness
- [ ] Uniqueness
- [ ] Validity
- [ ] Consistency
- [ ] Timeliness
- [ ] Accuracy / GL reconciliation

### Lineage

- [ ] Table lineage
- [ ] Column lineage
- [ ] Upstream lineage
- [ ] Downstream lineage
- [ ] Talend external endpoint metadata
- [ ] Power BI external endpoint metadata
- [ ] Lineage snapshot
- [ ] Worked deposit trace
- [ ] Impact analysis

### Catalog & Certification

- [ ] Streamlit catalog
- [ ] ACCESS_HISTORY adoption
- [ ] `CERTIFY(object)`
- [ ] Successful certification evidence
- [ ] Refused certification evidence
- [ ] AI description approval queue
- [ ] Seven-word scorecard

### Submission

- [ ] README
- [ ] Evidence pack
- [ ] HOURS.md
- [ ] AI_DISCLOSURE.md
- [ ] Block 6 write-up
- [ ] 10-minute walkthrough
- [ ] Fresh-trial rebuild tested

---

## 30. Final Architecture Statement

The solution is designed as a **metadata-driven governance control plane around a Snowflake data product**.

The core principle is:

```text
Detect
  ↓
Classify
  ↓
Review
  ↓
Govern
  ↓
Protect
  ↓
Measure quality
  ↓
Trace lineage
  ↓
Certify
  ↓
Expose through catalog
```

The goal is not merely to demonstrate Snowflake features individually, but to show how those capabilities combine into an auditable and repeatable process for determining whether a banking data product can be trusted and consumed.
