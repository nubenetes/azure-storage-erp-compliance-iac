# Azure Blob Storage ERP WORM & Cost-Optimized Tiering (Spain Central)

[![CI - Validate & Lint](https://github.com/nubenetes/azure-storage-erp-compliance-iac/actions/workflows/ci-lint-validate.yml/badge.svg)](https://github.com/nubenetes/azure-storage-erp-compliance-iac/actions/workflows/ci-lint-validate.yml)
[![Region: Spain Central](https://img.shields.io/badge/Azure_Region-Spain_Central_(Madrid)-0078D4?logo=microsoftazure)](https://azure.microsoft.com/explore/global-infrastructure/geographies/#spain)
[![Terraform >= 1.5](https://img.shields.io/badge/Terraform->=1.5_(AzureRM_v4)-844FBA?logo=terraform)](https://www.terraform.io/)
[![Bicep v0.48+](https://img.shields.io/badge/Bicep-Native_IaC-0078D4?logo=microsoftazure)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
[![Ansible >= 2.14](https://img.shields.io/badge/Ansible-azure.azcollection-EE0000?logo=ansible)](https://docs.ansible.com/)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-Az_Module-5391FE?logo=powershell)](https://learn.microsoft.com/powershell/azure/)
[![Compliance: Cód. Comercio & VeriFactu](https://img.shields.io/badge/Compliance-C%C3%B3d._Comercio_Art._30_%7C_VeriFactu-2ea44f)](docs/LEGAL_COMPLIANCE_SPAIN.md)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Enterprise reference architecture and multi-tool **Infrastructure as Code (IaC)** suite for storing and legally archiving ERP invoices and orders (up to 1 TB and scaling) in **Azure Blob Storage** within the **Spain Central (Madrid)** region.

This project delivers fully automated implementations across **Terraform / OpenTofu**, **Azure CLI**, **PowerShell (Az module)**, **Ansible**, and **Azure Bicep**.

---

## 🇪🇸 Resumen Ejecutivo (Español)

Para un sistema ERP en España (SAP, Microsoft Dynamics, Navision, Odoo o desarrollo propio), la arquitectura más eficiente y conforme a derecho consiste en:
1. **Cuenta Standard General Purpose v2 (`StorageV2`) con redundancia ZRS** (distribuida en las 3 zonas de disponibilidad de Madrid) o **LRS**, desplegada en la región **Spain Central (`spaincentral`)**.
2. **Políticas automáticas de ciclo de vida (Lifecycle Management)** con progresión de 4 niveles:
   - **Hot (0 – 90 días)**: Facturas y pedidos activos. Lectura inmediata sin coste por GB leído.
   - **Cool (91 – 365 días)**: Cierres trimestrales y anuales (~46% de ahorro en almacenamiento).
   - **Cold (366 – 1.095 días / 1 a 3 años)**: Auditorías puntuales (~76% de ahorro frente a Hot).
   - **Archive (1.096 – 2.190+ días / 3 a 6+ años)**: Custodia legal según el **Art. 30 del Código de Comercio** (~95% de ahorro, ~0,00099 €/GB/mes).
3. **Inmutabilidad WORM Legal**: Directiva de retención basada en tiempo de **2.190 días (6 años)** con soporte para anexar registros protegidos (`allowProtectedAppendWrites = true`), garantizando la inalterabilidad exigida por la **Ley Antifraude 11/2021** y el **Reglamento VeriFactu (RD 1007/2023)**.
4. **Resiliencia y Antiransomware**: Eliminación temporal (*Soft Delete*) de 30 días para blobs y contenedores, versionado de blobs y bloqueo de recurso de Azure de tipo `CanNotDelete`.

> 💡 **Impacto Financiero**: Esta arquitectura reduce el coste de almacenar 1 TB de unos **19,00 €/mes** en Hot Tier a tan solo **~4,37 €/mes (LRS)** o **~5,43 €/mes (ZRS con 3 zonas de disponibilidad)**, logrando un **ahorro recurrente superior al 75%** y garantizando el cumplimiento normativo mercantil y fiscal en España.

---

## 🏛️ Architecture Overview

```mermaid
flowchart TD
    subgraph Corporate["🏢 ERP & Corporate Billing Clients (Spain)"]
        ERP["ERP System<br/>(SAP / Dynamics / Odoo)"]
        Auditor["Tax & Legal Auditors<br/>(AEAT / Compliance)"]
    end

    subgraph AzureSpain["🇪🇸 Azure Spain Central (Madrid)"]
        subgraph RG["Resource Group: rg-erp-storage-prod-spaincentral"]
            Lock["🔒 Management Lock: CanNotDelete"]
            
            subgraph StorageAccount["Storage Account: StorageV2 (Standard_ZRS)<br/>TLS 1.2+ | No Public Access | Entra ID RBAC"]
                subgraph Protection["Resilience & Protection"]
                    SoftDel["🗑️ Soft Delete (30 Days)<br/>Blobs & Containers"]
                    Vers["📑 Blob Versioning<br/>Enabled"]
                end

                subgraph Containers["WORM Containers (2,190 days retention)"]
                    C_Facturas["📁 facturas<br/>Time-based retention: 6 yrs<br/>Append allowed"]
                    C_Pedidos["📁 pedidos<br/>Time-based retention: 6 yrs<br/>Append allowed"]
                end

                subgraph Lifecycle["Automatic Lifecycle Management Rules"]
                    direction LR
                    Hot["🔥 Hot (0-90d)<br/>Active Billing<br/>Zero read fee"]
                    Cool["❄️ Cool (91-365d)<br/>Fiscal close<br/>~46% savings"]
                    Cold["🧊 Cold (1-3y)<br/>Audits<br/>~76% savings"]
                    Archive["📦 Archive (3-6+y)<br/>Legal custody<br/>~95% savings (<1€/mo)"]

                    Hot -->|90 days| Cool
                    Cool -->|365 days| Cold
                    Cold -->|1,095 days| Archive
                end
            end
        end
    end

    ERP -->|"REST / SDK (TLS 1.2+)"| C_Facturas
    ERP -->|"REST / SDK (TLS 1.2+)"| C_Pedidos
    Auditor -->|"Online Query"| Cold
    Auditor -.->|"Rehydrate in hours"| Archive
```

---

## 📊 Detailed Cost Breakdown (1 TB over 6 Years)

| Access Tier / Phase | Storage Period | Effective Volume | LRS Price (€/GB/mo) | ZRS Price (€/GB/mo) | Monthly Cost (LRS) | Monthly Cost (ZRS) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Hot** (Recent) | Days 0 – 90 | 41.67 GB | 0.0184 € | 0.0230 € | 0.77 € | 0.96 € |
| **Cool** (Fiscal Year) | Days 91 – 365 | 125.00 GB | 0.0100 € | 0.0125 € | 1.25 € | 1.56 € |
| **Cold** (Historical) | Years 1 – 3 | 333.33 GB | 0.0045 € | 0.0058 € | 1.50 € | 1.93 € |
| **Archive** (Statutory) | Years 3 – 6 | 500.00 GB | 0.00099 € | 0.00125 € | 0.50 € | 0.63 € |
| Operations & Lifecycle | Ongoing | ~14 GB/mo new | - | - | ~0.35 € | ~0.35 € |
| **Total Steady State** | **1,000 GB (1 TB)** | **100% of data** | - | - | **~4.37 € / mo** | **~5.43 € / mo** |

* Traditional 100% Hot Tier cost: **~18.80 € / mo (LRS)** or **~23.40 € / mo (ZRS)**.
* **Cumulative 6-year savings**: **~1,038.96 € saved per TB** (> 75% savings).
* Full financial modeling in [`docs/COST_OPTIMIZATION.md`](docs/COST_OPTIMIZATION.md).

---

## ⚖️ Legal & Regulatory Mapping (Spain & EU)

| Law / Regulation | Key Requirement | How This Architecture Complies |
| :--- | :--- | :--- |
| **Código de Comercio (Art. 30.1)** | Obligation to retain business books and invoices for **6 years**. | WORM retention policy set to **2,190 days** (6 calendar years). |
| **Ley General Tributaria (Ley 58/2003)** | General prescription of 4 years; 10 years for negative tax bases (BINs). | Data kept online (Hot $\rightarrow$ Cool $\rightarrow$ Cold) for 3 years, then archived at ultra-low cost. |
| **Ley Antifraude (Ley 11/2021)** | Guarantee **integrity, conservation, traceability, and inalterability**. | WORM policy prevents modifying or deleting blobs even by administrators. |
| **Reglamento VeriFactu (RD 1007/2023)**| Tamper-proof audit logs and chained hashes. | `allowProtectedAppendWrites = true` allows appending hash records securely. |
| **RGPD / LOPDGDD** | Sovereignty and data protection for personal details in invoices. | Deployed strictly in **Spain Central (Madrid)**; TLS 1.2+; Entra ID RBAC. |
| **ENS (Esquema Nacional de Seguridad)**| Level **ALTO** certification for public sector/regulated workloads. | Microsoft Azure Spain Central holds official **ENS Nivel Alto** certification. |

* In-depth legal analysis in [`docs/LEGAL_COMPLIANCE_SPAIN.md`](docs/LEGAL_COMPLIANCE_SPAIN.md).

---

## 🚀 Infrastructure as Code Solutions

This repository provides 5 ready-to-run IaC solutions. Choose the tool that best fits your platform engineering stack:

### 1. Terraform / OpenTofu

Located in [`terraform/`](terraform/). Validated against Terraform >= 1.5 and `azurerm` v4.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

### 2. Azure CLI

Located in [`azure-cli/`](azure-cli/). POSIX bash script with idempotency and safety controls.

```bash
cd azure-cli
chmod +x deploy.sh lock-immutability.sh destroy.sh

# Deploy infrastructure (Unlocked test mode)
./deploy.sh -g rg-erp-compliance-prod -l spaincentral -r Standard_ZRS

# Once tested, permanently apply legal WORM lock (optional/production)
./lock-immutability.sh -g rg-erp-compliance-prod -s <storage_account_name> -c facturas
```

### 3. PowerShell (Az Module)

Located in [`powershell/`](powershell/). Enterprise PowerShell 7+ script with `-WhatIf` and Verbose support.

```powershell
cd powershell
# Deploy with 3-zone HA in Madrid
./Deploy-AzureStorageWORM.ps1 `
  -ResourceGroupName "rg-erp-storage-prod-spaincentral" `
  -Location "spaincentral" `
  -SkuName "Standard_ZRS" `
  -RetentionDays 2190
```

### 4. Ansible

Located in [`ansible/`](ansible/). Modular playbook using `azure.azcollection`.

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbook.yml
```

### 5. Azure Bicep

Located in [`bicep/`](bicep/). Native modular Azure Bicep templates.

```bash
cd bicep
# Create resource group if needed
az group create --name rg-erp-storage-prod-spaincentral --location spaincentral

# Deploy using Bicep
az deployment group create \
  --resource-group rg-erp-storage-prod-spaincentral \
  --template-file main.bicep \
  --parameters main.bicepparam
```

---

## 🔒 Crucial Note on WORM Policy Locking

> [!CAUTION]
> **PERMANENT LEGAL LOCK IS IRREVERSIBLE**
> 
> By default, all 5 IaC templates deploy the 2,190-day retention policy in **Unlocked** state. This allows you to verify ingestion and integration tests safely.
> 
> Once you verify the deployment, you can permanently lock the policy using our dedicated tools (`lock-immutability.sh`, `Lock-ImmutabilityPolicy.ps1`, or setting `lock_immutability_policy = true`).
> 
> **Once LOCKED, neither you, your Global Admins, nor Microsoft Azure Support can delete or shorten the policy until 2,190 days elapse.**
> 
> Read the complete guide in [`docs/WORM_POLICY_LOCK_GUIDE.md`](docs/WORM_POLICY_LOCK_GUIDE.md).

---

## 📂 Repository Structure

```text
azure-storage-erp-compliance-iac/
├── .github/
│   └── workflows/
│       └── ci-lint-validate.yml        # CI pipeline validating Terraform, Bicep, Bash & PS
├── docs/
│   ├── ARCHITECTURE.md                 # Detailed architecture & Mermaid diagrams
│   ├── COST_OPTIMIZATION.md            # Mathematical TCO model for 1 TB in Spain Central
│   ├── LEGAL_COMPLIANCE_SPAIN.md       # Cód. Comercio, LGT, Ley Antifraude, VeriFactu, RGPD
│   └── WORM_POLICY_LOCK_GUIDE.md       # Step-by-step WORM Unlocked vs Locked guide
├── terraform/
│   ├── versions.tf                     # Provider constraints (AzureRM v4)
│   ├── main.tf                         # StorageV2, Containers, WORM, Lifecycle, Lock
│   ├── variables.tf                    # Parameter definitions & validations
│   ├── outputs.tf                      # Endpoints, IDs, policy status
│   └── terraform.tfvars.example        # Spain Central ZRS template
├── azure-cli/
│   ├── deploy.sh                       # Idempotent Bash deployment script
│   ├── lock-immutability.sh            # Safe interactive script to lock WORM policy
│   └── destroy.sh                      # Controlled cleanup script for test environments
├── powershell/
│   ├── Deploy-AzureStorageWORM.ps1     # PowerShell 7+ Az module automation
│   └── Lock-ImmutabilityPolicy.ps1     # Interactive PowerShell WORM lock script
├── ansible/
│   ├── requirements.yml                # azure.azcollection
│   ├── playbook.yml                    # Main orchestration playbook
│   └── roles/
│       └── azure_storage_worm/         # Modular Ansible role (tasks, defaults, meta)
├── bicep/
│   ├── main.bicep                      # Root Bicep template
│   ├── main.bicepparam                 # Parameter file for Spain Central
│   └── modules/                        # Modular resources (storage, containers, lifecycle, lock)
├── LICENSE                             # Apache-2.0 License
└── README.md                           # This documentation
```

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/nubenetes/azure-storage-erp-compliance-iac/issues).

---

## 📜 License

Distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE) for more information.
