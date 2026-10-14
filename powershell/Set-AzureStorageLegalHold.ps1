<#
.SYNOPSIS
    Applies or removes a Legal Hold on an Azure Blob Storage container for AEAT tax audits.

.DESCRIPTION
    A Legal Hold freezes container deletion indefinitely, independent of time-based retention.
    Used when tax audits or judicial investigations require preservation beyond standard statutory windows.

.PARAMETER ResourceGroupName
    Name of the Resource Group.

.PARAMETER StorageAccountName
    Name of the Storage Account.

.PARAMETER ContainerName
    Name of the container (e.g., facturas).

.PARAMETER Tag
    Unique identifier for the legal hold (e.g., aeat-expediente-2026).

.PARAMETER Clear
    Switch to clear/remove the specified legal hold tag.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "facturas",

    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [Parameter(Mandatory = $false)]
    [switch]$Clear
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Clear) {
    Write-Host "Removing Legal Hold '$Tag' from container '$ContainerName'..." -ForegroundColor Yellow
    Clear-AzStorageContainerLegalHold `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -Name $ContainerName `
        -Tag $Tag | Out-Null
    Write-Host "✓ Legal hold removed." -ForegroundColor Green
} else {
    Write-Host "Applying Legal Hold '$Tag' to container '$ContainerName'..." -ForegroundColor Cyan
    Set-AzStorageContainerLegalHold `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -Name $ContainerName `
        -Tag $Tag | Out-Null
    Write-Host "✓ Legal hold active. Container is frozen against deletion." -ForegroundColor Green
}
