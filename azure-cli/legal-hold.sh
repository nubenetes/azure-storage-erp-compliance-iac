#!/usr/bin/env bash
# ==============================================================================
# Script: legal-hold.sh
# Purpose: Apply or clear an AEAT Tax / Judicial Legal Hold on a WORM container
# Context: Under Spanish Tax Law (LGT), when an audit or judicial procedure begins,
#          documents must remain frozen indefinitely until the hold tag is cleared.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

STORAGE_ACCOUNT=""
CONTAINER="facturas"
ACTION=""
TAG="aeat-inspeccion-tributaria"

usage() {
    cat <<EOF
Usage: $(basename "$0") -s <storage-account> -c <container> --action <set|clear|show> [--tag <tag-name>]

Options:
  -s, --storage-account NAME   Azure Storage Account name
  -c, --container NAME         Container name (default: facturas)
  -a, --action ACTION          Action to execute: set, clear, show
  -t, --tag TAG                Legal hold tag identifier (default: aeat-inspeccion-tributaria)
  -h, --help                   Display this help message

Examples:
  $(basename "$0") -s sterpspainprod01 -c facturas --action set --tag aeat-expediente-2026-48
  $(basename "$0") -s sterpspainprod01 -c facturas --action show
  $(basename "$0") -s sterpspainprod01 -c facturas --action clear --tag aeat-expediente-2026-48
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--storage-account)
            STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
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

if [[ -z "$STORAGE_ACCOUNT" || -z "$ACTION" ]]; then
    echo -e "${RED}Error: Storage account and action (set|clear|show) are required.${NC}"
    usage
fi

case "$ACTION" in
    set)
        echo -e "${CYAN}Applying Legal Hold '${TAG}' on container '${CONTAINER}'...${NC}"
        az storage container legal-hold set \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER" \
            --tags "$TAG" \
            --auth-mode login \
            -o table
        echo -e "${GREEN}✓ Legal hold successfully applied. Container is frozen against deletion.${NC}"
        ;;
    clear)
        echo -e "${YELLOW}Clearing Legal Hold '${TAG}' on container '${CONTAINER}'...${NC}"
        az storage container legal-hold clear \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER" \
            --tags "$TAG" \
            --auth-mode login \
            -o table
        echo -e "${GREEN}✓ Legal hold tag '${TAG}' removed.${NC}"
        ;;
    show)
        echo -e "${CYAN}Querying Legal Hold status on container '${CONTAINER}'...${NC}"
        az storage container legal-hold show \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER" \
            --auth-mode login \
            -o json
        ;;
    *)
        echo -e "${RED}Invalid action: $ACTION. Must be set, clear, or show.${NC}"
        usage
        ;;
esac
