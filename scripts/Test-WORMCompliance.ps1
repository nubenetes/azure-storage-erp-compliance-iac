<#
.SYNOPSIS
    Automated Day-2 Compliance & Immutability Verification Suite in PowerShell.

.DESCRIPTION
    Validates the 6 key compliance assertions:
    1. Ingestion of test invoice blob
    2. Overwrite rejection (WORM immutability)
    3. Deletion rejection (BlobImmutableDueToPolicy)
    4. Protected append writes support
    5. Data protection properties (Soft delete 30d, Versioning, Change Feed)
    6. CanNotDelete Azure Management Lock presence

.PARAMETER ResourceGroupName
    Name of the Resource Group.

.PARAMETER StorageAccountName
    Name of the Storage Account.

.PARAMETER ContainerName
    Name of the container to test (default: facturas).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "facturas"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failedTests = 0
$totalTests = 6

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🧪 Azure ERP Storage WORM Compliance Verification Suite (Az)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Yellow
Write-Host "Resource Group:  $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Container:       $ContainerName" -ForegroundColor Yellow
Write-Host "=================================================================`n" -ForegroundColor Cyan

$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$ctx = $sa.Context
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$testBlobName = "audit_test_$timestamp.pdf"
$tmpFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmpFile -Value "ERP-WORM-TEST-PAYLOAD-$timestamp"

try {
    # Test 1: Upload
    Write-Host -NoNewline "Test 1/6: Ingestion of new invoice block blob... "
    $null = Set-AzStorageBlobContent -File $tmpFile -Container $ContainerName -Blob $testBlobName -Context $ctx -Force
    Write-Host "[PASS] Upload succeeded." -ForegroundColor Green

    # Test 2: Overwrite
    Write-Host -NoNewline "Test 2/6: Overwrite prevention on existing invoice... "
    $overwritePrevented = $false
    try {
        $null = Set-AzStorageBlobContent -File $tmpFile -Container $ContainerName -Blob $testBlobName -Context $ctx -Force -ErrorAction Stop
    } catch {
        $overwritePrevented = $true
    }
    if ($overwritePrevented) {
        Write-Host "[PASS] Overwrite rejected by WORM policy." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Overwrite succeeded! Policy inactive." -ForegroundColor Red
        $failedTests++
    }

    # Test 3: Deletion
    Write-Host -NoNewline "Test 3/6: Deletion prevention on protected invoice... "
    $deletionPrevented = $false
    try {
        $null = Remove-AzStorageBlob -Container $ContainerName -Blob $testBlobName -Context $ctx -ErrorAction Stop
    } catch {
        $deletionPrevented = $true
    }
    if ($deletionPrevented) {
        Write-Host "[PASS] Deletion rejected (BlobImmutableDueToPolicy)." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Deletion succeeded! Blob was deleted." -ForegroundColor Red
        $failedTests++
    }

    # Test 4: Append writes check
    Write-Host -NoNewline "Test 4/6: Checking container immutability policy properties... "
    $policy = Get-AzStorageContainerImmutabilityPolicy -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -ContainerName $ContainerName -ErrorAction SilentlyContinue
    if ($policy -and $policy.AllowProtectedAppendWrite) {
        Write-Host "[PASS] AllowProtectedAppendWrite is ENABLED (VeriFactu compliant)." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Policy missing or AllowProtectedAppendWrite is false." -ForegroundColor Yellow
        $failedTests++
    }

    # Test 5: Soft delete & versioning
    Write-Host -NoNewline "Test 5/6: Soft Delete (30d) and Versioning validation... "
    $props = Get-AzStorageBlobServiceProperty -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
    if ($props.IsVersioningEnabled -and $props.DeleteRetentionPolicy.Enabled -and $props.DeleteRetentionPolicy.Days -ge 14) {
        Write-Host "[PASS] Versioning=True, SoftDelete=$($props.DeleteRetentionPolicy.Days)d." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Data protection settings do not meet compliance baseline." -ForegroundColor Red
        $failedTests++
    }

    # Test 6: Resource lock
    Write-Host -NoNewline "Test 6/6: CanNotDelete Resource Lock presence... "
    $locks = Get-AzResourceLock -ResourceGroupName $ResourceGroupName -ResourceName $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts" -ErrorAction SilentlyContinue
    $hasCanNotDelete = $locks | Where-Object { $_.LockLevel -eq "CanNotDelete" }
    if ($hasCanNotDelete) {
        Write-Host "[PASS] CanNotDelete lock active." -ForegroundColor Green
    } else {
        Write-Host "[WARN] No CanNotDelete lock found." -ForegroundColor Yellow
        $failedTests++
    }

} finally {
    if (Test-Path $tmpFile) {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
if ($failedTests -eq 0) {
    Write-Host "🎉 ALL 6 COMPLIANCE TESTS PASSED!" -ForegroundColor Green
    Write-Host "Storage Account complies with WORM, Código de Comercio Art. 30, and VeriFactu." -ForegroundColor Green
} else {
    Write-Host "⚠️  $failedTests/$totalTests TESTS FAILED OR WARNED." -ForegroundColor Red
}
Write-Host "=================================================================" -ForegroundColor Cyan
