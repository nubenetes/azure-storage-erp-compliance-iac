#!/usr/bin/env bash
# ==============================================================================
# Script: rehydrate_archive_blob.sh
# Purpose: Direct Azure Storage REST API call to rehydrate an invoice from Archive tier
# Useful for: Legacy ERP systems, mainframe exports, or automated batch jobs.
# ==============================================================================

set -euo pipefail

STORAGE_ACCOUNT="${1:-sterpspainprod01}"
CONTAINER="${2:-facturas}"
BLOB_NAME="${3:-2022/FAC-2022-1042.pdf}"
PRIORITY="${4:-Standard}" # Standard or High

echo "Obtaining OAuth2 bearer token from Azure CLI..."
BEARER_TOKEN=$(az account get-access-token --resource https://storage.azure.com/ --query accessToken -o tsv)

URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER}/${BLOB_NAME}?comp=tier"

echo "Requesting rehydration of '${BLOB_NAME}' to Cool tier via REST API..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$URL" \
  -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -H "x-ms-version: 2023-11-03" \
  -H "x-ms-access-tier: Cool" \
  -H "x-ms-rehydrate-priority: ${PRIORITY}" \
  -H "Content-Length: 0")

if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "202" ]]; then
    echo "✓ Rehydration request accepted (HTTP $HTTP_STATUS). Blob will transition to Cool tier."
else
    echo "✗ Failed to request rehydration. HTTP response code: $HTTP_STATUS"
    exit 1
fi
