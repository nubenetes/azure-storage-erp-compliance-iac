#!/usr/bin/env bash
# ==============================================================================
# Script: lock-immutability.sh
# Purpose: Permanently lock an Azure Blob Storage container immutability policy (WORM)
# WARNING: THIS OPERATION IS IRREVERSIBLE.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
CONTAINER=""
FORCE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") -g <resource-group> -s <storage-account> -c <container> [--force]

Options:
  -g, --resource-group NAME    Resource Group name
  -s, --storage-account NAME   Storage Account name
  -c, --container NAME         Container name (e.g., facturas, pedidos)
  --force                      Bypass interactive confirmation prompt
  -h, --help                   Display this help message
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -s|--storage-account)
            STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            usage
            ;;
    esac
done

if [[ -z "$RESOURCE_GROUP" || -z "$STORAGE_ACCOUNT" || -z "$CONTAINER" ]]; then
    echo -e "${RED}Error: Resource group, storage account, and container must be specified.${NC}"
    usage
fi

echo -e "${RED}=================================================================${NC}"
echo -e "${RED}⚠️  CRITICAL WARNING: PERMANENT WORM POLICY LOCK INITIATED       ⚠️${NC}"
echo -e "${RED}=================================================================${NC}"
echo -e "You are about to lock the immutability policy on:"
echo -e "  Storage Account: ${YELLOW}${STORAGE_ACCOUNT}${NC}"
echo -e "  Container:       ${YELLOW}${CONTAINER}${NC}"
echo -e "  Resource Group:  ${YELLOW}${RESOURCE_GROUP}${NC}"
echo ""
echo -e "ONCE LOCKED:"
echo -e "1. Blobs CANNOT be modified, overwritten, or deleted until retention expires."
echo -e "2. The policy CANNOT be removed or shortened."
echo -e "3. NOT EVEN AZURE SUPPORT OR GLOBAL ADMINS CAN UNDO THIS ACTION."
echo -e "${RED}=================================================================${NC}"

# Fetch current policy
echo -e "\n${CYAN}Fetching current policy details...${NC}"
POLICY=$(az storage container immutability-policy show \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --auth-mode login 2>&1) || {
    echo -e "${RED}Error retrieving policy: ${POLICY}${NC}"
    exit 1
}

STATE=$(echo "$POLICY" | jq -r '.state')
DAYS=$(echo "$POLICY" | jq -r '.immutabilityPeriodSinceCreationInDays')
ETAG=$(echo "$POLICY" | jq -r '.etag')

echo -e "Current State:    ${YELLOW}${STATE}${NC}"
echo -e "Retention Period: ${YELLOW}${DAYS} days${NC} (~$(( DAYS / 365 )) years)"

if [[ "$STATE" == "Locked" ]]; then
    echo -e "\n${GREEN}✓ Policy is ALREADY LOCKED. No further action needed.${NC}"
    exit 0
fi

if [[ "$FORCE" != true ]]; then
    echo -e "\nTo confirm that you understand the permanent consequences,"
    read -r -p "type 'CONFIRM-LEGAL-LOCK': " CONFIRMATION
    if [[ "$CONFIRMATION" != "CONFIRM-LEGAL-LOCK" ]]; then
        echo -e "\n${YELLOW}Operation aborted by user. Policy remains UNLOCKED.${NC}"
        exit 0
    fi
fi

echo -e "\n${CYAN}Executing permanent policy lock...${NC}"
az storage container immutability-policy lock \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --if-match "$ETAG" \
    --auth-mode login \
    -o none

echo -e "\n${GREEN}=================================================================${NC}"
echo -e "${GREEN}🔒 Container '${CONTAINER}' is now permanently LOCKED in WORM mode!${NC}"
echo -e "${GREEN}Retention guaranteed for ${DAYS} days.${NC}"
echo -e "${GREEN}=================================================================${NC}"
