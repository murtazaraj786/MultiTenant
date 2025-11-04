<#
.SYNOPSIS
    Grants required permissions to the Logic App managed identity on delegated subscriptions.

.DESCRIPTION
    This script assigns the necessary RBAC roles to the Logic App's managed identity
    on delegated customer subscriptions accessed via Azure Lighthouse.

.PARAMETER ManagedIdentityPrincipalId
    The Principal ID (Object ID) of the Logic App's managed identity.

.PARAMETER DelegatedSubscriptionId
    The subscription ID of the delegated customer tenant.

.PARAMETER DelegatedTenantId
    The tenant ID of the delegated customer.

.EXAMPLE
    .\Grant-Permissions.ps1 -ManagedIdentityPrincipalId "xxx" -DelegatedSubscriptionId "yyy" -DelegatedTenantId "zzz"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManagedIdentityPrincipalId,

    [Parameter(Mandatory = $true)]
    [string]$DelegatedSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$DelegatedTenantId
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Grant Permissions on Delegated Tenant" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Connect to the delegated tenant
Write-Host "[1/3] Connecting to delegated tenant..." -ForegroundColor Yellow
Write-Host "Tenant ID: $DelegatedTenantId" -ForegroundColor Gray

try {
    $context = Get-AzContext
    if ($context.Tenant.Id -ne $DelegatedTenantId) {
        Connect-AzAccount -Tenant $DelegatedTenantId
    }
    
    Set-AzContext -SubscriptionId $DelegatedSubscriptionId -TenantId $DelegatedTenantId | Out-Null
    Write-Host "Connected successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to delegated tenant." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Assign Microsoft Sentinel Contributor role
Write-Host ""
Write-Host "[2/3] Assigning 'Microsoft Sentinel Contributor' role..." -ForegroundColor Yellow

try {
    $scope = "/subscriptions/$DelegatedSubscriptionId"
    
    # Check if role assignment already exists
    $existingAssignment = Get-AzRoleAssignment `
        -ObjectId $ManagedIdentityPrincipalId `
        -RoleDefinitionName "Microsoft Sentinel Contributor" `
        -Scope $scope `
        -ErrorAction SilentlyContinue
    
    if ($existingAssignment) {
        Write-Host "Role already assigned!" -ForegroundColor Green
    } else {
        New-AzRoleAssignment `
            -ObjectId $ManagedIdentityPrincipalId `
            -RoleDefinitionName "Microsoft Sentinel Contributor" `
            -Scope $scope | Out-Null
        
        Write-Host "Role assigned successfully!" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to assign role." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Assign Log Analytics Reader role (optional but recommended)
Write-Host ""
Write-Host "[3/3] Assigning 'Log Analytics Reader' role..." -ForegroundColor Yellow

try {
    $scope = "/subscriptions/$DelegatedSubscriptionId"
    
    # Check if role assignment already exists
    $existingAssignment = Get-AzRoleAssignment `
        -ObjectId $ManagedIdentityPrincipalId `
        -RoleDefinitionName "Log Analytics Reader" `
        -Scope $scope `
        -ErrorAction SilentlyContinue
    
    if ($existingAssignment) {
        Write-Host "Role already assigned!" -ForegroundColor Green
    } else {
        New-AzRoleAssignment `
            -ObjectId $ManagedIdentityPrincipalId `
            -RoleDefinitionName "Log Analytics Reader" `
            -Scope $scope | Out-Null
        
        Write-Host "Role assigned successfully!" -ForegroundColor Green
    }
} catch {
    Write-Host "Warning: Failed to assign Log Analytics Reader role." -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Permissions granted successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Managed Identity: $ManagedIdentityPrincipalId" -ForegroundColor White
Write-Host "  Delegated Tenant: $DelegatedTenantId" -ForegroundColor White
Write-Host "  Delegated Subscription: $DelegatedSubscriptionId" -ForegroundColor White
Write-Host "  Roles Assigned:" -ForegroundColor White
Write-Host "    - Microsoft Sentinel Contributor" -ForegroundColor Gray
Write-Host "    - Log Analytics Reader" -ForegroundColor Gray
Write-Host ""
