#!/usr/bin/env bash
# ==============================================================================
# Script: destroy.sh
# Purpose: Safe cleanup script for testing environments (removes lock first)
# NOTE: If a WORM policy is LOCKED, Azure will reject container/account deletion.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

RESOURCE_GROUP=""

usage() {
    cat <<EOF
Usage: $(basename "$0") -g <resource-group>

Options:
  -g, --resource-group NAME    Resource Group name to dismantle
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
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
    echo -e "${RED}Error: Resource Group must be specified with -g${NC}"
    usage
fi

echo -e "${YELLOW}=================================================================${NC}"
echo -e "${YELLOW}⚠️  Dismantling Azure ERP Storage Environment: ${RESOURCE_GROUP}${NC}"
echo -e "${YELLOW}=================================================================${NC}"

# Check for Azure Management Locks on the resource group or child resources
echo -e "\n${CYAN}Step 1: Removing Azure Management Locks...${NC}"
LOCK_IDS=$(az lock list --resource-group "$RESOURCE_GROUP" --query '[].id' -o tsv || true)

if [[ -n "$LOCK_IDS" ]]; then
    for lock_id in $LOCK_IDS; do
        echo -e "Deleting lock: ${lock_id}"
        az lock delete --ids "$lock_id"
    done
    echo -e "${GREEN}✓ All management locks removed.${NC}"
else
    echo -e "${GREEN}✓ No active management locks found.${NC}"
fi

# Attempt deletion of Resource Group
echo -e "\n${CYAN}Step 2: Deleting Resource Group '${RESOURCE_GROUP}'...${NC}"
echo -e "${YELLOW}Note: If any container has a LOCKED WORM policy, deletion will be rejected by Azure.${NC}"

az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo -e "\n${GREEN}✓ Deletion operation submitted to Azure asynchronously.${NC}"
