#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Deploys the Sentinel Incident Sync Logic App with RBAC permissions

.DESCRIPTION
    This script:
    1. Deploys the Logic App ARM template
    2. Automatically assigns required RBAC permissions to the Managed Identity
    3. Outputs the Logic App details

.PARAMETER ResourceGroupName
    The resource group where the Logic App will be deployed

.PARAMETER TemplateFile
    Path to the ARM template file (default: deploy-final.json)

.PARAMETER ParametersFile
    Path to the parameters file (default: deploy-final.parameters.json)

.EXAMPLE
    .\Deploy-Final.ps1 -ResourceGroupName "rg-uks-sentinel"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "deploy-final.json",

    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "deploy-final.parameters.json"
)

$ErrorActionPreference = "Stop"

# Check if logged in to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        throw "Not logged in"
    }
    Write-Host "✓ Connected to Azure as: $($context.Account.Id)" -ForegroundColor Green
}
catch {
    Write-Host "⚠ Please login to Azure first" -ForegroundColor Yellow
    Connect-AzAccount
}

# Ensure resource group exists
Write-Host "`n📁 Checking resource group..." -ForegroundColor Cyan
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "⚠ Resource group '$ResourceGroupName' not found. Please create it first." -ForegroundColor Red
    exit 1
}
Write-Host "✓ Resource group exists: $ResourceGroupName" -ForegroundColor Green

# Deploy the Logic App
Write-Host "`n🚀 Deploying Logic App..." -ForegroundColor Cyan
try {
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -Verbose

    Write-Host "✓ Logic App deployed successfully!" -ForegroundColor Green
    
    $logicAppName = $deployment.Outputs.logicAppName.Value
    $principalId = $deployment.Outputs.managedIdentityPrincipalId.Value
    
    Write-Host "`nLogic App Details:" -ForegroundColor Yellow
    Write-Host "  Name: $logicAppName"
    Write-Host "  Managed Identity Principal ID: $principalId"
}
catch {
    Write-Host "✗ Deployment failed: $_" -ForegroundColor Red
    exit 1
}

# Wait for Managed Identity to propagate
Write-Host "`n⏳ Waiting 30 seconds for Managed Identity to propagate..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Load parameters to get workspace details
Write-Host "`n🔐 Assigning RBAC permissions..." -ForegroundColor Cyan
$params = Get-Content $ParametersFile | ConvertFrom-Json

$remoteWorkspaces = $params.parameters.remoteWorkspaces.value
$centralSubId = $params.parameters.centralSubscriptionId.value
$centralRg = $params.parameters.centralResourceGroup.value
$centralWs = $params.parameters.centralWorkspace.value

# Sentinel Reader role (for remote workspaces)
$sentinelReaderRole = "8d289c81-5878-46d4-8554-54e1e3d8b5cb"
# Sentinel Contributor role (for central workspace)
$sentinelContributorRole = "ab8e14d6-4a74-4a29-9ba8-549422addade"

# Assign Reader to remote workspaces
foreach ($workspace in $remoteWorkspaces) {
    $scope = "/subscriptions/$($workspace.subscriptionId)/resourceGroups/$($workspace.resourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($workspace.workspace)"
    
    Write-Host "  → Assigning Sentinel Reader to: $($workspace.name)" -ForegroundColor Gray
    try {
        New-AzRoleAssignment `
            -ObjectId $principalId `
            -RoleDefinitionId $sentinelReaderRole `
            -Scope $scope `
            -ErrorAction SilentlyContinue | Out-Null
        Write-Host "    ✓ Done" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "    ✓ Already assigned" -ForegroundColor Yellow
        }
        else {
            Write-Host "    ✗ Failed: $_" -ForegroundColor Red
        }
    }
}

# Assign Contributor to central workspace
$centralScope = "/subscriptions/$centralSubId/resourceGroups/$centralRg/providers/Microsoft.OperationalInsights/workspaces/$centralWs"
Write-Host "  → Assigning Sentinel Contributor to: $centralWs" -ForegroundColor Gray
try {
    New-AzRoleAssignment `
        -ObjectId $principalId `
        -RoleDefinitionId $sentinelContributorRole `
        -Scope $centralScope `
        -ErrorAction SilentlyContinue | Out-Null
    Write-Host "    ✓ Done" -ForegroundColor Green
}
catch {
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "    ✓ Already assigned" -ForegroundColor Yellow
    }
    else {
        Write-Host "    ✗ Failed: $_" -ForegroundColor Red
    }
}

Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
Write-Host "`n📋 Summary:" -ForegroundColor Yellow
Write-Host "  Logic App: $logicAppName"
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Managed Identity: $principalId"
Write-Host "  Status: Ready to sync incidents"
Write-Host "`n💡 The Logic App will run every 5 minutes automatically."
Write-Host "   View run history in Azure Portal to monitor syncs." -ForegroundColor Cyan
