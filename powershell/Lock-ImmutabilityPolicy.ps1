<#
.SYNOPSIS
    Permanently locks a WORM immutability policy on an Azure Blob Storage container.

.DESCRIPTION
    WARNING: THIS OPERATION IS IRREVERSIBLE.
    Once locked, neither the Subscription Owner nor Microsoft Azure Support can unlock or delete it.

.PARAMETER ResourceGroupName
    Name of the Resource Group.

.PARAMETER StorageAccountName
    Name of the Storage Account.

.PARAMETER ContainerName
    Name of the container (e.g., facturas, pedidos).

.PARAMETER Force
    Skip interactive confirmation.
#>

#Requires -Version 7.2
#Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.15.0" }, @{ ModuleName="Az.Storage"; ModuleVersion="5.11.0" }

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Red
Write-Host "⚠️  CRITICAL WARNING: PERMANENT WORM POLICY LOCK INITIATED       ⚠️" -ForegroundColor Red
Write-Host "=================================================================" -ForegroundColor Red
Write-Host "Target Storage Account: $StorageAccountName" -ForegroundColor Yellow
Write-Host "Target Container:       $ContainerName" -ForegroundColor Yellow
Write-Host "Resource Group:         $ResourceGroupName" -ForegroundColor Yellow
Write-Host ""
Write-Host "ONCE LOCKED: Invoices cannot be altered or removed for the retention duration." -ForegroundColor Red
Write-Host "=================================================================" -ForegroundColor Red

# Fetch current policy
$policy = Get-AzStorageContainerImmutabilityPolicy `
    -ResourceGroupName $ResourceGroupName `
    -StorageAccountName $StorageAccountName `
    -ContainerName $ContainerName

if (-not $policy) {
    throw "No immutability policy found on container '$ContainerName'."
}

Write-Host "Current State:    $($policy.State)" -ForegroundColor Yellow
Write-Host "Retention Period: $($policy.ImmutabilityPeriodSinceCreationInDays) days" -ForegroundColor Yellow

if ($policy.State -eq "Locked") {
    Write-Host "`n✓ Policy is ALREADY LOCKED. No action needed." -ForegroundColor Green
    return
}

if (-not $Force) {
    $confirm = Read-Host "`nTo confirm permanent legal lock, type 'CONFIRM-LEGAL-LOCK'"
    if ($confirm -ne "CONFIRM-LEGAL-LOCK") {
        Write-Host "Operation cancelled by user. Policy remains UNLOCKED." -ForegroundColor Yellow
        return
    }
}

if ($PSCmdlet.ShouldProcess($ContainerName, "Lock Immutability Policy Permanently")) {
    Lock-AzStorageContainerImmutabilityPolicy `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -ContainerName $ContainerName `
        -ETag $policy.ETag | Out-Null

    Write-Host "`n=================================================================" -ForegroundColor Green
    Write-Host "🔒 Container '$ContainerName' is now permanently LOCKED in WORM mode!" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
}
