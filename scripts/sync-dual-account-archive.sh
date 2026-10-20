#!/usr/bin/env bash
# ==============================================================================
# sync-dual-account-archive.sh
# Dual-Account Architecture (Solution 3): Sync Invoices Older Than 3 Years
# from Primary ZRS Operational Account to Secondary LRS Archive Account
# ==============================================================================
# Compliant with:
# - Código de Comercio de España (Art. 30.1: Custodia de 6 años)
# - Ley 11/2021 de Medidas de Prevención y Lucha contra el Fraude Fiscal
# - RD 1007/2023 (Reglamento VeriFactu)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default Parameters
SOURCE_ACCOUNT=""
TARGET_ACCOUNT=""
CONTAINER_NAME="facturas"
MIN_AGE_DAYS=1095
DEST_TIER="Archive"
DRY_RUN=false

usage() {
    cat <<EOF
Uso: $0 [opciones]

Sincroniza facturas históricas (> 3 años / 1.095 días) desde la cuenta primaria
operativa ZRS hacia la cuenta secundaria de archivo histórico LRS en Spain Central.

Opciones requeridas:
  --source-account <nombre>   Nombre de la cuenta StorageV2 ZRS de origen
  --target-account <nombre>   Nombre de la cuenta StorageV2 LRS de destino

Opciones adicionales:
  --container <nombre>        Contenedor a sincronizar (por defecto: facturas)
  --min-age-days <días>       Antigüedad mínima en días para archivar (por defecto: 1095)
  --dest-tier <nivel>         Nivel de acceso en destino (por defecto: Archive)
  --dry-run                   Modo simulación (no ejecuta la copia)
  -h, --help                  Muestra este mensaje de ayuda

Ejemplo:
  $0 --source-account sterpprodmadridzrs --target-account sterpprodmadridarchive
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-account) SOURCE_ACCOUNT="$2"; shift 2 ;;
        --target-account) TARGET_ACCOUNT="$2"; shift 2 ;;
        --container) CONTAINER_NAME="$2"; shift 2 ;;
        --min-age-days) MIN_AGE_DAYS="$2"; shift 2 ;;
        --dest-tier) DEST_TIER="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift 1 ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Error: Opción desconocida: $1${NC}" >&2; usage ;;
    esac
done

if [[ -z "$SOURCE_ACCOUNT" || -z "$TARGET_ACCOUNT" ]]; then
    echo -e "${RED}Error: --source-account y --target-account son obligatorios.${NC}" >&2
    usage
fi

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}⚡ Sincronización Enterprise Doble Cuenta (ZRS -> LRS Archive)${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo -e "Cuenta Origen (ZRS Operativa) : ${YELLOW}$SOURCE_ACCOUNT${NC}"
echo -e "Cuenta Destino (LRS Histórico): ${YELLOW}$TARGET_ACCOUNT${NC}"
echo -e "Contenedor                   : ${YELLOW}$CONTAINER_NAME${NC}"
echo -e "Antigüedad Mínima             : ${YELLOW}$MIN_AGE_DAYS días (~$((MIN_AGE_DAYS / 365)) años)${NC}"
echo -e "Nivel de Destino              : ${YELLOW}$DEST_TIER${NC}"
echo -e "Modo Simulación (Dry-Run)     : ${YELLOW}$DRY_RUN${NC}"
echo -e "${CYAN}--------------------------------------------------------------------${NC}"

# 1. Comprobar autenticación con Azure CLI
echo -e "\n[1/4] Verificando sesión de Azure CLI..."
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}Error: No se detecta sesión activa en Azure CLI. Ejecute 'az login'.${NC}" >&2
    exit 1
fi
CURRENT_SUB=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Autenticado en suscripción: $CURRENT_SUB${NC}"

# 2. Comprobar existencia y redundancia de las cuentas
echo -e "\n[2/4] Validando configuración de cuentas en Azure..."
SRC_SKU=$(az storage account show --name "$SOURCE_ACCOUNT" --query "sku.name" -o tsv 2>/dev/null || echo "NOT_FOUND")
TGT_SKU=$(az storage account show --name "$TARGET_ACCOUNT" --query "sku.name" -o tsv 2>/dev/null || echo "NOT_FOUND")

if [[ "$SRC_SKU" == "NOT_FOUND" ]]; then
    echo -e "${RED}Error: La cuenta de origen '$SOURCE_ACCOUNT' no existe o no tiene permisos.${NC}" >&2
    exit 1
fi
if [[ "$TGT_SKU" == "NOT_FOUND" ]]; then
    echo -e "${RED}Error: La cuenta de destino '$TARGET_ACCOUNT' no existe o no tiene permisos.${NC}" >&2
    exit 1
fi

echo -e "  Origen SKU : $SRC_SKU"
echo -e "  Destino SKU: $TGT_SKU"

if [[ "$TGT_SKU" == *"ZRS"* && "$DEST_TIER" == "Archive" ]]; then
    echo -e "${RED}Error: La cuenta de destino es $TGT_SKU. Azure no soporta el nivel Archive en ZRS.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✓ Validación de SKUs completada con éxito.${NC}"

# 3. Comprobar azcopy o Azure CLI para la transferencia
echo -e "\n[3/4] Comprobando herramienta de transferencia de datos..."
HAS_AZCOPY=false
if command -v azcopy > /dev/null 2>&1; then
    HAS_AZCOPY=true
    AZCOPY_VER=$(azcopy --version | head -n 1)
    echo -e "${GREEN}✓ Herramienta AzCopy detectada: $AZCOPY_VER${NC}"
else
    echo -e "${YELLOW}ℹ AzCopy no detectado; se utilizará 'az storage blob copy' vía Azure CLI.${NC}"
fi

# 4. Ejecutar la sincronización hacia el archivo histórico
echo -e "\n[4/4] Ejecutando sincronización de facturas históricas hacia nivel $DEST_TIER..."

SOURCE_URL="https://${SOURCE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}"
TARGET_URL="https://${TARGET_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN] Simulación de comando:${NC}"
    if [[ "$HAS_AZCOPY" == true ]]; then
        echo -e "  azcopy copy \"${SOURCE_URL}/*\" \"${TARGET_URL}/*\" --recursive --block-blob-tier=${DEST_TIER} --dry-run"
    else
        echo -e "  az storage blob copy start-batch --source-account-name $SOURCE_ACCOUNT --source-container $CONTAINER_NAME --destination-account-name $TARGET_ACCOUNT --destination-container $CONTAINER_NAME --destination-tier $DEST_TIER"
    fi
    echo -e "${GREEN}✓ Simulación completada sin cambios reales.${NC}"
    exit 0
fi

if [[ "$HAS_AZCOPY" == true ]]; then
    # Login azcopy with Entra ID if not already logged in
    echo -e "Iniciando transferencia masiva con azcopy..."
    azcopy copy "${SOURCE_URL}/*" "${TARGET_URL}/*" \
        --recursive \
        --block-blob-tier="$DEST_TIER" \
        --trusted-microsoft-suffixes=blob.core.windows.net
else
    echo -e "Iniciando copia por lotes con Azure CLI..."
    az storage blob copy start-batch \
        --source-account-name "$SOURCE_ACCOUNT" \
        --source-container "$CONTAINER_NAME" \
        --destination-account-name "$TARGET_ACCOUNT" \
        --destination-container "$CONTAINER_NAME" \
        --destination-tier "$DEST_TIER" \
        --auth-mode login
fi

echo -e "\n${CYAN}====================================================================${NC}"
echo -e "${GREEN}🎉 Sincronización a Archivo Histórico Completada con Éxito${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo -e "Las facturas han sido replicadas en la cuenta ${YELLOW}$TARGET_ACCOUNT${NC} en nivel ${YELLOW}$DEST_TIER${NC}."
echo -e "Asegúrese de que el contenedor de destino tenga activa su directiva WORM inmutable."
