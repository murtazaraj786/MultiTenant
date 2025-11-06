#!/usr/bin/env pwsh

# Deploy Remote-to-Central Sentinel Logic App
# Deploy this in each REMOTE tenant to send incidents TO your central Sentinel

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$RemoteInstanceName,
    
    [Parameter(Mandatory=$true)]
    [string]$CentralSubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$CentralResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$CentralWorkspace,
    
    [Parameter(Mandatory=$false)]
    [string]$LogicAppName = "remote-to-central-sync"
)

Write-Host "🏢 Deploying Remote-to-Central Sentinel Logic App" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Remote Instance: $RemoteInstanceName" -ForegroundColor Cyan
Write-Host "Central Target: $CentralWorkspace" -ForegroundColor Cyan

# Check if logged in
$context = Get-AzContext
if (-not $context) {
    Write-Host "❌ Please login first: Connect-AzAccount" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Logged in as: $($context.Account.Id)" -ForegroundColor Green

# Check resource group
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "❌ Resource group '$ResourceGroupName' not found" -ForegroundColor Red
    $create = Read-Host "Create it? (y/n)"
    if ($create -eq 'y') {
        New-AzResourceGroup -Name $ResourceGroupName -Location "East US"
        Write-Host "✅ Created resource group" -ForegroundColor Green
    } else {
        exit 1
    }
}

# Deploy
Write-Host "🔨 Deploying Logic App..." -ForegroundColor Yellow

try {    
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "remote-to-central.json" `
        -logicAppName $LogicAppName `
        -centralSentinel @{
            subscriptionId = $CentralSubscriptionId
            resourceGroup = $CentralResourceGroup  
            workspace = $CentralWorkspace
        } `
        -remoteInstanceName $RemoteInstanceName `
        -Verbose
    
    Write-Host "✅ DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    Write-Host "Logic App: $($deployment.Outputs.logicAppName.Value)" -ForegroundColor White
    Write-Host "Remote Instance: $($deployment.Outputs.remoteInstance.Value)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Go to Azure Portal → $ResourceGroupName → $LogicAppName" -ForegroundColor White  
Write-Host "2. Go to API connections → azuresentinel → Authorize" -ForegroundColor White
Write-Host "3. Sign in with account that has access to BOTH:" -ForegroundColor White
Write-Host "   - This remote Sentinel workspace (to read incidents)" -ForegroundColor Gray
Write-Host "   - Central Sentinel workspace (to create incidents)" -ForegroundColor Gray
Write-Host "4. Test by creating incident in this remote Sentinel" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Deploy this same Logic App in each remote tenant!" -ForegroundColor Green
Write-Host ""
Write-Host "📖 Example for next remote tenant:" -ForegroundColor Yellow
Write-Host "   .\deploy-remote.ps1 ``" -ForegroundColor White
Write-Host "     -ResourceGroupName 'rg-remote-tenant-2' ``" -ForegroundColor White
Write-Host "     -RemoteInstanceName 'Remote-Tenant-2' ``" -ForegroundColor White
Write-Host "     -CentralSubscriptionId '$CentralSubscriptionId' ``" -ForegroundColor White
Write-Host "     -CentralResourceGroup '$CentralResourceGroup' ``" -ForegroundColor White
Write-Host "     -CentralWorkspace '$CentralWorkspace'" -ForegroundColor White