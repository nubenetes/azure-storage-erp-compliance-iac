#!/usr/bin/env bash
# ==============================================================================
# Script: deploy.sh
# Purpose: Automate Azure Blob Storage deployment for ERP WORM compliance in Spain Central
# Target Region: spaincentral (Madrid)
# Redundancy: Standard_ZRS (3 Availability Zones) or Standard_LRS
# Legal Retention: 2,190 days (6 years - Código de Comercio Art. 30)
# ==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
LOCATION="spaincentral"
ENVIRONMENT="prod"
PROJECT="erp"
SKU="Standard_ZRS"
RETENTION_DAYS=2190
SOFT_DELETE_DAYS=30
LOCK_WORM=false
ENABLE_RESOURCE_LOCK=true
RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
CONTAINERS=("facturas" "pedidos")

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -g, --resource-group NAME    Azure Resource Group name (default: rg-\$PROJECT-storage-\$ENV-\$LOCATION)
  -s, --storage-account NAME   Storage account name (default: generated sterp<env><random>)
  -l, --location REGION        Azure Region (default: spaincentral)
  -e, --environment ENV        Environment: dev, staging, prod (default: prod)
  -r, --sku SKU                Replication SKU: Standard_ZRS or Standard_LRS (default: Standard_ZRS)
  -d, --retention-days DAYS    WORM retention period in days (default: 2190)
  --lock-worm                  Permanently lock the WORM policy (IRREVERSIBLE! Default: false / Unlocked)
  --no-resource-lock           Do not apply Azure CanNotDelete management lock
  -h, --help                   Display this help message

Example:
  $(basename "$0") -g rg-erp-compliance-prod -l spaincentral -r Standard_ZRS
EOF
    exit 1
}

# Parse CLI arguments
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
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--sku)
            SKU="$2"
            shift 2
            ;;
        -d|--retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --lock-worm)
            LOCK_WORM=true
            shift
            ;;
        --no-resource-lock)
            ENABLE_RESOURCE_LOCK=false
            shift
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

# Set defaults if not provided
if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="rg-${PROJECT}-storage-${ENVIRONMENT}-${LOCATION}"
fi

if [[ -z "$STORAGE_ACCOUNT" ]]; then
    RANDOM_SUFFIX=$(od -N 3 -t x /dev/urandom | head -1 | awk '{print $2}')
    STORAGE_ACCOUNT="st${PROJECT}${ENVIRONMENT}${RANDOM_SUFFIX}"
fi

# Sanitize storage account name (lowercase alphanumerics, 3-24 chars)
STORAGE_ACCOUNT=$(echo "$STORAGE_ACCOUNT" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]' | cut -c 1-24)

echo -e "${BLUE}=================================================================${NC}"
echo -e "${CYAN}🚀 Azure Blob Storage ERP Compliance & Tiering Deployment (CLI)${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "Resource Group:      ${YELLOW}${RESOURCE_GROUP}${NC}"
echo -e "Storage Account:     ${YELLOW}${STORAGE_ACCOUNT}${NC}"
echo -e "Location:            ${YELLOW}${LOCATION}${NC} (Spain Central / Madrid)"
echo -e "SKU Redundancy:      ${YELLOW}${SKU}${NC}"
echo -e "WORM Retention:      ${YELLOW}${RETENTION_DAYS} days${NC} (Art. 30 Código de Comercio)"
echo -e "WORM Policy Lock:    ${YELLOW}${LOCK_WORM}${NC}"
echo -e "Soft Delete:         ${YELLOW}${SOFT_DELETE_DAYS} days${NC}"
echo -e "CanNotDelete Lock:   ${YELLOW}${ENABLE_RESOURCE_LOCK}${NC}"
echo -e "Containers:          ${YELLOW}${CONTAINERS[*]}${NC}"
echo -e "${BLUE}=================================================================${NC}"

# 1. Verify az CLI authentication
echo -e "\n${CYAN}Step 1: Checking Azure authentication...${NC}"
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}Error: You are not logged in to Azure CLI. Run 'az login' first.${NC}"
    exit 1
fi
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✓ Authenticated to subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})${NC}"

# 2. Create Resource Group if not exists
echo -e "\n${CYAN}Step 2: Ensuring Resource Group exists...${NC}"
if az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Resource Group '$RESOURCE_GROUP' already exists.${NC}"
else
    echo -e "Creating Resource Group '$RESOURCE_GROUP' in '$LOCATION'..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags Workload="ERP-Document-Archive" LegalCompliance="Codigo-de-Comercio-Art30-VeriFactu" Country="Spain" \
        -o none
    echo -e "${GREEN}✓ Resource Group created.${NC}"
fi

# 3. Create Storage Account (StorageV2, TLS 1.2, no public access)
echo -e "\n${CYAN}Step 3: Creating/Updating Storage Account '$STORAGE_ACCOUNT'...${NC}"
if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Storage account '$STORAGE_ACCOUNT' already exists.${NC}"
else
    echo -e "Provisioning Storage Account in $LOCATION with $SKU..."
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --kind StorageV2 \
        --sku "$SKU" \
        --access-tier Hot \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --https-only true \
        --default-action Allow \
        --tags Workload="ERP-Document-Archive" LegalCompliance="Codigo-de-Comercio-Art30-VeriFactu" Country="Spain" \
        -o none
    echo -e "${GREEN}✓ Storage Account created.${NC}"
fi

# 4. Configure Blob Service Properties (Soft Delete, Versioning, Change Feed)
echo -e "\n${CYAN}Step 4: Configuring Data Protection & Soft Delete (30 days)...${NC}"
az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-delete-retention true \
    --delete-retention-days "$SOFT_DELETE_DAYS" \
    --enable-container-delete-retention true \
    --container-delete-retention-days "$SOFT_DELETE_DAYS" \
    --enable-versioning true \
    --enable-change-feed true \
    -o none
echo -e "${GREEN}✓ Soft delete (30d), blob versioning, and change feed enabled.${NC}"

# 5. Create Containers and WORM Immutability Policies
echo -e "\n${CYAN}Step 5: Configuring Containers and WORM Immutability Policies...${NC}"
for container in "${CONTAINERS[@]}"; do
    echo -e "Checking container '${container}'..."
    az storage container create \
        --name "$container" \
        --account-name "$STORAGE_ACCOUNT" \
        --auth-mode login \
        -o none 2>/dev/null || true

    # Create time-based retention policy if not exists
    echo -e "Applying WORM retention policy (${RETENTION_DAYS} days) to '${container}'..."
    if ! az storage container immutability-policy show --account-name "$STORAGE_ACCOUNT" --container-name "$container" --auth-mode login > /dev/null 2>&1; then
        az storage container immutability-policy create \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$container" \
            --period "$RETENTION_DAYS" \
            --allow-protected-append-writes true \
            --auth-mode login \
            -o none
        echo -e "${GREEN}✓ Immutability policy created for '${container}' (State: Unlocked).${NC}"
    else
        echo -e "${YELLOW}ℹ Immutability policy already exists for '${container}'.${NC}"
    fi

    # Lock policy if requested
    if [[ "$LOCK_WORM" == true ]]; then
        echo -e "${YELLOW}⚠️  Locking WORM policy permanently for '${container}'...${NC}"
        ETAG=$(az storage container immutability-policy show --account-name "$STORAGE_ACCOUNT" --container-name "$container" --auth-mode login --query etag -o tsv)
        az storage container immutability-policy lock \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$container" \
            --if-match "$ETAG" \
            --auth-mode login \
            -o none
        echo -e "${RED}🔒 Policy for '${container}' is now permanently LOCKED.${NC}"
    fi
done

# 6. Apply Lifecycle Management Policy (Hot -> Cool -> Cold -> Archive)
echo -e "\n${CYAN}Step 6: Applying Lifecycle Management Policy (Tiering)...${NC}"
cat <<JSON > /tmp/lifecycle_policy_${STORAGE_ACCOUNT}.json
{
  "rules": [
    {
      "enabled": true,
      "name": "tier-erp-invoices-and-orders",
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["facturas/", "pedidos/"]
        },
        "actions": {
          "baseBlob": {
            "tierToCool": { "daysAfterModificationGreaterThan": 90 },
            "tierToCold": { "daysAfterModificationGreaterThan": 365 },
            "tierToArchive": { "daysAfterModificationGreaterThan": 1095 }
          },
          "snapshot": {
            "tierToCool": { "daysAfterCreationGreaterThan": 90 },
            "tierToCold": { "daysAfterCreationGreaterThan": 365 },
            "tierToArchive": { "daysAfterCreationGreaterThan": 1095 }
          },
          "version": {
            "tierToCool": { "daysAfterCreationGreaterThan": 90 },
            "tierToCold": { "daysAfterCreationGreaterThan": 365 },
            "tierToArchive": { "daysAfterCreationGreaterThan": 1095 }
          }
        }
      }
    }
  ]
}
JSON

az storage account management-policy create \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --policy @/tmp/lifecycle_policy_${STORAGE_ACCOUNT}.json \
    -o none
rm -f /tmp/lifecycle_policy_${STORAGE_ACCOUNT}.json
echo -e "${GREEN}✓ Lifecycle tiering policy applied (90d -> Cool, 365d -> Cold, 1095d -> Archive).${NC}"

# 7. Apply CanNotDelete Management Lock
if [[ "$ENABLE_RESOURCE_LOCK" == true ]]; then
    echo -e "\n${CYAN}Step 7: Applying CanNotDelete Management Lock...${NC}"
    LOCK_NAME="lock-${STORAGE_ACCOUNT}-prevent-deletion"
    SA_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    if az lock show --name "$LOCK_NAME" --resource "$SA_ID" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Management lock '$LOCK_NAME' already active.${NC}"
    else
        az lock create \
            --name "$LOCK_NAME" \
            --resource "$SA_ID" \
            --lock-type CanNotDelete \
            --notes "Prevents accidental deletion of ERP compliance storage account." \
            -o none
        echo -e "${GREEN}✓ CanNotDelete lock successfully applied.${NC}"
    fi
fi

echo -e "\n${BLUE}=================================================================${NC}"
echo -e "${GREEN}🎉 Deployment successfully completed!${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "Storage Account Endpoint: https://${STORAGE_ACCOUNT}.blob.core.windows.net/"
echo -e "WORM Status: $(if [[ "$LOCK_WORM" == true ]]; then echo -e "${RED}LOCKED${NC}"; else echo -e "${YELLOW}UNLOCKED (Test Mode)${NC}"; fi)"
echo -e "To lock the policy permanently when ready for production:"
echo -e "  ${CYAN}./lock-immutability.sh -g ${RESOURCE_GROUP} -s ${STORAGE_ACCOUNT} -c facturas${NC}"
echo -e "${BLUE}=================================================================${NC}"
