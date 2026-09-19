#!/usr/bin/env bash
set -euo pipefail

#chmod +x scripts/upload_vendor_dictionary_to_stage.sh
#./scripts/upload_vendor_dictionary_to_stage.sh

# ============================================================
# Avidia Bank
# Upload vendor_dictionary.csv to Snowflake internal stage.
# ============================================================
#
# Recommended repo location:
#   scripts/upload_vendor_dictionary_to_stage.sh
#
# Usage:
#   chmod +x scripts/upload_vendor_dictionary_to_stage.sh
#   ./scripts/upload_vendor_dictionary_to_stage.sh
#
# Optional overrides:
#   CONNECTION=avidia ROLE=DATA_GOVERNANCE_ADMIN \
#   DATA_FILE=data/vendor_dictionary.csv \
#   ./scripts/upload_vendor_dictionary_to_stage.sh
#
# Prerequisites:
#   - Snowflake CLI (`snow`) installed and configured
#   - Connection "avidia" exists, unless overridden
#   - GOVERNANCE.CATALOG exists
#   - DATA_GOVERNANCE_ADMIN has CREATE STAGE / CREATE FILE FORMAT
#     on GOVERNANCE.CATALOG and DML on DATA_DICTIONARY
# ============================================================

CONNECTION="${CONNECTION:-avidia}"
ROLE="${ROLE:-DATA_GOVERNANCE_ADMIN}"
WAREHOUSE="${WAREHOUSE:-WH_GOVERNANCE_XS}"
DATA_FILE="${DATA_FILE:-data/vendor_dictionary.csv}"
STAGE="@GOVERNANCE.CATALOG.DICTIONARY_STAGE"

if [[ ! -f "${DATA_FILE}" ]]; then
  echo "ERROR: Dictionary file not found: ${DATA_FILE}" >&2
  exit 1
fi

echo "============================================================"
echo "Avidia Vendor Dictionary Upload"
echo "Connection      : ${CONNECTION}"
echo "Role            : ${ROLE}"
echo "Warehouse       : ${WAREHOUSE}"
echo "Data file       : ${DATA_FILE}"
echo "Stage           : ${STAGE}"
echo "============================================================"

echo
echo "Testing Snowflake connection..."
snow connection test -c "${CONNECTION}"

echo
echo "Ensuring dictionary CSV file format and stage exist..."
snow sql \
  -c "${CONNECTION}" \
  --role "${ROLE}" \
  --warehouse "${WAREHOUSE}" \
  -q "
CREATE FILE FORMAT IF NOT EXISTS GOVERNANCE.CATALOG.DICTIONARY_CSV_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
  TRIM_SPACE = TRUE
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', 'NULL');

CREATE STAGE IF NOT EXISTS GOVERNANCE.CATALOG.DICTIONARY_STAGE
  FILE_FORMAT = GOVERNANCE.CATALOG.DICTIONARY_CSV_FORMAT
  COMMENT = 'Internal stage for committed vendor data dictionary files';
"

echo
echo "Uploading vendor_dictionary.csv..."
snow stage copy \
  "${DATA_FILE}" \
  "${STAGE}/" \
  -c "${CONNECTION}" \
  --role "${ROLE}" \
  --warehouse "${WAREHOUSE}"

echo
echo "Verifying dictionary file on stage..."
snow sql \
  -c "${CONNECTION}" \
  --role "${ROLE}" \
  --warehouse "${WAREHOUSE}" \
  -q "LIST ${STAGE};"

echo
echo "============================================================"
echo "Vendor dictionary uploaded successfully."
echo "Run metadata/13_load_data_dictionary.sql separately to load it."
echo "============================================================"
