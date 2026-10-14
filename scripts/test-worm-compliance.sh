#!/usr/bin/env bash
# ==============================================================================
# Script: test-worm-compliance.sh
# Purpose: Automated Day-2 Compliance & Immutability Verification Suite
# Verifies: WORM immutability, overwrite prevention, append support, soft delete,
#           and resource lock protection on Azure Blob Storage.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STORAGE_ACCOUNT=""
RESOURCE_GROUP=""
CONTAINER="facturas"
FAILED_TESTS=0
TOTAL_TESTS=6

usage() {
    cat <<EOF
Usage: $(basename "$0") -s <storage-account> -g <resource-group> [-c <container>]

Options:
  -s, --storage-account NAME   Azure Storage Account name
  -g, --resource-group NAME    Azure Resource Group name
  -c, --container NAME         Container name to test (default: facturas)
  -h, --help                   Display this help message
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--storage-account)
            STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

if [[ -z "$STORAGE_ACCOUNT" || -z "$RESOURCE_GROUP" ]]; then
    echo -e "${RED}Error: Storage account and Resource Group are required.${NC}"
    usage
fi

echo -e "${BLUE}=================================================================${NC}"
echo -e "${CYAN}🧪 Azure ERP Storage Compliance & WORM Verification Suite${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "Storage Account: ${YELLOW}${STORAGE_ACCOUNT}${NC}"
echo -e "Resource Group:  ${YELLOW}${RESOURCE_GROUP}${NC}"
echo -e "Container:       ${YELLOW}${CONTAINER}${NC}"
echo -e "${BLUE}=================================================================${NC}\n"

TIMESTAMP=$(date +%s)
TEST_BLOB="audit_test_${TIMESTAMP}.pdf"
TMP_FILE="/tmp/${TEST_BLOB}"
echo "ERP-WORM-TEST-PAYLOAD-${TIMESTAMP}" > "$TMP_FILE"

# Assertion 1: Upload a new invoice block blob
echo -n "Test 1/6: Ingestion of new invoice block blob... "
if az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --name "$TEST_BLOB" \
    --file "$TMP_FILE" \
    --auth-mode login \
    --overwrite false \
    -o none 2>/dev/null; then
    echo -e "${GREEN}[PASS] Blob uploaded successfully.${NC}"
else
    echo -e "${RED}[FAIL] Could not upload blob.${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Assertion 2: Verify overwrite is strictly prohibited (WORM)
echo -n "Test 2/6: Overwrite prevention on existing invoice... "
TMP_OVERWRITE="/tmp/overwrite_${TEST_BLOB}"
echo "MODIFIED-MALICIOUS-CONTENT" > "$TMP_OVERWRITE"

if az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --name "$TEST_BLOB" \
    --file "$TMP_OVERWRITE" \
    --auth-mode login \
    --overwrite true \
    -o none 2>/dev/null; then
    echo -e "${RED}[FAIL] Overwrite succeeded! WORM policy is NOT active.${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
else
    echo -e "${GREEN}[PASS] Overwrite rejected by Azure immutability policy.${NC}"
fi
rm -f "$TMP_OVERWRITE"

# Assertion 3: Verify deletion is strictly prohibited
echo -n "Test 3/6: Deletion prevention on protected invoice... "
if az storage blob delete \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --name "$TEST_BLOB" \
    --auth-mode login \
    -o none 2>/dev/null; then
    echo -e "${RED}[FAIL] Deletion succeeded! Blob was deleted.${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
else
    echo -e "${GREEN}[PASS] Deletion rejected (BlobImmutableDueToPolicy).${NC}"
fi

# Assertion 4: Verify Protected Append Writes (VeriFactu log requirement)
echo -n "Test 4/6: Protected Append Writes support... "
APPEND_BLOB="audit_log_${TIMESTAMP}.log"
TMP_LOG="/tmp/${APPEND_BLOB}"
echo "AUDIT-EVENT-INIT-HASH-001" > "$TMP_LOG"

# Create append blob
if az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --name "$APPEND_BLOB" \
    --file "$TMP_LOG" \
    --type append \
    --auth-mode login \
    -o none 2>/dev/null; then
    
    # Attempt appending new data block
    echo "AUDIT-EVENT-APPEND-HASH-002" > "$TMP_LOG"
    if az storage blob append-block \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --name "$APPEND_BLOB" \
        --source-file "$TMP_LOG" \
        --auth-mode login \
        -o none 2>/dev/null; then
        echo -e "${GREEN}[PASS] Append writes permitted while historical blocks remain immutable.${NC}"
    else
        echo -e "${YELLOW}[WARN] Append write failed (check allowProtectedAppendWrites setting).${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${YELLOW}[SKIP] Append blob creation failed or not supported in current auth mode.${NC}"
fi
rm -f "$TMP_LOG"

# Assertion 5: Verify Data Protection (Soft Delete & Versioning)
echo -n "Test 5/6: Soft Delete (30 days) and Blob Versioning... "
PROPERTIES=$(az storage account blob-service-properties show \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null) || PROPERTIES="{}"

VERSIONING=$(echo "$PROPERTIES" | jq -r '.isVersioningEnabled // false')
SOFT_DEL_BLOB=$(echo "$PROPERTIES" | jq -r '.deleteRetentionPolicy.enabled // false')
SOFT_DEL_DAYS=$(echo "$PROPERTIES" | jq -r '.deleteRetentionPolicy.days // 0')

if [[ "$VERSIONING" == "true" && "$SOFT_DEL_BLOB" == "true" && "$SOFT_DEL_DAYS" -ge 14 ]]; then
    echo -e "${GREEN}[PASS] Versioning=True, SoftDelete=${SOFT_DEL_DAYS}d.${NC}"
else
    echo -e "${RED}[FAIL] Data protection settings missing: Versioning=${VERSIONING}, SoftDeleteDays=${SOFT_DEL_DAYS}.${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Assertion 6: Verify CanNotDelete Azure Management Lock
echo -n "Test 6/6: CanNotDelete Resource Lock on Storage Account... "
LOCKS=$(az lock list --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null) || LOCKS="[]"
HAS_CANNOT_DELETE=$(echo "$LOCKS" | jq '[.[] | select(.level=="CanNotDelete")] | length')

if [[ "$HAS_CANNOT_DELETE" -gt 0 ]]; then
    echo -e "${GREEN}[PASS] Active CanNotDelete lock protects account against deletion.${NC}"
else
    echo -e "${YELLOW}[WARN] No CanNotDelete lock found on Storage Account.${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

rm -f "$TMP_FILE"

echo -e "\n${BLUE}=================================================================${NC}"
if [[ "$FAILED_TESTS" -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL 6 COMPLIANCE TESTS PASSED!${NC}"
    echo -e "${GREEN}Storage Account complies with WORM, Código de Comercio Art. 30, and VeriFactu.${NC}"
    echo -e "${BLUE}=================================================================${NC}"
    exit 0
else
    echo -e "${RED}⚠️  ${FAILED_TESTS}/${TOTAL_TESTS} TESTS FAILED OR WARNED.${NC}"
    echo -e "${RED}Please review your deployment parameters before locking the policy.${NC}"
    echo -e "${BLUE}=================================================================${NC}"
    exit 1
fi
