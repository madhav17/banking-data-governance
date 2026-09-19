#!/usr/bin/env bash
set -euo pipefail

#chmod +x scripts/upload_raw_to_stage.sh
#./scripts/upload_raw_to_stage.sh



# ============================================================
# Avidia Bank
# Upload all RAW CSV files to Snowflake internal stage
# ============================================================
#
# Usage:
#   ./scripts/upload_raw_to_stage.sh
#
# Optional overrides:
#   CONNECTION=avidia DATA_DIR=data/generated/raw ./scripts/upload_raw_to_stage.sh
#
# Prerequisites:
#   - Snowflake CLI (`snow`) installed and configured
#   - Connection "avidia" exists, unless overridden
#   - RAW.BANKING.STG_BANKING_CSV already exists
#   - DATA_ENGINEER has access to the stage
# ============================================================

CONNECTION="${CONNECTION:-avidia}"
ROLE="${ROLE:-DATA_ENGINEER}"
WAREHOUSE="${WAREHOUSE:-WH_GOVERNANCE_XS}"
DATA_DIR="${DATA_DIR:-data/generated/raw}"
STAGE="@RAW.BANKING.STG_BANKING_CSV"

echo "============================================================"
echo "Avidia RAW CSV Upload"
echo "Connection : ${CONNECTION}"
echo "Role       : ${ROLE}"
echo "Warehouse  : ${WAREHOUSE}"
echo "Data dir   : ${DATA_DIR}"
echo "Stage      : ${STAGE}"
echo "============================================================"

echo
echo "Testing Snowflake connection..."
snow connection test -c "${CONNECTION}"

echo
echo "Uploading branch.csv..."
snow stage copy   "${DATA_DIR}/branch.csv"   "${STAGE}/branch/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading officer.csv..."
snow stage copy   "${DATA_DIR}/officer.csv"   "${STAGE}/officer/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading product.csv..."
snow stage copy   "${DATA_DIR}/product.csv"   "${STAGE}/product/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading customer.csv..."
snow stage copy   "${DATA_DIR}/customer.csv"   "${STAGE}/customer/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading account.csv..."
snow stage copy   "${DATA_DIR}/account.csv"   "${STAGE}/account/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading account_daily_balance.csv..."
snow stage copy   "${DATA_DIR}/account_daily_balance.csv"   "${STAGE}/account_daily_balance/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading card.csv..."
snow stage copy   "${DATA_DIR}/card.csv"   "${STAGE}/card/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading loan.csv..."
snow stage copy   "${DATA_DIR}/loan.csv"   "${STAGE}/loan/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading loan_collateral.csv..."
snow stage copy   "${DATA_DIR}/loan_collateral.csv"   "${STAGE}/loan_collateral/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading transactions.csv..."
snow stage copy   "${DATA_DIR}/transaction.csv"   "${STAGE}/transactions/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Uploading gl_control_total.csv..."
snow stage copy   "${DATA_DIR}/gl_control_total.csv"   "${STAGE}/gl_control_total/"   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"

echo
echo "Verifying files on stage..."
snow sql   -c "${CONNECTION}"   --role "${ROLE}"   --warehouse "${WAREHOUSE}"   -q "LIST ${STAGE};"

echo
echo "============================================================"
echo "All RAW CSV files uploaded successfully."
echo "============================================================"
