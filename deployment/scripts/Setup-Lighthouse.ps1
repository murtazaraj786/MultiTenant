<#
.SYNOPSIS
    Helper script to validate Azure Lighthouse delegations.

.DESCRIPTION
    This script checks and displays information about Azure Lighthouse delegations,
    helping you verify that customer tenants are properly delegated to your service
    provider tenant.

.PARAMETER SubscriptionId
    Optional. Specific subscription ID to check. If not provided, checks all accessible subscriptions.

.EXAMPLE
    .\Setup-Lighthouse.ps1
    .\Setup-Lighthouse.ps1 -SubscriptionId "xxx-xxx-xxx"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Azure Lighthouse Delegation Checker" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure PowerShell module is installed
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Host "Az.Accounts module not found. Please install it first." -ForegroundColor Red
    Write-Host "Run: Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force" -ForegroundColor Yellow
    exit 1
}

# Connect to Azure
Write-Host "[1/3] Connecting to Azure..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Connect-AzAccount
    $context = Get-AzContext
}

Write-Host "Connected as: $($context.Account.Id)" -ForegroundColor Green
Write-Host "Current Tenant: $($context.Tenant.Id)" -ForegroundColor Green
Write-Host ""

# Get delegated subscriptions
Write-Host "[2/3] Checking for delegated subscriptions..." -ForegroundColor Yellow

if ($SubscriptionId) {
    $subscriptions = Get-AzSubscription -SubscriptionId $SubscriptionId
} else {
    $subscriptions = Get-AzSubscription
}

Write-Host "Found $($subscriptions.Count) accessible subscription(s)" -ForegroundColor Green
Write-Host ""

# Check each subscription for delegation details
Write-Host "[3/3] Analyzing delegations..." -ForegroundColor Yellow
Write-Host ""

$delegatedCount = 0
$subscriptionDetails = @()

foreach ($sub in $subscriptions) {
    Write-Host "Subscription: $($sub.Name)" -ForegroundColor Cyan
    Write-Host "  ID: $($sub.Id)" -ForegroundColor Gray
    Write-Host "  Tenant: $($sub.TenantId)" -ForegroundColor Gray
    
    # Check if this is a delegated subscription (tenant different from current context)
    if ($sub.TenantId -ne $context.Tenant.Id) {
        Write-Host "  Status: DELEGATED via Lighthouse" -ForegroundColor Green
        $delegatedCount++
        
        $subscriptionDetails += [PSCustomObject]@{
            Name = $sub.Name
            SubscriptionId = $sub.Id
            TenantId = $sub.TenantId
            State = $sub.State
            IsDelegated = $true
        }
    } else {
        Write-Host "  Status: Local subscription" -ForegroundColor Yellow
        
        $subscriptionDetails += [PSCustomObject]@{
            Name = $sub.Name
            SubscriptionId = $sub.Id
            TenantId = $sub.TenantId
            State = $sub.State
            IsDelegated = $false
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Total Subscriptions: $($subscriptions.Count)" -ForegroundColor White
Write-Host "Delegated Subscriptions: $delegatedCount" -ForegroundColor White
Write-Host ""

if ($delegatedCount -gt 0) {
    Write-Host "Delegated Subscriptions for Sentinel Sync:" -ForegroundColor Green
    $subscriptionDetails | Where-Object { $_.IsDelegated } | Format-Table -AutoSize
    
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Update config/tenants.json with these subscription details" -ForegroundColor White
    Write-Host "2. Ensure each delegated subscription has a Sentinel workspace" -ForegroundColor White
    Write-Host "3. Grant permissions using Grant-Permissions.ps1 for each delegated subscription" -ForegroundColor White
} else {
    Write-Host "No delegated subscriptions found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To set up Azure Lighthouse delegations:" -ForegroundColor Cyan
    Write-Host "1. Have customers deploy Azure Lighthouse delegation templates" -ForegroundColor White
    Write-Host "2. Customers must grant 'Microsoft Sentinel Contributor' role" -ForegroundColor White
    Write-Host "3. Documentation: https://docs.microsoft.com/azure/lighthouse/how-to/onboard-customer" -ForegroundColor White
}

Write-Host ""

# Export to JSON for easy config file creation
if ($delegatedCount -gt 0) {
    $exportPath = Join-Path $PSScriptRoot "..\..\config\discovered-tenants.json"
    
    $exportData = @{
        discoveredAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        delegatedTenants = @($subscriptionDetails | Where-Object { $_.IsDelegated } | ForEach-Object {
            @{
                tenantId = $_.TenantId
                subscriptionId = $_.SubscriptionId
                tenantName = $_.Name
                resourceGroup = "UPDATE-ME"
                workspaceName = "UPDATE-ME"
                enabled = $false
                description = "Discovered via Azure Lighthouse"
            }
        })
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportPath -Encoding UTF8
    Write-Host "Discovered delegations exported to: $exportPath" -ForegroundColor Green
    Write-Host "Review and update resource group and workspace names, then merge with tenants.json" -ForegroundColor Yellow
}
