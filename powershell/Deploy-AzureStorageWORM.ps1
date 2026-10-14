<#
.SYNOPSIS
    Deploys cost-optimized, WORM-compliant Azure Blob Storage for ERP invoices in Spain Central.

.DESCRIPTION
    Automates the provisioning of:
    - Resource Group in Spain Central (Madrid)
    - General Purpose v2 Storage Account with Standard_ZRS (3 availability zones)
    - Minimum TLS 1.2, public blob access blocked, HTTPS only
    - Blob & Container Soft Delete (30 days) and Blob Versioning
    - WORM Immutability Policy (2,190 days / 6 years according to Código de Comercio Art. 30)
    - 4-Tier Lifecycle Management (Hot -> Cool 90d -> Cold 365d -> Archive 1095d)
    - Azure Management Lock (CanNotDelete)

.PARAMETER ResourceGroupName
    Name of the Resource Group. Defaults to rg-erp-storage-prod-spaincentral.

.PARAMETER StorageAccountName
    Name of the Storage Account (3-24 lowercase alphanumerics). Auto-generated if not specified.

.PARAMETER Location
    Azure Region. Defaults to spaincentral.

.PARAMETER SkuName
    Replication SKU: Standard_ZRS (recommended for 3-zone HA in Madrid) or Standard_LRS.

.PARAMETER RetentionDays
    Immutability period in days (default: 2,190 days / 6 years).

.PARAMETER SoftDeleteRetentionDays
    Soft delete retention in days (default: 30 days).

.PARAMETER LockWormPolicy
    CRITICAL: If set, permanently locks the immutability policy (irreversible!).

.PARAMETER Containers
    List of containers to create and protect. Defaults to 'facturas', 'pedidos'.

.EXAMPLE
    ./Deploy-AzureStorageWORM.ps1 -ResourceGroupName "rg-erp-prod" -SkuName "Standard_ZRS"
#>

#Requires -Version 7.2
#Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.15.0" }, @{ ModuleName="Az.Storage"; ModuleVersion="5.11.0" }, @{ ModuleName="Az.Resources"; ModuleVersion="6.12.0" }

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-erp-storage-prod-spaincentral",

    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName = "",

    [Parameter(Mandatory = $false)]
    [string]$Location = "spaincentral",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Standard_LRS", "Standard_ZRS", "Standard_GRS", "Standard_GZRS")]
    [string]$SkuName = "Standard_ZRS",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 146000)]
    [int]$RetentionDays = 2190,

    [Parameter(Mandatory = $false)]
    [ValidateRange(7, 365)]
    [int]$SoftDeleteRetentionDays = 30,

    [Parameter(Mandatory = $false)]
    [switch]$LockWormPolicy,

    [Parameter(Mandatory = $false)]
    [switch]$NoResourceLock,

    [Parameter(Mandatory = $false)]
    [string[]]$Containers = @("facturas", "pedidos")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Auto-generate Storage Account name if not provided
if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    $randomSuffix = -join ((97..122) + (48..57) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    $StorageAccountName = "sterpprod$randomSuffix"
} else {
    $StorageAccountName = $StorageAccountName.ToLower() -replace '[^a-z0-9]', ''
    if ($StorageAccountName.Length -gt 24) {
        $StorageAccountName = $StorageAccountName.Substring(0, 24)
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🚀 Deploying Azure ERP Storage Compliance & Cost Tiering (Az)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Resource Group:    $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Storage Account:   $StorageAccountName" -ForegroundColor Yellow
Write-Host "Region:            $Location (Spain Central - Madrid)" -ForegroundColor Yellow
Write-Host "SKU:               $SkuName" -ForegroundColor Yellow
Write-Host "Retention Period:  $RetentionDays days (Art. 30 Código de Comercio)" -ForegroundColor Yellow
Write-Host "WORM Lock State:   $(if ($LockWormPolicy) { 'LOCKED (IRREVERSIBLE)' } else { 'UNLOCKED (Test mode)' })" -ForegroundColor Yellow
Write-Host "Soft Delete:       $SoftDeleteRetentionDays days" -ForegroundColor Yellow
Write-Host "Containers:        $($Containers -join ', ')" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Verify Az Context
Write-Host "`n[1/7] Verifying Azure Context..." -ForegroundColor Cyan
$context = Get-AzContext
if (-not $context) {
    throw "No active Azure context found. Please run 'Connect-AzAccount' first."
}
Write-Host "✓ Authenticated as: $($context.Account.Id) on Subscription: $($context.Subscription.Name)" -ForegroundColor Green

# 2. Resource Group
Write-Host "`n[2/7] Ensuring Resource Group '$ResourceGroupName'..." -ForegroundColor Cyan
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create Resource Group in $Location")) {
        $tags = @{
            Workload        = "ERP-Document-Archive"
            LegalCompliance = "Codigo-de-Comercio-Art30-VeriFactu"
            Country         = "Spain"
            ManagedBy       = "PowerShell"
        }
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $tags
        Write-Host "✓ Resource Group created." -ForegroundColor Green
    }
} else {
    Write-Host "✓ Resource Group already exists." -ForegroundColor Green
}

# 3. Storage Account
Write-Host "`n[3/7] Provisioning Storage Account '$StorageAccountName'..." -ForegroundColor Cyan
$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (-not $sa) {
    if ($PSCmdlet.ShouldProcess($StorageAccountName, "Create Storage Account with SKU $SkuName in $Location")) {
        $sa = New-AzStorageAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -Location $Location `
            -SkuName $SkuName `
            -Kind "StorageV2" `
            -AccessTier "Hot" `
            -MinimumTlsVersion "TLS1_2" `
            -AllowBlobPublicAccess $false `
            -EnableHttpsTrafficOnly $true `
            -Tag @{
                Workload        = "ERP-Document-Archive"
                LegalCompliance = "Codigo-de-Comercio-Art30-VeriFactu"
                Country         = "Spain"
            }
        Write-Host "✓ Storage Account created." -ForegroundColor Green
    }
} else {
    Write-Host "✓ Storage Account already exists." -ForegroundColor Green
}

# 4. Blob Service Properties (Soft Delete, Versioning, Change Feed)
Write-Host "`n[4/7] Configuring Data Protection & Soft Delete ($SoftDeleteRetentionDays days)..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess($StorageAccountName, "Update Blob Service Properties")) {
    Update-AzStorageBlobServiceProperty `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -EnableDeleteRetentionPolicy $true `
        -DeleteRetentionDays $SoftDeleteRetentionDays `
        -EnableContainerDeleteRetentionPolicy $true `
        -ContainerDeleteRetentionDays $SoftDeleteRetentionDays `
        -IsVersioningEnabled $true `
        -EnableChangeFeed $true | Out-Null
    Write-Host "✓ Blob & Container soft delete, versioning, and change feed enabled." -ForegroundColor Green
}

# 5. Containers & WORM Immutability Policies
Write-Host "`n[5/7] Configuring Containers and WORM Immutability Policies..." -ForegroundColor Cyan
$saContext = $sa.Context

foreach ($containerName in $Containers) {
    Write-Host "Processing container: $containerName..."
    $container = Get-AzStorageContainer -Name $containerName -Context $saContext -ErrorAction SilentlyContinue
    if (-not $container) {
        if ($PSCmdlet.ShouldProcess($containerName, "Create Blob Container")) {
            $container = New-AzStorageContainer -Name $containerName -Context $saContext -Permission "Off"
            Write-Host "✓ Container '$containerName' created." -ForegroundColor Green
        }
    }

    # Time-based retention policy
    $immutabilityPolicy = Get-AzStorageContainerImmutabilityPolicy `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -ContainerName $containerName `
        -ErrorAction SilentlyContinue

    if (-not $immutabilityPolicy) {
        if ($PSCmdlet.ShouldProcess($containerName, "Set Immutability Policy of $RetentionDays days")) {
            $immutabilityPolicy = Set-AzStorageContainerImmutabilityPolicy `
                -ResourceGroupName $ResourceGroupName `
                -StorageAccountName $StorageAccountName `
                -ContainerName $containerName `
                -ImmutabilityPeriod $RetentionDays `
                -AllowProtectedAppendWrite $true
            Write-Host "✓ Immutability policy of $RetentionDays days created (State: Unlocked)." -ForegroundColor Green
        }
    } else {
        Write-Host "ℹ Immutability policy already configured on '$containerName'." -ForegroundColor Yellow
    }

    # Lock policy if requested
    if ($LockWormPolicy -and $immutabilityPolicy -and $immutabilityPolicy.State -ne "Locked") {
        Write-Host "⚠️  Locking WORM policy permanently on '$containerName'..." -ForegroundColor Yellow
        Lock-AzStorageContainerImmutabilityPolicy `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -ContainerName $containerName `
            -ETag $immutabilityPolicy.ETag | Out-Null
        Write-Host "🔒 Policy on '$containerName' is now permanently LOCKED." -ForegroundColor Red
    }
}

# 6. Lifecycle Management Policy (Tiering)
Write-Host "`n[6/7] Applying Lifecycle Management Rules (Tiering Hot -> Cool -> Cold -> Archive)..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess($StorageAccountName, "Apply Lifecycle Management Rules")) {
    $filters = New-AzStorageAccountManagementPolicyFilter `
        -BlobType "blockBlob" `
        -PrefixMatch @("facturas/", "pedidos/")

    $action = New-AzStorageAccountManagementPolicyActionItem `
        -BaseBlobActionTierToCool 90 `
        -BaseBlobActionTierToCold 365 `
        -BaseBlobActionTierToArchive 1095 `
        -SnapshotActionTierToCool 90 `
        -SnapshotActionTierToCold 365 `
        -SnapshotActionTierToArchive 1095 `
        -BlobVersionActionTierToCool 90 `
        -BlobVersionActionTierToCold 365 `
        -BlobVersionActionTierToArchive 1095

    $rule = New-AzStorageAccountManagementPolicyRule `
        -Name "tier-erp-invoices-and-orders" `
        -Filter $filters `
        -Action $action

    Set-AzStorageAccountManagementPolicy `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -Rule $rule | Out-Null
    Write-Host "✓ Lifecycle Management Policy applied successfully." -ForegroundColor Green
}

# 7. Azure Management Lock (CanNotDelete)
if (-not $NoResourceLock) {
    Write-Host "`n[7/7] Applying CanNotDelete Management Lock..." -ForegroundColor Cyan
    $lockName = "lock-$StorageAccountName-prevent-deletion"
    $existingLock = Get-AzResourceLock -ResourceGroupName $ResourceGroupName -ResourceName $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts" -ErrorAction SilentlyContinue

    if (-not $existingLock) {
        if ($PSCmdlet.ShouldProcess($StorageAccountName, "Apply CanNotDelete Management Lock")) {
            New-AzResourceLock `
                -LockName $lockName `
                -LockLevel "CanNotDelete" `
                -ResourceGroupName $ResourceGroupName `
                -ResourceName $StorageAccountName `
                -ResourceType "Microsoft.Storage/storageAccounts" `
                -LockNotes "Protects ERP compliance storage account against accidental or malicious deletion." | Out-Null
            Write-Host "✓ CanNotDelete lock successfully applied." -ForegroundColor Green
        }
    } else {
        Write-Host "✓ Management lock already active." -ForegroundColor Green
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "🎉 PowerShell Deployment Complete!" -ForegroundColor Green
Write-Host "Storage Account Endpoint: https://$StorageAccountName.blob.core.windows.net/" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
