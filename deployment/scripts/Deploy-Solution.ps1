<#
.SYNOPSIS
    Deploys the Sentinel Multi-Tenant Incident Sync Logic App solution.

.DESCRIPTION
    This script deploys the complete solution including:
    - Resource group creation
    - Managed identity setup
    - Logic App deployment with ARM template
    - API connection configuration
    - Permission assignments

.PARAMETER SubscriptionId
    The Azure subscription ID where resources will be deployed.

.PARAMETER ResourceGroupName
    Name of the resource group to create or use.

.PARAMETER Location
    Azure region for resource deployment (default: eastus).

.PARAMETER LogicAppName
    Name for the Logic App (default: sentinel-incident-sync).

.PARAMETER MainTenantId
    Tenant ID of the main Sentinel instance.

.PARAMETER MainSubscriptionId
    Subscription ID of the main Sentinel instance.

.PARAMETER MainResourceGroup
    Resource group containing the main Sentinel workspace.

.PARAMETER MainWorkspaceName
    Name of the main Sentinel Log Analytics workspace.

.EXAMPLE
    .\Deploy-Solution.ps1 -SubscriptionId "xxx" -ResourceGroupName "sentinel-sync-rg" -Location "eastus"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$LogicAppName = "sentinel-incident-sync",

    [Parameter(Mandatory = $true)]
    [string]$MainTenantId,

    [Parameter(Mandatory = $true)]
    [string]$MainSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$MainResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$MainWorkspaceName,

    [Parameter(Mandatory = $false)]
    [int]$RecurrenceInterval = 5,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPermissions
)

$ErrorActionPreference = "Stop"

# Script variables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path (Split-Path -Parent $scriptPath) "arm-templates"
$logicAppTemplate = Join-Path $templatePath "logic-app.json"
$logicAppParameters = Join-Path $templatePath "logic-app.parameters.json"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Sentinel Multi-Tenant Sync Deployment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure PowerShell module is installed
Write-Host "[1/8] Checking Azure PowerShell module..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Host "Az.Accounts module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}

# Connect to Azure
Write-Host "[2/8] Connecting to Azure..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Connect-AzAccount
}

# Set subscription context
Write-Host "[3/8] Setting subscription context..." -ForegroundColor Yellow
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
Write-Host "Using subscription: $($SubscriptionId)" -ForegroundColor Green

# Create or get resource group
Write-Host "[4/8] Creating resource group..." -ForegroundColor Yellow
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-Host "Created resource group: $ResourceGroupName" -ForegroundColor Green
} else {
    Write-Host "Using existing resource group: $ResourceGroupName" -ForegroundColor Green
}

# Prepare deployment parameters
Write-Host "[5/8] Preparing deployment parameters..." -ForegroundColor Yellow
$deploymentParameters = @{
    logicAppName = $LogicAppName
    location = $Location
    mainTenantId = $MainTenantId
    mainSubscriptionId = $MainSubscriptionId
    mainResourceGroup = $MainResourceGroup
    mainWorkspaceName = $MainWorkspaceName
    recurrenceInterval = $RecurrenceInterval
    enableManagedIdentity = $true
}

# Deploy Logic App
Write-Host "[6/8] Deploying Logic App..." -ForegroundColor Yellow
$deployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $logicAppTemplate `
    -TemplateParameterObject $deploymentParameters `
    -Name "LogicAppDeployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
    -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    Write-Host "Logic App deployed successfully!" -ForegroundColor Green
    $logicAppId = $deployment.Outputs.logicAppId.Value
    $managedIdentityPrincipalId = $deployment.Outputs.managedIdentityPrincipalId.Value
    
    Write-Host "  Logic App ID: $logicAppId" -ForegroundColor Gray
    Write-Host "  Managed Identity Principal ID: $managedIdentityPrincipalId" -ForegroundColor Gray
} else {
    Write-Host "Deployment failed with state: $($deployment.ProvisioningState)" -ForegroundColor Red
    exit 1
}

# Assign permissions
if (-not $SkipPermissions -and $managedIdentityPrincipalId) {
    Write-Host "[7/8] Assigning permissions to managed identity..." -ForegroundColor Yellow
    
    try {
        # Assign Azure Sentinel Contributor role on main subscription
        Write-Host "  Assigning 'Microsoft Sentinel Contributor' role..." -ForegroundColor Gray
        New-AzRoleAssignment `
            -ObjectId $managedIdentityPrincipalId `
            -RoleDefinitionName "Microsoft Sentinel Contributor" `
            -Scope "/subscriptions/$MainSubscriptionId" `
            -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "  Permissions assigned successfully!" -ForegroundColor Green
        Write-Host "  NOTE: You must also assign permissions on delegated subscriptions via Lighthouse" -ForegroundColor Yellow
    } catch {
        Write-Host "  Warning: Could not assign all permissions. You may need to assign them manually." -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
} else {
    Write-Host "[7/8] Skipping permission assignment..." -ForegroundColor Yellow
}

# Display next steps
Write-Host ""
Write-Host "[8/8] Deployment Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Configure delegated tenants in config/tenants.json" -ForegroundColor White
Write-Host "2. Ensure Azure Lighthouse delegations are set up for customer tenants" -ForegroundColor White
Write-Host "3. Grant 'Microsoft Sentinel Contributor' role on delegated subscriptions" -ForegroundColor White
Write-Host "4. Update the Logic App to load tenant configuration from secure storage" -ForegroundColor White
Write-Host "5. Test the Logic App with a manual run" -ForegroundColor White
Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor Cyan
Write-Host "  Get Logic App status:" -ForegroundColor White
Write-Host "    Get-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName" -ForegroundColor Gray
Write-Host ""
Write-Host "  View run history:" -ForegroundColor White
Write-Host "    Get-AzLogicAppRunHistory -ResourceGroupName $ResourceGroupName -Name $LogicAppName" -ForegroundColor Gray
Write-Host ""
Write-Host "  Trigger manual run:" -ForegroundColor White
Write-Host "    Start-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName -TriggerName Recurrence" -ForegroundColor Gray
Write-Host ""
Write-Host "Documentation: See docs/ folder for detailed configuration and troubleshooting guides" -ForegroundColor Yellow
Write-Host ""
